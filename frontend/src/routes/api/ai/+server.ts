import type { RequestHandler } from './$types';
import { getClubMembership, jsonError } from '$lib/server/clubAuth';
import { readClubAIConfig, resolveSystemPrompt } from '$lib/server/clubAI';

/**
 * Generates content with the club's own AI subscription. The key stays on the
 * server: the browser only sends which club and team it is generating for.
 */
export const POST: RequestHandler = async ({ request }) => {
	const { prompt, club: clubId, team: teamId, systemPrompt: overridePrompt, context } = await request.json();

	if (!prompt || !clubId) {
		return jsonError('Prompt of club ontbreekt', 400);
	}

	const membership = await getClubMembership(request.headers.get('Authorization'), clubId);
	if (!membership || membership.role === 'viewer') {
		return jsonError('Geen toegang tot de AI van deze club', 403);
	}

	let config;
	try {
		config = await readClubAIConfig(clubId);
	} catch (e) {
		return jsonError(`Kon de AI-instellingen niet laden: ${e}`, 500);
	}

	const apiKey = config?.api_key?.trim();
	if (!apiKey) {
		return jsonError('Deze club heeft nog geen AI-sleutel ingesteld.', 400);
	}

	const provider = config?.provider || 'openai';
	const model = config?.model?.trim();
	// A caller may pass its own prompt for a different task (the training
	// reflection, for instance); otherwise team beats club beats default.
	const basePrompt =
		typeof overridePrompt === 'string' && overridePrompt.trim()
			? overridePrompt.trim()
			: await resolveSystemPrompt(config?.system_prompt, teamId);
	// Optional per-request context (e.g. attendance + positions for a
	// training) is appended to whichever system prompt was resolved above,
	// so the persona/rules stay intact while the AI still sees live data.
	const systemPrompt =
		typeof context === 'string' && context.trim()
			? `${basePrompt}\n\n${context.trim()}`
			: basePrompt;

	try {
		let content = '';

		if (provider === 'openai') {
			const res = await fetch('https://api.openai.com/v1/chat/completions', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${apiKey}`
				},
				body: JSON.stringify({
					model: model || 'gpt-4o-mini',
					messages: [
						{ role: 'system', content: systemPrompt },
						{ role: 'user', content: prompt }
					],
					temperature: 0.7
				})
			});
			if (!res.ok) {
				return jsonError(`OpenAI-fout: ${res.status} ${await res.text()}`, 502);
			}
			const data = await res.json();
			content = data.choices?.[0]?.message?.content || '';
		} else if (provider === 'gemini') {
			const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model || 'gemini-3.6-flash'}:generateContent?key=${apiKey}`;
			const res = await fetch(apiUrl, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					systemInstruction: { parts: [{ text: systemPrompt }] },
					contents: [{ parts: [{ text: prompt }] }],
					generationConfig: { temperature: 0.7 }
				})
			});
			if (!res.ok) {
				return jsonError(`Gemini-fout: ${res.status} ${await res.text()}`, 502);
			}
			const data = await res.json();
			content = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
		} else {
			return jsonError(`Onbekende provider: ${provider}`, 400);
		}

		return new Response(JSON.stringify({ content }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return jsonError(String(e), 500);
	}
};
