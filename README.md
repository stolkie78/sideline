# 🏐 SetBaas — Volleybal Team Management PWA

Een Progressive Web App voor het beheren van je volleybalteam: spelers, trainingen, wedstrijden en competentie-ontwikkeling. Gebouwd voor coaches die hun team professioneel willen managen vanaf telefoon, tablet of laptop.

**Live:** [setbaas.nl](https://setbaas.nl) | **Versie:** 2.5.1

## Tech Stack

| Component | Technologie |
|-----------|-------------|
| **Frontend** | SvelteKit + Tailwind CSS |
| **Backend** | PocketBase (SQLite + Auth + File Storage + REST API) |
| **Reverse Proxy** | Caddy (automatisch HTTPS) |
| **Deployment** | Docker Compose |
| **AI** | OpenAI GPT / Google Gemini (optioneel) |

## Features

### 🏐 Training Lifecycle
- **Training Start Wizard** — 3-stappen flow: Aanwezigheid → Check-in → Start Training
- **Aanwezigheid** — Trainer markeert per speler: ✅ Aanwezig / ❌ Afwezig / 🤒 Ziek / 🤕 Geblesseerd
- **Happiness & Fitness Check-in** — Spelers geven emoji-scores aan (tablet-friendly): 😢→🤩 en 🥱→⚡
- **Actieve training** — LIVE badge op dashboard, bekijk training content, afronden met één klik
- **Training statussen** — Gepland → Actief → Afgerond (volledige lifecycle)
- **Skip check-in** — Snel starten als er geen tijd is, zonder valse data
- **Trainingsschema Generator** — Bulk trainingen aanmaken voor hele seizoen op vaste dagen/tijden
- **Bulk delete** — Alle geplande trainingen verwijderen bij een fout schema
- **AI Training Generator** — Genereer trainingsplannen met GPT of Gemini, context-aware met periodisering en vorige trainingen
- **Templates** — Herbruikbare trainingssjablonen
- **Markdown editor** — Rich text beschrijving met preview, kopjes, lijsten
- **PDF Export** — Training exporteren als PDF vanuit dashboard of detailpagina

### 👤 Spelersbeheer
- **Profiel** — Foto, positie(s), rugnummer (tot 999), status (actief/inactief)
- **Competenties** — 4x per seizoen meetbaar, categorieën: Technisch/Tactisch/Fysiek/Mentaal
- **Email koppeling** — Spelers automatisch gekoppeld aan gebruikersaccount via email
- **Cascade delete** — Verwijderen van speler ruimt alle gerelateerde data op

### 🏆 Wedstrijden
- **Wedstrijdbeheer** — Per-set lineups (positie 1-6), spelsysteem, wissels, timeouts
- **Nevobo Import** — Automatisch wedstrijdschema ophalen van volleybal.nl
- **Set scores** — Gewonnen/verloren per set, totaalscores

### 📊 Rapportages
- **Trainingsaanwezigheid** — Per speler: aanwezig/afwezig/ziek/geblesseerd (alleen afgeronde trainingen)
- **Welzijn & Fitheid** — Happiness en fitness per speler met trend (📈📉), gemiddelden, emoji-tijdlijn
- **Competenties** — Gemiddelde scores per competentie of per speler met voortgang
- **Punten per positie** — Gescoorde punten per speler per positie over alle wedstrijden
- **Sets gewonnen & verloren** — Seizoensoverzicht

### 🔐 Gebruikers & Rollen
- **Google OAuth + email/password** login
- **Multi-team** — Meerdere teams binnen één installatie
- **Rollen** — Admin (alles), Coach (team beheer), Speler (eigen dashboard)
- **Trainers** — Trainer profiel met voorkeursdag, automatisch gekoppeld bij planning
- **Speler dashboard** — Beschikbaarheid voor trainingen en wedstrijden
- **Email uitnodigingen** — Nodig teamleden uit via email (SMTP) of deelbare link
- **Seizoenen** — Meerdere seizoenen met periodisering

### 📱 Platform
- **PWA** — Installeerbaar op mobiel als app
- **Responsive** — Geoptimaliseerd voor telefoon, tablet en desktop
- **Dark mode** — Standaard aan
- **24-uurs tijdformat** — Consistent door de hele app
- **Systeem config** — Clear cache/localStorage bij problemen na updates
- **Backup & deploy scripts** — Automatische backup voor elke deployment

---

## Lokale Ontwikkeling

### Vereisten

- Docker & Docker Compose

### Starten

```bash
# Clone
git clone https://github.com/stolkie78/sideline.git
cd sideline

# Configuratie
cp .env.example .env
nano .env
# Minimaal invullen: PB_ADMIN_EMAIL + PB_ADMIN_PASSWORD

# Start (eerste keer)
docker compose up -d --build
docker compose --profile setup run --rm pb-setup

# Daarna:
docker compose up -d
```

De app draait op:
- **Frontend:** http://localhost:3000
- **PocketBase Admin:** http://localhost:8090/_/

---

## Productie Deployment

### Vereisten

- Linux server met Docker + Docker Compose
- Domein met DNS A-record naar je server
- Poort 80 + 443 open

### Deployment

```bash
# 1. Clone op de server
git clone https://github.com/stolkie78/sideline.git setbaas
cd setbaas

# 2. Configureer
cp .env.example .env
nano .env
# Invullen:
#   DOMAIN=setbaas.nl
#   ENABLE_SSL=true
#   SITE_URL=https://setbaas.nl
#   PB_ADMIN_EMAIL=admin@setbaas.nl
#   PB_ADMIN_PASSWORD=<sterk wachtwoord>
#   GOOGLE_CLIENT_ID=<van Google Cloud Console>
#   GOOGLE_CLIENT_SECRET=<van Google Cloud Console>

# 3. Start + setup
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml --profile setup run --rm pb-setup

# 4. Updates deployen
./scripts/deploy.sh
```

### HTTPS

Caddy regelt automatisch Let's Encrypt certificaten:
- Poort 80 + 443 moeten open staan
- DNS A-record moet naar het server IP wijzen
- `www.setbaas.nl` → automatisch redirect naar `setbaas.nl`

### Google OAuth

Redirect URIs in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
```
https://setbaas.nl/api/oauth2-redirect
https://www.setbaas.nl/api/oauth2-redirect
```

---

## Backup & Restore

### Backup maken

```bash
# Op de server:
./scripts/backup.sh

# Of naar specifieke locatie:
./scripts/backup.sh /mnt/backups

# Backup downloaden naar lokale machine:
scp user@server:/path/to/setbaas/backups/setbaas_backup_*.tar.gz ~/backups/
```

Het script:
- Kopieert de PocketBase database + uploads uit de Docker container
- Maakt een gecomprimeerd `.tar.gz` archief met timestamp
- Behoudt de laatste 7 backups, oudere worden automatisch opgeruimd

### Deploy met automatische backup

```bash
./scripts/deploy.sh
# Maakt eerst een backup, daarna git pull + build + setup
```

### Automatische backup (cron)

```bash
# Op de server:
crontab -e
# Voeg toe (dagelijks om 3:00):
0 3 * * * cd /path/to/setbaas && ./scripts/backup.sh >> /var/log/setbaas-backup.log 2>&1
```

### Restore

```bash
# 1. Stop de containers
docker compose -f docker-compose.prod.yml down

# 2. Pak de backup uit
mkdir -p /tmp/restore
tar -xzf backups/setbaas_backup_YYYYMMDD_HHMMSS.tar.gz -C /tmp/restore

# 3. Kopieer database terug
docker compose -f docker-compose.prod.yml up -d pocketbase
docker compose -f docker-compose.prod.yml cp /tmp/restore/data.db pocketbase:/pb/pb_data/data.db
docker compose -f docker-compose.prod.yml cp /tmp/restore/storage pocketbase:/pb/pb_data/storage

# 4. Herstart
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 5. Opruimen
rm -rf /tmp/restore
```

---

## Email Uitnodigingen (SMTP)

Om uitnodigingen per email te versturen, configureer SMTP in `.env`:

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=jouw@gmail.com
SMTP_PASS=<app-password>
SMTP_FROM=noreply@setbaas.nl
```

> **Tip:** Gebruik een [Google App Password](https://myaccount.google.com/apppasswords) voor Gmail.

Zonder SMTP worden uitnodigingen aangemaakt met een deelbare link die je handmatig kunt kopiëren.

---

## AI Configuratie

1. Ga naar **Configuratie → AI** in de app
2. Kies provider: **OpenAI (GPT)** of **Google Gemini**
3. Vul je API key in
4. Kies een model (optioneel)

| Provider | Model | Omschrijving |
|----------|-------|-------------|
| OpenAI | `gpt-4o-mini` | Snel en goedkoop |
| OpenAI | `gpt-4o` | Beste kwaliteit |
| Gemini | `gemini-3.6-flash` | Snel (standaard) |

De AI gebruikt automatisch:
- **Periodiseringsdoelen** van de huidige periode als context
- **Laatste 3 trainingen** ter referentie (vermijdt herhaling)

---

## Environment Variables

| Variable | Beschrijving | Voorbeeld |
|----------|-------------|-----------|
| `DOMAIN` | Productie domein | `setbaas.nl` |
| `ENABLE_SSL` | HTTPS via Let's Encrypt | `true` / `false` |
| `SITE_URL` | Volledige site URL | `https://setbaas.nl` |
| `HTTP_PORT` | HTTP poort (standaard 80) | `80` |
| `PB_ADMIN_EMAIL` | PocketBase admin email | `admin@setbaas.nl` |
| `PB_ADMIN_PASSWORD` | PocketBase admin wachtwoord | (secret) |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | `*.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret | (secret) |
| `SMTP_HOST` | SMTP server | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP poort | `587` |
| `SMTP_USER` | SMTP gebruiker | `jouw@gmail.com` |
| `SMTP_PASS` | SMTP wachtwoord | (secret) |
| `SMTP_FROM` | Afzender email | `noreply@setbaas.nl` |

---

## Architectuur

```
┌─────────────────────────────────────────────┐
│  Caddy (reverse proxy, auto HTTPS)          │
│  :80 / :443                                 │
├─────────────────────────────────────────────┤
│  /api/nevobo  → Frontend (:3000)           │
│  /api/ai      → Frontend (:3000)           │
│  /api/invite  → Frontend (:3000)           │
│  /api/*       → PocketBase (:8090)         │
│  /_/*         → PocketBase (:8090)         │
│  /*           → Frontend (:3000)           │
└─────────────────────────────────────────────┘
```

---

## Versiegeschiedenis

| Versie | Datum | Beschrijving |
|--------|-------|-------------|
| **v2.5.1** | 2026-09-01 | Training lightbox op dashboard (bekijken + print/PDF), inline expand verwijderd |
| **v2.5.0** | 2026-09-01 | Wedstrijd aanwezigheid (match_attendance), training lightbox met print/PDF, setup-script field merge, aanwezigheid bovenaan detail pagina's |
| **v2.4.21** | 2026-09-01 | Lid toevoegen, permissierollen (Admin/Gebruiker/Lezer), inline naam bewerken, auto-aanwezigheid nieuwe spelers, setup-script field merge |
| **v2.4.20** | 2026-09-01 | Lid toevoegen (admin), permissierollen (Admin/Gebruiker/Lezer), inline naam bewerken, PB API rules voor team_access en users |
| **v2.4.10** | 2026-09-01 | Teamrollen (trainer/speler/ouder checkboxes), trainer/coach multi-select op trainingen en wedstrijden, namen op dashboard, 24-uurs datumvelden, schema generator met trainer per dag |
| **v2.4.1** | 2026-09-01 | Trainers: trainer/coach toewijzing aan trainingen en wedstrijden, trainers config tab met voorkeursdag, auto-toewijzing bij batch planning |
| **v2.4.0** | 2026-09-01 | Dashboard UX: uniforme kaartjes (weekdag naam trainingen), max 5 wedstrijden met "Gespeeld" link + filter tabs op wedstrijden pagina, groene start knop, cyan wedstrijden card |
| **v2.3.4** | 2026-09-01 | Trainingen filter tabs (Alles/Gepland/Afgerond) met deep link vanuit dashboard |
| **v2.3.3** | 2026-09-01 | Responsive layout: bredere container op tablet/desktop, 2-kolom grid voor trainingen/wedstrijden/spelers/rapporten |
| **v2.3.2** | 2026-09-01 | Dashboard: 5 geplande trainingen, afgerond als link met aantal, uitslagen in grijze card |
| **v2.3.1** | 2026-09-01 | "VOLGENDE →" highlight op eerstvolgende geplande training en wedstrijd |
| **v2.3** | 2026-09-01 | Dashboard cards-in-cards layout: trainingen (actief/gepland/afgerond) en wedstrijden (komend/uitslagen) als geneste kaarten |
| **v2.2** | 2026-09-01 | Dashboard herindeling: gecombineerde trainingen- en wedstrijdensecties, komende wedstrijden met blauwe highlight, stats en quick actions bovenaan |
| **v2.1** | 2026-09-01 | Dark mode fixes spelers/competenties, shirtnummer max 999, komende wedstrijden bovenaan dashboard, prod PB schema sync |
| **v2.0.1** | 2026-09-01 | Fix: dark mode kleuren spelers/competenties, shirtnummer max 999, PB jersey_number onlyInt |
| **v2.0** | 2026-09-01 | 🎉 Training Start Wizard (3 stappen), actieve training met LIVE badge, afronden vanuit dashboard, skip check-in, bulk delete trainingen, 24-uurs tijd, systeem config tab, reactive dashboard na login |
| v1.9.1 | 2026-09-01 | Fix: dashboard data na login, systeem config tab |
| v1.9 | 2026-09-01 | Active training status, bulk delete, 24h tijdformat, skip check-in |
| v1.8.2 | 2026-09-01 | SetBaas logo als favicon |
| v1.8.1 | 2026-09-01 | Fix: speler verwijderen met gerelateerde records |
| v1.8 | 2026-09-01 | Happiness/fitness check-in, welzijn rapport, aanwezigheid op geplande trainingen, "Open" → "Gepland" |
| v1.7 | 2026-08-31 | Trainingsschema generator, deploy script met backup |
| v1.6 | 2026-08-31 | Multi-team rollen (admin/coach/speler), speler dashboard, beschikbaarheid, AI context |
| v1.5 | 2026-08-31 | Nieuw SetBaas logo, versie in menu, branding update |
| v1.4 | 2026-08-30 | Email uitnodigingssysteem, PDF export, Gemini 3.6 |
| v1.3 | 2026-08-30 | Dashboard: open/afgerond trainingen gescheiden |
| v1.2 | 2026-08-30 | Dashboard: open status op geplande trainingen |
| v1.1 | 2026-08-30 | Periodisering in training formulier + AI context |
| v1.0 | 2026-08-29 | Eerste productie release |

---

## Licentie

Private project.
