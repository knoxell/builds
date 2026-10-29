# Custom Container Builds

Automated GitHub Actions pipelines to build, patch, and publish multi-architecture container images (`linux/amd64`, `linux/arm64`) to the GitHub Container Registry (GHCR) without maintaining hard forks of upstream projects.

---

## Published Images & Pipelines

| Image Package (GHCR) | Published Tags | Upstream Source | Branch / PR | Notes | Workflow |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`ghcr.io/knoxell/nginx-full`](https://github.com/users/knoxell/packages/container/package/nginx-full) | `certbot`, `certbot-node` | [docker-nginx-full](https://github.com/NginxProxyManager/docker-nginx-full) | [PR 41](https://github.com/NginxProxyManager/docker-nginx-full/pull/41)  | Base image dependency | [build-nginxproxymanager.yml](.github/workflows/build-nginxproxymanager.yml) |
| [`ghcr.io/knoxell/nginx-proxy-manager`](https://github.com/users/knoxell/packages/container/package/nginx-proxy-manager) | `latest` | [nginx-proxy-manager](https://github.com/NginxProxyManager/nginx-proxy-manager) | `master` | Built with [`ghcr.io/knoxell/nginx-full:certbot-node`](https://github.com/users/knoxell/packages/container/package/nginx-full) as base | [build-nginxproxymanager.yml](.github/workflows/build-nginxproxymanager.yml) |


---

## How It Works

Each pipeline operates as an orchestration harness:
1. Clones target upstream repositories at specific branches, tags, or pull request references (`refs/pull/<id>/head`).
2. Compiles dependencies or base images in sequence using Docker Buildx and Bake.
3. Rewires image tags and Dockerfile base layers dynamically during the workflow run.
4. Publishes final multi-arch manifests directly to GHCR.

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── build-nginxproxymanager.yml # Builds base nginx-full (PR 41) + nginx-proxy-manager master
│       └── <future-builds>.yml          # Additional build pipelines
└── README.md
```
