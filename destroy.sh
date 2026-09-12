#!/usr/bin/env bash
# Derruba o banco. Rode ANTES do destroy.sh do oficina-infra-k8s.
set -euo pipefail
cd "$(dirname "$0")/terraform"
echo "==> terraform destroy (~10 min) — skip_final_snapshot está ligado, o banco some de vez"
terraform destroy -auto-approve
