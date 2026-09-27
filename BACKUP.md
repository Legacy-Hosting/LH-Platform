# Backup og gjenoppretting

DigitalOcean Managed MySQL sine automatiske backups og point-in-time recovery (PITR) er primær gjenopprettingsmekanisme. Krypterte logiske eksporter gir en uavhengig kopi og brukes også til restore-drills.

## Datakategorier

| Data | Eier | Primær backup | Uavhengig kopi |
| --- | --- | --- | --- |
| Kunder, workspaces, applikasjoner, deployments og integrasjoner | `LH-API`-database | Managed MySQL PITR | Daglig kryptert logical dump |
| Identiteter, passkeys, OIDC grants, sesjoner og staff-roller | `LH-SSO`-database | Managed MySQL PITR | Daglig kryptert logical dump |
| Kundens persistente applikasjonsfiler | Hostingnode/LH-Ops | Lokal kryptert kopi med kort retention | Verifisert, kryptert FRA1 Spaces-kopi |
| Releaseartefakter | `LH-Releases` | GitHub + Git LFS | Periodisk verifisert speil/eksport |
| Kildekode og konfigurasjonsmaler | Hvert tjenesterepository | GitHub | Organisasjonsbackup/eksport |
| Produksjonssecrets | Beskyttet server/secret store | Kontrollert secret-backup | Offline recovery-sett med separat tilgang |
| Statushendelser, Web Push-abonnement og retry-kø | `LH-Status` | Atomiske lokale filer i FRA1 | Kryptert eksport uavhengig av AMS3 |

GitHub er ikke backup for database, kundedata eller server-secrets. `LH-Releases` inneholder kun deploybare artefakter og checksums.

LH-Status sin `push-state.json` inneholder sensitive push-endpoints og autentiseringsmateriale og skal behandles som person-/credential-data. Backupen må krypteres før den forlater FRA1. Samme VAPID-nøkkelpar må gjenopprettes sammen med filen; ved tap av enten nøkkelpar eller state må berørte nettlesere abonnere på nytt. Historiske leveranser skal ikke sendes på nytt etter restore.

## Databaseisolering

API og SSO skal bruke separate databaser og separate databasebrukere på samme Managed MySQL-cluster. En restore av én tjeneste skal ikke kreve overskriving av den andre.

Bare `ams3-api-01` og `ams3-sso-01` skal være trusted database sources. Backupjobber som trenger direkte DB-tilgang må kjøre på en av disse eller fra en eksplisitt, tidsbegrenset trusted source.

## Daglig logical backup

For hver database:

1. Bruk en egen backupbruker med minst nødvendige leserettigheter.
2. Koble med verifisert TLS og DigitalOcean CA.
3. Ta konsistent dump med routines/events bare dersom tjenesten faktisk bruker dem.
4. Komprimer før kryptering.
5. Krypter med `age` til en offentlig recipient; den tilhørende private identity-nøkkelen skal ikke ligge på databaseserveren eller i Spaces-kontoen.
6. Lag SHA-256-checksum av den krypterte filen.
7. Kopier til en separat, privat FRA1 Spaces-bucket med en tjenestespesifikk scoped key, og les objektet tilbake for SHA-256-verifisering.
8. Verifiser opplasting og slett plaintext/midlertidige filer.

Anbefalt filnavn:

```text
lh-api-db-YYYY-MM-DDTHHMMSSZ.sql.gz.age
lh-sso-db-YYYY-MM-DDTHHMMSSZ.sql.gz.age
```

Lokal retention er 14 dager. Off-site retention starter med 35 daglige, 12 månedlige og 3 årlige kopier, og justeres når juridiske og kommersielle krav er fastsatt.

Dette er implementert i `LH-Ops`: API og SSO har separate mode-`0600`, root-eide backupmiljøer, egne systemd timer-instanser, separate Spaces-buckets og ingen restore-admincredential eller privat age identity i den daglige jobben. Backupjobben feiler hvis off-site upload/readback ikke verifiseres. Restore bruker et separat, midlertidig `*-restore.env`, krever navngitt operatør og skriver et hemmelighetsfritt JSONL audit-event.

## Persistente applikasjonsfiler

`file:`- og `directory:`-stier i hostingplattformen overlever deploy. `LH-Ops`
har nå en separat, opt-in backup- og restoreflyt for disse dataene. En
applikasjon er ikke beskyttet før Infrastructure har opprettet en root-eid
mode-`0600` konfigurasjon og allowlist, kjørt første backup, verifisert remote
readback og aktivert den tilhørende systemd-timeren.

Den implementerte policyen er:

- eksplisitt opt-in eller planstyrt aktivering per applikasjon;
- en root-eid allowlist som skal samsvare med applikasjonens deklarerte
  persistent-stier;
