# homelab-edge-services

Network appliance tier for the `homelab-edge` node: DNS (Pi-hole + Unbound), LAN reverse proxy (Caddy), Cloudflare Tunnel (cloudflared), and supporting exporters.

Config-only repo — no custom images are built. All images are upstream.

---

## Services

| Container | Image | Purpose |
|---|---|---|
| `cloudflared` | `cloudflare/cloudflared:latest` | Cloudflare Tunnel — remote access lifeline |
| `caddy` | `caddy:2` | LAN reverse proxy (`.homelab.local` hostnames) |
| `pihole` | `pihole/pihole:latest` | LAN DNS + ad blocking |
| `pihole-exporter` | `ekofr/pihole-exporter:latest` | Pi-hole metrics for Prometheus |
| `portainer-agent` | `portainer/agent:latest` | Container management (connects to Portainer Server on homelab-observe) |

`unbound` is a host systemd service (not containerised). Pi-hole sends upstream DNS to `host.docker.internal:5335`.

---

## Deploy flow

Managed by `deploy-service` in the HomeLab repo. Secrets are injected at deploy time from Infisical — they are never written to this repo or to disk in the checkout.

```
deploy-service deploy homelab-edge-services
```

This runs `docker compose up -d --remove-orphans` on `homelab-edge`.

> **Critical:** `docker compose down` must never be called for this stack. `cloudflared` is the Cloudflare Tunnel — if it exits, the tunnel drops and remote SSH access is severed immediately. The `rolling` deploy strategy in `services.yml` enforces this.

Secrets pulled from Infisical at deploy time:

| Env var | Infisical path |
|---|---|
| `TUNNEL_TOKEN` | `/production/cloudflare/TUNNEL_TOKEN` |
| `PIHOLE_WEB_PASSWORD` | `/production/pihole/WEB_PASSWORD` |

---

## Adding a new `.homelab.local` hostname

1. Add a Caddy block to `configs/caddy/Caddyfile`:

   ```
   http://myservice.homelab.local {
       reverse_proxy <backend-ip>:<port>
   }
   ```

2. Add a DNS entry to `configs/pihole/custom.list`:

   ```
   192.168.50.192 myservice.homelab.local
   ```

   All `.homelab.local` names resolve to the edge node IP (`192.168.50.192`) — Caddy handles routing to the correct backend.

3. Deploy:

   ```
   deploy-service deploy homelab-edge-services
   ```

---

## Adding a new public Cloudflare Tunnel route

1. Create the public hostname in the Cloudflare Zero Trust dashboard (Tunnels → your tunnel → Public Hostnames).

2. Add an ingress rule to `configs/cloudflared/config.yml` **above** the wildcard catch-all:

   ```yaml
   - hostname: myservice.yourdomain.com
     service: http://<backend-ip>:<port>
   ```

3. Deploy:

   ```
   deploy-service deploy homelab-edge-services
   ```

---

## IP change procedure

When a backend node's IP changes:

1. Update the relevant `reverse_proxy` line(s) in `configs/caddy/Caddyfile`.
2. Update the relevant `service:` line(s) in `configs/cloudflared/config.yml` if the node has public tunnel routes.
3. Deploy:

   ```
   deploy-service deploy homelab-edge-services
   ```

If the edge node IP (`192.168.50.192`) changes, update every entry in `configs/pihole/custom.list` and the Caddy port binding as well.

---

## Repository structure

```
homelab-edge-services/
├── docker-compose.yml
├── .env.example
└── configs/
    ├── caddy/
    │   └── Caddyfile
    ├── cloudflared/
    │   └── config.yml
    └── pihole/
        └── custom.list
```
