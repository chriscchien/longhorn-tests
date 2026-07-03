#!/bin/bash

set -x

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/longhorn_namespace.sh"


longhorn_internal_networkpolicies_exist(){
  echo "Checking if Longhorn internal NetworkPolicies exist in namespace ${LONGHORN_NAMESPACE}..."

  echo "===== DEBUG inside longhorn_internal_networkpolicies_exist ====="
  echo "HOSTNAME=$(hostname)"
  echo "USER=$(id)"
  echo "KUBECONFIG=${KUBECONFIG:-<empty>}"
  which kubectl
  kubectl config current-context || true
  kubectl cluster-info || true

  echo
  echo "===== Namespace info BEFORE sleep ====="
  kubectl get ns "${LONGHORN_NAMESPACE}" -o wide || true
  kubectl get ns "${LONGHORN_NAMESPACE}" -o jsonpath='{.metadata.uid}{"\n"}' || true

  echo
  echo "===== NetworkPolicies BEFORE sleep ====="
  kubectl get networkpolicy -n "${LONGHORN_NAMESPACE}" -o wide || true
  echo "======================================="

  echo
  echo "DEBUG: sleeping 300 seconds, SSH into this container now if needed..."
  sleep 30

  echo
  echo "===== Namespace info AFTER sleep ====="
  kubectl get ns "${LONGHORN_NAMESPACE}" -o wide || true
  kubectl get ns "${LONGHORN_NAMESPACE}" -o jsonpath='{.metadata.uid}{"\n"}' || true

  echo
  echo "===== NetworkPolicies AFTER sleep ====="
  kubectl get networkpolicy -n "${LONGHORN_NAMESPACE}" -o wide || true
  echo "======================================"

  local found_manager=false
  local found_instance=false

  echo
  echo "===== CHECK NetworkPolicy: longhorn-manager ====="
  kubectl get networkpolicy longhorn-manager \
    -n "${LONGHORN_NAMESPACE}" \
    --request-timeout=300s \
    -o yaml
  local manager_rc=$?
  echo "DEBUG: manager_rc=${manager_rc}"

  if [[ "${manager_rc}" -eq 0 ]]; then
    found_manager=true
    echo "DEBUG: NetworkPolicy 'longhorn-manager' found in ${LONGHORN_NAMESPACE}"
  else
    echo "DEBUG: NetworkPolicy 'longhorn-manager' NOT found in ${LONGHORN_NAMESPACE}"
  fi

  echo
  echo "===== CHECK NetworkPolicy: instance-manager ====="
  kubectl get networkpolicy instance-manager \
    -n "${LONGHORN_NAMESPACE}" \
    --request-timeout=300s \
    -o yaml
  local instance_rc=$?
  echo "DEBUG: instance_rc=${instance_rc}"

  if [[ "${instance_rc}" -eq 0 ]]; then
    found_instance=true
    echo "DEBUG: NetworkPolicy 'instance-manager' found in ${LONGHORN_NAMESPACE}"
  else
    echo "DEBUG: NetworkPolicy 'instance-manager' NOT found in ${LONGHORN_NAMESPACE}"
  fi

  echo
  echo "===== NetworkPolicies FINAL list ====="
  kubectl get networkpolicy -n "${LONGHORN_NAMESPACE}" -o wide || true
  echo "======================================"

  echo
  echo "DEBUG: found_manager=${found_manager}"
  echo "DEBUG: found_instance=${found_instance}"

  if [[ "${found_manager}" == true && "${found_instance}" == true ]]; then
    echo "DEBUG: Both internal NetworkPolicies exist — will apply test NetworkPolicies"
    return 0
  else
    echo "DEBUG: One or both internal NetworkPolicies missing — will skip test NetworkPolicies"
    return 1
  fi
}

apply_longhorn_test_networkpolicy(){
  if ! command -v yq > /dev/null 2>&1; then
    echo "yq is required to install Longhorn test NetworkPolicies"
    exit 1
  fi

  LONGHORN_NAMESPACE="${LONGHORN_NAMESPACE}" yq e '.metadata.namespace = strenv(LONGHORN_NAMESPACE)' - <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-longhorn-test-to-manager
  namespace: longhorn-system
spec:
  podSelector:
    matchLabels:
      app: longhorn-manager
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: default
      podSelector:
        matchLabels:
          longhorn-test: test-job
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-longhorn-test-to-instance-manager
  namespace: longhorn-system
spec:
  podSelector:
    matchLabels:
      longhorn.io/component: instance-manager
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: default
      podSelector:
        matchLabels:
          longhorn-test: test-job
EOF
}

delete_longhorn_manager_networkpolicy(){
  kubectl delete networkpolicy allow-longhorn-test-to-manager allow-longhorn-test-to-instance-manager -n "${LONGHORN_NAMESPACE}" --ignore-not-found=true
}

setup_longhorn_manager_networkpolicy(){
  get_longhorn_namespace
  echo "===== DEBUG before checking NetworkPolicies ====="
  echo "HOSTNAME=$(hostname)"
  echo "USER=$(id)"
  echo "KUBECONFIG=${KUBECONFIG:-<empty>}"
  which kubectl
  kubectl config current-context || true
  kubectl cluster-info || true
  kubectl get ns "${LONGHORN_NAMESPACE}" -o wide || true
  kubectl get ns "${LONGHORN_NAMESPACE}" -o jsonpath='{.metadata.uid}{"\n"}' || true
  kubectl get networkpolicy -n "${LONGHORN_NAMESPACE}" || true
  echo "================================================="

  if longhorn_internal_networkpolicies_exist; then
    apply_longhorn_test_networkpolicy
  else
    delete_longhorn_manager_networkpolicy
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if declare -f "$1" > /dev/null; then
    "$@"
  else
    echo "Function '$1' not found"
    exit 1
  fi
fi
