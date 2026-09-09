import { base } from '$app/paths';
import { pb } from '$lib/pocketbase';

export interface GenerateOptions {
	prompt: string;
	club: string;
	team?: string;
	/** Overrides the team/club prompt for a different kind of task. */
	systemPrompt?: string;
	timeoutMs?: number;
}

/**
 * Calls the server-side AI endpoint. The club's API key lives in PocketBase and
 * is resolved on the server, so nothing secret passes through the browser — we
 * only forward the user's own auth token so the server can check club rights.
 */
export async function generateWithAI(options: GenerateOptions): Promise<string> {
	const { prompt, club, team, systemPrompt, timeoutMs = 60000 } = options;

	if (!club) throw new Error('Geen club geselecteerd.');

	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), timeoutMs);

	try {
		const res = await fetch(`${base}/api/ai`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Authorization: pb.authStore.token
			},
			body: JSON.stringify({ prompt, club, team, systemPrompt }),
			signal: controller.signal
		});
		const data = await res.json().catch(() => ({}));
		if (!res.ok) throw new Error(data.error || 'De AI-aanvraag is mislukt.');
		return data.content || '';
	} catch (e) {
		if (e instanceof DOMException && e.name === 'AbortError') {
			throw new Error('De AI-aanvraag duurde te lang.');
		}
		throw e;
	} finally {
		clearTimeout(timeout);
	}
}

export interface ClubAISettings {
	provider: 'openai' | 'gemini';
	model: string;
	systemPrompt: string;
	hasKey: boolean;
}

export async function loadClubAISettings(club: string): Promise<ClubAISettings> {
	const res = await fetch(`${base}/api/ai/config?club=${encodeURIComponent(club)}`, {
		headers: { Authorization: pb.authStore.token }
	});
	if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || 'Laden mislukt');
	return res.json();
}

export async function saveClubAISettings(
	club: string,
	settings: { provider: string; model: string; systemPrompt: string; apiKey?: string }
): Promise<void> {
	const res = await fetch(`${base}/api/ai/config`, {
		method: 'PUT',
		headers: {
			'Content-Type': 'application/json',
			Authorization: pb.authStore.token
		},
		body: JSON.stringify({ club, ...settings })
	});
	if (!res.ok) throw new Error((await res.json().catch(() => ({}))).error || 'Opslaan mislukt');
}
