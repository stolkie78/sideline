import type { RequestHandler } from './$types';
import { getAdminToken, pbUrl } from '$lib/server/pbAdmin';

const json = (body: unknown, status = 200) =>
	new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

// Tokens are generated as two dash-stripped UUIDs. Validating the shape keeps
// the value safe to interpolate into a PocketBase filter expression.
const TOKEN_RE = /^[a-f0-9]{32,128}$/;

async function findInvitation(token: string, adminToken: string) {
	const url = new URL(`${pbUrl()}/api/collections/invitations/records`);
	url.searchParams.set('filter', `token = "${token}" && status = "pending"`);
	url.searchParams.set('perPage', '1');

	const res = await fetch(url, { headers: { Authorization: adminToken } });
	if (!res.ok) return null;
	return ((await res.json()).items ?? [])[0] ?? null;
}

/** Look up an invitation by token. Unauthenticated on purpose: the token is the secret. */
export const GET: RequestHandler = async ({ url }) => {
	const token = url.searchParams.get('token') ?? '';
	if (!TOKEN_RE.test(token)) return json({ error: 'not_found' }, 404);

	let adminToken: string;
	try {
		adminToken = await getAdminToken();
	} catch (e) {
		return json({ error: `${e}` }, 500);
	}

	const invitation = await findInvitation(token, adminToken);
	if (!invitation) return json({ error: 'not_found' }, 404);
	if (new Date(invitation.expires_at) < new Date()) return json({ error: 'expired' }, 410);

	let clubName = 'Club';
	const clubRes = await fetch(`${pbUrl()}/api/collections/clubs/records/${invitation.club}`, {
		headers: { Authorization: adminToken }
	});
	if (clubRes.ok) clubName = (await clubRes.json()).name ?? clubName;

	// Only what the invite screen needs — never the whole record.
	return json({ email: invitation.email, role: invitation.role, clubName });
};

/**
 * Accept an invitation: grant club_access with the role stored on the
 * invitation, then mark it accepted. This runs server side with superuser
 * rights so the invitee never needs write access to club_access — otherwise
 * anyone could simply grant themselves admin on any club.
 */
export const POST: RequestHandler = async ({ request }) => {
	const { token, userId } = await request.json();
	if (!TOKEN_RE.test(token ?? '') || !userId) return json({ error: 'not_found' }, 404);

	let adminToken: string;
	try {
		adminToken = await getAdminToken();
	} catch (e) {
		return json({ error: `${e}` }, 500);
	}

	const invitation = await findInvitation(token, adminToken);
	if (!invitation) return json({ error: 'not_found' }, 404);
	if (new Date(invitation.expires_at) < new Date()) return json({ error: 'expired' }, 410);

	// The invitation is addressed to one mailbox, so verify the accepting
	// account owns it. Without this a leaked link is redeemable by anyone.
	const userRes = await fetch(`${pbUrl()}/api/collections/users/records/${userId}`, {
		headers: { Authorization: adminToken }
	});
	if (!userRes.ok) return json({ error: 'Gebruiker niet gevonden' }, 404);
	const user = await userRes.json();
	if ((user.email ?? '').toLowerCase() !== (invitation.email ?? '').toLowerCase()) {
		return json({ error: 'Deze uitnodiging hoort bij een ander emailadres.' }, 403);
	}

	const existingRes = await fetch(
		`${pbUrl()}/api/collections/club_access/records?perPage=1&filter=` +
			encodeURIComponent(`user = "${userId}" && club = "${invitation.club}"`),
		{ headers: { Authorization: adminToken } }
	);
	const existing = existingRes.ok ? ((await existingRes.json()).items ?? []) : [];

	if (existing.length === 0) {
		const createRes = await fetch(`${pbUrl()}/api/collections/club_access/records`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Authorization: adminToken },
			body: JSON.stringify({ user: userId, club: invitation.club, role: invitation.role })
		});
		if (!createRes.ok) {
			return json({ error: `Kon toegang niet verlenen: ${await createRes.text()}` }, 500);
		}
	}

	await fetch(`${pbUrl()}/api/collections/invitations/records/${invitation.id}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json', Authorization: adminToken },
		body: JSON.stringify({ status: 'accepted' })
	});

	return json({ success: true });
};
