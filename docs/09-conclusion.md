# Conclusion

This project stood up a self-hosted Identity Provider using Keycloak and
proved out the exact mechanism Zero Trust architectures depend on: turning
"who is this user, and what groups do they belong to" into a signed,
verifiable artifact — a JWT — that any downstream system can trust without
needing to talk to a central database on every request.

Concretely, the deployment:

- Runs Keycloak in a container, backed by Postgres, as an isolated IdP.
- Defines an isolated realm (`zerotrust-realm`) with three groups
  representing different privilege levels (`Admins`, `Developers`,
  `Auditors`) and one user in each.
- Registers a real downstream application (`ztna-app`, an ASP.NET Core OIDC
  Relying Party) as a trusted client using the OpenID Connect Authorization
  Code + PKCE flow.
- Adds a custom protocol mapper so every issued token carries the user's
  group membership as a `groups` claim — the signal an identity-aware
  proxy would consume to make an access decision.
- Enforces stronger authentication (TOTP-based MFA) for the highest
  privilege group, reflecting the Zero Trust principle that trust should
  scale inversely with the blast radius of a compromised account.
- Was validated end-to-end: browser login flow, direct token inspection,
  and negative tests confirming invalid credentials and tampered tokens
  are rejected.

The result is a small but complete demonstration of centralized identity as
the foundation of Zero Trust — the same pattern that scales, with the
enhancements noted in Section 8, into how real organizations authenticate
and authorize access across dozens or hundreds of internal applications.
