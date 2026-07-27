# Advantages, Limitations, and Future Enhancements

## 8.1 Advantages of a Self-Hosted IdP (Keycloak) vs. Commercial (Azure AD / Okta)

| Dimension | Keycloak (self-hosted) | Azure AD / Okta |
|---|---|---|
| Cost | Free, open-source | Per-user licensing |
| Control | Full control of data, deployment, and extension points | Vendor controls infrastructure and roadmap |
| Customization | Fully open — custom auth flows, custom mappers, custom themes | Configurable within vendor-exposed limits |
| Learning value | Forces you to understand OIDC/OAuth2 internals directly | Much is abstracted away behind a polished UI |
| Operational burden | You own uptime, patching, scaling, backups | Vendor handles availability and patching |
| Time-to-production | Slower — you build what the vendor already offers | Fast — mature, battle-tested, integrates broadly |
| Compliance certifications | You must pursue and prove them yourself | Vendor often already holds SOC2/ISO27001/etc. |

## 8.2 Limitations of the Current Implementation

- **Single-node deployment.** No high availability; if the Keycloak
  container goes down, authentication for every dependent app goes down
  with it.
- **No external identity federation.** Users are created directly in
  Keycloak rather than synced from an authoritative source like Active
  Directory or an HR system — so there are two places user lifecycle could
  drift out of sync in a real organization.
- **Manual/scripted provisioning only.** There's no self-service
  registration or automated deprovisioning tied to an HR offboarding event.
  In a real environment, a user shouldn't need someone to run a script by
  hand to lose or gain access.
- **MFA is enabled per-user, not via a true conditional authentication
  flow.** This project sets `CONFIGURE_TOTP` as a required action directly
  on the `Admins` user, which is simple but doesn't automatically apply to
  every future member added to that group. A production setup should use a
  **conditional flow with a "Condition - User Group" execution** so MFA
  requirement is driven by group membership dynamically, not per-user.
- **No downstream policy enforcement point actually deployed.** This
  project proves the IdP issues the right claims, but doesn't include an
  identity-aware proxy (e.g. oauth2-proxy, Envoy + OPA) that would actually
  *use* the `groups` claim to allow/deny requests to a real backend.

## 8.3 Future Enhancements

1. **Add a real Policy Enforcement Point (PEP).** Stand up an
   identity-aware reverse proxy in front of a sample backend service that
   reads the `groups` claim and enforces path-level authorization —
   completing the Zero Trust loop from "who are you" to "what can you
   touch."
2. **Group-based conditional MFA flow**, so MFA enforcement automatically
   applies to anyone who joins a sensitive group in the future, without a
   script needing to re-run per user.
3. **External user federation** (LDAP/AD, or a SCIM-based sync) so
   Keycloak reflects — rather than duplicates — the organization's real HR
   source of truth.
4. **TLS everywhere** and a hardened `start` (non-dev) Keycloak deployment
   behind a proper hostname, with secrets sourced from a vault rather than
   docker-compose environment variables.
5. **Ship login/audit events** to a central log store (e.g. via Keycloak's
   event listener SPI) for real detection and incident response value.
6. **High availability**: multi-node Keycloak behind a load balancer with
   a clustered/replicated Postgres backend.
