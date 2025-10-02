# CI/CD: Dev environment (GitHub Actions → Ansible → Docker)

The development environment is automatically deployed with every push to the dev branch using GitHub Actions, Ansible, and Docker Compose.

## Trigger

* **When:** on `push` to `dev`
* **Where:** GitHub Actions workflow

## Workflow (`.github/workflows/deploy-dev.yml`)

## Required GitHub Secrets

* `SSH_HOST` – target VM hostname/IP
* `SSH_USER` – SSH username on target VM
* `SSH_KEY` – private key with access to the target VM

## Ansible Playbook (`ansible/update_compose.yml`)

**Purpose:** install Docker (official repo) + Compose v2, sync repo to the server, write `.env`, and run `docker compose up -d --build`.

Key steps:

1. Install base packages, add Docker apt repo, update cache.
2. Install `docker.io` and `docker-compose-plugin`; enable and start Docker.
3. Add SSH user to `docker` group.
4. Ensure `rsync` and project directory exist.
5. **Sync code** from the workflow runner to `${project_dir}` via `rsync`.
6. Create `.env` with variables for Compose substitution.
7. Run `docker compose up -d --build`.


## Variables (overridable via `-e`)

* `project_dir` (default `/opt/test365`) – remote deploy path
* `app_color` (default `#00c853`) – passed to app via `.env`
* `host_port` (default `3001`) – host port published by Compose

## Expectations on Target VM

* Ubuntu-based system with outbound internet access.
* SSH access for `SSH_USER` using `SSH_KEY`.

## Manual Run (optional)

From your workstation with Ansible installed:

```bash
ansible-playbook -i ansible/inventory.ci.ini ansible/update_compose.yml \
  -e project_dir=/opt/test365 -e app_color="#00c853" -e host_port=3001
```

## Troubleshooting

* **SSH/Host key** errors: ensure `SSH_HOST`, `SSH_USER`, `SSH_KEY` are correct and host reachable.
* **Docker repo** issues: verify network/DNS and that Ubuntu codename matches Docker’s supported releases.
* **File sync** problems: check `rsync` is installed and that `${project_dir}` is writable.



# CI/CD: Prod environment (Main → Server `git pull` → `script/deploy.sh`)

This section describes how PROD is deployed from the `main` branch on the server using the provided Bash script.

## Trigger & Flow

* **Branch:** `main`
* **On server:** pull latest code, then run `script/deploy.sh`
* **Script does:**

  * Ensures **Nginx**, **Docker**, **Docker Compose v2** are installed.
  * Builds/starts containers via `docker compose`.
  * Configures **Nginx** from a template and reloads it.
  * Runs post-deploy health checks (HTTPS + SSL expiry).

## Prerequisites (on server)

* Valid TLS certs from **Certbot**:

  * `/etc/letsencrypt/live/<domain>/fullchain.pem`
  * `/etc/letsencrypt/live/<domain>/privkey.pem`
* Basic Auth file: `/etc/nginx/.htpasswd`
* Nginx template present at `template/nginx.conf.template` with placeholders:

  * `__DOMAIN__` and `__HOST_PORT__`

> The script will **exit** if certs or `.htpasswd` are missing.

## How to Deploy

```bash
# 1) SSH to the PROD server
ssh <user>@<host>

# 2) Go to the repo and pull main
cd /home/azureuser/test365
git fetch origin
git checkout main
git pull --ff-only origin main

# 3) Run the deploy script (branch + domain)
cd script
sudo bash deploy.sh branch your.domain.com
```

## Nginx Template Notes

* Source: `template/nginx.conf.template`
* Destination: `/etc/nginx/sites-available/<domain>.conf` (symlinked to `sites-enabled/`)
* Placeholders replaced:

  * `__DOMAIN__` → your FQDN
  * `__HOST_PORT__` → `3002` (for PROD)

## Troubleshooting

* **Certs/Auth missing:** create with `certbot` and `htpasswd` before redeploying.
* **Nginx test fails:** check generated conf at `/etc/nginx/sites-available/<domain>.conf` and run `sudo nginx -t`.
* **Containers not starting:** check `docker compose ps` and `docker compose logs -f`.
* **Wrong branch deployed:** ensure you ran `git pull` and passed `main` to the script.

## Rollback (quick)

```bash
# Revert code and redeploy
cd script
sudo bash deploy.sh branch your.domain.com
```
