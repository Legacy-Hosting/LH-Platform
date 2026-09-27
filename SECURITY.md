# Sikkerhetspolicy

## Rapportering

Rapporter sårbarheter privat til `security@legacyhosting.xyz`. Ikke legg kundedata, databaseuttrekk, access tokens, passkeys, private nøkler eller fungerende exploits i offentlige issues.

## Støttede versjoner

Bare siste produksjonsversjon av hver tjeneste mottar ordinære sikkerhetsrettelser. Produksjon skal bruke immutable, checksum-verifiserte releaseartefakter fra `LH-Releases`, aldri en tilfeldig working tree eller en samlet `LH-Platform`-build.

## Tillitsgrenser

- Cloudflare beskytter offentlige endepunkter; origin bruker gyldig TLS og `Full (strict)`.
- API, Panel, SSO og Hub ligger i AMS3. Status ligger i FRA1 og skal fungere selv om AMS3 eller kontrollplanet feiler.
- Bare `LH-API` og `LH-SSO` skal være trusted sources mot Managed MySQL.
- `LH-Panel`, `LH-Hub`, `LH-Status` og `LH-Discord` skal ikke koble direkte til API-databasen.
- VPC-trafikk erstatter ikke applikasjonsautentisering, TLS eller minste privilegium.
- Hub er kun for Legacy Hosting-ansatte og skal ikke være tilgjengelig bare fordi noen kjenner URL-en.

## Identitet og autorisasjon

`LH-SSO` skal bli felles identitetsautoritet gjennom OIDC Authorization Code Flow med PKCE. Panel, Hub og andre tjenester er separate klienter og validerer issuer, audience, signatur, expiry og nødvendig rolle.

Under migreringen gjelder følgende:

- Eksisterende Panel-passkeys og sesjoner beholdes til OIDC er produksjonsverifisert.
- Ingen bruker migreres ved å kopiere plaintext secrets; passkeys og identiteter flyttes kontrollert.
- Cookies skal være `HttpOnly`, `Secure`, `SameSite=Lax` eller strengere og host-only som standard.
- Én bred cookie på `.legacyhosting.xyz` skal ikke brukes som universell SSO-mekanisme.
- Logout, session revocation og nøkkelrotasjon skal testes på tvers av klienter.

SSO er autoritativ for staff-tilgang. Discord er bare en provisioneringskilde:

- Rolleoppslag bruker immutable Discord role IDs, aldri navn eller farge.
- Tillatte staff-roller er Founder, Management, Administrator, Developer, Infrastructure, Support og Sales.
- Customer-, Premium Customer-, Partner-, produkt-, varslings-, booster-, bot-, member- og muted-roller gir aldri Hub-tilgang.
- En Discord-rolle får først effekt når Discord-identiteten er eksplisitt koblet til riktig SSO-bruker.
- `/lh-link` synkroniserer først aktive staff-roller og utsteder deretter en ti minutters engangsbillett over den VPC-beskyttede servicekontrakten.
- Koblingsbilletten lagres kun som SHA-256, holdes i URL-fragmentet for å unngå HTTP-/referrer-logger, og kan bare fullføres med en eksisterende SSO-passkey med påkrevd user verification.
- Discord-ID og SSO-konto bindes én-til-én; displaynavn og e-post brukes aldri som automatisk koblingsgrunnlag.

## Tjeneste-til-tjeneste-sikkerhet

- Interne kall bruker egne tokens eller signerte kortlivede service credentials per avsender og mål.
- Tokens skal sammenlignes timing-safe der det er relevant, ha minst 256 bits entropi og kunne roteres uten kodeendring.
- Service tokens skal aldri gjenbrukes som bruker-, GitHub-, Cloudflare- eller DigitalOcean-token.
- Alle sensitive handlinger skal ha audit event med aktør, mål, tidspunkt og resultat.
- Produksjonsfeil returnerer stabil feilkode og request ID, ikke stack trace eller secrets.

## Agent-sikkerhet

`LH-Agent` har to eksplisitte moduser:

- `hosting-node` kan hente signerte kommandoer og utføre deploy, PM2-, Nginx-, TLS-, logg- og persistent-file-operasjoner.
- `monitor-only` rapporterer system/PM2-status, men poller aldri kommandoer og kan ikke promovere seg selv.

Modusen registreres i API-et og må samsvare med heartbeat. Monitorservere filtreres bort fra applikasjonsplassering. Bytte fra hosting til monitor skal avvises så lenge aktive applikasjoner finnes.

Agentkommandoer skal fortsatt bindes til node, timestamp, nonce, body og credential. Nonces er single-use, leases utløper, og node credentials lagres kun hashbasert på serversiden.

