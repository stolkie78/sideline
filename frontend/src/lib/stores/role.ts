import { writable, derived } from 'svelte/store';
import { selectedClubId, createPersistentStore } from './context';
import { pb, getClubAccessForUser, getPlayerByUserId, getPlayerByEmail, linkPlayerToUser } from '$lib/pocketbase';
import type { ClubAccess } from '$lib/pocketbase';
import type { Player } from '$lib/types';

/**
 * SetBaas separates two independent concepts:
 *
 * 1. `Permission` — WHAT you may do (access level, `club_access.role`):
 *      admin  → everything, including configuration and team management
 *      user   → fill in trainings, matches and competencies per player
 *      viewer → read-only (plus their own attendance/questionnaire answers)
 *
 * 2. `AppRole` — WHO you are on the club (`is_trainer`/`is_player`/`is_parent`):
 *      coach  → general dashboard
 *      player → personal player dashboard
 *      parent → parent dashboard (not built yet)
 *
 * The two are deliberately orthogonal: a coach can be read-only and a player
 * can be an admin. The permission decides what is editable, the role decides
 * which dashboard and navigation you land on.
 */
export type Permission = 'admin' | 'user' | 'viewer' | null;
export type AppRole = 'coach' | 'player' | 'parent';

export const APP_ROLES: AppRole[] = ['coach', 'player', 'parent'];

export const APP_ROLE_LABELS: Record<AppRole, string> = {
	coach: 'Coach',
	player: 'Speler',
	parent: 'Ouder',
};

export const APP_ROLE_ICONS: Record<AppRole, string> = {
	coach: '🧑‍🏫',
	player: '🏐',
	parent: '👨‍👩‍👦',
};

export const APP_ROLE_DESCRIPTIONS: Record<AppRole, string> = {
	coach: 'Trainingen, wedstrijden en teamoverzicht',
	player: 'Je eigen aanwezigheid, inbox en profiel',
	parent: 'Meekijken met je kind',
};

export const PERMISSION_LABELS: Record<'admin' | 'user' | 'viewer', string> = {
	admin: 'Beheerder',
	user: 'Gebruiker',
	viewer: 'Lezer',
};

// All club_access records for the current user
export const userClubAccess = writable<ClubAccess[]>([]);

// The player record linked to the current user (if any)
export const linkedPlayer = writable<Player | null>(null);

// Whether loadUserRoles() has completed at least once since login. Components
// that depend on `linkedPlayer` (e.g. PlayerDashboard) must wait for this
// before deciding "no linked player" — otherwise they can run before the
// async role/player lookup resolves and permanently show an empty state.
export const rolesLoaded = writable(false);

// === Permissions (access level) ===

/**
 * Access level for the selected club. Admin on any club counts as admin
 * everywhere, because club administration itself is a cross-club action.
 */
export const permission = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]): Permission => {
		if ($access.length === 0) return null;
		const isAdminAnywhere = $access.some((a) => a.role === 'admin');
		if (isAdminAnywhere) return 'admin';
		if (!$clubId) return null;
		const clubAccess = $access.find((a) => a.club === $clubId);
		return (clubAccess?.role as Permission) || null;
	}
);

/** Full access: configuration, clubs/teams/seasons and the player roster. */
export const isAdmin = derived(permission, ($p) => $p === 'admin');

/**
 * May record day-to-day data: trainings, matches, attendance and competency
 * scores. Explicitly does NOT include configuration or roster management.
 */
export const canEdit = derived(permission, ($p) => $p === 'admin' || $p === 'user');

/** Read-only access — may still submit their own attendance and answers. */
export const isReadOnly = derived(permission, ($p) => $p === 'viewer');

// === Roles (who you are) ===

/**
 * Which roles the current user may act in on the selected club. Someone with
 * no role flags at all still gets the coach view, so a plain admin or viewer
 * account lands on the regular dashboard instead of on nothing.
 */
export const availableRoles = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]): AppRole[] => {
		if ($access.length === 0) return [];
		const relevant = $clubId ? $access.filter((a) => a.club === $clubId) : $access;
		const roles: AppRole[] = [];
		if (relevant.some((a) => a.is_trainer)) roles.push('coach');
		if (relevant.some((a) => a.is_player)) roles.push('player');
		if (relevant.some((a) => a.is_parent)) roles.push('parent');
		return roles.length > 0 ? roles : ['coach'];
	}
);

/**
 * The role the user picked for this session. Empty until chosen; persisted so
 * a page reload doesn't ask again.
 */
export const activeRole = createPersistentStore('activeRole', '');

/**
 * The role actually in effect. A stored choice only counts while it is still
 * available, and a single available role is selected automatically so the user
 * is never asked a question that has only one answer.
 */
export const currentRole = derived(
	[availableRoles, activeRole],
	([$available, $active]): AppRole | null => {
		if ($active && $available.includes($active as AppRole)) return $active as AppRole;
		if ($available.length === 1) return $available[0];
		return null;
	}
);

/** Whether to ask the user which role they are acting in right now. */
export const needsRoleChoice = derived(
	[rolesLoaded, availableRoles, currentRole],
	([$loaded, $available, $current]) => $loaded && $available.length > 1 && !$current
);

export function selectRole(role: AppRole) {
	activeRole.set(role);
}

export const isCoachView = derived(currentRole, ($r) => $r === 'coach');
export const isPlayerView = derived(currentRole, ($r) => $r === 'player');
export const isParentView = derived(currentRole, ($r) => $r === 'parent');

/**
 * Whether the user is a player at all, regardless of the role they are
 * currently acting in — used to decide whether player-only data exists.
 */
export const isPlayer = derived(availableRoles, ($roles) => $roles.includes('player'));

/**
 * The default team for the current user on the current club, if one was set.
 * Only meaningful when someone has access to more than one team within the
 * club — otherwise the regular "first accessible team" fallback applies.
 */
export const defaultTeamId = derived(
	[userClubAccess, selectedClubId],
	([$access, $clubId]) => {
		const clubAccess = $access.find((a) => a.club === $clubId);
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
	// The next user on this browser must pick their own role.
	activeRole.set('');
}
