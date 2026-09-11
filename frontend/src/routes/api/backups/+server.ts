import type { RequestHandler } from './$types';
import { isRequestFromPlatformAdmin } from '$lib/server/platformAuth';
import { listBackups, createBackup } from '$lib/server/pbBackup';
import { jsonError } from '$lib/server/clubAuth';

export const GET: RequestHandler = async ({ request }) => {
	if (!(await isRequestFromPlatformAdmin(request.headers.get('Authorization')))) {
		return jsonError('Alleen een platformbeheerder mag backups bekijken', 403);
	}

	try {
		const backups = await listBackups();
		// Newest first, so the most useful backup is always on top.
		backups.sort((a, b) => (a.modified < b.modified ? 1 : -1));
		return new Response(JSON.stringify(backups), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(`Kon de backups niet ophalen: ${e}`, 500);
	}
};

export const POST: RequestHandler = async ({ request }) => {
	if (!(await isRequestFromPlatformAdmin(request.headers.get('Authorization')))) {
		return jsonError('Alleen een platformbeheerder mag een backup maken', 403);
	}

	const body = await request.json().catch(() => ({}));
	const name = typeof body?.name === 'string' && body.name.trim() ? body.name.trim() : undefined;

	try {
		await createBackup(name);
		return new Response(JSON.stringify({ ok: true }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(`Kon geen backup maken: ${e}`, 500);
	}
};
