# soloist-docker (ARM64 / x86_64)

A lightweight container image for [Spotify Soloist](https://developer.spotify.com/documentation/soloist), a headless Spotify client, for **ARM64** devices (Raspberry Pi 3/4/5) and **x86_64** Linux hosts. It is designed to run efficiently on Kubernetes (k3s) or Docker Compose using the PipeWire backend on Linux.

Images are published to the GitHub Container Registry:

| Tag | Description |
| --- | --- |
| `latest` | The newest Spotify Soloist release |
| `1.3.10`, `1.3.9`, ... | A pinned Spotify Soloist release (version without the `v` prefix) |

```bash
docker pull ghcr.io/tyz/soloist-docker:latest
```

Each tag is a multi-arch image index for `linux/amd64` and `linux/arm64`. Docker, Podman and containerd select the image that matches the host architecture automatically, so the same name works on a Raspberry Pi and on an x86_64 server. To inspect the available platforms or force one:

```bash
docker buildx imagetools inspect ghcr.io/tyz/soloist-docker:latest
docker pull --platform linux/arm64 ghcr.io/tyz/soloist-docker:latest
```

A 32-bit Raspberry Pi userland reports `linux/arm/v7`, which is not published; use a 64-bit (arm64) OS.

## Requirements

- An ARM64 or x86_64 host running a 64-bit Linux distribution.
- PipeWire on the host (its PulseAudio compatibility layer also works).
- A Spotify **Premium** account and a [Spotify Soloist API key](https://developer.spotify.com/dashboard/soloist).
- The Spotify app on the same local network to pair the device.

> [!WARNING]
> Spotify Soloist builds expire 90 days after their build date; an expired build exits with code `10`. The image embeds the Soloist build that was current when it was published, so keep it updated. See [How the image is built](#how-the-image-is-built).

## Docker Compose

[docker-compose.yaml](docker-compose.yaml) is a working example. It uses host networking for Spotify Connect discovery, mounts the host PipeWire session, and keeps the pairing data in a named volume. The image is multi-arch, so the example works unchanged on ARM64 and x86_64 hosts.

1. Create a `.env` file next to the compose file:

   ```dotenv
   SOLOIST_API_KEY=your-soloist-api-key
   SOLOIST_DEVICE_NAME=Kitchen speaker
   ```

   `.env` is ignored by git; keep the API key out of the repository.

2. Start the container:

   ```bash
   docker compose up -d
   ```

3. Open the Spotify app, choose the device picker, and select the name from `SOLOIST_DEVICE_NAME`.

The Spotify Connect session is stored in the `soloist-data` volume. Keep the volume to stay paired across restarts; removing it requires pairing again.

The example mounts `/run/user/1000` and sets `XDG_RUNTIME_DIR=/run/user/1000`, assuming the audio user has uid `1000` (the default on Raspberry Pi OS). Adjust both values if your user differs. To route audio to a specific device, add `--pipewire-device <node>` to the container command.

To enable the optional WebSocket API, add `--ws 0.0.0.0:8765` to the command in `docker-compose.yaml`. The API has no authentication, so only expose it on trusted networks.

## Kubernetes

[k8s.yaml](k8s.yaml) contains a `Deployment` and a `PersistentVolumeClaim` for a single-node k3s cluster. It runs with `hostNetwork: true`, mounts the node's `/run/user/1000` directory for PipeWire, and reads the API key from a `Secret`. Container runtimes pull the image variant that matches the node architecture.

```bash
kubectl create secret generic soloist --from-literal=api-key='your-soloist-api-key'
kubectl apply -f k8s.yaml
```

The deployment uses the `Recreate` strategy because only one Soloist process may use the data directory at a time. Update the `hostPath` and `XDG_RUNTIME_DIR` values if the PipeWire user on the node is not uid `1000`.

## How the image is built

The [workflow](.github/workflows/build.yaml) runs when the `Dockerfile` or the workflow changes, on the first day of every month, and on demand. Each run:

1. Downloads the ARM64 archive and reads the newest version from `CHANGELOG.md` inside it (the first `## Release vX.Y.Z` heading).
2. Checks GHCR for an image with that version as its tag.
3. Creates `<version>` and `latest` only if the version tag does not exist yet. Two native runners build `linux/amd64` (from Spotify's `soloist_release_x86_64.tar.gz`) and `linux/arm64` (from `soloist_release_arm64.tar.gz`) in parallel, push each image by digest, and a final job combines the digests into a multi-arch manifest under both tags.

Because existing versions are skipped, Dockerfile or base-image changes are only published together with a new Soloist release. To republish the current version, delete its tag from GHCR and run the workflow again. Images published before multi-arch support only contain `linux/arm64`; delete such a tag once to republish it as a multi-arch image.

### Building locally

The Dockerfile expects the release archive for the target architecture in the build context, named after buildx's `TARGETARCH` value (`amd64` or `arm64`). Spotify's x86_64 archive is renamed to match:

```bash
# x86_64 host
curl -sfL -o soloist_release_amd64.tar.gz \
  https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz

# ARM64 host
curl -sfL -o soloist_release_arm64.tar.gz \
  https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz

docker build --build-arg SOLOIST_VERSION=1.3.10 -t soloist .
```

To build both platforms locally, download both archives and use buildx with an OCI output:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg SOLOIST_VERSION=1.3.10 \
  --output type=oci,dest=soloist.tar .
```
