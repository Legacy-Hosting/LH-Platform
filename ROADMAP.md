# Legacy Hosting – roadmap

Sist oppdatert: 27.09.2026

Denne rotmappen er et midlertidig migreringsområde. Hver tjeneste eies, testes, versjoneres og deployes fra sitt eget repository. `LH-Platform` skal fjernes når alle driftsfiler er flyttet og de selvstendige produksjonsdeployene er verifisert.

## Statusbetydning

- `PLANNED` – ikke startet.
- `STARTED` – delvis implementert, men ikke ferdig produksjonsverifisert.
- `READY` – implementert og verifisert i CI, men kan mangle produksjonsutrulling.
- `LIVE` – satt i produksjon og kontrollert med health checks.

## Målarkitektur

| Repository | Ansvar | Produksjonsplassering | Status |
| --- | --- | --- | --- |
| `LH-API` | Kunde-, workspace-, applikasjons-, deployment- og integrasjons-API | `ams3-api-01.legacyh.fyi` | `STARTED` |
| `LH-Panel` | Kundepanel og plattformadministrasjon | `ams3-panel-01.legacyh.fyi` | `STARTED` |
| `LH-SSO` | Felles identitet, OIDC, passkeys, sesjoner og staff-roller | `ams3-sso-01.legacyh.fyi` | `STARTED` |
| `LH-Hub` | Internt driftsdashboard for Legacy Hosting-ansatte | `ams3-hub-01.legacyh.fyi` | `STARTED` |
| `LH-Status` | Offentlig og uavhengig statusside | `fra1-status-01.legacyh.fyi` | `STARTED` |
| `LH-Discord` | Discord-integrasjon og synkronisering av staff-roller | Samme server som `LH-Panel`, egen PM2-prosess | `READY` |
| `LH-Agent` | Overvåking på alle servere og hostingkommandoer på applikasjonsnoder | Alle relevante servere | `READY` |
| `LH-Releases` | Immutable releasearkiver og SHA-256-filer | GitHub/LFS, ikke en kjørende tjeneste | `READY` |
| `LH-Ops` | Felles infrastruktur, serverbootstrap, backup og restore-drills | Privat driftsrepository, ikke en kjørende tjeneste | `READY` |
| `LH-Platform` | Gammel samlet orkestrering | Skal ikke deployes videre | Klar for arkivering etter produksjonsverifisering |

API, Panel, SSO og Hub ligger i `default-ams3`. Status ligger i `default-fra1` for å unngå at én regionfeil skjuler driftsstatus. Managed MySQL ligger i AMS3. Bare API og SSO skal ha databasetilgang.

## Fase 1 – Repository-splitt og eierskap

**Status: `STARTED`**

- [x] Opprette `LH-Agent`, `LH-API`, `LH-Discord`, `LH-Hub`, `LH-Panel`, `LH-Releases`, `LH-SSO` og `LH-Status`.
- [x] Flytte aktiv API-, Panel- og Agent-kode til egne repositories.
- [x] Opprette sentral release-struktur med egen `SHA256`-mappe per tjeneste.
- [x] Opprette `LH-Ops` for felles infrastruktur, topologi, backup og restore-drills.
- [x] Etablere Node.js 24 LTS som runtime-baseline.
- [x] Lage Ubuntu 26.04-bootstrap for checksum-verifisert Node 24.21.0, pnpm 12.4.1, PM2 7.0.4, Certbot, 2 GiB swap og signert DigitalOcean Metrics Agent.
- [x] Lage felles skrivebeskyttet host-audit, trygg førstegangsutstedelse av sertifikat og en ordnet produksjonsrunbook i `LH-Ops`.
- [x] Flytte alle nødvendige Nginx-, installasjons-, deploy-, rollback- og backupfiler ut av `LH-Platform`.
- [x] Fjerne den gamle samlede release- og CI-flyten fra `LH-Platform`.
- [ ] Fjerne de siste submodule-referansene når migreringsrepoet arkiveres.
- [ ] Arkivere og deretter slette `LH-Platform` når slettesjekklisten nederst er fullført.

## Fase 2 – API, Panel og hostingplattform

**Status: `STARTED`**

