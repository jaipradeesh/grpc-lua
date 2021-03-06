--- Service stub.
-- Wraps C `ServiceStub` class.
-- @classmod grpc_lua.client.service_stub.ServiceStub

local ServiceStub = {}

local c = require("grpc_lua.c")  -- from grpc_lua.so
local ClientAsyncReaderWriter = require("grpc_lua.client.async.ClientAsyncReaderWriter")
local ClientAsyncWriter = require("grpc_lua.client.async.ClientAsyncWriter")
local ClientSyncReader = require("grpc_lua.client.sync.ClientSyncReader")
local ClientSyncReaderWriter = require("grpc_lua.client.sync.ClientSyncReaderWriter")
local ClientSyncWriter = require("grpc_lua.client.sync.ClientSyncWriter")
local MethodInfo = require("grpc_lua.client.service_stub.MethodInfo")
local mcb_wrapper = require("grpc_lua.client.service_stub.msg_cb_wrapper")
local pb = require("luapbintf")

--- Decode response string to message table.
-- @string response_type
-- @tparam string|nil response_str
local function decode_response(response_type, response_str)
    assert("string" == type(response_type))
    if not response_str then return nil end
    assert("string" == type(response_str))
    return pb.decode(response_type, response_str)
end  -- decode_response()

-------------------------------------------------------------------------------
--- Public functions.
-- @section public

--- New `ServiceStub` object.
-- Do not call it directly, use `grpc_lua.ServiceStub(ch)` instead.
-- @tparam userdata c_channel C `Channel` object
-- @string service_name full service name like "helloworld.Greeter"
-- @treturn table `ServiceStub` object
function ServiceStub:new(c_channel, service_name)
    assert("userdata" == type(c_channel))
    local stub = {
        -- public:

        -- private:
        _c_stub = c.ServiceStub(c_channel),
        _c_channel = c_channel,

        -- Error callback for async request.
        -- `function(error_str, status_code)`
        -- nil to ignore all errors.
        _error_cb = nil,
        _timeout_sec = nil,  -- default no timeout

        _service_name = service_name,  -- full service name
        _method_info_map = {}  -- map { [method_name] = MethodInfo }
    }
    setmetatable(stub, self)
    self.__index = self
    return stub
end  -- new()

-- Todo: get_channel() to new other stub.

--- Set error callback function.
-- @func error_cb `function(error_str|nil, status_code)`
function ServiceStub:set_error_cb(error_cb)
    assert(not error_cb or "function" == type(error_cb))
    self._c_stub:set_error_cb(error_cb)
    self._error_cb = error_cb
end  -- set_error_cb()

--- Get timeout seconds.
-- @treturn number|nil timeout in seconds, nil means no timeout
function ServiceStub:get_timeout_sec()
    return self._timeout_sec
end

--- Set timeout seconds
-- @tparam number|nil timeout seconds, or nil if no timeout
function ServiceStub:set_timeout_sec(timeout_sec)
    assert(not timeout_sec or "number" == type(timeout_sec))
    self._c_stub:set_timeout_sec(timeout_sec)
    self._timeout_sec = timeout_sec
end

--- Sync request.
-- @string method_name
-- @tab request request message
-- @treturn string|(nil, string, int) response string or
-- `(nil, error_string, grpc_status_code)`.
-- @usage request("SayHello", { name = "Jq" })
function ServiceStub:sync_request(method_name, request)
    assert("table" == type(request))
    local mi = self:_get_method_info(method_name)
    mi:assert_simple_rpc()
    local request_str = pb.encode(mi.request_type, request)
    local response_str, error_str, status_code =
        self._c_stub:sync_request(mi.request_name, request_str)
    local response = decode_response(mi.response_type, response_str)
    return response, error_str, status_code
end  -- request()

--- Async request.
-- @string method_name method name
-- @tab request request message
-- @func[opt] response_cb response callback, `function(response_message_table)`
function ServiceStub:async_request(method_name, request, response_cb)
    assert("table" == type(request))
    assert(nil == response_cb or "function" == type(response_cb))
    local mi = self:_get_method_info(method_name)
    mi:assert_simple_rpc()
    local request_str = pb.encode(mi.request_type, request)
    -- Need to wrap the response callback.
    local response_str_cb = mcb_wrapper.wrap(response_cb, mi.response_type)
    self._c_stub:async_request(mi.request_name, request_str,
        response_str_cb, self._error_cb)
end  -- async_request()

