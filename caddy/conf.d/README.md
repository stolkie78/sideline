# Caddy Multi-Site Configuration

Add custom `.caddy` files to this directory (`caddy/conf.d/`) to proxy requests for additional hostnames/domains to other applications or containers.

Example (`caddy/conf.d/myapp.caddy`):

```caddy
myapp.com {
    reverse_proxy myapp-container:8080
}
```
