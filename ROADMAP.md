# Legacy Hosting Platform Roadmap

Sist oppdatert: 17.09.2026

Dette dokumentet dekker `LH-Panel`, `LH-API`, `LH-Agent` og den gjenbrukbare `TEMPLATE`-mappen.

## Statusbetydning

- `PLANNED` — arbeidet er ikke startet.
- `STARTED` — arbeidet er delvis implementert.
- `FINISHED` — arbeidet er implementert og verifisert lokalt. Produksjonssetting spores separat i fase 9.

## Oversikt

| Fase | Område | Status |
| --- | --- | --- |
| 1 | Designsystem og responsivt panelskall | `FINISHED` |
| 2 | API-, database- og modulgrunnlag | `FINISHED` |
| 3 | Kontoer, team og sikker innlogging | `FINISHED` |
| 4 | Cloudflare- og GitHub-integrasjoner | `FINISHED` |
| 5 | Noder, applikasjoner og deployment | `FINISHED` |
| 6 | DNS, reverse proxy og TLS | `FINISHED` |
| 7 | Drift, logger og sanntidsoppdateringer | `FINISHED` |
| 8 | Overvåking, varsling og ressursgrenser | `FINISHED` |
| 9 | Produksjonsherding og lansering | `STARTED` |
| 10 | Billing og fremtidige API-produkter | `PLANNED` |

## Fase 1 — Designsystem og responsivt panelskall

**Status: `FINISHED`**

- [x] Responsivt panel for desktop, nettbrett og mobil.
- [x] Fast sidebar, topbar og footer; kun hovedinnholdet ruller.
- [x] Scrollbar plassert ved høyre kant av nettleservinduet.
- [x] Footer med panelversjon, Legacy Hosting-lenke og live Europe/Oslo-klokke.
- [x] Ett hovedstilark: `LH-Panel/src/main.css`.
- [x] Gjenbrukbart Legacy Hosting-design i `TEMPLATE`.

## Fase 2 — API-, database- og modulgrunnlag

**Status: `FINISHED`**

- [x] Felles API laget for flere Legacy Hosting-produkter.
- [x] Modulstruktur for blant annet `panel/modules` og `billing/modules`.
- [x] DigitalOcean Managed MySQL 8 som databaseplattform.
- [x] Migrasjoner for brukere, team, integrasjoner, noder, applikasjoner, deployments og varsler.
- [x] Team-isolering av data og rollebasert tilgang.
- [x] Kryptering av lagrede hemmeligheter og audit-logg for viktige handlinger.

## Fase 3 — Kontoer, team og sikker innlogging

**Status: `FINISHED`**

- [x] Flere brukerkontoer og team/workspaces.
- [x] Roller, medlemskap og invitasjoner.
- [x] Registrering kan settes til åpen, kun invitasjon eller stengt.
- [x] Passkeys/WebAuthn med støtte for Windows Hello.
- [x] Databasebaserte sesjoner og sikker utlogging.
- [x] Administrasjon av konto- og sikkerhetsinnstillinger i panelet.

## Fase 4 — Cloudflare- og GitHub-integrasjoner

**Status: `FINISHED`**

- [x] Cloudflare OAuth per kunde/team med offline-tilgang.
- [x] Henting av soner og håndtering av proxied CNAME-poster.
- [x] GitHub App/OAuth for personlige kontoer og organisasjoner.
- [x] Tilgang til både offentlige og private repositories.
- [x] Sikker callback-, state- og tokenhåndtering.
- [x] GitHub-webhooks som starter automatisk deployment ved push.

## Fase 5 — Noder, applikasjoner og deployment

**Status: `FINISHED`**

- [x] Registrering av noder med offentlig/privat FQDN, separate IPv4- og IPv6-adresser og ønsket CNAME-mål.
- [x] Agent-token og signerte kommandoer mellom API og node.
- [x] Opprette, starte, stoppe, restarte og slette PM2-applikasjoner.
- [x] Lagringssti følger `/home/ROOT.DOMAIN/FULL.HOSTNAME`.
- [x] Miljøvariabler lagres kryptert og brukes ved oppstart/deployment.
- [x] Automatisk oppdagelse av npm, pnpm, yarn, bun og vanlige Node.js-rammeverk.
- [x] Internt styrt port og generering av PM2-konfigurasjon.
- [x] Deployment-historikk og rollback til tidligere commit.

