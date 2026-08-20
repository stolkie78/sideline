# 🏐 SetBaas — Volleybal Team Management PWA

Een Progressive Web App voor het beheren van je volleybalteam: spelers, trainingen, wedstrijden en competentie-ontwikkeling.

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
- **Seizoen periodisering** — Technisch/Tactisch/Fysiek/Mentaal doelen

### Integraties
- **Nevobo Import** — Automatisch wedstrijdschema ophalen van de Nederlandse Volleybal Bond API. Supports upsert: herimporteren werkt bestaande wedstrijden bij (datum, locatie, scores) zonder je eigen data te overschrijven
- **AI Training Generator** — Genereer trainingsplannen met OpenAI GPT of Google Gemini. Configureerbare systeem prompt voor team-specifieke volleybal-AI

### Platform
- **Auth** — Google OAuth + email/password, multi-user met team_access (admin/coach/viewer)
- **Ownership** — Wie heeft een training klaargezet of scores ingevoerd
- **Dashboard** — Komende wedstrijden (datum, tijd, locatie), klaargezette trainingen met content preview, gespeelde uitslagen
- **Dark mode** — Standaard aan
- **Subpath deployment** — Draait op `/setbaas` subpath (configureerbaar)

---

## Lokale Ontwikkeling

### Vereisten

- Docker & Docker Compose
- Node.js 20+ (alleen voor frontend dev buiten Docker)

### Starten

```bash
# Clone
git clone https://github.com/stolkie78/setbaas.git
cd setbaas

# Configuratie
cp .env.production .env
# Vul je credentials in:
nano .env

# Start (eerste keer)
docker compose up -d
docker compose --profile setup run --rm pb-setup

# Daarna alleen:
docker compose up -d
```

De app draait op:
- **Frontend:** http://localhost:3000
- **PocketBase API:** http://localhost:8090
- **PocketBase Admin:** http://localhost:8090/_/

### Makefile shortcuts

```bash
make up        # Start containers
make down      # Stop containers
make rebuild   # Rebuild + restart frontend
make setup     # Run PocketBase collection setup
make logs      # Tail container logs
```

---

## Productie Deployment (Docker Linux)

### Vereisten

- Linux server (Ubuntu 22.04+ aanbevolen) met Docker + Docker Compose
- Domein met DNS A-record naar je server
- Poort 80 + 443 open (voor Caddy HTTPS)
- Minimaal 1 GB RAM, 10 GB disk

### Stap-voor-stap deployment (setbaas.nl)

```bash
# 1. Installeer Docker (als dat nog niet is gedaan)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log opnieuw in

# 2. Clone op de server
git clone https://github.com/stolkie78/setbaas.git
cd setbaas

# 3. Configureer environment
cp .env.example .env
nano .env
# Minimaal invullen:
#   PB_ADMIN_EMAIL=admin@setbaas.nl
#   PB_ADMIN_PASSWORD=<sterk wachtwoord>
#   GOOGLE_CLIENT_ID=<van Google Cloud Console>
#   GOOGLE_CLIENT_SECRET=<van Google Cloud Console>

# 4. Eerste deployment (inclusief collection setup)
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml --profile setup run --rm pb-setup

# 5. Updates deployen
git pull && docker compose -f docker-compose.prod.yml up -d --build
```

### HTTPS / Let's Encrypt

Caddy regelt automatisch een Let's Encrypt certificaat voor `setbaas.nl`:
- Poort **80** en **443** moeten open staan op de server
- DNS A-record voor `setbaas.nl` moet naar het server IP wijzen
- Caddy handelt certificate provisioning, renewal en OCSP stapling automatisch af
- `www.setbaas.nl` wordt automatisch geredirect naar `setbaas.nl`

### Docker Compose bestanden

