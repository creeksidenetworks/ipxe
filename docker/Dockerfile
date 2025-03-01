FROM alpine:latest
LABEL maintainer="Creekside Networks LLC"

# Install required packages
RUN apk add --no-cache tftp-hpa nginx wget

# Create necessary directories
RUN mkdir -p /config /images /var/lib/tftpboot /run/nginx

# Download iPXE boot files
RUN wget -O /var/lib/tftpboot/ipxe.efi https://boot.ipxe.org/ipxe.efi && \
    wget -O /var/lib/tftpboot/undionly.kpxe https://boot.ipxe.org/undionly.kpxe

# Copy default TFTP and NGINX configurations
COPY tftpd-hpa /etc/conf.d/tftpd-hpa
COPY nginx.conf /etc/nginx/nginx.conf
COPY boot.ipxe /etc/boot.ipxe

# Set permissions
RUN chmod -R 755 /images

# Expose volumes for configuration and images
VOLUME ["/config", "/images"]

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary ports
EXPOSE 69/udp 80/tcp

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