- snapshots som avviser symlinks i hele stien og alle sockets, devices og
  andre spesialfiler;
- lokal `age`-kryptering før opplasting til privat FRA1 Spaces med scoped key;
- SHA-256 readback-verifisering av både arkiv og checksum;
- 2 dager lokal retention og 35 daglige, 12 månedlige og 3 årlige off-site
  kopier;
- kundens valgte restorepunkt stages og valideres fullstendig før en navngitt
  operatør kan overskrive live-data med eksplisitt applikasjons-ID-bekreftelse;
- lokal pre-restore rollback-kopi i 7 dager og automatisk rollback av stier som
  allerede er endret dersom apply feiler;
- root-beskyttet JSONL-audit for opprettelse, retention-sletting, staging,
  vellykket restore og feil.

Databasefiler, sockets, caches, `node_modules` og midlertidige stier avvises
eller ekskluderes som standard. Den private `age` identity-nøkkelen finnes ikke
i daglig backupkonfigurasjon eller Spaces; den installeres bare midlertidig fra
separat operatørforvaring ved restore. Detaljert prosedyre og eksempelfiler
ligger i `LH-Ops`.

## Restore-drill for API og SSO

Restore kjøres mot en disponibel database med tydelig navn, for eksempel `lh_api_restore_drill_YYYYMMDD` eller `lh_sso_restore_drill_YYYYMMDD`.

1. Velg en backup og kontroller checksum før dekryptering.
2. Opprett en tom drilldatabase og en tidsbegrenset restorebruker.
3. Dekrypter og importer uten å eksponere dumpen i shell history eller logger.
4. Kontroller tabeller, row counts, referanseintegritet og migreringsledger.
5. Start riktig tjeneste mot drilldatabasen i isolert miljø.
6. Test minst én kritisk leseflyt og én sikker skriveflyt.
7. Dokumenter backupens alder, varighet, datatap og feil.
8. Slett bare den eksakte, validerte drilldatabasen og fjern midlertidig tilgang.

Restore-drill gjennomføres før første produksjonssetting og deretter minst kvartalsvis for begge databaser. SSO-restore skal i tillegg teste token-/session-invalidering og at gamle signeringsnøkler håndteres som planlagt.

## Full gjenopprettingsrekkefølge

1. Opprett nettverk og brannmur, DNS-only A/AAAA-originposter under `legacyh.fyi`, proxied CNAME-er fra `legacyhosting.xyz`, og Cloudflare Full (strict).
2. Gjenopprett Managed MySQL eller velg PITR-tidspunkt.
3. Gjenopprett SSO-database og start SSO.
4. Gjenopprett API-database og start API/arbeidere.
5. Deploy Panel og verifiser innlogging.
6. Start Hub etter at SSO og API er verifisert.
7. Start Discord og kjør kontrollert rolle-resync.
8. Re-enroller eller verifiser Agent på hver server med korrekt mode.
9. Gjenopprett eventuelle kundedata på hostingnoder.
10. Hold LH-Status tilgjengelig gjennom hele hendelsen fra FRA1.

## Recoverymål

- API-database: mål-RPO opptil 15 minutter med PITR, maks 24 timer via logical backup; mål-RTO 60 minutter.
- SSO-database: mål-RPO opptil 15 minutter med PITR, maks 24 timer via logical backup; mål-RTO 60 minutter.
- Releaseartefakter: mål-RPO 0 etter vellykket publisering; mål-RTO 30 minutter fra speil eller rebuild av verifisert tag.
- Persistente kundefiler: teknisk mål-RPO 24 timer og mål-RTO 4 timer for en
  aktivert applikasjon etter første verifiserte off-site backup. Dette er ikke
  en kundegaranti før planen, bemanningstiden og produktvilkårene uttrykkelig
  inkluderer backup; applikasjoner uten aktiv timer har ingen backupgaranti.
- Status: mål-RTO 15 minutter fra statisk fallback eller separat FRA1-deploy; Web Push-state har mål-RPO 24 timer inntil egen hyppigere backup er aktivert.

## Ansvar og varsling

- Infrastructure eier automatisering, retention og restore-drills.
- Developer eier migreringskompatibilitet og applikasjonsverifisering.
- Management godkjenner RPO/RTO og retentionkrav.
- Alle restore-operasjoner og sletting av backups logges og krever navngitt operatør.
- Mislykket backup, manglende off-site kopi eller utløpt restore-drill skal varsles som en driftsfeil.

Backup- og restore-skriptene eies nå av `LH-Ops`. API, SSO og hver beskyttet
kundeapplikasjon bruker separate, root-eide konfigurasjoner og egne systemd
timer-instanser; `LH-Platform` er ikke lenger en backupavhengighet.