- [x] Kunde- og workspace-isolering.
- [x] Cloudflare OAuth og GitHub App user-to-server-autorisasjon.
- [x] Brukere ser bare repositories de selv har lese- og skrivetilgang til.
- [x] Flere prosesser per applikasjon, inkludert web, API, worker, custom og bot.
- [x] Live buildlogger, runtime-logger, kopiering og automatisk loggscrolling.
- [x] Live statusoppdatering ved deploy, restart og stopp.
- [x] Redigering og sletting av applikasjoner.
- [x] Supportvisning av kundens workspace med eksplisitt retur til egen administratorkontekst.
- [x] Skjule nodeinfrastruktur fra vanlige kunder.
- [x] Skille mellom `hosting-node` og `monitor-only` i Agent, API og Panel.
- [ ] Flytte Panel/API-innlogging til LH-SSO uten å bryte eksisterende brukere eller passkeys.
- [ ] Produksjonssette API og Panel på hver sin nye server.

## Fase 3 – Felles identitet med LH-SSO

**Status: `STARTED`**

- [x] Opprette separat SSO-database og migreringsløp.
- [x] Opprette autentisert Discord-rolle-synk med tillatte staff-roller.
- [x] Implementere OIDC Authorization Code Flow med påtvunget PKCE for alle klienter.
- [x] Implementere ES256-signering, offentlig JWKS, nøkkelrotasjon og kortlivede access-/ID-tokens.
- [x] Persistere OIDC-sesjoner, grants, koder og tokens i SSO-databasen med utløpsrydding.
- [x] Etablere en tidsbegrenset engangsbillett-bro fra eksisterende Panel-login til SSO-interaksjoner.
- [x] La autentiserte Panel-sesjoner fullføre SSO-interaksjoner med samme immutable bruker-UUID, uten å eksponere brotokenet i nettleseren.
- [x] Implementere Authorization Code + PKCE callback som BFF i LH-API og opprette eksisterende HttpOnly Panel-sesjon etter validert ID-token.
- [x] Implementere SSO-eid passkey-innlogging med same-origin WebAuthn, generiske autentiseringsfeil og rollback-bryter.
- [x] Lage idempotent dry-run/apply-migrering av aktive legacy-passkeys med RP-ID-, identitets- og credential-kollisjonskontroll.
- [ ] Produksjonsmigrere passkeys/WebAuthn og flytte kontogjenoppretting til SSO.
- [x] Støtte statisk allowlistede OIDC-klienter og separate resource-audiences for Panel, Hub og API.
- [ ] Konfigurere produksjonsklienter, secrets og callback-URL-er på de nye serverne.
- [ ] Migrere eksisterende Panel-brukere, identiteter og aktive sesjoner kontrollert.
- [x] Bruke Secure, HttpOnly, SameSite og host-only SSO-cookies uten delt domene-cookie.
- [x] Legge til RP-initiated logout og signert back-channel session revocation på tvers av SSO, API, Panel og Hub.
- [ ] Fjerne gammel API-innlogging først etter parallell drift og godkjent rollback-test.

## Fase 4 – Ansattportal med LH-Hub

**Status: `STARTED`**

- [x] Beskytte Hub-API-et med LH-SSO JWT/JWKS-verifisering og eksplisitt tillatte staff-roller.
- [x] Implementere Hub-innlogging med Authorization Code + PKCE, server-side tokenhåndtering, roterende refresh-token og HttpOnly nettlesersesjon.
- [ ] Aktivere Hub OIDC-klienten og callbacken i produksjon.
- [x] Bruke server-side DigitalOcean API med minst mulige read-only scopes.
- [x] Vise CPU, minne, disk, last, båndbredde og health per server, med cache og stale fallback.
- [x] Etablere server-side health-innhenting uten å eksponere interne URL-er eller tokens til nettleseren.
- [ ] Samle API-, Agent-, deployment-, database- og statusinformasjon i Hub.
- [x] Støtte serverhåndhevede rollebaserte visninger for Founder, Management, Administrator, Developer, Infrastructure, Support og Sales.
- [ ] Legge til audit-logg for support- og administrasjonshandlinger.
- [x] Holde kunde-, produkt- og Discord-varslingsroller utenfor Hub-autorisasjon.

## Fase 5 – Offentlig status med LH-Status

**Status: `STARTED`**

- [x] Bygge tjenesten uten avhengighet til AMS3, Managed MySQL, API, Panel, Hub eller SSO.
- [x] Publisere aggregert komponentstatus uten interne URL-er eller feildetaljer.
- [x] Implementere tidsavgrensede eksterne HTTPS-probes med treg-, feil- og foreldet-status.
- [x] Lagre status atomisk lokalt og levere siste snapshot via Nginx- og nettleserfallback.
- [ ] Produksjonssette probe-tjenesten på FRA1 og verifisere fallback under et simulert AMS3-avbrudd.
- [ ] Publisere hendelser og planlagt vedlikehold uten interne detaljer.
- [ ] Støtte incidenthistorikk, abonnementsvarsler og RSS/Atom.
- [ ] Etablere egen varslingsvei som ikke er avhengig av systemet den overvåker.

