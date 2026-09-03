<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { pb, getTrainingTemplates, updateTraining } from '$lib/pocketbase';
	import type { Training, TrainingTemplate } from '$lib/types';
	import { TRAINING_TYPE_LABELS } from '$lib/types';
	import MarkdownEditor from '$lib/components/MarkdownEditor.svelte';
	import { aiConfig, DEFAULT_SYSTEM_PROMPT } from '$lib/stores/ai';

	let training: Training | null = null;
	let templates: TrainingTemplate[] = [];
	let selectedTemplate = '';
	let formContent = '';
	let currentPeriod: any = null;
	let recentTrainings: Training[] = [];
	let aiPrompt = '';
	let aiGenerating = false;
	let aiError = '';
	let loading = true;
	let saving = false;
	let loadError = '';

	const dashboardPath = `${base}/`;

	onMount(async () => {
		try {
			const trainingId = $page.params.id;
			if (!trainingId) throw new Error('Training-ID ontbreekt');
			training = await pb.collection('trainings').getOne<Training>(trainingId);
			selectedTemplate = training.template || '';
			formContent = training.content || '';
			templates = await getTrainingTemplates();

			const trainingDate = training.date.slice(0, 10);
			const periodFilters = [
				`start_date <= "${trainingDate}"`,
				`end_date >= "${trainingDate}"`,
			];
			if (training.team) periodFilters.push(`team = "${training.team}"`);

			const periods = await pb.collection('season_periods').getFullList({
				filter: periodFilters.join(' && '),
				sort: '-start_date',
			});
			currentPeriod = periods[0] || null;

			const recentFilters = [`id != "${training.id}"`];
			if (training.team) recentFilters.push(`team = "${training.team}"`);
			if (training.season) recentFilters.push(`season = "${training.season}"`);
			recentTrainings = await pb.collection('trainings').getList<Training>(1, 3, {
				filter: recentFilters.join(' && '),
				sort: '-date',
			}).then(result => result.items);
		} catch (error) {
			console.error('Failed to load training preparation:', error);
			loadError = 'De trainingsvoorbereiding kon niet worden geladen.';
		} finally {
			loading = false;
		}
	});

	function applyTemplate() {
		const template = templates.find(item => item.id === selectedTemplate);
		if (template) formContent = template.content || '';
	}

	async function generateWithAI() {
		if (!aiPrompt.trim() || !$aiConfig.apiKey) return;

		aiGenerating = true;
		aiError = '';
		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 60000);

		try {
			let fullPrompt = aiPrompt.trim();
			if (currentPeriod) {
				const goals = [
					currentPeriod.goals_technical && `Technisch: ${currentPeriod.goals_technical}`,
					currentPeriod.goals_tactical && `Tactisch: ${currentPeriod.goals_tactical}`,
					currentPeriod.goals_physical && `Fysiek: ${currentPeriod.goals_physical}`,
					currentPeriod.goals_mental && `Mentaal: ${currentPeriod.goals_mental}`,
				].filter(Boolean);

				if (goals.length > 0) {
					fullPrompt += `\n\nHuidige periodisering: "${currentPeriod.name}" (fase: ${currentPeriod.phase || 'onbekend'})\nDoelen voor deze periode:\n${goals.join('\n')}`;
				}
			}

			if (recentTrainings.length > 0) {
				const summaries = recentTrainings.map((item, index) => {
					const date = new Date(item.date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' });
					return `Training ${index + 1} (${date}):\n${(item.content || '').slice(0, 500)}`;
				});
				fullPrompt += `\n\n--- Vorige trainingen (ter referentie, vermijd herhaling) ---\n${summaries.join('\n\n')}`;
			}

			const response = await fetch(`${base}/api/ai`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					prompt: fullPrompt,
					provider: $aiConfig.provider,
					apiKey: $aiConfig.apiKey,
					model: $aiConfig.model || undefined,
					systemPrompt: $aiConfig.systemPrompt || DEFAULT_SYSTEM_PROMPT,
				}),
				signal: controller.signal,
			});
			const data = await response.json();
			if (!response.ok) {
				aiError = data.error || 'De training kon niet worden gegenereerd.';
				return;
			}
			formContent = data.content || '';
		} catch (error) {
			console.error('Failed to generate training:', error);
			aiError = error instanceof DOMException && error.name === 'AbortError'
				? 'De AI-aanvraag duurde te lang.'
				: 'De training kon niet worden gegenereerd.';
		} finally {
			clearTimeout(timeout);
			aiGenerating = false;
		}
	}

	async function handleSubmit() {
		if (!training) return;
		saving = true;
		try {
			await updateTraining(training.id, {
				template: selectedTemplate || undefined,
				content: formContent || undefined,
			});
			await goto(dashboardPath);
		} catch (error) {
			console.error('Failed to save training preparation:', error);
			alert('Fout bij opslaan van de trainingsvoorbereiding');
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Training voorbereiden - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if loadError || !training}
	<div class="card text-center">
		<p class="text-red-600 dark:text-red-400">{loadError || 'Training niet gevonden.'}</p>
		<a href={dashboardPath} class="btn-secondary inline-block mt-4">Terug naar dashboard</a>
	</div>
{:else}
	<form class="max-w-3xl mx-auto space-y-4" on:submit|preventDefault={handleSubmit}>
		<div>
			<h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">📝 Training voorbereiden</h1>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
				{new Date(training.date).toLocaleDateString('nl-NL', {
					weekday: 'long',
					day: 'numeric',
					month: 'long',
					year: 'numeric',
				})}
			</p>
		</div>

		{#if currentPeriod}
			<div class="card bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800">
				<div class="flex flex-wrap items-center gap-2 mb-2">
					<h2 class="font-semibold text-blue-700 dark:text-blue-300">📅 {currentPeriod.name}</h2>
					{#if currentPeriod.phase}
						<span class="text-xs px-2 py-0.5 rounded-full bg-blue-100 dark:bg-blue-800 text-blue-600 dark:text-blue-300">
							{currentPeriod.phase}
						</span>
					{/if}
				</div>
				<div class="grid sm:grid-cols-2 gap-2 text-sm text-gray-700 dark:text-gray-300">
					{#if currentPeriod.goals_technical}<p>🎯 <strong>Technisch:</strong> {currentPeriod.goals_technical}</p>{/if}
					{#if currentPeriod.goals_tactical}<p>🧠 <strong>Tactisch:</strong> {currentPeriod.goals_tactical}</p>{/if}
					{#if currentPeriod.goals_physical}<p>💪 <strong>Fysiek:</strong> {currentPeriod.goals_physical}</p>{/if}
					{#if currentPeriod.goals_mental}<p>🧘 <strong>Mentaal:</strong> {currentPeriod.goals_mental}</p>{/if}
				</div>
			</div>
		{/if}

		<div class="card space-y-4">
			<div>
				<label class="label" for="preparation-template">Template</label>
				<div class="flex gap-2">
					<select id="preparation-template" class="input flex-1" bind:value={selectedTemplate}>
						<option value="">— Geen template —</option>
						{#each templates as template}
							<option value={template.id}>{template.name} ({TRAINING_TYPE_LABELS[template.type]})</option>
						{/each}
					</select>
					<button type="button" class="btn-secondary text-sm px-3" on:click={applyTemplate} disabled={!selectedTemplate}>
						Toepassen
					</button>
				</div>
			</div>

			{#if $aiConfig.apiKey}
				<div class="p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg space-y-2">
					<p class="label text-purple-700 dark:text-purple-300">🤖 Genereer met AI</p>
					{#if currentPeriod}
						<p class="text-xs text-purple-600 dark:text-purple-400">De periodiseringsdoelen worden automatisch als context meegestuurd.</p>
					{/if}
					<div class="flex flex-col sm:flex-row gap-2">
						<input
							class="input flex-1"
							type="text"
							bind:value={aiPrompt}
							placeholder="Bijv. focus op bovenhands spel, 90 min"
							on:keydown={(event) => event.key === 'Enter' && (event.preventDefault(), generateWithAI())}
						/>
						<button type="button" class="btn-primary text-sm whitespace-nowrap" disabled={aiGenerating || !aiPrompt.trim()} on:click={generateWithAI}>
							{aiGenerating ? '⏳ Genereren...' : '✨ Genereer'}
						</button>
					</div>
					{#if aiError}<p class="text-xs text-red-500">{aiError}</p>{/if}
				</div>
			{:else}
				<p class="text-sm text-gray-500 dark:text-gray-400">
					Configureer eerst een AI-model via Configuratie → AI om een training te genereren.
				</p>
			{/if}

			<div>
				<p class="label">Trainingsinformatie</p>
				<MarkdownEditor bind:value={formContent} minRows={14} placeholder="Werk de training uit in Markdown..." />
			</div>
		</div>

		<div class="grid grid-cols-2 gap-3">
			<a href={dashboardPath} class="btn-secondary text-center">Annuleren</a>
			<button type="submit" class="btn-primary" disabled={saving}>
				{saving ? 'Opslaan...' : 'Voorbereiding opslaan'}
			</button>
		</div>
	</form>
{/if}
