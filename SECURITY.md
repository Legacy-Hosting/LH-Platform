# Security policy

## Supported releases

Only the latest `1.x` release receives security fixes. Production deployments must use an immutable tagged release, not a working tree.

## Reporting

Report vulnerabilities privately to `security@legacyhosting.xyz`. Do not include customer credentials, database dumps, access tokens, or private keys in an issue.

## Production controls

- Browser mutations require an exact allowed Origin and a session-bound CSRF token.
- Session cookies are `HttpOnly`, `Secure` in production, `SameSite=Lax`, and high priority.
- Authentication endpoints and the complete API are rate limited.
- Agent v2 requests bind timestamp, nonce, body, and node credential in an HMAC. Nonces are single-use in MySQL.
- OAuth credentials, environment secrets, and webhook secrets use AES-256-GCM at rest.
- WebAuthn challenges are short-lived and atomically consumed.
- GitHub webhooks require SHA-256 signatures and persistent delivery-id deduplication.
- Production errors return a request ID without stack traces.

## Secret rotation

1. Revoke and reconnect customer OAuth integrations from the provider when a provider credential is suspected.
2. Rotate node tokens from the panel, replace the node's protected environment value, and restart the agent.
3. Rotate `GITHUB_WEBHOOK_SECRET` in GitHub and the API environment in one maintenance window.
4. Rotate `CSRF_SECRET` by updating the API environment and restarting the API. Existing browser CSRF tokens refresh automatically.
5. `CREDENTIAL_ENCRYPTION_KEY` rotation requires a dedicated re-encryption migration. Never replace it directly while encrypted records exist.
6. Revoke all affected sessions and passkeys when an account or host is compromised.

Set `ALLOW_LEGACY_AGENT_SIGNATURES=true` only during the v1 rolling upgrade. After every node reports agent `1.0.0` or newer, set it to `false` and reload the API.
