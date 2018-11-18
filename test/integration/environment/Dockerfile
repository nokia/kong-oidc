FROM kong:0.14.1-centos

RUN yum install -y git unzip && yum clean all

RUN luarocks install kong-oidc
