import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';

export const pbUrl = () => pubEnv.PUBLIC_POCKETBASE_URL || 'http://pb:8090';

/**
 * Authenticates as the PocketBase superuser.
 *
 * Anything that has to bypass the collection API rules — granting club_access
 * from an invitation, for example — must go through here. Doing it from the
 * browser would mean giving the end user permission to write those records
 * themselves, which is exactly the privilege escalation the rules prevent.
 */
export async function getAdminToken(): Promise<string> {
	const adminEmail = env.PB_ADMIN_EMAIL;
	const adminPassword = env.PB_ADMIN_PASSWORD;

	if (!adminEmail || !adminPassword) {
		throw new Error('Server niet geconfigureerd (PB admin credentials ontbreken)');
	}

	const body = JSON.stringify({ identity: adminEmail, password: adminPassword });
	const headers = { 'Content-Type': 'application/json' };

	const legacy = await fetch(`${pbUrl()}/api/admins/auth-with-password`, { method: 'POST', headers, body });
	if (legacy.ok) return (await legacy.json()).token;

	const superuser = await fetch(`${pbUrl()}/api/collections/_superusers/auth-with-password`, {
		method: 'POST',
		headers,
		body
	});
	if (!superuser.ok) throw new Error('Admin auth failed');
	return (await superuser.json()).token;
}
