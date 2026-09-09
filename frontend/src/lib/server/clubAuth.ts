import { pbUrl } from './pbAdmin';

export interface ClubMembership {
	userId: string;
	role: 'admin' | 'user' | 'viewer';
}

/**
 * Resolves the caller's membership of a club using their *own* token, so the
 * check goes through PocketBase's collection rules rather than trusting
 * anything the browser claims. Returns null when the token is invalid or the
 * user has no access to that club.
 */
export async function getClubMembership(
	authHeader: string | null,
	clubId: string
): Promise<ClubMembership | null> {
	if (!authHeader || !clubId) return null;

	const me = await fetch(`${pbUrl()}/api/collections/users/auth-refresh`, {
		method: 'POST',
		headers: { Authorization: authHeader }
	});
	if (!me.ok) return null;
	const userId = (await me.json())?.record?.id;
	if (!userId) return null;

	const filter = encodeURIComponent(`user = "${userId}" && club = "${clubId}"`);
	const res = await fetch(
		`${pbUrl()}/api/collections/club_access/records?perPage=1&filter=${filter}`,
		{ headers: { Authorization: authHeader } }
	);
	if (!res.ok) return null;

	const role = (await res.json())?.items?.[0]?.role;
	if (role !== 'admin' && role !== 'user' && role !== 'viewer') return null;

	return { userId, role };
}

export function jsonError(message: string, status: number): Response {
	return new Response(JSON.stringify({ error: message }), {
		status,
		headers: { 'Content-Type': 'application/json' }
	});
}
