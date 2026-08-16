import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';
import type { Team, Season } from '$lib/types';

// Selected team & season IDs
function createPersistentStore(key: string, initial: string) {
	const stored = browser ? localStorage.getItem(key) : null;
	const store = writable<string>(stored || initial);

	if (browser) {
		store.subscribe((value) => {
			localStorage.setItem(key, value);
		});
	}

	return store;
}

export const selectedTeamId = createPersistentStore('selectedTeamId', '');
export const selectedSeasonId = createPersistentStore('selectedSeasonId', '');

// Full objects (set from layout)
export const teams = writable<Team[]>([]);
export const seasons = writable<Season[]>([]);

// Derived: current team & season objects
export const currentTeam = derived(
	[teams, selectedTeamId],
	([$teams, $id]) => $teams.find((t) => t.id === $id) || null
);

export const currentSeason = derived(
	[seasons, selectedSeasonId],
	([$seasons, $id]) => $seasons.find((s) => s.id === $id) || null
);

// Helper: build PocketBase filter string for team/season
export function contextFilter(teamId: string, seasonId: string): string {
	const parts: string[] = [];
	if (teamId) parts.push(`team = "${teamId}"`);
	if (seasonId) parts.push(`season = "${seasonId}"`);
	return parts.join(' && ');
}
