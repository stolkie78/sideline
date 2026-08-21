import type { RecordModel } from 'pocketbase';

// === Collection Types ===

export interface Player extends RecordModel {
	name: string;
	photo: string;
	position: PlayerPosition[];
	status: PlayerStatus;
	jersey_number?: number;
	email?: string;
	user_id?: string;
}

export interface Team extends RecordModel {
	name: string;
	nevobo_code?: string; // Nevobo verenigingscode (e.g. CKM1H25)
	nevobo_team_type?: string; // e.g. 'hs', 'ds', 'mb', 'mj'
	nevobo_team_number?: number; // e.g. 1
	nevobo_url?: string; // URL to team page on volleybal.nl
}

export interface Season extends RecordModel {
	name: string;
	start_year: number;
	end_year: number;
}

export interface TeamPlayer extends RecordModel {
	team: string;
	season: string;
	player: string;
	expand?: {
		player?: Player;
		team?: Team;
		season?: Season;
	};
}

export type PlayerPosition =
	| 'setter'
	| 'outside_hitter'
	| 'opposite'
	| 'middle_blocker'
	| 'libero'
	| 'defensive_specialist';

export type PlayerStatus = 'active' | 'injured' | 'inactive';

export interface Competency extends RecordModel {
	name: string;
	category: CompetencyCategory;
	description?: string;
}

export type CompetencyCategory = 'technical' | 'tactical' | 'physical' | 'mental';

export interface PlayerCompetency extends RecordModel {
	player: string;
	competency: string;
	rating: number;
	date: string;
	notes?: string;
	created_by?: string;
	// Expanded relations
	expand?: {
		player?: Player;
		competency?: Competency;
		created_by?: { id: string; name: string; email: string };
	};
}

export interface Training extends RecordModel {
	date: string;
	overall_rating?: number;
	general_comments?: string;
	team?: string;
	season?: string;
	template?: string;
	status?: 'open' | 'closed';
	content?: string;
	created_by?: string;
	expand?: {
		template?: TrainingTemplate;
		created_by?: { id: string; name: string; email: string };
	};
}

export interface TrainingAttendance extends RecordModel {
	training: string;
	player: string;
	status: AttendanceStatus;
	player_rating?: number;
	player_notes?: string;
	// Expanded relations
	expand?: {
		player?: Player;
		training?: Training;
	};
}

export type AttendanceStatus = 'present' | 'absent' | 'sick' | 'injured';

export type AvailabilityStatus = 'available' | 'unavailable' | 'uncertain';

export interface PlayerAvailability extends RecordModel {
	player: string;
	training?: string;
	match?: string;
	status: AvailabilityStatus;
	reason?: string;
	expand?: {
		player?: Player;
		training?: Training;
		match?: Match;
	};
}

export interface Match extends RecordModel {
	date: string;
	opponent: string;
	home_away: 'home' | 'away';
	score_team?: number;
	score_opponent?: number;
	set_scores?: SetScore[];
	general_notes?: string;
	team?: string;
	season?: string;
	lineups?: SetLineup[];
	game_system?: SetGameSystem[];
	substitutions?: Substitution[];
	timeouts?: Timeout[];
	created_by?: string;
	expand?: {
		created_by?: { id: string; name: string; email: string };
	};
}

export interface SetScore {
	team: number | null;
	opponent: number | null;
}

// Positions 1-6 mapped to player IDs
export interface SetLineup {
	set: number;
	positions: Record<string, string>; // "1"-"6" -> player ID
}

export type GameSystem = '5-1' | '6-2' | '4-2' | '6-0' | '';

export interface SetGameSystem {
	set: number;
	system: GameSystem;
}

export interface Substitution {
	set: number;
	playerIn: string;
	playerOut: string;
	atScore?: string; // e.g. "15-12"
}

export interface Timeout {
	set: number;
	team: 'own' | 'opponent';
	atScore?: string;
}

export const GAME_SYSTEM_LABELS: Record<string, string> = {
	'5-1': '5-1 (1 vaste spelverdeler)',
	'6-2': '6-2 (2 spelverdelers)',
	'4-2': '4-2 (2 spelverdelers vooraan)',
	'6-0': '6-0 (geen vaste spelverdeler)',
};

