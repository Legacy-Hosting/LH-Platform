# Legacy Hosting Platform

Orchestration-repository for Legacy Hosting-plattformen. API, agent og panel beholdes som egne repositories og festes til verifiserte commits gjennom Git submodules.

## Repository-struktur

- `LH-API` — felles, versjonert API med panel- og billing-moduler.
- `LH-Agent` — nodeagent for PM2, deploy, Nginx, TLS og overvåking.
- `LH-Panel` — responsivt administrasjonspanel.
- `TEMPLATE` — gjenbrukbart Legacy Hosting-design.
- `ops` — installasjon, release, rollback, backup, Nginx og systemd.

## Kloning

```bash
git clone --recurse-submodules REPOSITORY_URL
```

For en eksisterende klone:

```bash
git submodule update --init --recursive
```

Hvis komponent-repositories er private, må hovedrepoet ha en Actions-secret kalt `SUBMODULE_TOKEN` med read-only tilgang til `LH-API`, `LH-Agent` og `LH-Panel`.

## Lokal release-port

Kjør lint fra roten, og bruk deretter kommandoene i hvert produkt:

```bash
pnpm install --frozen-lockfile
pnpm lint
pnpm --dir LH-API test
pnpm --dir LH-API typecheck
pnpm --dir LH-API build
pnpm --dir LH-Agent test
pnpm --dir LH-Agent typecheck
pnpm --dir LH-Agent build
pnpm --dir LH-Panel build
pnpm --dir LH-Panel test:e2e
```

Produksjonsprosessen og sikkerhetskravene er dokumentert i `RELEASE.md`, `SECURITY.md` og `BACKUP.md`.
