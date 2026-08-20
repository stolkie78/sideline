#!/bin/sh
# Generates Caddyfile based on environment variables
# Usage: DOMAIN=setbaas.nl ENABLE_SSL=true ./generate-caddyfile.sh > /etc/caddy/Caddyfile

DOMAIN="${DOMAIN:-localhost}"
ENABLE_SSL="${ENABLE_SSL:-false}"

if [ "$ENABLE_SSL" = "true" ]; then
cat <<EOF
# SetBaas — HTTPS via Let's Encrypt
${DOMAIN} {
    handle /api/* {
        reverse_proxy pocketbase:8090
    }
    handle /_/* {
        reverse_proxy pocketbase:8090
    }
    handle {
        reverse_proxy frontend:3000
    }
}
www.${DOMAIN} {
    redir https://${DOMAIN}{uri} permanent
}
EOF
else
cat <<EOF
# SetBaas — HTTP only
:80 {
    handle /api/* {
        reverse_proxy pocketbase:8090
    }
    handle /_/* {
        reverse_proxy pocketbase:8090
    }
    handle {
        reverse_proxy frontend:3000
    }
}
EOF
fi
