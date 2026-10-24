#!/bin/bash
# set -e

# CLUSTER_NAME="iot-alassiqu"
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# echo "Script dir value: $SCRIPT_DIR"

# echo "==> [1/5] Deleting any existing cluster '${CLUSTER_NAME}'..."
# k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true

# echo "==> [2/5] Creating K3d cluster..."
# k3d cluster create "$CLUSTER_NAME" \
#     --port "8888:8888@loadbalancer" \
#     --agents 1 \
#     --wait

# echo "==> [3/5] Creating 'argocd' and 'dev' namespaces..."
# kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

# echo "==> [4/5] Installing Argo CD (stable)..."
# kubectl apply -n argocd --server-side --force-conflicts \
#     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# echo "==> Waiting for Argo CD pods to be Ready..."
# kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# echo "==> [5/5] Applying Argo CD Application..."
# kubectl apply -f "$SCRIPT_DIR/../confs/application.yaml"

# echo "        ================= Status =====================        "
# kubectl -n argocd get application iot-alassiqu 2>/dev/null || echo "  (Application will appear here shortly)"
# kubectl get pods -n dev 2>/dev/null || echo "  (pods will appear here once Argo CD syncs)"
# echo ""
# echo "  # 1 — Argo CD UI"
# echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
# echo ""
# echo "  # 2 — The App"
# echo "  kubectl -n dev port-forward svc/playground 8888:8888"
# echo ""
# echo "      ================= Setup Done =====================      "
# echo ""
# echo "=============================================================="
# echo "| Argo CD is up.                                             |"
# echo "|  URL      : https://localhost:8080                         |"
# echo "|  Username : admin                                          |"
# printf "|  Password : %-45s |\n" "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
# echo "=============================================================="
# echo ""
# echo "=============================================================="
# echo "| App is up too.                                             |"
# echo "|  URL      : http://localhost:8888                          |"
# echo "=============================================================="
# echo ""


#!/bin/bash
set -e

CLUSTER_NAME="iot-alassiqu"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> [1/5] Deleting any existing cluster '${CLUSTER_NAME}'..."
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true

echo "==> [2/5] Creating K3d cluster..."
k3d cluster create "$CLUSTER_NAME" \
    --port "8888:8888@loadbalancer" \
    --agents 1 \
    --wait

echo "==> [3/5] Creating 'argocd' and 'dev' namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

echo "==> [4/5] Installing Argo CD (stable)..."
kubectl apply -n argocd --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Waiting for Argo CD pods to be Ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "==> [5/5] Applying Argo CD Application..."
kubectl apply -f "$SCRIPT_DIR/../confs/application.yaml"

# ---------- wait for first sync ----------
echo "==> Waiting for Application to be Synced/Healthy (max 3 min)..."
SYNC_OK=0
for i in $(seq 1 90); do
    STATE=$(kubectl -n argocd get application iot-alassiqu \
        -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)
    if [ "$STATE" = "Synced Healthy" ]; then
        SYNC_OK=1
        break
    fi
    sleep 2
done

# Wait for the pod to be Ready (only if sync succeeded)
POD_OK=0
if [ "$SYNC_OK" = "1" ]; then
    echo "==> Waiting for the app pod to be Ready (max 1 min)..."
    for i in $(seq 1 30); do
        READY=$(kubectl -n dev get pods -l app=playground \
            -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || true)
        if [ "$READY" = "true" ]; then
            POD_OK=1
            break
        fi
        sleep 2
    done
fi

# Save the password once so we don't query the API twice
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "================= Status ================="
kubectl -n argocd get application iot-alassiqu 2>/dev/null || echo "  (Application not found)"
kubectl get pods -n dev 2>/dev/null || echo "  (no pods in dev yet)"
echo ""
if [ "$SYNC_OK" = "1" ] && [ "$POD_OK" = "1" ]; then
    echo "  [OK] Application Synced/Healthy, pod Ready."
else
    echo "  [WARN] Sync/Ready not confirmed within timeout."
    echo "         Check: kubectl -n argocd get applica    tion iot-alassiqu"
    echo "         Check: kubectl -n dev get pods"
fi
echo ""

echo "Before accesing Argo CD, port forward it to 8080:"
echo "  -> kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo ""
echo "=============================================================="
echo "| Argo CD is up.                                             |"
echo "|  URL      : https://localhost:8080   (after port-forward)  |"
echo "|  Username : admin                                          |"
printf "|  Password : %-46s |\n" "$ARGOCD_PASSWORD"
echo "=============================================================="
echo ""

echo ""
echo "=============================================================="
echo "| App is up too.                                             |"
echo "|  URL      : http://localhost:8888                          |"
echo "=============================================================="
echo ""

echo "Command to sed and change the app deployment yaml file from V1 to V2:"
echo "  -> sed -i 's#wil42/playground:v1#wil42/playground:v2#' deployment.yaml"
echo ""