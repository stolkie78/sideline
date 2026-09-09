import type { RequestHandler } from './$types';
import { getClubMembership, jsonError } from '$lib/server/clubAuth';
import { readClubAIConfig, writeClubAIConfig } from '$lib/server/clubAI';

/**
 * Reads the club's AI settings. The key itself is never returned — the UI only
 * needs to know whether one is stored.
 */
export const GET: RequestHandler = async ({ url, request }) => {
	const clubId = url.searchParams.get('club') || '';
	const membership = await getClubMembership(request.headers.get('Authorization'), clubId);
	if (!membership) return jsonError('Geen toegang tot deze club', 403);

	try {
		const config = await readClubAIConfig(clubId);
		return new Response(
			JSON.stringify({
				provider: config?.provider || 'openai',
				model: config?.model || '',
				systemPrompt: config?.system_prompt || '',
				hasKey: Boolean(config?.api_key)
			}),
			{ headers: { 'Content-Type': 'application/json' } }
		);
	} catch (e) {
		return jsonError(`Kon de AI-instellingen niet laden: ${e}`, 500);
	}
};

export const PUT: RequestHandler = async ({ request }) => {
	const body = await request.json();
	const clubId = body?.club || '';
	const membership = await getClubMembership(request.headers.get('Authorization'), clubId);
	if (membership?.role !== 'admin') {
		return jsonError('Alleen een beheerder mag de AI-instellingen wijzigen', 403);
	}

	const patch: Record<string, unknown> = {
		provider: body.provider === 'gemini' ? 'gemini' : 'openai',
		model: typeof body.model === 'string' ? body.model : '',
		system_prompt: typeof body.systemPrompt === 'string' ? body.systemPrompt : ''
	};

	// An omitted key leaves the stored one untouched; an explicit empty string
	// clears it, so a club can revoke its key without losing the rest.
	if (typeof body.apiKey === 'string') patch.api_key = body.apiKey.trim();

	try {
		await writeClubAIConfig(clubId, patch);
		return new Response(JSON.stringify({ ok: true }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(`Kon de AI-instellingen niet opslaan: ${e}`, 500);
	}
};
