#!/bin/bash
# configure-conan.sh — Create a Conan-hosted repository in Nexus.
#
# Usage: bash deploy/ec2/nexus/configure-conan.sh [NEXUS_URL] [ADMIN_PASSWORD]
#
# Waits for Nexus to be ready, then creates a Conan repository via REST API.
# This only needs to run once after first Nexus startup.

set -euo pipefail

NEXUS_URL="${1:-http://localhost:8081}"
ADMIN_PASSWORD="${2:-}"

echo "[INFO] Configuring Nexus Conan repository at ${NEXUS_URL}..."

# ---- Wait for Nexus to be ready ----
echo "[INFO] Waiting for Nexus to start..."
MAX_RETRIES=60
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "${NEXUS_URL}/service/rest/v1/status" > /dev/null 2>&1; then
        echo "[INFO] Nexus is ready."
        break
    fi
    if [ "$i" -eq "$MAX_RETRIES" ]; then
        echo "[ERROR] Nexus did not start within $(( MAX_RETRIES * 5 ))s"
        exit 1
    fi
    sleep 5
done

# ---- Get initial admin password if not provided ----
if [ -z "$ADMIN_PASSWORD" ]; then
    # Try to read from Nexus container
    ADMIN_PASSWORD=$(docker exec matlab-nexus cat /nexus-data/admin.password 2>/dev/null || echo "")

    if [ -z "$ADMIN_PASSWORD" ]; then
        echo "[WARN] Could not read initial admin password."
        echo "[WARN] If this is not a fresh install, the default password may have been changed."
        echo "[WARN] Trying 'admin123' as the password..."
        ADMIN_PASSWORD="admin123"
    else
        echo "[INFO] Read initial admin password from Nexus."

        # Change the default password to admin123 for demo convenience
        echo "[INFO] Setting admin password to 'admin123'..."
        curl -sf -X PUT "${NEXUS_URL}/service/rest/v1/security/users/admin/change-password" \
            -u "admin:${ADMIN_PASSWORD}" \
            -H "Content-Type: text/plain" \
            -d "admin123" || echo "[WARN] Password change failed (may already be set)"
        ADMIN_PASSWORD="admin123"
    fi
fi

# ---- Create Conan-hosted repository ----
echo "[INFO] Creating conan-hosted repository..."

REPO_EXISTS=$(curl -sf -o /dev/null -w "%{http_code}" \
    -u "admin:${ADMIN_PASSWORD}" \
    "${NEXUS_URL}/service/rest/v1/repositories/conan/hosted/conan-hosted" 2>/dev/null || echo "000")

if [ "$REPO_EXISTS" = "200" ]; then
    echo "[INFO] Repository 'conan-hosted' already exists. Skipping."
else
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        -X POST "${NEXUS_URL}/service/rest/v1/repositories/conan/hosted" \
        -u "admin:${ADMIN_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "conan-hosted",
            "online": true,
            "storage": {
                "blobStoreName": "default",
                "strictContentTypeValidation": true,
                "writePolicy": "ALLOW"
            }
        }' 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "[INFO] Repository 'conan-hosted' created successfully."
    else
        echo "[WARN] Repository creation returned HTTP ${HTTP_CODE}."
        echo "[WARN] It may already exist or Nexus may not support Conan format."
        echo "[WARN] You can create it manually at ${NEXUS_URL}/#admin/repository/repositories"
    fi
fi

# ---- Enable Conan Bearer Token Realm (required for Conan 2 auth) ----
echo "[INFO] Enabling Conan Bearer Token Realm..."
curl -sf -X PUT "${NEXUS_URL}/service/rest/v1/security/realms/active" \
    -u "admin:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '["NexusAuthenticatingRealm","ConanToken"]' \
    > /dev/null 2>&1 || echo "[WARN] Could not enable Conan Bearer Token Realm"

# ---- Enable anonymous access (demo convenience) ----
echo "[INFO] Enabling anonymous access for demo..."
curl -sf -X PUT "${NEXUS_URL}/service/rest/v1/security/anonymous" \
    -u "admin:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{"enabled": true, "userId": "anonymous", "realmName": "NexusAuthorizingRealm"}' \
    > /dev/null 2>&1 || echo "[WARN] Could not enable anonymous access"

echo ""
echo "[INFO] Nexus configuration complete."
echo "[INFO] Conan repository URL: ${NEXUS_URL}/repository/conan-hosted/"
echo "[INFO] Admin credentials: admin / admin123"
