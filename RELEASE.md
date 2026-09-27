# Release- og utrullingsrunbook

Hver tjeneste har sitt eget repository, sin egen semantiske versjon og sin egen release. Det finnes ikke lenger én samlet `legacy-hosting-X.Y.Z`-release, og `LH-Platform` skal ikke tagges med nye produksjonsreleaser.

## Artefaktstruktur

En tag `vX.Y.Z` i et tjenesterepository skal publisere følgende til `LH-Releases`:

```text
LH-Releases/
  LH-API/
    lh-api-X.Y.Z.tar.gz
    SHA256/
      lh-api-X.Y.Z.tar.gz.sha256
  LH-Agent/
    lh-agent-X.Y.Z.tar.gz
    SHA256/
      lh-agent-X.Y.Z.tar.gz.sha256
  LH-Discord/
  LH-Hub/
  LH-Panel/
  LH-SSO/
  LH-Status/
```

`.tar.gz` lagres med Git LFS. `.tar.gz.sha256` lagres som vanlig tekst. Publiserte versjoner er append-only og må aldri overskrives. Hvis en release er feil, publiseres en ny versjon.

## Tilgang til LH-Releases

Hvert tjenesterepository bruker Actions-secret `RELEASES_TOKEN` med minst mulig tilgang:

- Contents: Read and write kun for `Legacy-Hosting/LH-Releases`.
- Ingen administrasjons-, secrets-, workflow- eller organisasjonstilgang.
- Tokenet må ha utløpsdato og dokumentert eier.

En tjenesterelease skal bare endre sin egen mappe. Ved samtidig publisering kan et push måtte kjøres på nytt etter rebase; eksisterende artefakter skal aldri force-pushes eller slettes.

## Felles release gates

Før en tag opprettes:

1. Working tree skal være rent og `main` skal være synkronisert med origin.
2. Tjenestens CI skal være grønn på den eksakte committen.
3. Versjonen i `package.json` og eventuell runtime-versjonsfil skal stemme med taggen.
4. Dependency audit skal ikke ha kjente `high` eller `critical` produksjonssårbarheter.
5. Release-scriptet skal ha bestått shell-syntakskontroll.
6. Databaseendringer skal være additive og bakoverkompatible med forrige applikasjonsrelease.
7. Ingen `.env`, tokens, private nøkler, database-CA eller kundedata skal ligge i arkivet.

## Tjenestespesifikke porter

- `LH-API`: migrasjoner mot ren MySQL 8, integrasjonstester, typecheck og build.
- `LH-Panel`: produksjonsbuild og Playwright på desktop og mobil.
- `LH-Agent`: enhetstester, typecheck, build og test av både `hosting-node` og `monitor-only`.
- `LH-SSO`: migrasjoner mot ren MySQL 8, sikkerhetstester, token-/OIDC-tester og build.
- `LH-Hub`: autentisering/autorisasjon, mockede DigitalOcean-responser, build og UI-test.
- `LH-Status`: probe-, incident- og fallbacktester samt produksjonsbuild.
- `LH-Discord`: rolle-ID-policy, SSO-kontrakt, typecheck og build.

## Opprette en release

1. Oppdater versjon og changelog i tjenesterepositoryet.
2. Kjør alle lokale tester og bygg.
3. Commit og push til `main`.
4. Vent til CI er grønn.
5. Opprett annotert tag `vX.Y.Z` på den verifiserte committen og push taggen.
6. Release-workflowen bygger på nytt og committer arkiv/checksum til riktig mappe i `LH-Releases`.
7. Kontroller at arkivet er et LFS-objekt og at checksum-filen peker på riktig filnavn.
8. Verifiser lokalt med:

```bash
cd LH-Releases/LH-API
sha256sum --check SHA256/lh-api-X.Y.Z.tar.gz.sha256
```

Bytt tjenestenavn og filnavn etter behov.

## Produksjonsplassering

| Tjeneste | Server | Offentlig endepunkt |
| --- | --- | --- |
| API | `ams3-api-01.legacyh.fyi` | `api.legacyhosting.xyz` |
| Panel | `ams3-panel-01.legacyh.fyi` | `panel.legacyhosting.xyz` |
| SSO | `ams3-sso-01.legacyh.fyi` | `auth.legacyhosting.xyz` |
| Hub | `ams3-hub-01.legacyh.fyi` | `hub.legacyhosting.xyz` |
| Status | `fra1-status-01.legacyh.fyi` | `status.legacyhosting.xyz` |
| Discord | Panel-serveren | Ingen offentlig HTTP-tjeneste |

Origin-DNS skal være DNS-only, mens offentlige CNAME-er kan være proxied. Cloudflare SSL/TLS skal stå i `Full (strict)`.

## Utrulling

Inntil alle repositories har ferdige deploy-skript, gjøres produksjonsutrulling kontrollert og én tjeneste om gangen:

1. Last ned arkiv og checksum fra `LH-Releases`.
2. Verifiser SHA-256 før utpakking.
3. Pakk ut til en ny versjonert mappe under `/opt/legacy-hosting/<service>/releases/X.Y.Z`.
4. Installer kun låste produksjonsavhengigheter.
5. Koble inn tjenestens beskyttede miljøfil fra `/etc/legacy-hosting/<service>.env`.
6. For API/SSO: ta backup, kjør migrasjoner, og verifiser migreringsledger før prosessen byttes.
7. Bytt en atomisk `current`-symlink.
8. Reload riktig PM2-prosess eller Nginx-konfigurasjon.
9. Verifiser lokalt health-endepunkt før ekstern trafikk godtas.
10. Verifiser ekstern HTTPS, Cloudflare og én kritisk brukerflyt.
11. Kontroller Agent-heartbeat og Hub/Status etter utrullingen.

Panel er en statisk build og skal serveres direkte av Nginx. API, SSO, Hub-backend og Discord kjører som separate prosesser. `LH-Agent` kjører i `monitor-only` på kontrollplanserverne og i `hosting-node` kun på servere som kan utføre kundedeployments.

## Rollback

- Rull tilbake bare den berørte tjenesten til forrige verifiserte arkiv.
- Endre `current` tilbake til forrige versjon og restart/reload tjenesten.
- Database-migrasjoner rulles ikke automatisk tilbake. De skal være forward-compatible med minst én tidligere applikasjonsversjon.
- Ved bekreftet datakorrupsjon følges `BACKUP.md`; kode-rollback er ikke en database-restore.
- Ved SSO-feil skal eksisterende Panel-innlogging beholdes som kontrollert fallback frem til SSO-migreringen er godkjent.

## Hendelse under release

1. Stopp videre utrulling.
2. Registrer tidspunkt, tjenesteversjon, commit, request IDs og påvirkede brukere.
3. Bevar PM2-, Nginx-, audit- og migreringslogger før restart.
4. Roll tilbake den berørte tjenesten hvis health eller kritisk flyt feiler.
5. Oppdater LH-Status via en uavhengig kanal dersom kunder er påvirket.
6. Opprett ny patchrelease; et publisert artefakt skal aldri erstattes.
