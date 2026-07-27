# Centralized Identity Provider with Keycloak

A self-hosted Identity and Access Management (IAM) deployment demonstrating
the identity foundation of a Zero Trust architecture: a Keycloak IdP issuing
signed JWTs that carry both **who** a user is and **what group** they belong
to, consumed by a real OpenID Connect client application.

## What is this, in plain terms?

Think of "Sign in with Google" on any website. When you click it, the site
sends you *away* to Google's own login page, you enter your password *there*,
and Google sends you back already signed in — the site itself never sees
your password.

This project builds that same idea, but self-hosted:

| Role in the analogy | This project |
|---|---|
| "Sign in with Google" login page | **Keycloak** — the Identity Provider (IdP), running in Docker at `localhost:9090` |
| The website you actually wanted to use | **The client app** — a small ASP.NET Core app at `localhost:5000` |
| Your Google account + its permissions | **Users and groups** configured inside Keycloak (`alice`/Admins, `bob`/Developers, `carol`/Auditors) |

Keycloak never hands the app your password — it hands back a signed,
tamper-proof token (a JWT) that says who you are **and** which group you're
in. The client app trusts that token completely and shows you a different
screen depending on your group — an Admin Dashboard, Developer Tools, or an
Audit Log — without ever checking a password itself. That's the whole point
of a centralized identity provider: one place handles "who is this," and
every other app just trusts the signed result.

## Project Structure

```
keycloak-idp-project/
├── docker-compose.yml          # Milestone 2: deploys Keycloak + Postgres
├── setup/
│   └── configure-keycloak.sh   # Milestones 3, 4, 5: realm/groups/users/client/mapper/MFA
├── client-app/                 # Milestone 4/6: ASP.NET Core OIDC relying party (test client)
│   ├── ztna-app.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   ├── Properties/launchSettings.json
│   └── Pages/
│       ├── Index.cshtml        # role-based screens (Admin/Developer/Auditor) + raw claims proof
│       ├── Index.cshtml.cs
│       └── _ViewImports.cshtml
└── docs/
    ├── 01-requirements-analysis.md   # Milestone 1
    ├── 06-testing-validation.md      # Milestone 6
    ├── 07-security-analysis.md       # Section 7
    ├── 08-advantages-limitations.md  # Section 8
    └── 09-conclusion.md              # Conclusion
```

## Prerequisites

- Docker + Docker Compose
- `python3` on your host machine, used by `configure-keycloak.sh` to parse JSON
  (no `jq` install needed)
- [.NET 8 SDK](https://dotnet.microsoft.com/download) (to run the test client app)
- `curl` (for manual testing in Milestone 6)

## Step-by-Step: Running the Whole Project

### 1. Start Keycloak (Milestone 2)

```bash
cd keycloak-idp-project
docker compose up -d
docker compose logs -f keycloak
```
Wait until you see a line like `Keycloak ... started in ...ms`, then `Ctrl+C`
out of the log tail (the containers keep running in the background).

Sanity check: `http://localhost:9090` should show the Keycloak welcome page
(the compose file maps host port `9090` → container port `8080`; adjust the
left-hand side in `docker-compose.yml` if `9090` is already taken on your
machine).

### 2. Configure the realm, users, client, and MFA (Milestones 3, 4, 5)

```bash
cd setup
chmod +x configure-keycloak.sh
./configure-keycloak.sh
```

This script is idempotent-unfriendly by design (it's meant to run once
against a fresh realm) — if you need to re-run it, either delete the realm
first from the admin console, or `docker compose down -v` to fully reset.

At the end it prints your client secret and demo user credentials, and
writes `client-app/appsettings.Development.json` automatically so the test
app picks up the real secret without you typing it in by hand.

> Windows Git Bash note: the script sets `MSYS_NO_PATHCONV=1` internally to
> stop Git Bash from mangling container-internal paths passed to `docker exec`.

### 3. Run the client app

```bash
cd ../client-app
ASPNETCORE_ENVIRONMENT=Development dotnet run --urls "http://localhost:5000"
```
Visit `http://localhost:5000` and sign in as `bob`, `carol`, or `alice`
(password `Passw0rd!` for all three):

- **bob** (Developers) → lands on a Developer Tools screen
- **carol** (Auditors) → lands on an Audit & Compliance screen
- **alice** (Admins) → prompted to enroll in MFA (scan the QR code with any
  authenticator app) before landing on an Admin Dashboard screen

Every screen has a "Show the full raw signed token" section at the bottom —
that's the actual proof the group claim is really coming from Keycloak, not
hardcoded per-user in the app.

### 4. Validate everything (Milestone 6)

Follow `docs/06-testing-validation.md` for the full checklist, including a
no-browser method to fetch and decode a token directly with `curl` + `python3`.

## Where Each Milestone Lives

| Milestone | Where |
|---|---|
| 1. Requirement Analysis and Problem Definition | `docs/01-requirements-analysis.md` |
| 2. Deploying the Keycloak Server | `docker-compose.yml` |
| 3. Groups and Users | `setup/configure-keycloak.sh` (Milestone 3 section) |
| 4. OIDC Client and Group Claim | `setup/configure-keycloak.sh` (Milestone 4 section) + `client-app/` |
| 5. Multi-Factor Authentication | `setup/configure-keycloak.sh` (Milestone 5 section) |
| 6. Testing and Validation | `docs/06-testing-validation.md` |
| 7. Security Analysis and Threat Model | `docs/07-security-analysis.md` |
| 8. Advantages, Limitations, Future Enhancements | `docs/08-advantages-limitations.md` |
| Conclusion | `docs/09-conclusion.md` |

## Resetting Everything

```bash
docker compose down -v   # wipes Postgres data + Keycloak realm config
```
