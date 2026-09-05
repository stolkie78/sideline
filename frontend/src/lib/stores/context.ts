import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';
import type { Club, Team, Season } from '$lib/types';

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

export const selectedClubId = createPersistentStore('selectedClubId', '');
export const selectedTeamId = createPersistentStore('selectedTeamId', '');
export const selectedSeasonId = createPersistentStore('selectedSeasonId', '');

// Full objects (set from layout)
export const clubs = writable<Club[]>([]);
export const teams = writable<Team[]>([]);
export const seasons = writable<Season[]>([]);

// Derived: current club, team & season objects
export const currentClub = derived(
	[clubs, selectedClubId],
	([$clubs, $id]) => $clubs.find((c) => c.id === $id) || null
);

/**
 * Teams belonging to a club. A club without teams yields an empty list, so its
 * pages stay empty instead of showing another club's data. Only when no team
 * has a club at all — an unmigrated database — do we fall back to every team.
 */
export function teamsInClub(allTeams: Team[], clubId: string): Team[] {
	if (!clubId) return allTeams;
	if (!allTeams.some((t) => t.club)) return allTeams;
	return allTeams.filter((t) => t.club === clubId);
}

export const clubTeams = derived([teams, selectedClubId], ([$teams, $clubId]) =>
	teamsInClub($teams, $clubId)
);

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
	// Without a team there is no club context, so match nothing rather than
	// falling back to every team in the season.
	if (!teamId) return 'team = ""';

	const parts = [`team = "${teamId}"`];
	if (seasonId) parts.push(`season = "${seasonId}"`);
	return parts.join(' && ');
}
