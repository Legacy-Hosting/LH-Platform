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
    SIGNATURES/
      lh-api-X.Y.Z.tar.gz.sig
  LH-Agent/
    lh-agent-X.Y.Z.tar.gz
    SHA256/
      lh-agent-X.Y.Z.tar.gz.sha256
    SIGNATURES/
      lh-agent-X.Y.Z.tar.gz.sig
  LH-Discord/
  LH-Hub/
  LH-Panel/
  LH-SSO/
  LH-Status/
```

`.tar.gz` lagres med Git LFS, `.tar.gz.sha256` som vanlig tekst og den
64-byte Ed25519-signaturen `.tar.gz.sig` som en liten binær Git-fil. Alle tre
er append-only og må aldri overskrives. Hvis en release er feil, publiseres en
ny versjon.

## Gjeldende produksjonskandidater

| Tjeneste | Versjon |
| --- | --- |
| LH-API | `1.2.0` |
| LH-Panel | `1.0.38` |
| LH-Agent | `1.0.32` |
| LH-Discord | `1.3.0` |
| LH-SSO | `1.3.0` |
| LH-Hub | `0.6.0` |
| LH-Status | `0.4.0` |

Alle ligger som verifiserte LFS-arkiver i `LH-Releases`, med separat checksum
under tjenestens `SHA256`-mappe. Disse historiske kandidatene ble publisert før
signeringskravet og skal erstattes av nye signerte patchreleaser før utrulling
på de nye serverne.

### Ventende signerte patchkandidater

| Tjeneste | Versjon | Verifisert commit |
| --- | --- | --- |
| LH-API | `1.2.1` | `dbe91ac` |
| LH-Panel | `1.0.39` | `2145cd4` |
| LH-Agent | `1.0.33` | `55c743e` |
| LH-Discord | `1.3.1` | `78fb15c` |
| LH-SSO | `1.3.1` | `f329467` |
| LH-Hub | `0.6.1` | `9d1089d` |
| LH-Status | `0.4.1` | `28f20ae` |

Kandidatene er lokalt testet og bygget i rene Node 24/Linux-miljøer med
midlertidige Ed25519-testnøkler. Checksum, 64-byte signatur og release-manifest
er verifisert. De er ikke tagget eller publisert; først må CI kunne kjøre grønt,
og produksjonsnøklene må opprettes og provisioneres etter nøkkelprosedyren.

## Tilgang til LH-Releases

Hvert tjenesterepository bruker Actions-secret `RELEASES_TOKEN` med minst mulig tilgang:

- Contents: Read and write kun for `Legacy-Hosting/LH-Releases`.
- Ingen administrasjons-, secrets-, workflow- eller organisasjonstilgang.
- Tokenet må ha utløpsdato og dokumentert eier.

Hvert repository bruker i tillegg sin egen
`RELEASE_SIGNING_PRIVATE_KEY_B64`. Nøkkelen er Ed25519, skal bare være
tilgjengelig for release-workflowen og skal ha en kryptert offline recovery-kopi
utenfor GitHub og produksjon. Bare den offentlige nøkkelen og kontrollert
SHA-256-fingerprint provisioneres med `LH-Ops/scripts/install-release-verifier.sh`.

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
8. Tjenestens signeringssecret, offentlige nøkkel og kontrollerte fingerprint
   skal være på plass; unsigned release skal feile lukket.

Endringer i connection pools, databaseindekser, proxy/cache, runtime eller
kritiske leseflyter krever i tillegg den bounded smoke-/kapasitetsprosedyren i
`LH-Ops/docs/capacity-testing.md`. Produksjon får bare den ratebegrensede
smoke-profilen; metningstest kjøres mot produksjonslik staging.

## Tjenestespesifikke porter

- `LH-API`: migrasjoner mot ren MySQL 8, integrasjonstester, typecheck og build.
- `LH-Panel`: produksjonsbuild og Playwright på desktop og mobil.
- `LH-Agent`: enhetstester, typecheck, build og test av både `hosting-node` og `monitor-only`.
- `LH-SSO`: migrasjoner mot ren MySQL 8, sikkerhetstester, token-/OIDC-tester og build.
- `LH-Hub`: autentisering/autorisasjon, mockede DigitalOcean-responser, build og UI-test.
- `LH-Status`: probe-, incident-, fallback-, Web Push-kø-, SSRF-allowlist- og same-origin-tester samt produksjonsbuild.
- `LH-Discord`: rolle-ID-policy, SSO-kontrakt, typecheck og build.

## Opprette en release

1. Oppdater versjon og changelog i tjenesterepositoryet.
2. Kjør alle lokale tester og bygg.
3. Commit og push til `main`.
4. Vent til CI er grønn.
5. Opprett annotert tag `vX.Y.Z` på den verifiserte committen og push taggen.
6. Release-workflowen bygger på nytt og committer arkiv, checksum og signatur til riktig mappe i `LH-Releases`.
7. Kontroller at arkivet er et LFS-objekt, at checksum-filen peker på riktig filnavn og at signaturen er 64 byte.
8. Verifiser lokalt med den uavhengig provisionerte offentlige nøkkelen:

```bash
LH-Ops/scripts/verify-release-artifact.sh \
  /etc/legacy-hosting/release-keys/lh-api.pub \
  LH-Releases/LH-API/lh-api-X.Y.Z.tar.gz \
  LH-Releases/LH-API/SHA256/lh-api-X.Y.Z.tar.gz.sha256 \
  LH-Releases/LH-API/SIGNATURES/lh-api-X.Y.Z.tar.gz.sig
```

Hvis `RELEASES_TOKEN` mangler, publiseres det verifiserte artifactet kontrollert fra en ren lokal checkout:

```bash
git -C LH-Releases pull --ff-only origin main
RELEASE_SIGNING_PRIVATE_KEY_FILE=/secure/operator/path/lh-api-release-private.pem \
  LH-API/ops/scripts/build-release.sh X.Y.Z LH-Releases
LH-Ops/scripts/verify-release-artifact.sh \
  /secure/operator/path/lh-api-release.pub \
  LH-Releases/LH-API/lh-api-X.Y.Z.tar.gz \
  LH-Releases/LH-API/SHA256/lh-api-X.Y.Z.tar.gz.sha256 \
  LH-Releases/LH-API/SIGNATURES/lh-api-X.Y.Z.tar.gz.sig
cd LH-Releases
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
har nå sitt eget checksum- og signaturverifiserende `deploy-release.sh`,
`verify-release.sh` og `rollback-release.sh`. Utrulling gjøres én tjeneste om
gangen:

1. Kjør LH-Ops host-audit og utbedre alle feil.
2. Last ned arkiv, checksum og signatur fra `LH-Releases`.
3. Kjør tjenestens `ops/scripts/deploy-release.sh ARCHIVE CHECKSUM SIGNATURE VERSION`.
4. Kjør tjenestens `ops/scripts/verify-release.sh`.
5. Verifiser ekstern HTTPS, Cloudflare og én kritisk brukerflyt.
6. Kontroller Agent-heartbeat og Hub/Status før neste tjeneste flyttes.

Før en hostingnode eller en applikasjon med backupinkludert plan tas i bruk,
installeres `LH-Ops` sine application-backup jobs. Første timeraktivering skjer
først etter at allowlisten er kontrollert mot Panel, FRA1 Spaces-credential er
scoped, en backup har fullført remote readback, og staging av samme arkiv er
verifisert uten å endre live-data. Privat `age` identity skal ikke ligge fast på
hostingnoden.

Deploy-skriptene eier SHA-256- og Ed25519-kontroll, versjonert utpakking, låste
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
