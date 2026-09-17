# Release and incident runbook

## Release gates

1. CI must pass API tests, migration validation, typechecking, all builds, dependency audits, and responsive Playwright tests.
2. Create an annotated `vX.Y.Z` tag. The release workflow creates a checksummed immutable archive.
3. Verify the server SSH host fingerprint through the DigitalOcean console before accepting a changed key.
4. Copy the archive and checksum to `/opt/legacy-hosting/incoming`.
5. Run `ops/scripts/validate-production-env.sh` and create an encrypted database backup.
6. Run `ops/scripts/deploy-release.sh ARCHIVE CHECKSUM VERSION`.
7. Verify API health, PM2 state, panel HTTPS, WebAuthn login, one health check, and one signed agent heartbeat.
8. Set `ALLOW_LEGACY_AGENT_SIGNATURES=false` after all agents are on v1.

For a local release candidate after all builds pass, run `ops/scripts/build-release.sh X.Y.Z`. The script uses the same archive layout as GitHub Actions.

## Rollback

Run `ops/scripts/rollback-release.sh VERSION`. Releases use additive, forward-compatible migrations; application rollback never reverses database migrations automatically. Restore a database only for confirmed data corruption and follow `BACKUP.md`.

## Incident response

1. Record the start time, affected teams, request IDs, and current release.
2. Contain: disable registration, revoke exposed tokens/sessions, or drain the affected node.
3. Preserve PM2, Nginx, API, audit, and database logs before restarting services.
4. Roll back application code if the incident began with a release.
5. Recover data only from a verified encrypted backup or DigitalOcean point-in-time recovery.
6. Document root cause, customer impact, remediation, and follow-up owners.
