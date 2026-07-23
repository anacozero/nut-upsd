# Network UPS Tools server

Docker image for a [Network UPS Tools](https://networkupstools.org/) (NUT) server.
It compiles NUT from a GPG-verified source tarball and exposes `upsd` on port
`3493` for USB-attached UPS hardware.

- Multi-architecture: `linux/amd64` and `linux/arm64` (e.g. Raspberry Pi).
- Minimal, multi-stage build — no compiler or build tooling in the final image.
- Configuration is generated at start-up from environment variables.

## Usage

```console
docker run \
    --name nut-upsd \
    --detach \
    --publish 3493:3493 \
    --device /dev/bus/usb/xxx/yyy \
    --env SHUTDOWN_CMD="my-shutdown-command-from-container" \
    ghcr.io/anacozero/nut-upsd
```

### docker compose

```yaml
services:
  nut-upsd:
    image: ghcr.io/anacozero/nut-upsd
    restart: unless-stopped
    ports:
      - "3493:3493"
    devices:
      - /dev/bus/usb:/dev/bus/usb
    environment:
      UPS_DESC: "Eaton 5SC"
      SHUTDOWN_CMD: "my-shutdown-command-from-container"
```

## Configuration

Configuration is driven by environment variables.

| Variable        | Default                                    | Description                                                                 |
| --------------- | ------------------------------------------ | --------------------------------------------------------------------------- |
| `UPS_NAME`      | `ups`                                      | Name of the UPS as seen by clients.                                         |
| `UPS_DESC`      | `UPS`                                      | Human-readable description reported to clients.                             |
| `UPS_DRIVER`    | `usbhid-ups`                               | NUT driver used to talk to the UPS.                                         |
| `UPS_PORT`      | `auto`                                     | Port the UPS is connected to (`auto` for USB).                              |
| `ADMIN_PASSWORD`| *(random)*                                 | Password for the `admin` user (full control). Randomly generated if unset.  |
| `API_PASSWORD`  | *(random)*                                 | Password for the `monitor`/`upsmon` user. Randomly generated if unset.      |
| `SHUTDOWN_CMD`  | `echo 'System shutdown not configured!'`   | Command `upsmon` runs, inside the container, when a shutdown is required.   |

### Secrets

`ADMIN_PASSWORD` and `API_PASSWORD` can instead be read from a file by setting
`ADMIN_PASSWORD_FILE` / `API_PASSWORD_FILE`. This keeps secrets out of the
container's environment (`docker inspect`) and works with Docker/Kubernetes
secrets:

```yaml
services:
  nut-upsd:
    image: ghcr.io/anacozero/nut-upsd
    environment:
      API_PASSWORD_FILE: /run/secrets/nut_api_password
    secrets:
      - nut_api_password
secrets:
  nut_api_password:
    file: ./nut_api_password.txt
```

If a password is neither set directly nor via a `*_FILE`, a random one is
generated at start-up.

## Users

The server defines two fixed accounts:

- `admin` — full administrative control (`set`, `fsd`, all instant commands).
- `monitor` — the account `upsmon` uses to monitor the UPS.

## Notes

- **USB access:** the UPS device must be passed into the container
  (`--device /dev/bus/usb/...` or by mounting `/dev/bus/usb`). The driver runs as
  the unprivileged `nut` user.
- **Health check:** the container reports healthy only while `upsd` can read the
  UPS (`upsc <UPS_NAME>@localhost`).
- **Network exposure:** `upsd` listens on `0.0.0.0:3493` without transport
  encryption. Restrict access to a trusted network.
