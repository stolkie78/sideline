import { pb } from '$lib/pocketbase';
import { EXTRA_ACTIVITY_LABELS } from '$lib/types';
import type { ExtraActivity } from '$lib/types';

/** Trainingen en wedstrijden hebben geen duurveld, dus rekenen we met vaste blokken. */
export const TRAINING_HOURS = 1.5;
export const MATCH_HOURS = 2;

/** Aantal weken waarover we terugkijken voor het gemiddelde. */
export const LOAD_WINDOW_WEEKS = 8;

export interface LoadLine {
	label: string;
	detail?: string;
	hoursPerWeek: number;
}

export interface PlayerLoad {
	weeks: number;
	trainingCount: number;
	matchCount: number;
	teamHoursPerWeek: number;
	extraHoursPerWeek: number;
	totalHoursPerWeek: number;
	lines: LoadLine[];
}

function round(value: number): number {
	return Math.round(value * 10) / 10;
}

export function extraActivityLabel(activity: ExtraActivity, teamNames: Record<string, string> = {}): string {
	const type = EXTRA_ACTIVITY_LABELS[activity.type] || activity.type;
	const team = (activity.team && teamNames[activity.team]) || activity.team_name;
	return team ? `${type} — ${team}` : type;
}

/** Telt de uren per week uit teamtrainingen, wedstrijden en extra activiteiten. */
export function buildPlayerLoad(input: {
	trainingCount: number;
	matchCount: number;
	extras: ExtraActivity[];
	teamNames?: Record<string, string>;
	weeks?: number;
}): PlayerLoad {
	const weeks = input.weeks || LOAD_WINDOW_WEEKS;
	const trainingHours = (input.trainingCount * TRAINING_HOURS) / weeks;
	const matchHours = (input.matchCount * MATCH_HOURS) / weeks;
	const teamHoursPerWeek = trainingHours + matchHours;

	const lines: LoadLine[] = [];
	if (input.trainingCount > 0) {
		lines.push({
			label: 'Teamtrainingen',
			detail: `${input.trainingCount} in ${weeks} weken`,
			hoursPerWeek: round(trainingHours),
		});
	}
	if (input.matchCount > 0) {
		lines.push({
			label: 'Wedstrijden',
			detail: `${input.matchCount} in ${weeks} weken`,
			hoursPerWeek: round(matchHours),
		});
	}

	let extraHoursPerWeek = 0;
	for (const extra of input.extras || []) {
		const hours = Number(extra.hours) || 0;
		extraHoursPerWeek += hours;
		lines.push({
			label: extraActivityLabel(extra, input.teamNames),
			detail: extra.notes || 'Extra belasting',
			hoursPerWeek: round(hours),
		});
	}

	return {
		weeks,
		trainingCount: input.trainingCount,
		matchCount: input.matchCount,
		teamHoursPerWeek: round(teamHoursPerWeek),
		extraHoursPerWeek: round(extraHoursPerWeek),
		totalHoursPerWeek: round(teamHoursPerWeek + extraHoursPerWeek),
		lines,
	};
}

/**
 * Haalt de daadwerkelijke deelname van een speler op over het venster: alleen
 * trainingen waar de speler aanwezig was en wedstrijden van het eigen team.
 */
export async function fetchPlayerLoad(
	playerId: string,
	extras: ExtraActivity[],
	options: { teamId?: string; seasonId?: string; weeks?: number } = {}
): Promise<PlayerLoad> {
	const weeks = options.weeks || LOAD_WINDOW_WEEKS;
	const since = new Date();
	since.setDate(since.getDate() - weeks * 7);
	const sinceIso = since.toISOString().slice(0, 19).replace('T', ' ');
	const nowIso = new Date().toISOString().slice(0, 19).replace('T', ' ');

	let trainingCount = 0;
	let matchCount = 0;

	try {
		const attendance = await pb.collection('training_attendance').getFullList({
			filter: `player = "${playerId}" && status = "present"`,
			expand: 'training',
		});
		trainingCount = attendance.filter((a: any) => {
			const date = a.expand?.training?.date;
			return date && date >= sinceIso && date <= nowIso;
		}).length;
	} catch (e) {
		console.error('Failed to load training attendance for load report:', e);
	}

	if (options.teamId) {
		try {
			const filters = [`team = "${options.teamId}"`, `date >= "${sinceIso}"`, `date <= "${nowIso}"`];
			if (options.seasonId) filters.push(`season = "${options.seasonId}"`);
			const matches = await pb.collection('matches').getFullList({ filter: filters.join(' && ') });
			matchCount = matches.length;
		} catch (e) {
			console.error('Failed to load matches for load report:', e);
		}
	}

	const teamNames: Record<string, string> = {};
	const teamIds = [...new Set((extras || []).map((e) => e.team).filter(Boolean))] as string[];
	for (const id of teamIds) {
		try {
			const team = await pb.collection('teams').getOne(id);
			teamNames[id] = team.name;
		} catch {
			// Team kan verwijderd zijn; dan valt hij terug op de vrije tekst.
		}
	}

	return buildPlayerLoad({ trainingCount, matchCount, extras: extras || [], teamNames, weeks });
}