--- Sync request server side streaming rpc.
-- Will return immediately.
-- @string method_name method name
-- @tab request request message
-- @treturn ClientSyncReader
function ServiceStub:sync_request_read(method_name, request)
    assert("table" == type(request))
    local mi = self:_get_method_info(method_name)
    mi:assert_server_side_streaming()
    local req_str = pb.encode(mi.request_type, request)
    return ClientSyncReader:new(self._c_channel, mi.request_name,
        req_str, mi.response_type, self._timeout_sec)
end  -- sync_request_read()

--- Async request server side streaming rpc.
-- Will return immediately.
-- The callback function msg_cb and status_cb will be called in the run().
-- @string method_name method name
-- @tab request request message
-- @tparam[opt=nil] function|nil msg_cb message callback, `function(table)`
-- @tparam[optchain=nil] function|nil status_cb status callback,
--  `function(error_str|nil, status_code)`, nil means to use self.error_cb
-- @usage
-- stub:async_request_read("ListFeatures", rect,
--   function(message) assert("table" == type(message)) end,
--   function(error_str, status_code)
--     assert(not error_str or "string" == type(error_str))
--     assert("number" == type(status_code))
--   end)
function ServiceStub:async_request_read(method_name, request, msg_cb, status_cb)
    assert("table" == type(request))
    assert(not msg_cb or "function" == type(msg_cb))
    status_cb = status_cb or self._error_cb
    assert(not status_cb or "function" == type(status_cb))
    local mi = self:_get_method_info(method_name)
    mi:assert_server_side_streaming()

    local req_str = pb.encode(mi.request_type, request)
    -- Need to wrap the message callback.
    local msg_str_cb = mcb_wrapper.wrap(msg_cb, mi.response_type)
    self._c_stub:async_request_read(mi.request_name,
        req_str, msg_str_cb, status_cb)  -- XXX timeout
end  -- async_request_read()

--- Sync request client side streaming rpc.
-- Will return immediately.
-- @string method_name method name
-- @treturn ClientSyncWriter
function ServiceStub:sync_request_write(method_name)
    local mi = self:_get_method_info(method_name)
    mi:assert_client_side_streaming()
    return ClientSyncWriter:new(self._c_channel, mi.request_name,
        mi.request_type, mi.response_type, self._timeout_sec)
end  -- sync_request_read()

--- Async request client side streaming rpc.
-- Will return immediately.
-- @string method_name method name
-- @treturn ClientAsyncWriter
function ServiceStub:async_request_write(method_name)
    local mi = self:_get_method_info(method_name)
    mi:assert_client_side_streaming()
    return ClientAsyncWriter:new(self._c_stub, mi.request_name,
        mi.request_type, mi.response_type, self._timeout_sec)
end  -- async_request_write()

--- Sync request bi-directional streaming rpc.
-- Will return immediately.
-- @string method_name method name
-- @treturn ClientSyncReaderWriter
function ServiceStub:sync_request_rdwr(method_name)
    local mi = self:_get_method_info(method_name)
    mi:assert_bidirectional_streaming()
    return ClientSyncReaderWriter:new(self._c_channel,
        mi.request_name, mi.request_type, mi.response_type, self._timeout_sec);
end  -- sync_request_rdwr()

--- Async request bi-directional streaming rpc.
-- Will return immediately.
-- @string method_name method name
-- @tparam function|nil status_cb status callback, `function(error_str|nil, status_code)`
-- @treturn ClientAsyncReaderWriter
function ServiceStub:async_request_rdwr(method_name, status_cb)
    status_cb = status_cb or self._error_cb
    assert(not status_cb or "function" == type(status_cb))
    local mi = self:_get_method_info(method_name)
    mi:assert_bidirectional_streaming()
    return ClientAsyncReaderWriter:new(self._c_stub,
        mi.request_name, mi.request_type, mi.response_type,
        self._timeout_sec, status_cb);
end  -- async_request_rdwr()

--- Blocking run.
function ServiceStub:run()
    self._c_stub:run()
end  -- run()

--- Shutdown the stub.
-- To end run().
function ServiceStub:shutdown()
    self._c_stub:shutdown()
end  -- shutdown()

-------------------------------------------------------------------------------
--- Private functions.
-- @section private

--- Get method information.
-- Load it if not.
-- @string method_name
-- @treturn MethodInfo
function ServiceStub:_get_method_info(method_name)
    local method_info = self._method_info_map[method_name]
    if method_info then return method_info end

    method_info = MethodInfo:new(self._service_name, method_name)
    self._method_info_map[method_name] = method_info
    return method_info
end  -- _get_method_info()

return ServiceStub
