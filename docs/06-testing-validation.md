# Milestone 6: Testing and Validation

Run these checks after `docker compose up -d` and `setup/configure-keycloak.sh`
have both completed successfully.

## 6.1 Verify the server is up

```bash
curl -s http://localhost:9090/realms/zerotrust-realm/.well-known/openid-configuration | python -m json.tool
```
Expected: a JSON document listing `authorization_endpoint`, `token_endpoint`,
`jwks_uri`, etc. If this fails, Keycloak either isn't started yet or the
realm wasn't created — check `docker compose logs keycloak`.

## 6.2 Verify groups and users via the Admin Console

1. Open `http://localhost:9090/admin/` and log in as `admin`.
2. Switch realm (top-left dropdown) to `zerotrust-realm`.
3. Go to **Groups** → confirm `Admins`, `Developers`, `Auditors` exist.
4. Go to **Users** → open `alice` → **Groups** tab → confirm she's in `Admins`.
5. Repeat for `bob` (Developers) and `carol` (Auditors).

## 6.3 Full end-to-end login test (recommended — exercises everything)

```bash
cd client-app
dotnet run
```
Then visit `http://localhost:5000`:

1. Click **Sign in with Keycloak**.
2. You're redirected to Keycloak's login page — log in as `bob` / `Passw0rd!`.
3. You're redirected back to the app, now showing:
   - Your username
   - A **group badge** reading `Developers`
   - A full claims table pulled straight from the token/session

4. Sign out, then repeat logging in as `alice` / `Passw0rd!`.
   - Because `alice` is in `Admins`, Keycloak will first force her through
     an **OTP enrollment screen** (scan the QR code with an authenticator
     app such as Google Authenticator or Authy) before completing login.
   - This is Milestone 5's group-conditional MFA in action.
   - Once logged in, her group badge should read `Admins`.

If the `groups` claim is missing or empty for any user, re-check the
protocol mapper on the `ztna-app` client (Milestone 4) — `Clients →
ztna-app → Client scopes → dedicated scope → Mappers → group-membership`.

## 6.4 Direct token inspection (no browser, useful for debugging)

Keycloak's Direct Access Grant flow lets you fetch a token straight from the
command line and decode it, without a browser round-trip:

```bash
curl -s -X POST \
  http://localhost:9090/realms/zerotrust-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=ztna-app" \
  -d "client_secret=<paste from setup script output>" \
  -d "grant_type=password" \
  -d "username=carol" \
  -d "password=Passw0rd!" \
  -d "scope=openid" | python -m json.tool
```

Take the `access_token` value from the response and decode its payload
(JWTs are base64url, unsigned inspection only — do NOT trust an undecoded
token in real code):

```bash
python -c "
import json, base64, sys
token = input('paste access_token: ').strip()
payload = token.split('.')[1]
payload += '=' * (-len(payload) % 4)
print(json.dumps(json.loads(base64.urlsafe_b64decode(payload)), indent=2))
"
```

You should see standard claims (`iss`, `sub`, `exp`, `preferred_username`)
**plus** the custom `groups` claim listing `["Auditors"]` for carol.

**Verified on this deployment (2026-07-26):** this exact flow was run for all
three users. `bob` → `groups: ["Developers"]`, `carol` → `groups: ["Auditors"]`,
both with valid signed tokens. `alice` was correctly **refused** a token
(`invalid_grant: "Account is not fully set up"`) because her `CONFIGURE_TOTP`
required action hasn't been completed yet — proof the MFA gate in Milestone 5
is actually enforced server-side, not just configured.

## 6.5 Negative tests (confirm the system fails safely)

| Test | Expected result |
|---|---|
| Log in with a wrong password | Login rejected, no token issued |
| Try the token endpoint with a wrong `client_secret` | `401 Unauthorized` / `invalid_client` |
| Tamper one character of a valid JWT's signature and try to use it | Any conformant OIDC library must reject it — signature no longer validates |
| Log in as `alice` without completing OTP setup | Blocked at the "Configure OTP" required-action screen, no token issued yet |

## 6.6 Validation checklist

- [ ] Discovery document reachable
- [ ] 3 groups created, 3 users created and each in the correct group
- [ ] Full browser login flow succeeds for a non-privileged user
- [ ] `groups` claim present and correct in the returned token
- [ ] Admin-group user is forced through MFA enrollment before token issuance
- [ ] Invalid credentials and tampered tokens are both rejected
