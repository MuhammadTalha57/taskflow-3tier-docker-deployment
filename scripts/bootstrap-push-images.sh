#!/usr/bin/env bash
# One-time bootstrap: build both images locally and push them to Amazon ECR
# BEFORE the Auto Scaling Groups are created, so the very first EC2 instances
# have something to pull. After this, the GitHub Actions pipeline takes over.
#
# Prerequisites: AWS CLI logged in (aws sts get-caller-identity works), Docker
# running, and the ECR repos created (terraform apply -target=aws_ecr_repository.repo ...).
#
# Usage (from repo root, Git Bash / Linux / macOS):
#   bash scripts/bootstrap-push-images.sh [region]
set -euo pipefail

REGION="${1:-ap-south-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
TAG="bootstrap-$(git rev-parse --short HEAD 2>/dev/null || date +%s)"

echo "==> Logging in to ${REGISTRY}"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for svc in backend frontend; do
  echo "==> Building taskflow-${svc}"
  docker build --platform linux/amd64 -t "${REGISTRY}/taskflow-${svc}:${TAG}" -t "${REGISTRY}/taskflow-${svc}:latest" "./${svc}"
  docker push "${REGISTRY}/taskflow-${svc}:${TAG}"
  docker push "${REGISTRY}/taskflow-${svc}:latest"
done

echo "==> Done. Images in ECR:"
for svc in backend frontend; do
  aws ecr describe-images --region "$REGION" --repository-name "taskflow-${svc}" \
    --query 'imageDetails[].imageTags' --output text
done
echo "Instances will start with tag 'latest' (initial value of SSM parameter /taskflow/image-tag)."
