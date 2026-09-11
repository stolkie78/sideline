import { pbUrl } from './pbAdmin';

/**
 * Confirms the caller's own token belongs to a platform admin (the narrow,
 * built-in `is_platform_admin` flag on `users`), by asking PocketBase itself
 * rather than trusting anything the browser claims.
 */
export async function isRequestFromPlatformAdmin(authHeader: string | null): Promise<boolean> {
	if (!authHeader) return false;

	const res = await fetch(`${pbUrl()}/api/collections/users/auth-refresh`, {
		method: 'POST',
		headers: { Authorization: authHeader }
	});
	if (!res.ok) return false;

	return !!(await res.json())?.record?.is_platform_admin;
}
