#!/bin/sh
set -e

# Ensure NGINX and TFTP use the provided configurations
if [ -f /config/nginx.conf ]; then
    cp /config/nginx.conf /etc/nginx/nginx.conf
else
    echo "No custom nginx.conf found, using default."
    cp /etc/nginx/nginx.conf /config/nginx.conf 
fi

if [ ! -f /images/boot.ipxe ]; then
    cp /etc/boot.ipxe /images/boot.ipxe
fi

# Start TFTP
/usr/sbin/in.tftpd -L --secure /var/lib/tftpboot &

# Start NGINX in foreground mode
exec nginx -g "daemon off;"
