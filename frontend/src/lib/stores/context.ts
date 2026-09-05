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

// Teams belonging to a club. Teams without a club are always included so an
// incomplete club relation never leaves the user without a selectable team.
export function teamsInClub(allTeams: Team[], clubId: string): Team[] {
	if (!clubId) return allTeams;
	return allTeams.filter((t) => !t.club || t.club === clubId);
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
	const parts: string[] = [];
	if (teamId) parts.push(`team = "${teamId}"`);
	if (seasonId) parts.push(`season = "${seasonId}"`);
	return parts.join(' && ');
}
