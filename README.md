# gRPC-Lua
The Lua [gRPC](http://www.grpc.io/) binding.

NOT READY!

## Dependings

gRPC-Lua depends on

* [grpc_cb](https://github.com/jinq0123/grpc_cb)
* [lua-intf](https://github.com/SteveKChiu/lua-intf)
* [LuaPbIntf](https://github.com/jinq0123/LuaPbIntf)
* [lua](https://www.lua.org/)

## Build

### Init third-party
Init include and lib dir. See [third_party/README.md](third_party/README.md)

### Make
Use premake5 to generate VS solution and linux Makefile, see [premake5.bat](build/premake5.bat).

Vs2015 sln and Makefile are provided.

### Run example
See:
* [examples/helloworld/README.md](examples/helloworld/README.md)
* [examples/route_guide/README.md](examples/route_guide/README.md)
