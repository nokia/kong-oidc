#!/bin/bash

export LUA_VERSION=${LUA_VERSION:-5.1}
export KONG_VERSION=${KONG_VERSION:-0.11.2-0}
export LUA_RESTY_OPENIDC_VERSION=${LUA_RESTY_OPENIDC_VERSION:-1.5.3}

apt-get update
apt-get install -y unzip

pip install hererocks
hererocks lua_install -r^ --lua=${LUA_VERSION}
export PATH=${PATH}:${PWD}/lua_install/bin

luarocks install kong ${KONG_VERSION}
luarocks install lua-resty-openidc ${LUA_RESTY_OPENIDC_VERSION}
luarocks install lua-cjson
luarocks install luaunit
luarocks install luacov

lua -lluacov test/unit/test_filter.lua -o TAP --failure
lua -lluacov test/unit/test_filters_advanced.lua -o TAP --failure
lua -lluacov test/unit/test_utils.lua -o TAP --failure
lua -lluacov test/unit/test_handler_mocking_openidc.lua --failure
lua -lluacov test/unit/test_introspect.lua -o TAP --failure
lua -lluacov test/unit/test_utils_bearer_access_token.lua -o TAP --failure
