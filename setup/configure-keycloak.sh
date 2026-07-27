#!/usr/bin/env bash
set -euo pipefail

# On Windows Git Bash/MSYS, paths like /opt/keycloak/bin/kcadm.sh get rewritten
# into Windows paths before reaching `docker exec`, breaking the command inside
# the Linux container. This disables that rewriting for this script.
export MSYS_NO_PATHCONV=1

# =============================================================================
# Milestones 3, 4, 5: Groups & Users | OIDC Client & Group Claim | MFA
# -----------------------------------------------------------------------------
# Prerequisites on the HOST machine (not inside the container):
#   - docker + docker compose        (Milestone 2 stack must already be up)
#   - python3                        (used to parse kcadm JSON output instead
#                                      of jq, so no extra install is required)
#
# Run this AFTER `docker compose up -d` and after Keycloak has fully started
# (check with: docker compose logs -f keycloak, wait for "started in ...").
#
# Usage:
#   chmod +x configure-keycloak.sh
#   ./configure-keycloak.sh
# =============================================================================

KC_CONTAINER="keycloak"
KC_URL="http://localhost:8080"   # kcadm runs INSIDE the container via docker exec,
                                  # so it uses the container-internal port (8080),
                                  # regardless of the host-side port mapping.
HOST_URL="http://localhost:9090" # what the HOST (browser, .NET client app, curl
                                  # from your terminal) must use -- matches the
                                  # "9090:8080" port mapping in docker-compose.yml.
ADMIN_USER="admin"
ADMIN_PASS="admin_change_me"
REALM="zerotrust-realm"
CLIENT_ID="ztna-app"
REDIRECT_URI="http://localhost:5000/signin-oidc"
APP_USER_PASSWORD="Passw0rd!"     # dev-only test password for demo users

KCADM="docker exec -i ${KC_CONTAINER} /opt/keycloak/bin/kcadm.sh"
PYJSON() { python -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }

echo "=================================================================="
echo "Milestone 3: Requirement Analysis check -> logging in as admin"
echo "=================================================================="
${KCADM} config credentials --server "${KC_URL}" --realm master \
  --user "${ADMIN_USER}" --password "${ADMIN_PASS}"

echo ""
echo "==> Creating isolated identity realm: ${REALM}"
${KCADM} create realms -s realm="${REALM}" -s enabled=true \
  -s sslRequired=external -s registrationAllowed=false \
  -s bruteForceProtected=true

echo ""
echo "=================================================================="
echo "Milestone 3: Groups and Users"
echo "=================================================================="
echo "==> Creating groups: Admins, Developers, Auditors"
${KCADM} create groups -r "${REALM}" -s name=Admins
${KCADM} create groups -r "${REALM}" -s name=Developers
${KCADM} create groups -r "${REALM}" -s name=Auditors

ADMINS_GID=$(${KCADM} get groups -r "${REALM}" -q search=Admins     | PYJSON "[0]['id']")
DEVS_GID=$(${KCADM}   get groups -r "${REALM}" -q search=Developers | PYJSON "[0]['id']")
AUDIT_GID=$(${KCADM}  get groups -r "${REALM}" -q search=Auditors   | PYJSON "[0]['id']")

echo "   Admins:     ${ADMINS_GID}"
echo "   Developers: ${DEVS_GID}"
echo "   Auditors:   ${AUDIT_GID}"

echo "==> Creating three demo users (alice=Admin, bob=Developer, carol=Auditor)"
${KCADM} create users -r "${REALM}" -s username=alice -s enabled=true -s emailVerified=true -s email=alice@example.local -s firstName=Alice -s lastName=Admin
${KCADM} create users -r "${REALM}" -s username=bob   -s enabled=true -s emailVerified=true -s email=bob@example.local   -s firstName=Bob   -s lastName=Developer
${KCADM} create users -r "${REALM}" -s username=carol -s enabled=true -s emailVerified=true -s email=carol@example.local -s firstName=Carol -s lastName=Auditor

