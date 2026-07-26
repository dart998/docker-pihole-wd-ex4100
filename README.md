# Pi-hole Docker for WD My Cloud EX4100

Compatibility build of the official [`pi-hole/docker-pi-hole`](https://github.com/pi-hole/docker-pi-hole) image for the WD My Cloud EX4100 (`linux/arm/v7`).

## Why this build exists

The EX4100 runs kernel `4.14.22-armada-18.09.3`. On this device:

- Alpine `3.17.10` runs correctly.
- Alpine `3.18+` exits immediately with code `139`.
- Current official Pi-hole images use a newer Alpine base.
- Docker bridge port publishing for DNS can fail on the EX4100 even when Pi-hole works correctly inside the container.

This project keeps the official Pi-hole Docker source and applies only the compatibility changes required by the EX4100:

1. Pin Alpine to `3.17.10`.
2. Replace Alpine package `procps-ng` with `procps`.
3. Normalize shell scripts to Unix LF endings.
4. Build only for `linux/arm/v7`.
5. Publish a single-platform image without provenance or SBOM metadata for older Docker engines.
6. Use host networking in the EX4100 Portainer stack to avoid the legacy Docker DNS proxy problem.

## Image

Current image:

```text
ovelayos/pihole-wd-ex4100:2026.07.2-ex4100-r4
```

Rolling aliases:

```text
ovelayos/pihole-wd-ex4100:latest-ex4100-armv7
ovelayos/pihole-wd-ex4100:legacy-armv7
```

This is an unofficial compatibility build. Pi-hole itself remains the upstream project.

## Portainer App Template catalog

Portainer does not discover templates by scanning a Git repository. Configure the catalog using this exact URL:

```text
https://raw.githubusercontent.com/dart998/docker-pihole-wd-ex4100/main/templates.json
```

In Portainer:

1. Open **Settings**.
2. Find **App Templates** or **Template URL**.
3. Replace or add the URL above.
4. Save the settings.
5. Open **App Templates** and select **Pi-hole WD EX4100 ARMv7**.

The catalog file is:

```text
templates.json
```

It defines a Compose stack template (`type: 3`) and loads:

```text
compose/portainer-stack.yml
```

The deployment form exposes the Pi-hole password, timezone, web ports and persistent data paths. Upstream DNS servers remain configurable from the Pi-hole web interface.

## Manual Portainer Custom Template

The template can also be created manually with:

```text
Title: pihole-wd-ex4100-armv7
Repository URL: https://github.com/dart998/docker-pihole-wd-ex4100
Repository reference: refs/heads/main
Compose path: compose/portainer-stack.yml
Authentication: disabled
Skip TLS verification: disabled
```

The repository is public and does not contain passwords or Docker Hub tokens. Real secrets must be supplied through Portainer environment variables or GitHub repository secrets.

## Automatic Portainer updates

To let Portainer deploy validated Pi-hole releases automatically, create the stack using **Stacks → Add stack → Git repository** rather than from App Templates.

Use:

```text
Repository URL: https://github.com/dart998/docker-pihole-wd-ex4100
Repository reference: refs/heads/main
Compose path: compose/portainer-stack.yml
```

Enable automatic updates with:

```text
Mechanism: Polling
Fetch interval: 24h
Re-pull image: disabled
Force redeployment: disabled
```

`Re-pull image` and `Force redeployment` may appear as Business Edition features in Portainer Community Edition. They are not required by this project: each validated release receives a new immutable image tag and the workflow commits that new tag to `main`. Portainer detects the new Git commit, redeploys the stack, and Docker downloads the newly referenced image because its tag has changed.

## EX4100 deployment

The recommended stack is:

```text
compose/portainer-stack.yml
```

It uses:

```text
network_mode: host
DNS: 53/tcp and 53/udp
HTTP: 32768
HTTPS: 32769
```

The WD My Cloud web interface occupies ports 80 and 443, so Pi-hole uses the historical EX4100 web port `32768` and `32769` for HTTPS.

Web access:

```text
http://EX4100_IP:32768/admin/
https://EX4100_IP:32769/admin/
```

DNS server:

```text
EX4100_IP:53
```

## Environment variables

Copy `.env.example` or define the variables directly in Portainer.

Minimum required value:

```env
PIHOLE_PASSWORD=CAMBIA_ESTA_PASSWORD
```

Default configuration:

```env
PIHOLE_IMAGE=ovelayos/pihole-wd-ex4100:2026.07.2-ex4100-r4
CONTAINER_NAME=pihole-ex4100
HOSTNAME=pihole-ex4100
TZ=Europe/Madrid
PIHOLE_PASSWORD=CAMBIA_ESTA_PASSWORD
DNS_LISTENING_MODE=ALL
WEB_SERVER_PORTS=32768,32769s
PIHOLE_CONFIG_PATH=/shares/Volume_1/docker/pihole-ex4100/etc-pihole
DNSMASQ_CONFIG_PATH=/shares/Volume_1/docker/pihole-ex4100/etc-dnsmasq.d
```

Never commit a real `.env` file. The repository ignores `.env` and `.env.*`, except `.env.example`.

## Generic ARMv7 stack

For other ARMv7 systems where Docker bridge networking works normally, use:

```text
compose/portainer-generic.yml
```

The generic stack uses traditional port mappings and is not the recommended option for the WD EX4100.

## Why there is no Dockerfile at the repository root

The build process clones the exact official `pi-hole/docker-pi-hole` tag into `.build`, patches `.build/src/Dockerfile`, validates it and builds from the complete official source context.

The generated Dockerfile is:

```text
.build/src/Dockerfile
```

Keeping a copied Dockerfile at the repository root would drift from upstream and would not include all required source files such as `start.sh`, `bash_functions.sh` and `crontab.txt`.

## Local build from Windows

Requirements:

- Docker Desktop with Buildx
- Git
- PowerShell 7
- QEMU support through Docker Desktop

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\build-and-push.ps1 `
  -DockerHubUser ovelayos `
  -PiholeTag 2026.07.2 `
  -Revision r4
```

The script clones the exact upstream tag, applies the EX4100 compatibility patch, builds `linux/arm/v7`, validates Alpine, LF line endings and the FTL binary, and only then publishes the image.

## GitHub Actions

The build workflow checks the latest stable official Pi-hole Docker release once a day at `04:17 UTC`. It can also be started manually and runs when the build workflow or compatibility scripts change on `main`.

Required repository secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

For each new official release, the workflow:

1. Resolves and validates the latest stable official `pi-hole/docker-pi-hole` tag.
2. Skips the build when the matching EX4100 repository tag already exists.
3. Applies and validates the EX4100 compatibility patch.
4. Builds a local single-platform `linux/arm/v7` image without provenance or SBOM metadata.
5. Runs smoke tests through QEMU.
6. Pushes the versioned image and rolling aliases to Docker Hub.
7. Updates the stable image references in the Portainer stack, `.env.example` and README, then commits them to `main`.
8. Creates the repository tag only after the image has been built, tested, published and promoted successfully.

That promotion commit is what Portainer Git polling detects to update the running stack.

Repository tags use this format:

```text
<official-tag>-ex4100-r4
```

Example:

```text
2026.07.2-ex4100-r4
```

## Persistent data

The default host directories are:

```text
/shares/Volume_1/docker/pihole-ex4100/etc-pihole
/shares/Volume_1/docker/pihole-ex4100/etc-dnsmasq.d
```

Back up these directories before replacing or migrating an existing Pi-hole installation.

Do not mount the only copy of an old Pi-hole configuration during the first migration test. Work from a copy so rollback remains possible.

## Basic verification

After deployment:

```sh
docker ps --filter name=pihole-ex4100
docker logs --tail 100 pihole-ex4100
docker exec pihole-ex4100 cat /etc/alpine-release
docker exec pihole-ex4100 pihole-FTL -vv
```

Expected Alpine version:

```text
3.17.10
```

Test DNS from another device:

```powershell
nslookup google.com EX4100_IP
nslookup pi.hole EX4100_IP
```

## NTP warning

Pi-hole may log:

```text
Insufficient permissions to set system time (CAP_SYS_TIME required)
```

This warning does not prevent DNS or the web interface from working. `SYS_TIME` is intentionally not granted.

## Security and maintenance

Alpine 3.17 is end-of-life. This image is a compatibility workaround for legacy NAS hardware and should be isolated and updated carefully.

The long-term safer option is to run Pi-hole on maintained hardware, a supported virtual machine or a current Linux host.