// Court position labels (1-6)
export const COURT_POSITION_LABELS: Record<string, string> = {
	'1': 'Pos 1 (RA)',
	'2': 'Pos 2 (RV)',
	'3': 'Pos 3 (MV)',
	'4': 'Pos 4 (LV)',
	'5': 'Pos 5 (LA)',
	'6': 'Pos 6 (MA)',
};

export interface PositionPoints {
	set: number;
	position: PlayerPosition;
	points: number;
}

export interface MatchPlayerStats extends RecordModel {
	match: string;
	player: string;
	position_points?: PositionPoints[];
	notes?: string;
	expand?: {
		player?: Player;
		match?: Match;
	};
}

// === UI Helper Types ===

export const POSITION_LABELS: Record<PlayerPosition, string> = {
	setter: 'Setter',
	outside_hitter: 'Buitenaanvaller',
	opposite: 'Diagonal',
	middle_blocker: 'Middenblokker',
	libero: 'Libero',
	defensive_specialist: 'Verdedigingsspecialist',
};

export const STATUS_LABELS: Record<PlayerStatus, string> = {
	active: 'Actief',
	injured: 'Geblesseerd',
	inactive: 'Inactief',
};

export const ATTENDANCE_LABELS: Record<AttendanceStatus, string> = {
	present: 'Aanwezig',
	absent: 'Afwezig',
	sick: 'Ziek',
	injured: 'Geblesseerd',
};

export const CATEGORY_LABELS: Record<CompetencyCategory, string> = {
	technical: 'Technisch',
	tactical: 'Tactisch',
	physical: 'Fysiek',
	mental: 'Mentaal',
};

// === Training Templates & Plan ===

export type TrainingType = 'serve' | 'pass' | 'attack' | 'block' | 'defense' | 'setting' | 'all_round' | 'game' | 'conditioning';

export const TRAINING_TYPE_LABELS: Record<TrainingType, string> = {
	serve: 'Opslag',
	pass: 'Pass',
	attack: 'Aanval',
	block: 'Blok',
	defense: 'Verdediging',
	setting: 'Setup',
	all_round: 'All-round',
	game: 'Wedstrijdvorm',
	conditioning: 'Conditie/Kracht',
};

export const TRAINING_PHASES = ['warmup', 'technique', 'core1', 'core2', 'game'] as const;
export type TrainingPhase = typeof TRAINING_PHASES[number];

export const PHASE_LABELS: Record<TrainingPhase, string> = {
	warmup: 'Warm-up / Kracht',
	technique: 'Techniek',
	core1: 'Kern 1',
	core2: 'Kern 2',
	game: 'Game',
};

export interface TrainingTemplate extends RecordModel {
	name: string;
	type: TrainingType;
	content: string;
	notes: string;
	team: string;
	season: string;
}

export interface TrainingPlan extends RecordModel {
	date: string;
	template: string;
	title: string;
	content: string;
	notes: string;
	team: string;
	season: string;
	expand?: {
		template?: TrainingTemplate;
	};
}

// === Season Periodization ===

export type SeasonPhase = 'preparation' | 'competition_1' | 'winter_break' | 'competition_2' | 'playoffs' | 'off_season';

export const SEASON_PHASE_LABELS: Record<SeasonPhase, string> = {
	preparation: 'Voorbereiding',
	competition_1: 'Competitie 1e helft',
	winter_break: 'Winterstop',
	competition_2: 'Competitie 2e helft',
	playoffs: 'Playoffs / Nacompetitie',
	off_season: 'Rustperiode',
};

export const SEASON_PHASE_COLORS: Record<SeasonPhase, string> = {
	preparation: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
	competition_1: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
	winter_break: 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400',
	competition_2: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400',
	playoffs: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
	off_season: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400',
};

export interface SeasonPeriod extends RecordModel {
	name: string;
	phase: SeasonPhase;
	start_date: string;
	end_date: string;
	goals_technical: string;
	goals_tactical: string;
	goals_physical: string;
	goals_mental: string;
	notes: string;
	team: string;
	season: string;
}
