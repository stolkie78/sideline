import type { RequestHandler } from './$types';
import { isRequestFromPlatformAdmin } from '$lib/server/platformAuth';
import { fetchBackupFile, deleteBackup } from '$lib/server/pbBackup';
import { jsonError } from '$lib/server/clubAuth';

export const GET: RequestHandler = async ({ params, request }) => {
	if (!(await isRequestFromPlatformAdmin(request.headers.get('Authorization')))) {
		return jsonError('Alleen een platformbeheerder mag een backup downloaden', 403);
	}

	try {
		const upstream = await fetchBackupFile(params.key);
		return new Response(upstream.body, {
			headers: {
				'Content-Type': 'application/zip',
				'Content-Disposition': `attachment; filename="${params.key}"`
			}
		});
	} catch (e) {
		return jsonError(`Kon de backup niet downloaden: ${e}`, 500);
	}
};

export const DELETE: RequestHandler = async ({ params, request }) => {
	if (!(await isRequestFromPlatformAdmin(request.headers.get('Authorization')))) {
		return jsonError('Alleen een platformbeheerder mag een backup verwijderen', 403);
	}

	try {
		await deleteBackup(params.key);
		return new Response(JSON.stringify({ ok: true }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(`Kon de backup niet verwijderen: ${e}`, 500);
	}
};
