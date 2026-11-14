# soloist-docker (ARM64 / Raspberry Pi)

A lightweight container image for [Spotify Soloist](https://developer.spotify.com/documentation/soloist), a headless Spotify client, built for **ARM64** devices (Raspberry Pi 3/4/5). It is designed to run efficiently on Kubernetes (k3s) or Docker Compose using the PipeWire backend on Linux.

Images are published to the GitHub Container Registry:

| Tag | Description |
| --- | --- |
| `latest` | The newest Spotify Soloist release |
| `1.3.10`, `1.3.9`, ... | A pinned Spotify Soloist release (version without the `v` prefix) |

```bash
docker pull ghcr.io/tyz/soloist-docker:latest
```

Only `linux/arm64` images are built.

## Requirements

- An ARM64 host running a 64-bit Linux distribution.
- PipeWire on the host (its PulseAudio compatibility layer also works).
- A Spotify **Premium** account and a [Spotify Soloist API key](https://developer.spotify.com/dashboard/soloist).
- The Spotify app on the same local network to pair the device.

> [!WARNING]
> Spotify Soloist builds expire 90 days after their build date; an expired build exits with code `10`. The image embeds the Soloist build that was current when it was published, so keep it updated. See [How the image is built](#how-the-image-is-built).

## Docker Compose

[docker-compose.yaml](docker-compose.yaml) is a working example. It uses host networking for Spotify Connect discovery, mounts the host PipeWire session, and keeps the pairing data in a named volume.

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

[k8s.yaml](k8s.yaml) contains a `Deployment` and a `PersistentVolumeClaim` for a single-node k3s cluster. It runs with `hostNetwork: true`, mounts the node's `/run/user/1000` directory for PipeWire, and reads the API key from a `Secret`.

```bash
kubectl create secret generic soloist --from-literal=api-key='your-soloist-api-key'
kubectl apply -f k8s.yaml
```

The deployment uses the `Recreate` strategy because only one Soloist process may use the data directory at a time. Update the `hostPath` and `XDG_RUNTIME_DIR` values if the PipeWire user on the node is not uid `1000`.

## How the image is built

The [workflow](.github/workflows/build-arm64.yaml) runs when the `Dockerfile` or the workflow changes, on the first day of every month, and on demand. Each run:

1. Downloads `soloist_release_arm64.tar.gz` from Spotify's build server.
2. Reads the newest version from `CHANGELOG.md` inside the archive (the first `## Release vX.Y.Z` heading).
3. Checks GHCR for an image with that version as its tag.
4. Builds and pushes `<version>` and `latest` only if the version tag does not exist yet.

Because existing versions are skipped, Dockerfile or base-image changes are only published together with a new Soloist release. To republish the current version, delete its tag from GHCR and run the workflow again.

### Building locally

The Dockerfile expects the release archive in the build context, so download it first:

```bash
curl -sfL -o soloist_release_arm64.tar.gz \
  https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz

docker build --build-arg SOLOIST_VERSION=1.3.10 -t soloist .
```
