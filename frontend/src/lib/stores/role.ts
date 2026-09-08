import { writable, derived, get } from 'svelte/store';
import { selectedClubId } from './context';
import { isAuthenticated } from './auth';
import { pb, getClubAccessForUser, getPlayerByUserId, getPlayerByEmail, linkPlayerToUser } from '$lib/pocketbase';
import type { ClubAccess } from '$lib/pocketbase';
import type { Player } from '$lib/types';

export type UserRole = 'admin' | 'user' | 'viewer' | null;

// All club_access records for the current user
export const userClubAccess = writable<ClubAccess[]>([]);

// The player record linked to the current user (if any)
export const linkedPlayer = writable<Player | null>(null);

// Whether loadUserRoles() has completed at least once since login. Components
// that depend on `linkedPlayer` (e.g. PlayerDashboard) must wait for this
// before deciding "no linked player" — otherwise they can run before the
// async role/player lookup resolves and permanently show an empty state.
export const rolesLoaded = writable(false);

// Current role for the selected club
export const userRole = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]) => {
		if (!$clubId || $access.length === 0) return null;
		// Admin on any club = admin everywhere
		const isAdminAnywhere = $access.some(a => a.role === 'admin');
		if (isAdminAnywhere) return 'admin' as UserRole;
		const clubAccess = $access.find(a => a.club === $clubId);
		return (clubAccess?.role as UserRole) || null;
	}
);

// Is admin (global)
export const isAdmin = derived(userClubAccess, ($access) =>
	$access.some(a => a.role === 'admin')
);

// Is user or admin for current club (i.e. not a read-only viewer)
export const isCoachOrAdmin = derived(
	[userRole],
	([$role]) => $role === 'admin' || $role === 'user'
);

/**
 * Whether the current user is flagged as a player (`is_player`) for the
 * selected club. This is independent of their permission `role` — a coach
 * or admin can also be tagged as a player (e.g. a playing coach), in which
 * case they get access to the personal "Mijn training" landing page in
 * addition to their regular role-based dashboard.
 */
export const isPlayer = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]) => {
		if ($access.length === 0) return false;
		if (!$clubId) return $access.some(a => a.is_player);
		const clubAccess = $access.find(a => a.club === $clubId);
		return !!clubAccess?.is_player;
	}
);

/**
 * The default team for the current user on the current club, if one was set.
 * Only meaningful when someone has access to more than one team within the
 * club — otherwise the regular "first accessible team" fallback applies.
 */
export const defaultTeamId = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]) => {
		const clubAccess = $access.find(a => a.club === $clubId);
		return clubAccess?.default_team || '';
	}
);

// Load user role data — call after login
export async function loadUserRoles() {
	const model = (pb.authStore as any).record || (pb.authStore as any).model;
	if (!model) return;

	const userId = model.id;
	const userEmail = model.email;

	try {
		// Load club access
		const access = await getClubAccessForUser(userId);
		userClubAccess.set(access);

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
	} finally {
		// Always flip this, even on failure, so components waiting on it
		// (e.g. PlayerDashboard) don't hang in a permanent loading state.
		rolesLoaded.set(true);
	}
}

// Clear on logout
export function clearUserRoles() {
	userClubAccess.set([]);
	linkedPlayer.set(null);
	rolesLoaded.set(false);
}
