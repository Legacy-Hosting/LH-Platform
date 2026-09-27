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

## Gjeldende produksjonskandidater

| Tjeneste | Versjon |
| --- | --- |
| LH-API | `1.2.0` |
| LH-Panel | `1.0.38` |
| LH-Agent | `1.0.32` |
| LH-Discord | `1.2.0` |
| LH-SSO | `1.2.2` |
| LH-Hub | `0.6.0` |
| LH-Status | `0.3.0` |

Alle ligger som verifiserte LFS-arkiver i `LH-Releases`, med separat checksum
under tjenestens `SHA256`-mappe.

## Tilgang til LH-Releases

Hvert tjenesterepository bruker Actions-secret `RELEASES_TOKEN` med minst mulig tilgang:

- Contents: Read and write kun for `Legacy-Hosting/LH-Releases`.
- Ingen administrasjons-, secrets-, workflow- eller organisasjonstilgang.
- Tokenet må ha utløpsdato og dokumentert eier.

Skrivbare deploy keys er for øyeblikket deaktivert av organisasjonspolicyen. Ikke bruk et bredt personlig `repo`-token som snarvei. Frem til en repository-avgrenset fine-grained token er konfigurert, bygger og verifiserer release-workflowen hele releasen og laster opp tjenestemappen som et Actions-artifact med syv dagers retention. Kryss-repository-publisering hoppes eksplisitt over.

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

Hvis `RELEASES_TOKEN` mangler, publiseres det verifiserte artifactet kontrollert fra en ren lokal checkout:

```bash
git -C LH-Releases pull --ff-only origin main
LH-API/ops/scripts/build-release.sh X.Y.Z LH-Releases
cd LH-Releases/LH-API
sha256sum --check SHA256/lh-api-X.Y.Z.tar.gz.sha256
cd ..
git lfs install --local
git add LH-API
git commit -m "release: LH-API X.Y.Z"
git push origin main
```

Erstatt `LH-API` med aktuell tjeneste. Et eksisterende arkiv skal aldri overskrives; publiser en ny patchversjon ved feil.

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

Følg den ordnede runbooken i `LH-Ops/docs/production-rollout.md`. Hver tjeneste
har nå sitt eget checksum-verifiserende `deploy-release.sh`,
`verify-release.sh` og `rollback-release.sh`. Utrulling gjøres én tjeneste om
gangen:

1. Kjør LH-Ops host-audit og utbedre alle feil.
2. Last ned arkiv og checksum fra `LH-Releases`.
3. Kjør tjenestens `ops/scripts/deploy-release.sh ARCHIVE CHECKSUM VERSION`.
4. Kjør tjenestens `ops/scripts/verify-release.sh`.
5. Verifiser ekstern HTTPS, Cloudflare og én kritisk brukerflyt.
6. Kontroller Agent-heartbeat og Hub/Status før neste tjeneste flyttes.

Deploy-skriptene eier SHA-256-kontroll, versjonert utpakking, låste
produksjonsavhengigheter, beskyttede miljøfiler, atomisk `current`-symlink,
PM2/Nginx og lokal health verification. API og SSO nekter å migrere før den
krypterte backupjobben er installert.

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
