# Pi-hole Docker for WD My Cloud EX4100

Compatibility build of the official [`pi-hole/docker-pi-hole`](https://github.com/pi-hole/docker-pi-hole) image for the WD My Cloud EX4100 (`linux/arm/v7`).

## Why this build exists

The EX4100 runs kernel `4.14.22-armada-18.09.3`. On this device:

- Alpine `3.17.10` runs correctly.
- Alpine `3.18+` exits immediately with code `139`.
- Current official Pi-hole images use a newer Alpine base.

This project keeps the official Pi-hole Docker source and applies only the compatibility changes required by the EX4100:

1. Pin Alpine to `3.17.10`.
2. Replace Alpine package `procps-ng` with `procps`.
3. Normalize shell scripts to Unix LF endings.
4. Build only for `linux/arm/v7`.
5. Publish a single-platform image without provenance or SBOM metadata for older Docker engines.

## Image

Default target:

```text
ovelayos/pihole-wd-ex4100:2026.07.2-ex4100-r4
```

This is an unofficial compatibility build. Pi-hole itself remains the upstream project.

## Local build from Windows

Requirements:

- Docker Desktop with Buildx
- Git
- PowerShell 7

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\build-and-push.ps1 `
  -DockerHubUser ovelayos `
  -PiholeTag 2026.07.2
```

The script clones the exact upstream tag, applies the compatibility patch, builds `linux/arm/v7`, runs smoke tests and pushes the image.

## First deployment: diagnostic stack

Deploy [`compose/diagnostic.yml`](compose/diagnostic.yml) first. It does not use persistent volumes and maps DNS to port `8053`, so it can run alongside an existing Pi-hole.

Web interface:

```text
http://EX4100_IP:8081/admin/
```

Follow logs:

```sh
docker logs -f pihole-ex4100-diag
```

## Production deployment

Only after the diagnostic container stays running:

1. Stop the old Pi-hole container.
2. Back up its `/etc/pihole` data.
3. Edit the host paths and password in [`compose/production.yml`](compose/production.yml).
4. Deploy the production stack.
5. Point clients or the router to the EX4100 IP on DNS port 53.

Do not mount the original Pi-hole directory directly during the first migration test. Copy it to a new directory so rollback remains possible.

## NTP warning

Pi-hole may log:

```text
Insufficient permissions to set system time (CAP_SYS_TIME required)
```

This does not prevent DNS or the web interface from working. `SYS_TIME` is intentionally not granted.

## Security and maintenance

Alpine 3.17 is end-of-life. This image is a compatibility workaround for legacy NAS hardware and should be isolated and updated carefully. The long-term safer option is to run Pi-hole on a maintained host or virtual machine.

## Docker Hub automation

The GitHub Actions workflow expects these repository secrets:

- `DOCKERHUB_USERNAME` — normally `ovelayos`
- `DOCKERHUB_TOKEN` — a Docker Hub access token

Run the workflow manually and provide the upstream Pi-hole tag to publish.
