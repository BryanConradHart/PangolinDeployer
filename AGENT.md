# Pangolin Deployment Agent

This agent helps create headless Pangolin deployments using Docker Compose.

## Source of Truth

All Pangolin deployment configurations are based on the official documentation:
- **Primary:** https://docs.pangolin.net/self-host/manual/docker-compose.md
- **Config reference:** https://docs.pangolin.net/self-host/advanced/config-file.md
- **Installer source:** https://github.com/fosrl/pangolin/tree/main/install/main.go

The **installer source** is particularly important because it contains the logic for collecting user configuration and generating config files. This script is the combination of our GitHub page and deployer image - it does everything we want, except it must be manually executed in the host environment.

**Our goal is to functionally recreate the installer**, except that rather than producing an installed Pangolin instance, we generate the runtime values needed to wire up a static docker-compose template with the deployer image.

### Installer Non-Interactive Mode

The Pangolin installer (source: `install/main.go` and `install/input.go`) has a limited non-interactive mode that activates when:
- Running with piped input (CI/automation)
- `TERM=dumb` is set
- `ACCESSIBLE` env var is set

However, this only simplifies the prompts - it still requires runtime input. There is **no** CLI flag support to pass all config upfront. This confirms our approach to recreate the installer's functionality via:
1. GitHub page to collect config (replaces interactive prompts)
2. Deployer container to generate configs at runtime (what the installer does)

## Deployment Approach

This project provides two components:

1. **GitHub Page Generator** - Interactive form that outputs a static docker-compose template and generates a `stack.env` file with the necessary configuration values.
2. **Deployer Docker Image** - Auto-generates config files from environment variables when the compose file is deployed.

### Smoke Test Strategy

The deployer image is covered by pytest smoke tests in `deployer/tests/test_smoke.py`.
Those tests are intentionally local-friendly:

- they build the deployer image from `deployer/Dockerfile` if it is missing,
- they validate generated files exist,
- they verify no unresolved `${...}` placeholders remain,
- they parse generated YAML with PyYAML,
- they verify a second idempotent run succeeds when `/config` already exists.

CI runs the same smoke tests in `.github/workflows/deployer-smoke-ci.yml`.

## Key Constraints

- Users should be able to use the github page to generate a static compose template and a `stack.env` file for deployment.
- When generating the env file, users should be able to skip sensitive data (certificates, secrets) and fill them in manually later.
- Deployer must run first to generate any missing config files, and complete before any other services start (use `condition: service_completed`).
- Deployment should be completely headless and idempotent.
- Everything needed should be self-contained in the compose template plus the generated `.env`.
- Redeploying should not reset the pangolin deployment if the user has set up anything through the app itself.