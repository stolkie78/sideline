import type { Match, SetScore } from '$lib/types';

/**
 * Score convention: the FIRST number of a set (and of the final score) always
 * belongs to the HOME team, exactly like on a Nevobo scoresheet. Which side is
 * "ours" therefore depends on match.home_away.
 */

export interface MatchSetResult {
	set: number;
	home: number | null;
	away: number | null;
	ours: number | null;
	theirs: number | null;
	/** true = we won this set, false = we lost it, null = not played/incomplete */
	wonByUs: boolean | null;
}

export interface MatchScore {
	ourSets: number;
	theirSets: number;
	homeSets: number;
	awaySets: number;
	played: boolean;
}

export type MatchOutcome = 'won' | 'lost' | 'draw' | null;

type MatchLike = Pick<Match, 'home_away'> &
	Partial<Pick<Match, 'set_scores' | 'score_team' | 'score_opponent'>>;

export function isHomeMatch(match: MatchLike): boolean {
	return match.home_away !== 'away';
}

function toSetScores(match: MatchLike): SetScore[] {
	const raw = match.set_scores;
	return Array.isArray(raw) ? (raw as SetScore[]) : [];
}

export function getMatchSets(match: MatchLike): MatchSetResult[] {
	const home = isHomeMatch(match);

	return toSetScores(match).map((set, i) => {
		const homeScore = set?.team ?? null;
		const awayScore = set?.opponent ?? null;
		const ours = home ? homeScore : awayScore;
		const theirs = home ? awayScore : homeScore;
		const wonByUs = ours === null || theirs === null || ours === theirs ? null : ours > theirs;

		return { set: i + 1, home: homeScore, away: awayScore, ours, theirs, wonByUs };
	});
}

export function getMatchScore(match: MatchLike): MatchScore {
	const sets = getMatchSets(match).filter((s) => s.wonByUs !== null);

	if (sets.length > 0) {
		const ourSets = sets.filter((s) => s.wonByUs === true).length;
		const theirSets = sets.length - ourSets;
		const home = isHomeMatch(match);

		return {
			ourSets,
			theirSets,
			homeSets: home ? ourSets : theirSets,
			awaySets: home ? theirSets : ourSets,
			played: true,
		};
	}

	// Fallback on the stored final score, which is also home-first.
	const homeSets = match.score_team ?? null;
	const awaySets = match.score_opponent ?? null;

	if (homeSets === null || homeSets === undefined || awaySets === null || awaySets === undefined) {
		return { ourSets: 0, theirSets: 0, homeSets: 0, awaySets: 0, played: false };
	}

	const home = isHomeMatch(match);

	return {
		ourSets: home ? homeSets : awaySets,
		theirSets: home ? awaySets : homeSets,
		homeSets,
		awaySets,
		played: true,
	};
}

export function getMatchOutcome(match: MatchLike): MatchOutcome {
	const { ourSets, theirSets, played } = getMatchScore(match);
	if (!played) return null;
	if (ourSets > theirSets) return 'won';
	if (ourSets < theirSets) return 'lost';
	return 'draw';
}

/** "3 - 1" from our perspective. */
export function formatMatchScore(match: MatchLike): string {
	const { ourSets, theirSets } = getMatchScore(match);
	return `${ourSets} - ${theirSets}`;
}

/** "25-20" as printed on the scoresheet (home first). */
export function formatSetScore(set: MatchSetResult): string {
	return `${set.home ?? '?'}-${set.away ?? '?'}`;
}
