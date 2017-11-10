FROM archive.docker-registry.eecloud.nsn-net.net/ava-paas/kong-0.10.1:0.1.0
MAINTAINER Team Analytics and Data Services "team_saas@groups.nokia.com"

ARG http_s_proxy
ENV http_proxy=$http_s_proxy https_proxy=$http_s_proxy KONG_CUSTOM_PLUGINS=oidc
ENV LUA_PATH="/usr/local/share/lua/5.1/?.lua;;"

RUN yum install -y --disableplugin=fastestmirror \
                unzip \
                gcc \
                git && \
    git config --global http.proxy $http_s_proxy && \
    git config --global https.proxy $http_s_proxy && \
    git config --global url."https://".insteadOf git:// && \
    luarocks install busted && \
    luarocks install lua-resty-dns-client 0.4.0 && \
    mkdir -p /usr/local/share/lua/5.1/kong/plugins/oidc && \
    git clone https://github.com/nokia/kong-oidc.git && \
    git clone https://github.com/Mashape/kong.git && \
    cd kong && \
    git checkout 0.10.1 && \
    cd .. && \
    echo -e "\ntest-oidc:\n\t@\$(TEST_CMD) spec/03-plugins/oidc/access_spec.lua\n" >> kong/Makefile && \
    sed -i -e 's/levels.quiet/levels.debug/g' kong/spec/helpers.lua && \
    cp -vr kong/* /usr/local/share/lua/5.1/kong/ && \
    cp -v kong-oidc/kong/plugins/oidc/* /usr/local/share/lua/5.1/kong/plugins/oidc/ && \
    cp -vr kong-oidc/spec/plugins/* /usr/local/share/lua/5.1/kong/spec/03-plugins/ && \
    luarocks install lua-resty-openidc && \
    luarocks install luaunit && \
    luarocks install lua-resty-dns-client 0.4.0 && \
    ln -s /usr/local/openresty/bin/resty /usr/bin/resty && \
    yum -y --disableplugin=fastestmirror remove \
        git \
        gcc \
        wget \
        unzip \
        fipscheck \
        less \
        libedit \
        libgnome-keyring \
        perl-Error \
        perl-TermReadKey \
        rsync && \

    yum clean all && \
    rm -rf /tmp/* \
           /root/.cache \
           /root/.gitconfig


CMD make -C /usr/local/share/lua/5.1/kong test-oidc