## Fase 6 — DNS, reverse proxy og TLS

**Status: `FINISHED`**

- [x] Opprette og oppdatere Cloudflare CNAME for applikasjonsdomener.
- [x] Generere Nginx reverse-proxy-konfigurasjon per applikasjon.
- [x] TLS-utstedelse med Certbot og Cloudflare DNS-01.
- [x] Midlertidig credential-fil for Cloudflare-token under sertifikatutstedelse.
- [x] Automatisk sertifikatfornyelse.
- [x] Opprydding av PM2-prosess, proxy, sertifikat og applikasjonsfiler ved sletting.

## Fase 7 — Drift, logger og sanntidsoppdateringer

**Status: `FINISHED`**

- [x] Applikasjonsdetaljer, deployments og driftskommandoer i panelet.
- [x] PM2 stdout/stderr-logger tilgjengelig fra panelet.
- [x] Agent-polling for nye kommandoer.
- [x] Live build-output via Server-Sent Events.
- [x] Mulighet til å avbryte en pågående deployment.
- [x] Varslingssenter med lest/ulest-status per bruker.
- [x] Skrivebeskyttet visning av hemmelige miljøverdier etter lagring.

## Fase 8 — Overvåking, varsling og ressursgrenser

**Status: `FINISHED`**

- [x] Agent-heartbeat og nåværende CPU-, minne-, disk- og PM2-status.
- [x] Grunnleggende node- og applikasjonsstatus i dashboardet.
- [x] Interne panelvarsler for relevante hendelser.
- [x] Historiske målinger, dynamisk aggregering, retention og responsive tidsseriegrafer.
- [x] HTTP health checks, oppetid og responstid per applikasjon.
- [x] Automatisk deteksjon og recovery-varsling når en node eller applikasjon går ned.
- [x] CPU-, minne-, lagrings- og månedlige trafikkgrenser med workspace-standard og applikasjonsoverstyring.
- [x] Panel-, Resend-e-post- og signerte webhook-varsler med konfigurerbare regler og cooldown.

## Fase 9 — Produksjonsherding og lansering

**Status: `STARTED`**

- [x] Fullføre enhets-, integrasjons- og ende-til-ende-tester.
- [x] Legge til CI for lint, test, build og migrasjonskontroll.
- [x] Gjennomgå rate limiting, CSRF, replay-beskyttelse og nøkkelrotasjon.
- [x] Definere backup, restore-test, loggretention og beredskapsrutiner.
- [x] Lage repeterbar installasjon, oppdatering og rollback for API, panel og agent.
- [ ] Produksjonskonfigurere GitHub App, Cloudflare OAuth og alle secrets.
- [ ] Staged utrulling til `ams3.web-01.legacyh.fyi` og verifikasjon mot Managed MySQL 8.
- [ ] Produksjonsgodkjenning, dokumentasjon og første versjonerte release.

Produksjonsdelen avventer bekreftelse av serverens nye SSH-fingeravtrykk og at produksjonshemmelighetene legges direkte på serveren.

## Fase 10 — Billing og fremtidige API-produkter

**Status: `PLANNED`**

- [ ] Definere planer, abonnementer, kvoter og bruksbasert måling.
- [ ] Integrere betalingsleverandør, fakturaer og betalingsstatus.
- [ ] Koble ressursgrenser og applikasjonstilgang til kundens plan.
- [ ] Utvide `billing/modules` uten å blande billing-logikk inn i panelmodulene.
- [ ] Lage versjonert API-dokumentasjon for fremtidige Legacy Hosting-prosjekter.

## Neste anbefalte arbeid

Fullfør fase 9 med verifisert SSH-tilkobling, produksjonssecrets, staged utrulling og produksjonsgodkjenning før fase 10 startes.
