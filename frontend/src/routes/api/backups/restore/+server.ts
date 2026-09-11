import type { RequestHandler } from './$types';
import { isRequestFromPlatformAdmin } from '$lib/server/platformAuth';
import { uploadAndRestoreBackup } from '$lib/server/pbBackup';
import { jsonError } from '$lib/server/clubAuth';

/**
 * Restores the whole instance (SQLite data + files) from an uploaded backup
 * zip. This overwrites everything currently in PocketBase and restarts it, so
 * it is intentionally the most locked-down route in the app.
 */
export const POST: RequestHandler = async ({ request }) => {
	if (!(await isRequestFromPlatformAdmin(request.headers.get('Authorization')))) {
		return jsonError('Alleen een platformbeheerder mag een backup terugzetten', 403);
	}

	const form = await request.formData().catch(() => null);
	const file = form?.get('file');
	if (!(file instanceof File) || !file.size) {
		return jsonError('Geen backupbestand ontvangen', 400);
	}
	if (!file.name.endsWith('.zip')) {
		return jsonError('Een backup moet een .zip-bestand zijn', 400);
	}

	try {
		await uploadAndRestoreBackup(file);
		return new Response(JSON.stringify({ ok: true }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(`Herstellen is mislukt: ${e}`, 500);
	}
};
