import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml

DEFAULT_IMAGE = "pangolin-deployer:smoke-test"
IMAGE = os.environ.get("DEPLOYER_TEST_IMAGE", DEFAULT_IMAGE)
REPO_ROOT = Path(__file__).resolve().parents[2]
DEPLOYER_DIR = REPO_ROOT / "deployer"


def image_exists(image):
    return subprocess.run(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def build_image(image):
    print(f"Building Docker image {image} from {DEPLOYER_DIR}")
    subprocess.run(
        ["docker", "build", "-t", image, str(DEPLOYER_DIR)],
        check=True,
    )


@pytest.fixture(scope="module")
def tmp_config_dir():
    dirpath = tempfile.mkdtemp()
    yield Path(dirpath)
    shutil.rmtree(dirpath)


@pytest.fixture(scope="module")
def deployer_image():
    if not image_exists(IMAGE):
        build_image(IMAGE)
    return IMAGE


def run_deployer(image, config_path):
    subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "-e",
            "DOMAIN=ci.example.test",
            "-e",
            "DASHBOARD_URL=https://ci.example.test/dashboard",
            "-e",
            "LETSENCRYPT_EMAIL=ci@example.test",
            "-v",
            f"{config_path}:/config",
            image,
        ],
        check=True,
    )


def assert_files_exist(config_path):
    assert (config_path / "config.yml").exists() or (config_path / "config.yaml").exists()
    assert (config_path / "traefik" / "traefik_config.yml").exists()
    assert (config_path / "traefik" / "dynamic_config.yml").exists()


def assert_no_placeholders(config_path):
    for path in config_path.rglob("*.yml"):
        text = path.read_text()
        assert "${" not in text, f"Unreplaced placeholder found in {path}"


def assert_server_secret(config_path):
    text = (config_path / "config.yml").read_text()
    assert "secret:" in text


def assert_yaml_valid(config_path):
    for path in [
        config_path / "config.yml",
        config_path / "traefik" / "traefik_config.yml",
        config_path / "traefik" / "dynamic_config.yml",
    ]:
        with path.open() as stream:
            yaml.safe_load(stream)


def test_generate_config(tmp_config_dir, deployer_image):
    run_deployer(deployer_image, tmp_config_dir)
    assert_files_exist(tmp_config_dir)
    assert_no_placeholders(tmp_config_dir)
    assert_server_secret(tmp_config_dir)
    assert_yaml_valid(tmp_config_dir)


def test_idempotent_run(tmp_config_dir, deployer_image):
    run_deployer(deployer_image, tmp_config_dir)
    assert_files_exist(tmp_config_dir)
