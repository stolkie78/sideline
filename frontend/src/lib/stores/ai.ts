import { writable } from 'svelte/store';
import { browser } from '$app/environment';

export interface AIConfig {
	provider: 'openai' | 'gemini';
	apiKey: string;
	model: string;
}

const DEFAULT_CONFIG: AIConfig = {
	provider: 'openai',
	apiKey: '',
	model: ''
};

function loadConfig(): AIConfig {
	if (!browser) return DEFAULT_CONFIG;
	try {
		const stored = localStorage.getItem('sideline_ai_config');
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
			if (browser) localStorage.setItem('sideline_ai_config', JSON.stringify(value));
			set(value);
		},
		update: (fn: (config: AIConfig) => AIConfig) => {
			update((current) => {
				const next = fn(current);
				if (browser) localStorage.setItem('sideline_ai_config', JSON.stringify(next));
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
		{ value: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash (snel)' },
		{ value: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash' },
		{ value: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro (beste)' },
	]
};
