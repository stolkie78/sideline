# 🏐 TeamTracker - Volleybal Team Management PWA

Een Progressive Web App voor het beheren van je volleybalteam: spelers, trainingen, wedstrijden en competentie-ontwikkeling.

## Tech Stack

- **Backend:** PocketBase (SQLite + Auth + REST API + File Storage)
- **Frontend:** SvelteKit + TypeScript
- **Styling:** Tailwind CSS (mobile-first)
- **Charts:** Chart.js
- **Deployment:** Docker Compose

## Quick Start

### Optie 1: Docker (aanbevolen voor productie)

```bash
docker compose up -d
```

- Frontend: http://localhost:3000
- PocketBase Admin: http://localhost:8090/_/

### Optie 2: Development (lokaal)

```bash
# Terminal 1: PocketBase
# Download PocketBase van https://pocketbase.io/docs/
./pocketbase serve --migrationsDir=./pb_migrations

# Terminal 2: Frontend
cd frontend
npm install
npm run dev
```

Frontend draait op http://localhost:5173

## Eerste Setup

1. Start de applicatie
2. Ga naar PocketBase Admin (http://localhost:8090/_/)
3. Maak een admin-account aan
4. De migrations maken automatisch alle collections aan
5. De seed-migration voegt standaard volleybal-competenties toe

## Project Structuur

```
TeamTracker/
├── docker-compose.yml          # Docker orchestratie
├── pb_migrations/              # PocketBase database migrations
│   ├── 1_create_players.js
│   ├── 2_create_competencies.js
│   ├── 3_create_player_competencies.js
│   ├── 4_create_trainings.js
│   ├── 5_create_training_attendance.js
│   ├── 6_create_matches.js
│   ├── 7_create_match_player_stats.js
│   └── 8_seed_competencies.js
├── pb_data/                    # PocketBase data (gitignore)
└── frontend/
    ├── Dockerfile
    ├── src/
    │   ├── lib/
    │   │   ├── pocketbase.ts       # PocketBase SDK client
    │   │   ├── types/index.ts      # TypeScript types
    │   │   └── components/         # Herbruikbare UI componenten
    │   └── routes/
    │       ├── +page.svelte        # Dashboard
    │       ├── players/            # Spelersoverzicht & profiel
    │       ├── trainings/          # Trainingsbeheer
    │       └── matches/            # Wedstrijdregistratie
    └── tailwind.config.js
```

## Functionaliteiten

### ✅ Spelersbeheer
- Spelers aanmaken met foto, positie, rugnummer
- Status tracking (actief/geblesseerd/inactief)
- Competentie-scores vastleggen over tijd
- Groeigrafiek per competentie (Chart.js)

### ✅ Trainingstracking
- Snel-invoer formulier (mobiel-vriendelijk, langs de lijn)
- Aanwezigheid met één tik wisselen
- Individuele scores en notities per speler
- Algemene trainingsbeoordeling

### ✅ Wedstrijdregistratie
- Wedstrijd aanmaken met tegenstander en uitslag
- Speeltijd en sets per speler
- Individuele prestatiescores
- Win/verlies visuele indicatie

## Mobile-First UX

De app is ontworpen voor gebruik langs de lijn:
- Grote touch targets (min 48px)
- Bottom navigation tab bar
- Snelle status-toggles (tik om te wisselen)
- Compacte maar leesbare formulieren
