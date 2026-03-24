#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="glaze-vision"
IMAGE_TAG="latest"

# Source .env.local if it exists (enables 1Password / secret-manager injection)
if [[ -f "$SCRIPT_DIR/.env.local" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env.local"
fi

# Auto-detect container runtime: prefer podman (open-source), fall back to docker
if command -v podman &>/dev/null; then
  RUNTIME="podman"
elif command -v docker &>/dev/null; then
  RUNTIME="docker"
else
  echo "ERROR: No container runtime found."
  echo ""
  echo "Install one of:"
  echo "  macOS:   brew install podman"
  echo "  Windows: winget install RedHat.Podman"
  echo "  Linux:   sudo apt install podman  (or dnf install podman)"
  echo ""
  echo "Docker also works but requires a commercial license for business use."
  exit 1
fi

echo "Using container runtime: $RUNTIME"

# Prompt for repo URL if not set
if [[ -z "${SNOWFLAKE_IMAGE_REPO_URL:-}" ]]; then
  echo ""
  echo "To find your image repository URL:"
  echo "  1. Run deploy_all.sql first (it creates the image repo)"
  echo "  2. In Snowsight, run: SHOW IMAGE REPOSITORIES IN SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;"
  echo "  3. Copy the repository_url column value"
  echo ""
  read -rp "Snowflake image repository URL: " SNOWFLAKE_IMAGE_REPO_URL
fi

# Extract the registry host (everything before the first /)
REGISTRY_HOST="${SNOWFLAKE_IMAGE_REPO_URL%%/*}"

# Prompt for PAT if not set
if [[ -z "${SNOWFLAKE_REGISTRY_PAT:-}" ]]; then
  echo ""
  echo "Generate a PAT in Snowsight: User menu → Programmatic Access Tokens"
  echo ""
  read -rsp "Snowflake PAT: " SNOWFLAKE_REGISTRY_PAT
  echo ""
fi

FULL_IMAGE_TAG="${SNOWFLAKE_IMAGE_REPO_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "Building image..."
$RUNTIME build -t "${IMAGE_NAME}:${IMAGE_TAG}" "$SCRIPT_DIR"

echo "Tagging as ${FULL_IMAGE_TAG}..."
$RUNTIME tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE_TAG"

echo "Authenticating to ${REGISTRY_HOST}..."
echo "$SNOWFLAKE_REGISTRY_PAT" | $RUNTIME login "$REGISTRY_HOST" \
  --username "0sessiontoken" \
  --password-stdin

echo "Pushing image..."
$RUNTIME push "$FULL_IMAGE_TAG"

echo ""
echo "Done. Image pushed to: ${FULL_IMAGE_TAG}"
echo "You can now run deploy_all.sql in Snowsight."