ALICE_ID=$(${KCADM} get users -r "${REALM}" -q username=alice | PYJSON "[0]['id']")
BOB_ID=$(${KCADM}   get users -r "${REALM}" -q username=bob   | PYJSON "[0]['id']")
CAROL_ID=$(${KCADM} get users -r "${REALM}" -q username=carol | PYJSON "[0]['id']")

echo "==> Setting passwords (permanent, dev-only value -- rotate for real use)"
${KCADM} set-password -r "${REALM}" --userid "${ALICE_ID}" --new-password "${APP_USER_PASSWORD}"
${KCADM} set-password -r "${REALM}" --userid "${BOB_ID}"   --new-password "${APP_USER_PASSWORD}"
${KCADM} set-password -r "${REALM}" --userid "${CAROL_ID}" --new-password "${APP_USER_PASSWORD}"

echo "==> Assigning group membership"
${KCADM} update "users/${ALICE_ID}/groups/${ADMINS_GID}" -r "${REALM}"
${KCADM} update "users/${BOB_ID}/groups/${DEVS_GID}"      -r "${REALM}"
${KCADM} update "users/${CAROL_ID}/groups/${AUDIT_GID}"   -r "${REALM}"

echo ""
echo "=================================================================="
echo "Milestone 4: OIDC Client and Group Claim"
echo "=================================================================="
echo "==> Registering downstream application as an OIDC client: ${CLIENT_ID}"
${KCADM} create clients -r "${REALM}" \
  -s clientId="${CLIENT_ID}" \
  -s enabled=true \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=false \
  -s "redirectUris=[\"${REDIRECT_URI}\",\"http://localhost:5000/*\"]" \
  -s "webOrigins=[\"http://localhost:5000\"]"

CLIENT_UUID=$(${KCADM} get clients -r "${REALM}" -q clientId="${CLIENT_ID}" | PYJSON "[0]['id']")
echo "   Client internal id: ${CLIENT_UUID}"

CLIENT_SECRET=$(${KCADM} get "clients/${CLIENT_UUID}/client-secret" -r "${REALM}" | PYJSON "['value']")
echo "   Client secret retrieved."

echo "==> Adding group-membership mapper so JWTs carry a 'groups' claim"
${KCADM} create "clients/${CLIENT_UUID}/protocol-mappers/models" -r "${REALM}" \
  -s name=group-membership \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-group-membership-mapper \
  -s 'config."full.path"=false' \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  -s 'config."userinfo.token.claim"=true' \
  -s 'config."claim.name"=groups'

echo ""
echo "=================================================================="
echo "Milestone 5: Multi-Factor Authentication"
echo "=================================================================="
echo "==> Requiring OTP (TOTP authenticator app) setup for the Admins group"
echo "    (Zero Trust principle: higher-privilege identities get stronger auth)"
${KCADM} update "users/${ALICE_ID}" -r "${REALM}" -s 'requiredActions=["CONFIGURE_TOTP"]'

echo ""
echo "=================================================================="
echo "DONE. Save these values -- you will need them for the client app"
echo "and for Milestone 6 testing:"
echo "=================================================================="
cat <<EOF

  Realm:            ${REALM}
  Realm endpoint:    ${HOST_URL}/realms/${REALM}
  OIDC discovery:    ${HOST_URL}/realms/${REALM}/.well-known/openid-configuration
  Admin console:     ${HOST_URL}/admin/  (login: ${ADMIN_USER} / ${ADMIN_PASS})

  Client ID:         ${CLIENT_ID}
  Client secret:     ${CLIENT_SECRET}
  Redirect URI:      ${REDIRECT_URI}

  Demo users (password: ${APP_USER_PASSWORD}):
    alice  -> group: Admins      (must set up OTP on first login)
    bob    -> group: Developers
    carol  -> group: Auditors

EOF

# Write secret + config into the client app folder so it can pick it up
CONFIG_OUT="../client-app/appsettings.Development.json"
cat > "${CONFIG_OUT}" <<EOF
{
  "Keycloak": {
    "Authority": "${HOST_URL}/realms/${REALM}",
    "ClientId": "${CLIENT_ID}",
    "ClientSecret": "${CLIENT_SECRET}"
  }
}
EOF
echo "==> Wrote client app config to ${CONFIG_OUT}"
