#! /bin/bash

OURNAME=13_install_local_ssl_certs.sh

echo -e "\n-- Executing ${ORANGE}${OURNAME}${NC} subscript --"

#### SSL CERTS ####

# Create certificates directory if it doesn't exist
mkdir -p /etc/wildduck/certs

# Install mkcert if not already installed
if ! command -v mkcert &> /dev/null; then
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y libnss3-tools
        wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
        chmod +x /usr/local/bin/mkcert
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        yum install -y nss-tools
        wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
        chmod +x /usr/local/bin/mkcert
    else
        echo "Unsupported distribution. Please install mkcert manually."
        exit 1
    fi
fi

# Install local CA
mkcert -install

# Generate certificates for the hostname
mkcert -key-file /etc/wildduck/certs/privkey.pem \
       -cert-file /etc/wildduck/certs/fullchain.pem \
       "$HOSTNAME" "*.$HOSTNAME" "localhost" "127.0.0.1"

# WildDuck TLS config
echo 'cert="/etc/wildduck/certs/fullchain.pem"
key="/etc/wildduck/certs/privkey.pem"' > /etc/wildduck/tls.toml

sed -i -e "s/key=/#key=/g;s/cert=/#cert=/g" /etc/zone-mta/interfaces/feeder.toml
echo '# @include "../../wildduck/tls.toml"' >> /etc/zone-mta/interfaces/feeder.toml

# vanity script as first run should not restart anything
echo '#!/bin/bash
echo "OK"' > /usr/local/bin/reload-services.sh
chmod +x /usr/local/bin/reload-services.sh

# Update site config
echo "server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $HOSTNAME;

    ssl_certificate /etc/wildduck/certs/fullchain.pem;
    ssl_certificate_key /etc/wildduck/certs/privkey.pem;

    # special config for EventSource to disable gzip
    location /api/events {
        proxy_http_version 1.1;
        gzip off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header HOST \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass http://127.0.0.1:3000;
        proxy_redirect off;
    }

    # special config for uploads
    location /webmail/send {
        client_max_body_size 15M;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header HOST \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass http://127.0.0.1:3000;
        proxy_redirect off;
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header HOST \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass http://127.0.0.1:3000;
        proxy_redirect off;
    }
}" > "/etc/nginx/sites-available/$HOSTNAME"

# Create symlink if it doesn't exist
if [ ! -f "/etc/nginx/sites-enabled/$HOSTNAME" ]; then
    ln -s "/etc/nginx/sites-available/$HOSTNAME" "/etc/nginx/sites-enabled/$HOSTNAME"
fi

#See issue https://github.com/nodemailer/wildduck/issues/83
$SYSTEMCTL_PATH start nginx
$SYSTEMCTL_PATH reload nginx