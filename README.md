# 🏐 SideLine — Volleybal Team Management PWA

Een Progressive Web App voor het beheren van je volleybalteam: spelers, trainingen, wedstrijden en competentie-ontwikkeling.

## Tech Stack

| Component | Technologie |
|-----------|-------------|
| **Frontend** | SvelteKit + Tailwind CSS |
| **Backend** | PocketBase (SQLite + Auth + File Storage + REST API) |
| **Reverse Proxy** | Caddy (automatisch HTTPS) |
| **Deployment** | Docker Compose |

## Features

- **Spelersbeheer** — Foto, positie(s), status, competenties per seizoen
- **Trainingen** — Markdown beschrijving met rich editor, templates, aanwezigheid + scores
- **Wedstrijden** — Per-set lineups (pos 1-6), spelsysteem, wissels, timeouts
- **Competenties** — 4x per seizoen meetbaar, eigenaarschap per meting
- **Seizoen periodisering** — Technisch/Tactisch/Fysiek/Mentaal doelen
- **Auth** — Google OAuth + email/password, multi-user met team_access (admin/coach/viewer)
- **Ownership** — Wie heeft een training klaargezet of scores ingevoerd
- **Dark mode** — Standaard aan

---

## Lokale Ontwikkeling

### Vereisten

- Docker & Docker Compose
- Node.js 20+ (alleen voor frontend dev buiten Docker)

### Starten

```bash
# Clone
git clone https://github.com/stolkie78/sideline.git
cd sideline

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

- Linux server met Docker + Docker Compose
- Domein met DNS A-record naar je server
- Poort 80 + 443 open

### Deploy naar www.readplando.com/sideline

```bash
# 1. Clone op de server
git clone https://github.com/stolkie78/sideline.git
cd sideline

# 2. Configureer
cp .env.production .env
nano .env  # Vul in: PB_ADMIN_PASSWORD, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET

# 3. Deploy (eerste keer met setup)
./scripts/deploy-prod.sh setup

# 4. Updates deployen
git pull
./scripts/deploy-prod.sh
```

### URLs na deployment

| URL | Functie |
|-----|---------|
| `https://www.readplando.com/sideline/` | Frontend app |
| `https://www.readplando.com/sideline/api/` | PocketBase REST API |
| `https://www.readplando.com/sideline/api/_/` | PocketBase Admin UI |

### Google OAuth configuratie

Na deployment, update de **Authorized redirect URI** in de [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

```
https://www.readplando.com/sideline/api/oauth2-redirect
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

## Architectuur

```
┌─────────────────────────────────────────────┐
│  Caddy (reverse proxy, auto HTTPS)          │
│  :80 / :443                                 │
├─────────────────────────────────────────────┤
│  /sideline/*        → Frontend (:3000)      │
│  /sideline/api/*    → PocketBase (:8090)    │
└─────────────────────────────────────────────┘
         │                      │
    ┌────▼────┐          ┌──────▼──────┐
    │ SvelteKit│          │ PocketBase  │
    │ Node.js  │          │ SQLite      │
    │ :3000    │◄────────►│ :8090       │
    └──────────┘  API     └─────────────┘
                                │
                          ┌─────▼─────┐
                          │ pb_data/  │
                          │ (volume)  │
                          └───────────┘
```

---

## Project Structuur

```
├── frontend/                   # SvelteKit app
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/     # MarkdownEditor etc.
│   │   │   ├── stores/         # Auth, context stores
│   │   │   ├── types/          # TypeScript interfaces
│   │   │   └── pocketbase.ts   # PocketBase SDK + API functies
│   │   └── routes/             # SvelteKit pages
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
| `BASE_PATH` | Subpath voor SvelteKit | `/sideline` |
| `PUBLIC_POCKETBASE_URL` | PB API URL (voor frontend) | `https://www.readplando.com/sideline/api` |
| `ORIGIN` | Frontend origin | `https://www.readplando.com` |
| `PB_ADMIN_EMAIL` | PocketBase admin email | `admin@sideline.app` |
| `PB_ADMIN_PASSWORD` | PocketBase admin wachtwoord | (secret) |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | `*.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret | (secret) |

---

## PocketBase Collections

Het setup script (`scripts/setup-collections.sh`) maakt automatisch alle benodigde collections aan:

| Collection | Beschrijving |
|-----------|-------------|
| `teams` | Teams (naam) |
| `seasons` | Seizoenen (naam, start/eind datum) |
| `players` | Spelers (naam, foto, positie, status) |
| `team_players` | Koppeling speler↔team↔seizoen |
| `competencies` | Competentie definities |
| `player_competencies` | Scores per speler per competentie |
| `trainings` | Trainingen (markdown content, score, status) |
| `training_templates` | Herbruikbare training templates |
| `training_attendance` | Aanwezigheid + individuele scores |
| `training_plans` | Jaarplanning |
| `matches` | Wedstrijden |
| `match_sets` | Per-set data |
| `season_periods` | Periodisering fases |
| `team_access` | Gebruikersrechten per team |

---

## Versies

| Tag | Beschrijving |
|-----|-------------|
| v0.1 | Eerste werkende versie (auth, spelers, trainingen, wedstrijden) |
| v0.2 | Idempotent setup, data safety, default seeding |

---

## Licentie

Private project.
