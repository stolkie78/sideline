// Nevobo API helper for fetching match schedules
// All requests go through /api/nevobo proxy to avoid CORS issues
import { base } from '$app/paths';

async function nevoboFetch(path: string): Promise<Response> {
	return fetch(`${base}/api/nevobo?path=${encodeURIComponent(path)}`);
}

export interface NevoboMatch {
	uuid: string;
	code: string;
	datum: string;
	tijdstip: string;
	sporthal: string;
	poule: string;
	teams: string[];
	status: { waarde: string; omschrijving: string };
	urlDwf?: string;
	setstanden?: { set: number; team1: number; team2: number }[];
	uitslag?: { setsTeam1: number; setsTeam2: number };
}

export interface NevoboTeam {
	uuid: string;
	naam: string;
	seizoen: string;
	vereniging: string;
	volgnummer: number;
}

export interface NevoboPouleIndeling {
	team: string;
	omschrijving: string;
	indelingsletter: string;
}

// Team types as used in the Nevobo URL structure
export const NEVOBO_TEAM_TYPES = [
	{ value: 'heren', label: 'Heren' },
	{ value: 'dames', label: 'Dames' },
	{ value: 'jongens-a', label: 'Jongens A' },
	{ value: 'jongens-b', label: 'Jongens B' },
	{ value: 'jongens-c', label: 'Jongens C' },
	{ value: 'meiden-a', label: 'Meiden A' },
	{ value: 'meiden-b', label: 'Meiden B' },
	{ value: 'meiden-c', label: 'Meiden C' },
	{ value: 'cmv-6', label: 'CMV 6' },
	{ value: 'cmv-4', label: 'CMV 4' },
];

/**
 * Get matches for a team using the Nevobo team IRI filter
 * @param code - Verenigingscode (e.g. CKL9N3N)
 * @param teamType - Team type slug (e.g. meiden-b, heren, dames)
 * @param teamNumber - Team number (e.g. 1)
 */
export async function getTeamMatches(
	code: string,
	teamType: string,
	teamNumber: number
): Promise<NevoboMatch[]> {
	const path = `/competitie/wedstrijden?team=${encodeURIComponent(`/competitie/teams/${code.toLowerCase()}/${teamType}/${teamNumber}`)}`;
	const res = await nevoboFetch(path);
	if (!res.ok) return [];
	return res.json();
}

/**
 * Resolve a pouleindeling IRI to get the team name
 */
export async function resolvePouleIndeling(iri: string): Promise<string> {
	try {
		const res = await nevoboFetch(iri);
		if (!res.ok) return '?';
		const data: NevoboPouleIndeling = await res.json();
		return data.omschrijving || '?';
	} catch {
		return '?';
	}
}

/**
 * Resolve sporthal name from IRI
 */
export async function resolveSporthal(iri: string): Promise<string> {
	if (!iri) return '';
	try {
		const res = await nevoboFetch(iri);
		if (!res.ok) return '';
		const data = await res.json();
		return data.naam || '';
	} catch {
		return '';
	}
}

/**
 * Get team info by code/type/number
 */
export async function getTeamInfo(code: string, teamType: string, teamNumber: number): Promise<NevoboTeam | null> {
	try {
		const res = await nevoboFetch(`/competitie/teams/${code.toLowerCase()}/${teamType}/${teamNumber}`);
		if (!res.ok) return null;
		return res.json();
	} catch {
		return null;
	}
}
