# filepath: deployer/Dockerfile
FROM alpine:3.19

# Install required tools
RUN apk add --no-cache \
    bash \
    sed \
    coreutils \
    openssl \
    ca-certificates \
    gettext

# Create working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy templates
COPY templates /app/templates

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]