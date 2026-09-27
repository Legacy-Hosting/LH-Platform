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
| `LH-Status` | Offentlig og uavhengig statusside | `fra1-status-01.legacyh.fyi` | `PLANNED` |
| `LH-Discord` | Discord-integrasjon og synkronisering av staff-roller | Samme server som `LH-Panel`, egen PM2-prosess | `READY` |
| `LH-Agent` | Overvåking på alle servere og hostingkommandoer på applikasjonsnoder | Alle relevante servere | `READY` |
| `LH-Releases` | Immutable releasearkiver og SHA-256-filer | GitHub/LFS, ikke en kjørende tjeneste | `READY` |
| `LH-Platform` | Gammel samlet orkestrering | Skal ikke deployes videre | `STARTED` utfasing |

API, Panel, SSO og Hub ligger i `default-ams3`. Status ligger i `default-fra1` for å unngå at én regionfeil skjuler driftsstatus. Managed MySQL ligger i AMS3. Bare API og SSO skal ha databasetilgang.

## Fase 1 – Repository-splitt og eierskap

**Status: `STARTED`**

- [x] Opprette `LH-Agent`, `LH-API`, `LH-Discord`, `LH-Hub`, `LH-Panel`, `LH-Releases`, `LH-SSO` og `LH-Status`.
- [x] Flytte aktiv API-, Panel- og Agent-kode til egne repositories.
- [x] Opprette sentral release-struktur med egen `SHA256`-mappe per tjeneste.
- [x] Etablere Node.js 24 LTS som runtime-baseline.
- [ ] Flytte alle nødvendige Nginx-, installasjons-, deploy-, rollback- og backupfiler ut av `LH-Platform`.
- [ ] Fjerne submodule-avhengigheter og den gamle samlede releaseflyten.
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
- [ ] Implementere OIDC Authorization Code Flow med PKCE.
- [ ] Implementere signering, JWKS, nøkkelrotasjon og kortlivede tokens.
- [ ] Flytte passkeys/WebAuthn og kontogjenoppretting til SSO.
- [ ] Registrere Panel, Hub og andre tjenester som separate OIDC-klienter.
- [ ] Migrere eksisterende Panel-brukere, identiteter og aktive sesjoner kontrollert.
- [ ] Beholde host-only cookies; ikke dele én sesjonscookie på hele domenet.
- [ ] Legge til logout og session revocation på tvers av tjenester.
- [ ] Fjerne gammel API-innlogging først etter parallell drift og godkjent rollback-test.

## Fase 4 – Ansattportal med LH-Hub

**Status: `STARTED`**

- [ ] Kreve LH-SSO og staff-rolle for alle Hub-ruter.
- [ ] Bruke server-side DigitalOcean API med minst mulige read-only scopes.
- [ ] Vise CPU, minne, disk, last, båndbredde og health per server.
- [ ] Samle API-, Agent-, deployment-, database- og statusinformasjon uten å eksponere leverandørtokens til nettleseren.
- [ ] Støtte rollebaserte visninger for Founder, Management, Administrator, Developer, Infrastructure, Support og Sales.
- [ ] Legge til audit-logg for support- og administrasjonshandlinger.
- [ ] Holde kunde-, produkt- og Discord-varslingsroller utenfor Hub-autorisasjon.

## Fase 5 – Offentlig status med LH-Status

**Status: `PLANNED`**

- [ ] Kjøre uavhengig av AMS3, Managed MySQL, API, Panel, Hub og SSO.
- [ ] Publisere komponentstatus, hendelser og vedlikehold uten interne detaljer.
- [ ] Kjøre eksterne probes fra FRA1 mot offentlige endepunkter.
- [ ] Ha separat datalager eller statisk fallback slik at status fortsatt vises ved kontrollplanfeil.
- [ ] Støtte incidenthistorikk, abonnementsvarsler og RSS/Atom.
- [ ] Etablere egen varslingsvei som ikke er avhengig av systemet den overvåker.

## Fase 6 – Discord og rollemodell

**Status: `READY`**

- [x] Eget `LH-Discord` repository og egen PM2-prosess.
- [x] Rolleoppslag basert på immutable Discord role IDs, ikke rollenavn.
- [x] Synkronisere kun staff-rollene Founder, Management, Administrator, Developer, Infrastructure, Support og Sales.
- [x] Hindre customer-, product-, notification-, booster-, bot-, member- og muted-roller fra å gi Hub-tilgang.
- [ ] Koble Discord-identitet til SSO-konto med eksplisitt brukerflyt.
- [ ] Legge til retry-kø og audit-logg for mislykket synkronisering.
- [ ] Produksjonssette boten på Panel-serveren.

## Fase 7 – Releases og produksjonsdrift

**Status: `STARTED`**

- [x] Separate CI-løp for API, Panel, Agent, Discord og SSO.
- [x] Separate release-workflows som publiserer til `LH-Releases`.
- [x] Git LFS for `.tar.gz`; checksum-filer ligger som vanlig tekst under `SHA256`.
- [ ] Legge samme workflow til Hub og Status.
- [ ] Lage selvstendig installer, deploy, health verification og rollback per kjørende tjeneste.
- [ ] Konfigurere `RELEASES_TOKEN` med kun nødvendig tilgang.
- [ ] Signere releaseartefakter i tillegg til SHA-256.
- [ ] Verifisere restore og rollback på en ren Ubuntu 26.04 LTS-server.
- [ ] Tagge og publisere første separate produksjonsrelease for hver tjeneste.

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

1. Fullfør Hub- og Status-grunnlag med CI og releaseworkflow.
2. Flytt driftsfiler fra `LH-Platform` til riktig tjenesterepository.
3. Implementer og test full OIDC/PKCE i SSO.
4. Migrer Panel og API til SSO med parallell drift og rollbackmulighet.
5. Produksjonssett API, Panel, SSO, Hub, Status og Discord én tjeneste om gangen.
6. Kjør backup-, restore-, failover- og sikkerhetstest.
7. Arkiver nødvendige historiske referanser og slett `LH-Platform`.

## Sjekkliste før LH-Platform slettes

- [ ] Ingen produksjonsworkflow leser filer fra roten.
- [ ] Alle kjørende tjenester kan bygges fra en ren klone av eget repository.
- [ ] Hver tjeneste kan deployes og rulles tilbake uten submodules.
- [ ] Backup- og restore-skript eies av API/SSO eller et eksplisitt ops-repository.
- [ ] Nginx- og systemd-filer ligger hos tjenesten som bruker dem.
- [ ] Siste samlede release er beholdt som historisk artefakt, ikke som aktiv deploykilde.
- [ ] Alle secrets er rotert etter utfasing av gammel server og workflow.
