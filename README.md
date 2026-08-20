# 🏐 SetBaas — Volleybal Team Management PWA

Een Progressive Web App voor het beheren van je volleybalteam: spelers, trainingen, wedstrijden en competentie-ontwikkeling.

**Live:** [setbaas.nl](https://setbaas.nl)

## Tech Stack

| Component | Technologie |
|-----------|-------------|
| **Frontend** | SvelteKit + Tailwind CSS |
| **Backend** | PocketBase (SQLite + Auth + File Storage + REST API) |
| **Reverse Proxy** | Caddy (automatisch HTTPS) |
| **Deployment** | Docker Compose |
| **AI** | OpenAI GPT / Google Gemini (optioneel) |

## Features

### Kernfuncties
- **Spelersbeheer** — Foto, positie(s), status, competenties per seizoen
- **Trainingen** — Markdown beschrijving met rich editor, templates, aanwezigheid + scores
- **Wedstrijden** — Per-set lineups (pos 1-6), spelsysteem, wissels, timeouts
- **Competenties** — 4x per seizoen meetbaar, eigenaarschap per meting
- **Seizoen periodisering** — Technisch/Tactisch/Fysiek/Mentaal doelen per fase
- **PDF Export** — Training exporteren als PDF vanuit dashboard of detailpagina

### Integraties
- **Nevobo Import** — Automatisch wedstrijdschema ophalen van volleybal.nl
- **AI Training Generator** — Genereer trainingsplannen met OpenAI GPT of Google Gemini, inclusief periodiseringsdoelen als context
- **Email Uitnodigingen** — Nodig teamleden uit via email (SMTP) of deelbare link

### Platform
- **Auth** — Google OAuth + email/password, multi-user met team_access (admin/coach/viewer)
- **Dashboard** — Open trainingen, afgeronde trainingen (met scores), komende wedstrijden, gespeelde uitslagen
- **Dark mode** — Standaard aan
- **PWA** — Installeerbaar op mobiel

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
git pull && docker compose -f docker-compose.prod.yml up -d --build
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

De AI gebruikt automatisch de **periodiseringsdoelen** van de huidige periode als extra context.

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

## Versies

| Tag | Beschrijving |
|-----|-------------|
| v1.0 | Eerste productie release (auth, spelers, trainingen, wedstrijden, Nevobo, AI, logo) |
| v1.1 | Periodisering in training formulier + AI context |
| v1.2 | Dashboard: Open status op geplande trainingen |
| v1.3 | Dashboard: Open/Afgerond trainingen gescheiden (max 3 per sectie) |
| v1.4 | Email uitnodigingssysteem, PDF export, Gemini 3.6 |
| v1.5 | Productie fixes: OAuth, Caddy routing, trusted proxy, PB URL |

---

## Licentie

Private project.
