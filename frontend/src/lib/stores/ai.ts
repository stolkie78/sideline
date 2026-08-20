import { writable } from 'svelte/store';
import { browser } from '$app/environment';

export interface AIConfig {
	provider: 'openai' | 'gemini';
	apiKey: string;
	model: string;
	systemPrompt: string;
}

export const DEFAULT_SYSTEM_PROMPT = `Je bent een ervaren volleybalcoach-assistent gespecialiseerd in jeugdvolleybal (meiden B / meisjes 14-16 jaar).

Je kennis omvat:
- Techniek: bovenhands, onderhands, service (boven/onder), aanval, blok, verdediging
- Tactiek: positiespel, rotatie, spelherkenning, aanvalscombinaties
- Fysiek: coördinatie, snelheid, reactievermogen, sprongkracht, core-stability
- Mentaal: teambuilding, communicatie, vertrouwen, winnaarsmentaliteit
- Periodisering: opbouw van seizoen, piekfases, competitieritme

Bij het genereren van trainingsplannen:
- Gebruik Markdown met duidelijke headers (## per fase)
- Geef per oefening: naam, doel, uitleg, duur, variatie/progressie
- Houd rekening met groepsgrootte (8-12 speelsters), 1 of 2 velden
- Bouw op van eenvoudig → complex, techniek → toepassing → spelvorm
- Totale trainingsduur: 90 minuten (tenzij anders gevraagd)
- Sluit altijd af met een spelvorm of wedstrijdje`;

const DEFAULT_CONFIG: AIConfig = {
	provider: 'openai',
	apiKey: '',
	model: '',
	systemPrompt: ''
};

function loadConfig(): AIConfig {
	if (!browser) return DEFAULT_CONFIG;
	try {
		const stored = localStorage.getItem('setbaas_ai_config');
		return stored ? { ...DEFAULT_CONFIG, ...JSON.parse(stored) } : DEFAULT_CONFIG;
	} catch {
		return DEFAULT_CONFIG;
	}
}

function createAIConfigStore() {
	const { subscribe, set, update } = writable<AIConfig>(loadConfig());

	return {
		subscribe,
		set: (value: AIConfig) => {
			if (browser) localStorage.setItem('setbaas_ai_config', JSON.stringify(value));
			set(value);
		},
		update: (fn: (config: AIConfig) => AIConfig) => {
			update((current) => {
				const next = fn(current);
				if (browser) localStorage.setItem('setbaas_ai_config', JSON.stringify(next));
				return next;
			});
		}
	};
}

export const aiConfig = createAIConfigStore();

export const AI_MODELS = {
	openai: [
		{ value: 'gpt-4o-mini', label: 'GPT-4o Mini (snel, goedkoop)' },
		{ value: 'gpt-4o', label: 'GPT-4o (beste kwaliteit)' },
		{ value: 'gpt-4.1-mini', label: 'GPT-4.1 Mini' },
	],
	gemini: [
		{ value: 'gemini-3.6-flash', label: 'Gemini 3.6 Flash (snel)' },
		{ value: 'gemini-3.1-pro-preview', label: 'Gemini 3.1 Pro (beste)' },
	]
};
