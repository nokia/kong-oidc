ARG KONG_BASE_TAG
FROM kong${KONG_BASE_TAG}

ENV LUA_PATH /usr/local/share/lua/5.1/?.lua;/usr/local/kong-oidc/?.lua
# For lua-cjson
ENV LUA_CPATH /usr/local/lib/lua/5.1/?.so

# Install unzip for luarocks, gcc for lua-cjson
RUN echo "ip_resolve=4" >> /etc/yum.conf && yum install -y unzip gcc
# Change openidc version when version in rockspec changes
RUN luarocks install lua-resty-openidc 1.7.2-1

WORKDIR /usr/local/kong-oidc

COPY . .