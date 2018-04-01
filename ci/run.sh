#!/bin/bash -e

export LUA_VERSION=${LUA_VERSION:-5.1}

apt-get update
apt-get install -y unzip

pip install hererocks
hererocks lua_install -r^ --lua=${LUA_VERSION}
export PATH=${PATH}:${PWD}/lua_install/bin

luarocks install kong 0.11.2-0
luarocks install lua-resty-openidc 1.5.3
luarocks install lua-cjson
luarocks install luaunit
luarocks install luacov

lua -lluacov test/unit/test_filter.lua -e -o TAP --failure
lua -lluacov test/unit/test_filters_advanced.lua -e -o TAP --failure
lua -lluacov test/unit/test_utils.lua -e -o TAP --failure
lua -lluacov test/unit/test_handler_mocking_openidc.lua -e --failure
lua -lluacov test/unit/test_introspect.lua -e -o TAP --failure
lua -lluacov test/unit/test_utils_bearer_access_token.lua -e -o TAP --failure
