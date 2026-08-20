import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	const { prompt, provider, apiKey, model } = await request.json();

	if (!prompt || !provider || !apiKey) {
		return new Response(JSON.stringify({ error: 'Missing prompt, provider or apiKey' }), {
			status: 400,
			headers: { 'Content-Type': 'application/json' }
		});
	}

	const systemPrompt = `Je bent een ervaren volleybalcoach-assistent. Genereer trainingsplannen in Markdown format. 
Gebruik headers (##), lijsten, en duidelijke structuur. Focus op praktische oefeningen met tijdsindicatie.
Geef per oefening: naam, doel, beschrijving, duur, variaties.`;

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
				const err = await res.text();
				return new Response(JSON.stringify({ error: `OpenAI error: ${res.status} ${err}` }), {
					status: 502,
					headers: { 'Content-Type': 'application/json' }
				});
			}
			const data = await res.json();
			content = data.choices?.[0]?.message?.content || '';
		} else if (provider === 'gemini') {
			const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model || 'gemini-2.0-flash'}:generateContent?key=${apiKey}`;
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
				const err = await res.text();
				return new Response(JSON.stringify({ error: `Gemini error: ${res.status} ${err}` }), {
					status: 502,
					headers: { 'Content-Type': 'application/json' }
				});
			}
			const data = await res.json();
			content = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
		} else {
			return new Response(JSON.stringify({ error: `Unknown provider: ${provider}` }), {
				status: 400,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		return new Response(JSON.stringify({ content }), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return new Response(JSON.stringify({ error: String(e) }), {
			status: 500,
			headers: { 'Content-Type': 'application/json' }
		});
	}
};
