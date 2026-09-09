import { getAdminToken, pbUrl } from './pbAdmin';
import { DEFAULT_SYSTEM_PROMPT } from '$lib/stores/ai';

export interface ClubAIConfig {
	id?: string;
	club: string;
	provider?: 'openai' | 'gemini';
	api_key?: string;
	model?: string;
	system_prompt?: string;
}

/**
 * club_ai_config is superuser-only on purpose: the API key is the club's own
 * paid credential and must never be readable from the browser. Every access
 * therefore runs through here with an admin token.
 */
export async function readClubAIConfig(clubId: string): Promise<ClubAIConfig | null> {
	const token = await getAdminToken();
	const filter = encodeURIComponent(`club = "${clubId}"`);
	const res = await fetch(
		`${pbUrl()}/api/collections/club_ai_config/records?perPage=1&filter=${filter}`,
		{ headers: { Authorization: token } }
	);
	if (!res.ok) return null;
	return (await res.json())?.items?.[0] ?? null;
}

export async function writeClubAIConfig(
	clubId: string,
	patch: Partial<ClubAIConfig>
): Promise<void> {
	const token = await getAdminToken();
	const existing = await readClubAIConfig(clubId);
	const headers = { Authorization: token, 'Content-Type': 'application/json' };

	const url = existing
		? `${pbUrl()}/api/collections/club_ai_config/records/${existing.id}`
		: `${pbUrl()}/api/collections/club_ai_config/records`;

	const res = await fetch(url, {
		method: existing ? 'PATCH' : 'POST',
		headers,
		body: JSON.stringify({ ...patch, club: clubId })
	});
	if (!res.ok) throw new Error(await res.text());
}

export { DEFAULT_SYSTEM_PROMPT };

/**
 * Resolves the prompt for a training: the team's own prompt wins, then the
 * club's, then the built-in default.
 */
export async function resolveSystemPrompt(
	clubPrompt: string | undefined,
	teamId: string | undefined
): Promise<string> {
	if (teamId) {
		const token = await getAdminToken();
		const res = await fetch(`${pbUrl()}/api/collections/teams/records/${teamId}`, {
			headers: { Authorization: token }
		});
		if (res.ok) {
			const teamPrompt = (await res.json())?.ai_system_prompt;
			if (teamPrompt && teamPrompt.trim()) return teamPrompt.trim();
		}
	}
	if (clubPrompt && clubPrompt.trim()) return clubPrompt.trim();
	return DEFAULT_SYSTEM_PROMPT;
}