## Fase 6 – Discord og rollemodell

**Status: `READY`**

- [x] Eget `LH-Discord` repository og egen PM2-prosess.
- [x] Rolleoppslag basert på immutable Discord role IDs, ikke rollenavn.
- [x] Synkronisere kun staff-rollene Founder, Management, Administrator, Developer, Infrastructure, Support og Sales.
- [x] Hindre customer-, product-, notification-, booster-, bot-, member- og muted-roller fra å gi Hub-tilgang.
- [x] Lage checksum-verifisert Discord-deploy, readiness etter Discord-innlogging, health verification og automatisk rollback.
- [ ] Koble Discord-identitet til SSO-konto med eksplisitt brukerflyt.
- [ ] Legge til retry-kø og audit-logg for mislykket synkronisering.
- [ ] Produksjonssette boten på Panel-serveren.

## Fase 7 – Releases og produksjonsdrift

**Status: `STARTED`**

- [x] Separate CI-løp for API, Panel, Agent, Discord, SSO, Hub og Status.
- [x] Separate release-workflows som publiserer med credential, eller beholder et verifisert 7-dagers Actions-artifact for manuell publisering når credential mangler.
- [x] Git LFS for `.tar.gz`; checksum-filer ligger som vanlig tekst under `SHA256`.
- [x] Legge CI- og release-workflows til Hub og Status.
- [x] Lage selvstendig installer, deploy, health verification og rollback per kjørende tjeneste.
- [ ] Konfigurere `RELEASES_TOKEN` med kun nødvendig tilgang.
- [x] Tagge og publisere produksjonsklare split-releaser: API `1.0.36`, Panel `1.0.38`, Agent `1.0.32`, Discord `1.1.0`, SSO `1.2.2`, Hub `0.4.0` og Status `0.1.1`.
- [ ] Signere releaseartefakter i tillegg til SHA-256.
- [ ] Verifisere restore og rollback på en ren Ubuntu 26.04 LTS-server.
- [x] Tagge og publisere første separate produksjonsrelease for hver tjeneste.

## Fase 8 – Backup, observability og kapasitet

**Status: `STARTED`**

- [x] Managed MySQL automatiske backups/PITR som primærlag.
- [x] Agent-heartbeats og applikasjonsmålinger.
- [ ] Separate krypterte logiske backups av API- og SSO-databasene.
- [ ] Kvartalsvise restore-drills for begge databasene.
- [ ] Installere og kontrollere DigitalOcean Monitoring Agent på alle Droplets.
- [ ] Aggregere DigitalOcean Insights i Hub via read-only API-token.
- [ ] Definere backup for kundens persistente filer på hostingnoder.
- [ ] Fastsette retention, RPO og RTO per datakategori.
- [ ] Lastteste API, SSO og database før kundevekst.

## Fase 9 – Billing og produktstyring

**Status: `PLANNED`**

- [ ] Definere produkter, planer, kvoter og abonnementer.
- [ ] Integrere betalingsleverandør, fakturaer og betalingsstatus.
- [ ] Koble ressursgrenser og hostingtilgang til kundens plan.
- [ ] Holde billing-logikk adskilt fra deployment- og identitetslogikk.

## Rekkefølge videre

1. Konfigurer Panel-klienten og secrets i produksjon, kjør OIDC parallelt med eksisterende Panel-login og gjennomfør rollback-test.
2. Flytt passkeys, kontogjenoppretting og brukeridentiteter kontrollert til SSO.
3. Koble Hub til SSO og bygg server-side DigitalOcean/observability-integrasjoner.
4. Fullfør incidents, vedlikehold og uavhengig varsling i Status.
5. Produksjonssett API, Panel, SSO, Hub, Status og Discord én tjeneste om gangen.
6. Kjør backup-, restore-, failover- og sikkerhetstest.
7. Arkiver nødvendige historiske referanser og slett `LH-Platform`.

## Sjekkliste før LH-Platform slettes

- [x] Ingen produksjonsworkflow leser filer fra roten.
- [x] Alle kjørende tjenester kan bygges fra en ren klone av eget repository.
- [ ] Hver tjeneste kan deployes og rulles tilbake uten submodules.
- [x] Backup- og restore-skript eies av `LH-Ops`.
- [x] Tjenestespesifikke Nginx-filer ligger hos tjenesten; delte systemd-filer ligger i `LH-Ops`.
- [ ] Siste samlede release er beholdt som historisk artefakt, ikke som aktiv deploykilde.
- [ ] Alle secrets er rotert etter utfasing av gammel server og workflow.
