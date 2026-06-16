# PangolinDeployer

Deploy Pangolin headlessly using Docker Compose or Portainer with automatically generated configuration.

The Pangolin installer and manual Docker Compose instructions require interactive setup, which makes headless deployment in environments like Portainer difficult. This project solves that by automating config generation and providing a static compose stack template, enabling true headless deployment. It implements some—but not all—of the installer's functionality, focusing on what's needed for environment-driven compose deployments.

## Acknowledgments

This project is based on the [Pangolin installer](https://github.com/fosrl/pangolin/tree/main/install/main.go) and the Pangolin Docker Compose manual instructions. The upstream source is open source under AGPL-3, which allows reuse under compatible terms.

This project is not affiliated with the Pangolin team.

## Project Structure

```
PangolinDeployer/
├── deployer/           # Deployer Docker image
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── requirements.txt
│   └── tests/
│       └── test_smoke.py
├── github-page/       # Interactive generator
│   ├── index.html
│   └── docker-compose.yml.template
├── .github/            # CI workflows
│   └── workflows/
│       └── deployer-smoke-ci.yml
├── plan-pangolinHeadlessDeploymentSystem.md
├── AGENT.md
└── LICENSE
```

## Quick Start

1. Open https://BryanConradHart.github.io/PangolinDeployer/github-page/index.html in a browser
2. Fill in your domain and configuration
3. Download the generated `docker-compose.yml` and `stack.env`
4. Run `docker compose up -d`

## Smoke Tests

This repository includes pytest-based smoke tests for the deployer image.

- Build the deployer image locally and run the tests:
  ```bash
  docker build -t pangolin-deployer:smoke-test ./deployer
  python -m pytest
  ```
- The default test image tag is `pangolin-deployer:smoke-test`.
- You can override it with `DEPLOYER_TEST_IMAGE`:
  ```bash
  DEPLOYER_TEST_IMAGE=my-tag python -m pytest
  ```
- CI also runs the smoke tests in `.github/workflows/deployer-smoke-ci.yml`.

## Notes

- The deployer container is responsible for rendering all config files from environment variables.
