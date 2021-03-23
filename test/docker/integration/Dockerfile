ARG KONG_BASE_TAG
FROM kong${KONG_BASE_TAG}
USER root

ENV LUA_PATH /usr/local/share/lua/5.1/?.lua;/usr/local/kong-oidc/?.lua;;
# For lua-cjson
ENV LUA_CPATH /usr/local/lib/lua/5.1/?.so;;

# Install unzip for luarocks, gcc for lua-cjson
RUN yum install -y unzip gcc curl 
RUN luarocks install luacov
RUN luarocks install luaunit
RUN luarocks install lua-cjson

# Change openidc version when version in rockspec changes
RUN luarocks install lua-resty-openidc 1.7.4-1

COPY . /usr/local/kong-oidc