| Bestand | Gebruik |
|---------|---------|
| `docker-compose.yml` | Lokale development (geen Caddy, poort 3000+8090) |
| `docker-compose.local.yml` | LAN deployment op `setbaas.local` (HTTP only) |
| `docker-compose.prod.yml` | Productie op `setbaas.nl` (HTTPS via Let's Encrypt) |

### URLs na deployment

| URL | Functie |
|-----|---------|
| `https://setbaas.nl/` | Frontend app |
| `https://setbaas.nl/api/` | PocketBase REST API |
| `https://setbaas.nl/_/` | PocketBase Admin UI |
| `https://www.readplando.com/setbaas/api/_/` | PocketBase Admin UI |

### Google OAuth configuratie

Na deployment, update de **Authorized redirect URI** in de [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

```
https://www.readplando.com/setbaas/api/oauth2-redirect
```

### Onderhoud

```bash
# Logs bekijken
docker compose -f docker-compose.prod.yml logs -f

# Herstart na config wijziging
docker compose -f docker-compose.prod.yml restart

# Backend data backup (SQLite)
docker compose -f docker-compose.prod.yml exec pocketbase cp /pb/pb_data/data.db /pb/pb_data/backup.db

# Volledige rebuild
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d
```

---

## Azure Container Apps Deployment

Een alternatieve deployment op Azure Container Apps (Bicep):

```bash
# Login
az login

# Deploy
./infra/deploy.sh
```

Zie `infra/main.bicep` voor de volledige infrastructuur definitie.

Geschatte kosten: **€5-16/maand** (consumption plan).

---

## AI Configuratie

SetBaas ondersteunt AI-gegenereerde trainingsplannen via OpenAI of Google Gemini.

### Setup

1. Ga naar **Configuratie → AI** in de app
2. Kies provider: **OpenAI (GPT)** of **Google Gemini**
3. Vul je API key in:
   - OpenAI: [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
   - Gemini: [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
4. Kies een model (optioneel)

### Beschikbare modellen

| Provider | Model | Omschrijving |
|----------|-------|-------------|
| OpenAI | `gpt-4o-mini` | Snel en goedkoop |
| OpenAI | `gpt-4o` | Beste kwaliteit |
| OpenAI | `gpt-4.1-mini` | Nieuwste mini model |
| Gemini | `gemini-2.5-flash` | Snel |
| Gemini | `gemini-3.1-pro-preview` | Beste kwaliteit |

### Systeem prompt

De AI stuurt altijd een volleybal-specifieke systeem prompt mee, geoptimaliseerd voor meiden B (14-16 jaar). Deze prompt zorgt voor:
- Gestructureerde trainingsplannen in Markdown
- Oefeningen met naam, doel, uitleg, duur en variaties
- Opbouw van techniek → toepassing → spelvorm
- 90 minuten standaard trainingsduur

Je kunt de systeem prompt aanpassen in **Configuratie → AI** voor jouw specifieke teamcontext.

### Gebruik

Bij **Nieuwe training** verschijnt een "Genereer met AI" prompt veld. Voorbeeld prompts:
- "Training focus op bovenhands spel, 90 minuten"
- "Verdedigingstraining met veel balrally oefeningen"
- "Wedstrijdvoorbereiding tegen sterk blokkend team"

---

## Nevobo Integratie

Import wedstrijdschema's direct vanuit de Nederlandse Volleybal Bond (Nevobo) API.

### Configuratie

1. Ga naar **Configuratie → Teams** en vul de Nevobo URL in bij je team
2. Ga naar **Wedstrijden → 📥 Nevobo** om het importscherm te openen
3. Vul je verenigingscode in (bijv. `CKL9N3N` voor Zovoc)
4. Selecteer teamtype en nummer

### Features

- **Automatisch ophalen** van wedstrijdschema met datum, tijd, locatie, tegenstander
- **Thuis/Uit detectie** op basis van teamnaam
- **Upsert bij herimport** — bestaande wedstrijden worden bijgewerkt (datum, locatie, scores) zonder je eigen data (lineups, notities, wissels) te overschrijven
- **Scores importeren** zodra wedstrijden gespeeld zijn (setstanden + uitslag)

---

## Architectuur

```
┌─────────────────────────────────────────────┐
│  Caddy (reverse proxy, auto HTTPS)          │
│  :80 / :443                                 │
├─────────────────────────────────────────────┤
│  /setbaas/*        → Frontend (:3000)      │
│  /setbaas/api/*    → PocketBase (:8090)    │
└─────────────────────────────────────────────┘
         │                      │
    ┌────▼────┐          ┌──────▼──────┐
    │ SvelteKit│          │ PocketBase  │
    │ Node.js  │          │ SQLite      │
    │ :3000    │◄────────►│ :8090       │
    └──────────┘  API     └─────────────┘
         │                      │
    ┌────▼────┐          ┌──────▼──────┐
    │ /api/ai │          │ pb_data/    │
    │ /api/   │          │ (volume)    │
    │ nevobo  │          └─────────────┘
    └─────────┘
```

### Server-side proxy routes

| Route | Doel |
|-------|------|
| `/api/nevobo` | CORS proxy voor Nevobo API (api.nevobo.nl) |
| `/api/ai` | AI generation endpoint (OpenAI/Gemini) |

---

## Project Structuur

```
├── frontend/                   # SvelteKit app
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/     # MarkdownEditor etc.
│   │   │   ├── stores/         # Auth, context, AI config stores
│   │   │   ├── types/          # TypeScript interfaces
│   │   │   ├── pocketbase.ts   # PocketBase SDK + API functies
│   │   │   └── nevobo.ts       # Nevobo API helper
│   │   └── routes/
│   │       ├── api/
│   │       │   ├── ai/         # AI generation endpoint
│   │       │   └── nevobo/     # Nevobo CORS proxy
│   │       ├── matches/
│   │       │   └── import/     # Nevobo match import page
│   │       ├── trainings/      # Training CRUD
│   │       ├── config/         # Configuratie (teams, AI, etc.)
│   │       └── +page.svelte    # Dashboard
│   ├── Dockerfile
│   ├── svelte.config.js        # Base path configuratie
│   └── tailwind.config.js
├── infra/                      # Azure Bicep deployment
│   ├── main.bicep
│   ├── main.bicepparam
│   └── deploy.sh
├── scripts/
│   ├── setup-collections.sh    # Idempotent PB setup
│   └── deploy-prod.sh          # Productie deploy script
├── docker-compose.yml          # Lokale development
├── docker-compose.prod.yml     # Productie (met Caddy)
├── Caddyfile                   # Reverse proxy config
├── Dockerfile.pocketbase       # PB image voor ACR
├── .env.production             # Env template
├── .env                        # Lokale secrets (gitignored)
└── Makefile
```

---

## Environment Variables

| Variable | Beschrijving | Voorbeeld |
|----------|-------------|-----------|
| `DOMAIN` | Productie domein | `www.readplando.com` |
| `BASE_PATH` | Subpath voor SvelteKit | `/setbaas` |
| `PUBLIC_POCKETBASE_URL` | PB API URL (voor frontend) | `https://www.readplando.com/setbaas/api` |
| `ORIGIN` | Frontend origin | `https://www.readplando.com` |
| `PB_ADMIN_EMAIL` | PocketBase admin email | `admin@setbaas.app` |
| `PB_ADMIN_PASSWORD` | PocketBase admin wachtwoord | (secret) |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | `*.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret | (secret) |

> **Let op:** AI API keys worden **niet** server-side opgeslagen. Ze staan in de browser's localStorage en worden per-request meegestuurd naar de `/api/ai` proxy.

---

## PocketBase Collections

Het setup script (`scripts/setup-collections.sh`) maakt automatisch alle benodigde collections aan:

| Collection | Beschrijving |
|-----------|-------------|
| `teams` | Teams (naam, nevobo_code, nevobo_url) |
| `seasons` | Seizoenen (naam, start/eind jaar) |
| `players` | Spelers (naam, foto, positie, status) |
| `team_players` | Koppeling speler↔team↔seizoen |
| `competencies` | Competentie definities |
| `player_competencies` | Scores per speler per competentie |
| `trainings` | Trainingen (markdown content, score, status) |
| `training_templates` | Herbruikbare training templates |
| `training_attendance` | Aanwezigheid + individuele scores |
| `training_plans` | Jaarplanning |
| `matches` | Wedstrijden (nevobo_uuid voor sync, locatie, scores) |
| `match_sets` | Per-set data |
| `season_periods` | Periodisering fases |
| `team_access` | Gebruikersrechten per team |

---

## Versies

| Tag | Beschrijving |
|-----|-------------|
| v0.1 | Eerste werkende versie (auth, spelers, trainingen, wedstrijden) |
| v0.2 | Idempotent setup, data safety, default seeding |
| v0.3 | Markdown editor, Nevobo import, AI integratie, dashboard, subpath deployment |

---

## Licentie

Private project.
