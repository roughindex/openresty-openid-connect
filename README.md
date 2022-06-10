## How To 
### Create local certs 
    cd /usr/local/openresty/nginx/conf
    microdnf install openssl
    openssl genrsa 2048 > cert.key
    openssl req -x509 -days 1000 -new -key private.pem -out cert.pem
    # Optional cleanup
    microdnf remove openssl
    microdnf clean all

## TODO
1. Enable TLS Client Certs in openidc.call_token_endpoint