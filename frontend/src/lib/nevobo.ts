// Nevobo API helper for fetching match schedules
const NEVOBO_API = 'https://api.nevobo.nl';

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
	letter: string;
	naam?: string;
}

/**
 * Search for teams by name in Nevobo
 */
export async function searchNevoboTeams(query: string): Promise<NevoboTeam[]> {
	const res = await fetch(`${NEVOBO_API}/competitie/teams?naam=${encodeURIComponent(query)}`, {
		headers: { Accept: 'application/json' }
	});
	if (!res.ok) return [];
	return res.json();
}

/**
 * Get matches for a team by verenigingscode and team type
 * e.g. getTeamMatches('CKM1H25', 'hs', 1) for Vereniging X Heren 1
 */
export async function getTeamMatches(
	verenigingsCode: string,
	teamType: string,
	teamNumber: number
): Promise<NevoboMatch[]> {
	const code = verenigingsCode.toLowerCase();
	const type = teamType.toLowerCase();

	// Get matches filtered by vereniging
	const res = await fetch(
		`${NEVOBO_API}/competitie/wedstrijden?vereniging=/relatiebeheer/verenigingen/${code}`,
		{ headers: { Accept: 'application/json' } }
	);
	if (!res.ok) return [];
	const allMatches: NevoboMatch[] = await res.json();

	// Filter matches that involve this specific team
	// Team IRIs contain the pattern: verenigingscode/teamtype/volgnummer
	const teamPattern = `${code}/${type}/${teamNumber}`;

	return allMatches.filter(match => {
		return match.teams?.some(t => t.toLowerCase().includes(teamPattern));
	});
}

/**
 * Resolve a pouleindeling IRI to get the team name
 */
export async function resolvePouleIndeling(iri: string): Promise<string> {
	try {
		const res = await fetch(`${NEVOBO_API}${iri}`, {
			headers: { Accept: 'application/json' }
		});
		if (!res.ok) return iri;
		const data = await res.json();
		return data.team?.naam || data.naam || iri;
	} catch {
		return iri;
	}
}

/**
 * Resolve sporthal name from IRI
 */
export async function resolveSporthal(iri: string): Promise<string> {
	if (!iri) return '';
	try {
		const res = await fetch(`${NEVOBO_API}${iri}`, {
			headers: { Accept: 'application/json' }
		});
		if (!res.ok) return '';
		const data = await res.json();
		return data.naam || data.name || '';
	} catch {
		return '';
	}
}