## Leverandørintegrasjoner

- GitHub App-installation og GitHub-brukerautorisasjon er separate flyter.
- Vanlige brukere sendes aldri til `setup_action=update` for en eksisterende organisasjonsinstallation.
- Repositoryvalg filtreres etter den autoriserte brukerens faktiske lese- og skrivetilgang.
- Deploy bruker kortlivet, repository-begrenset installation token; brukerens OAuth-token sendes ikke til agenten.
- Cloudflare-tilkoblinger isoleres per workspace, og DNS/TLS-tokens begrenses til nødvendige soner.
- Hub bruker et DigitalOcean-token med read-only scopes som `droplet:read` og `monitoring:read`; tokenet brukes bare server-side.
- Hubs audit-visning videresender den innloggede ansattes kortlivede `lh-hub`-token kun server-side. API-et verifiserer issuer, audience, signatur, alder og staff-rolle på den dedikerte leseruten; det brukes ikke delt statisk admin-token.
- Audit-metadata redigeres rekursivt for token-, secret-, credential-, password-, cookie-, authorization-, private-key- og content-felter før data forlater API-et.
- Hubs operations-visning bruker samme kortlivede brukerautorisasjon mot et avgrenset API-aggregat. Den returnerer bare tellere, tilstand, tidsstempler og et begrenset sett deploymentmetadata; Hub får aldri direkte databaseforbindelse, kundehemmeligheter eller deploymentlogger.
- Offentlig status hentes fra LH-Status sitt validerte snapshot med kort server-side cache. API- og statusfeil isoleres slik at én utilgjengelig datakilde ikke skjuler den andre.
- `RELEASES_TOKEN` kan kun skrive til `LH-Releases`.

## Secrets og lagring

- `.env`, private nøkler, database-CA, backupnøkler og tokens skal aldri committes eller pakkes i releases.
- Miljøhemmeligheter og provider credentials krypteres med en versjonert envelope som støtter nøkkelrotasjon.
- En krypteringsnøkkel må ikke erstattes før alle eksisterende ciphertexts er re-kryptert.
- Produksjonsfiler under `/etc/legacy-hosting` eies av root og har mode `0600` når mulig.
- Git LFS i `LH-Releases` er distribusjon, ikke en secrets manager.

## Database og nettverk

- API og SSO bruker separate databaser og separate databasebrukere med minst mulig rettigheter.
- TLS mot Managed MySQL skal validere DigitalOcean CA; `rejectUnauthorized=false` er ikke tillatt.
- Databasepooler skal ha begrenset connection count, timeout og køgrense.
- Slow query log og Performance Schema brukes kontrollert; `log_queries_not_using_indexes` skal ikke stå permanent på uten måling av volum.
- DB trusted sources skal ikke inkludere Panel, Hub, Status eller Discord.
- API- og SSO-backups krypteres lokalt med age før endelig filnavn, lastes til separate private FRA1 Spaces-buckets og verifiseres ved SHA-256 readback. Bare den offentlige recipienten finnes på tjenestehostene; privat identity og restore-admincredentials holdes separat.

## Release- og forsyningskjedesikkerhet

- CI bruker låste avhengigheter og dependency audit.
- Releases bygges på verifisert tag, publiseres append-only og kontrolleres med SHA-256.
- GitHub Actions-permissions settes eksplisitt til minste nødvendige tilgang.
- Tredjepartsactions skal versjonspinnes og Dependabot-PR-er gjennomgås før merge.
- Langsiktig mål er signering og provenance/attestasjon i tillegg til checksum.

## Hendelseshåndtering og rotasjon

1. Begrens hendelsen: deaktiver berørt integrasjon, klient, bruker, node eller token.
2. Bevar audit-, reverse-proxy-, PM2-, SSO-, API- og databasebevis før restart.
3. Roter bare den berørte credential-klassen først; unngå ukontrollert totalrotasjon.
4. Revoke berørte sesjoner og OAuth-grants ved identitets- eller hostkompromiss.
5. Re-krypter data kontrollert dersom en at-rest-nøkkel er kompromittert.
6. Publiser kunderelevant informasjon via LH-Status uten interne eller sensitive detaljer.
7. Dokumenter rotårsak, påvirkning, tidslinje, tiltak og ansvarlig eier.

`LH-Platform` skal ikke slettes før ingen produksjonshemmelighet, workflow, backupjobb eller serverdeploy er avhengig av innholdet. Etter utfasing roteres tokens som kunne lese eller skrive det gamle repositoryet.
