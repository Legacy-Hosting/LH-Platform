# Release and incident runbook

## Release gates

1. CI must pass API tests, migration validation, typechecking, all builds, dependency audits, and responsive Playwright tests.
2. Create an annotated `vX.Y.Z` tag. The release workflow creates a checksummed immutable archive.
3. Verify the server SSH host fingerprint through the DigitalOcean console before accepting a changed key.
4. Copy the archive and checksum to `/opt/legacy-hosting/incoming`.
5. On the first installation, run `ops/scripts/configure-production.sh` interactively on the server. Never paste secrets into chat or commit them.
6. Run `ops/scripts/validate-production-env.sh /etc/legacy-hosting/api.env /etc/legacy-hosting/agent.env api-only`, then create an encrypted database backup.
7. Run `ops/scripts/deploy-release.sh ARCHIVE CHECKSUM VERSION`. The first deployment starts API and panel without an unenrolled agent.
8. Register the initial Windows Hello account with the protected bootstrap token, then remove the bootstrap-token file and `INITIAL_ADMIN_TOKEN` from `api.env`.
9. Create the node in the panel, run `configure-agent.sh` interactively with its one-time credentials, and run `activate-agent.sh`.
10. Verify API health, PM2 state, panel HTTPS, WebAuthn login, one health check, and one signed agent heartbeat.
11. Set `ALLOW_LEGACY_AGENT_SIGNATURES=false` after all agents are on v1.

For a local release candidate after all builds pass, run `ops/scripts/build-release.sh X.Y.Z`. The script uses the same archive layout as GitHub Actions.

When publishing from the multi-repository workspace, push `LH-API`, `LH-Agent`, and `LH-Panel` branches and tags first. Then push the platform repository's updated submodule references. Private component repositories require the platform secret `SUBMODULE_TOKEN` with read-only repository access.

## Rollback

Run `ops/scripts/rollback-release.sh VERSION`. Releases use additive, forward-compatible migrations; application rollback never reverses database migrations automatically. Restore a database only for confirmed data corruption and follow `BACKUP.md`.

## Incident response

1. Record the start time, affected teams, request IDs, and current release.
2. Contain: disable registration, revoke exposed tokens/sessions, or drain the affected node.
3. Preserve PM2, Nginx, API, audit, and database logs before restarting services.
4. Roll back application code if the incident began with a release.
5. Recover data only from a verified encrypted backup or DigitalOcean point-in-time recovery.
6. Document root cause, customer impact, remediation, and follow-up owners.
