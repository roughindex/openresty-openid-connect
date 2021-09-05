FROM registry.access.redhat.com/ubi7/ubi-minimal:latest as base
# dnsmasq comes from Centos due to a UBI issue (it doesn't exist in the RHEL7 repo)
# The centos mirror is enabled only for the duration of installing dnsmasq
RUN curl -L -o openresty.rpm https://openresty.org/package/rhel/7/x86_64/openresty-1.19.3.1-1.el7.x86_64.rpm && \
    curl -L -o openresty-zlib.rpm https://openresty.org/package/rhel/7/x86_64/openresty-zlib-1.2.11-3.el7.x86_64.rpm && \
    curl -L -o openresty-pcre.rpm https://openresty.org/package/rhel/7/x86_64/openresty-pcre-8.44-1.el7.x86_64.rpm && \
    curl -L -o openresty-ssl111.rpm https://openresty.org/package/rhel/7/x86_64/openresty-openssl111-1.1.1i-1.el7.x86_64.rpm && \
    rpm -i openresty-zlib.rpm && \
    rpm -i openresty-pcre.rpm && \
    rpm -i openresty-ssl111.rpm && \
    rpm -i openresty.rpm --nodeps && \
    rm *.rpm && \
    microdnf update && \
    microdnf install vi openssl gettext && \ 
    printf "[centos-7]\nname = centos-7\nbaseurl = https://www.mirrorservice.org/sites/mirror.centos.org/7/os/\$basearch\nenabled = 1\ngpgcheck = 0" > /etc/yum.repos.d/centos.repo && \
    microdnf install dnsmasq && \ 
    rm -f /etc/yum.repos.d/centos.repo && \
    microdnf clean all && \
    rpm --rebuilddb

from base as builder
RUN microdnf install git unzip gcc openssl-devel && \
    curl -LO https://luarocks.org/releases/luarocks-3.7.0.tar.gz && \
    tar -xf luarocks-3.7.0.tar.gz && \
    cd luarocks-3.7.0 && \
    ./configure --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 &&\
    make && make install && \
    luarocks install shell-games && \
    luarocks install lua-resty-http && \
    luarocks install lua-resty-auto-ssl && \
    luarocks install lua-resty-session && \
    luarocks install lua-resty-jwt && \
    luarocks install luacrypto OPENSSL_INCDIR=/usr/include && \
    luarocks install lua-resty-hmac && \
    luarocks install lua-resty-openidc

from base 
COPY --from=builder /luarocks-3.7.0 .
COPY server.crt /etc/nginx/server.crt
COPY server.key /etc/nginx/server.key
COPY auth.lua .

COPY *.conf /usr/local/openresty/nginx/conf/
COPY start .
RUN printf "daemon off;\nmaster_process off;\nerror_log  stderr  info;\n" >> /usr/local/openresty/nginx/conf/nginx.conf && \ 
    groupadd --gid 1000 dnsmasq && \
    groupadd --gid 1001 openresty && \
    useradd -r -M --uid 1000 --gid 1000 --home /etc/dnsmasq.d dnsmasq && \
    useradd    -M --uid 1001 --gid 1001 --home /usr/local/openresty/nginx openresty && \
    chown -R openresty /usr/local/openresty/nginx && \
    chown -R openresty /etc/nginx && \
    mkdir -p /var/log/nginx && \
    chown -R openresty /var/log/nginx

STOPSIGNAL SIGQUIT
EXPOSE 80/tcp
EXPOSE 443/tcp
CMD ["/bin/sh", "start"]
