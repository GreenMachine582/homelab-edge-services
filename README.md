# homelab-edge-services

![Docker Compose](https://img.shields.io/badge/Docker_Compose-2496ED?logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/Caddy-1F88C0?logo=caddy&logoColor=white)
![Pi-hole](https://img.shields.io/badge/Pi--hole-96060C?logo=pi-hole&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?logo=cloudflare&logoColor=white)
![Self-hosted](https://img.shields.io/badge/self--hosted-homelab-4A90D9)

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

Caddy backend IPs (`IP_OBSERVE`, `IP_SVC_01`, `IP_SVC_02`, `IP_SVC_03`) are injected at deploy time from Infisical — no git change needed:

1. Update the value in Infisical (`/production/network/IP_*`).
2. Deploy:

   ```
   deploy-service deploy homelab-edge-services
   ```

**Exceptions that still require a git change:**

- **cloudflared** (`configs/cloudflared/config.yml`) — the cloudflared image is distroless (no shell/envsubst); its 2 backend IPs are hardcoded. Edit the file and redeploy.
- **Pi-hole custom DNS** (`configs/pihole/custom.list`) — uses `ip_edge` (192.168.50.192, the edge node itself). If this IP changes, update every entry here and redeploy.

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
