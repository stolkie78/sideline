import { writable, derived, get } from 'svelte/store';
import { selectedTeamId } from './context';
import { isAuthenticated } from './auth';
import { pb, getTeamAccessForUser, getPlayerByUserId, getPlayerByEmail, linkPlayerToUser } from '$lib/pocketbase';
import type { TeamAccess } from '$lib/pocketbase';
import type { Player } from '$lib/types';

export type UserRole = 'admin' | 'coach' | 'player' | null;

// All team_access records for the current user
export const userTeamAccess = writable<TeamAccess[]>([]);

// The player record linked to the current user (if any)
export const linkedPlayer = writable<Player | null>(null);

// Current role for the selected team
export const userRole = derived(
	[userTeamAccess, selectedTeamId],
	([$access, $teamId]) => {
		if (!$teamId || $access.length === 0) return null;
		// Admin on any team = admin everywhere
		const isAdmin = $access.some(a => a.role === 'admin');
		if (isAdmin) return 'admin' as UserRole;
		const teamAccess = $access.find(a => a.team === $teamId);
		return (teamAccess?.role as UserRole) || null;
	}
);

// Is admin (global)
export const isAdmin = derived(userTeamAccess, ($access) =>
	$access.some(a => a.role === 'admin')
);

// Is coach or admin for current team
export const isCoachOrAdmin = derived(
	[userRole],
	([$role]) => $role === 'admin' || $role === 'coach'
);

// Load user role data — call after login
export async function loadUserRoles() {
	const model = (pb.authStore as any).record || (pb.authStore as any).model;
	if (!model) return;

	const userId = model.id;
	const userEmail = model.email;

	// Load team access
	const access = await getTeamAccessForUser(userId);
	userTeamAccess.set(access);

	// Try to find linked player
	let player = await getPlayerByUserId(userId);

	// Auto-link: if no player linked by user_id, try by email
	if (!player && userEmail) {
		player = await getPlayerByEmail(userEmail);
		if (player) {
			await linkPlayerToUser(player.id, userId);
		}
	}

	linkedPlayer.set(player);
}

// Clear on logout
export function clearUserRoles() {
	userTeamAccess.set([]);
	linkedPlayer.set(null);
}
