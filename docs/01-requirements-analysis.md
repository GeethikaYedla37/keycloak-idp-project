# Milestone 1: Requirement Analysis and Problem Definition

## 1.1 Problem Statement

Traditional network security relies on a perimeter: once a user or device is
"inside" the corporate network (VPN, office LAN), it is largely trusted. This
model fails against lateral movement, compromised credentials, insider
threats, and the reality of remote/hybrid work where there is no single
network perimeter left to defend.

**Zero Trust Architecture (ZTA)** replaces perimeter trust with continuous,
per-request verification: every access decision must be backed by a strong
answer to *"who is this, and what are they permitted to do?"*

That answer has to come from somewhere authoritative. This project builds
that authority: a **centralized Identity Provider (IdP)**.

## 1.2 Why Centralize Identity?

Without a centralized IdP:
- Each application manages its own user database (password sprawl, inconsistent
  policies, no single point to revoke access).
- There is no single place to enforce MFA, password policy, or account
  lockout.
- Downstream systems (proxies, gateways, apps) have no common, trustworthy
  signal of "who is this" to make policy decisions on.

With a centralized IdP:
- One realm of truth for identity and group membership.
- One place to revoke/disable a user and have it apply everywhere.
- Every downstream system consumes the same signed token format (JWT) and
  the same claims, instead of reinventing authentication.

## 1.3 Functional Requirements

| # | Requirement |
|---|-------------|
| FR1 | Deploy a self-hosted IdP server that can be reached over HTTP(S) |
| FR2 | Support multiple isolated identity domains (realms) |
| FR3 | Support creating/managing users and grouping them by role |
| FR4 | Support registering external applications as OIDC clients |
| FR5 | Issue signed JWTs (ID Token + Access Token) on successful login |
| FR6 | Embed group/role membership inside the issued token as a claim |
| FR7 | Support enforcing multi-factor authentication |
| FR8 | Allow verification/inspection of issued tokens for testing |

## 1.4 Non-Functional Requirements

| # | Requirement |
|---|-------------|
| NFR1 | Runs in a container for portability and reproducibility |
| NFR2 | Configuration should be scriptable/repeatable, not only manual clicks |
| NFR3 | Secrets (client secret, DB password) must not be hardcoded into the client app source |
| NFR4 | System should degrade safely — a downstream app should never accept an unsigned or unverifiable token |

## 1.5 Actors

- **Identity Administrator** — configures the realm, groups, users, and clients (you, via `kcadm.sh`/admin console).
- **End Users** — `alice` (Admins), `bob` (Developers), `carol` (Auditors) — represent different privilege levels.
- **Relying Party / Downstream Application** — the `ztna-app` OIDC client, standing in for any real internal application or an identity-aware proxy sitting in front of one.

## 1.6 Scope Boundaries

**In scope:** realm/user/group provisioning, OIDC client registration, group
claim propagation into JWTs, MFA enrollment for privileged users, manual
token inspection/testing.

**Out of scope (called out in Section 8 as future work):** production-grade
HA/clustering, external user federation (LDAP/AD sync), a real
identity-aware reverse proxy enforcing policy from the `groups` claim,
centralized audit log shipping.

## 1.7 Success Criteria

The project is considered functionally complete when:
1. Keycloak is running and reachable at `http://localhost:9090` (the host
   port configured in `docker-compose.yml`).
2. The `zerotrust-realm` realm exists with 3 groups and 3 users correctly assigned.
3. The `ztna-app` OIDC client can complete a full Authorization Code + PKCE
   login flow.
4. The resulting ID token contains a `groups` claim reflecting the logged-in
   user's group membership.
5. The `Admins` group user is required to enroll in TOTP-based MFA before
   completing login.
