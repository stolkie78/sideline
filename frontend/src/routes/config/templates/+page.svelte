<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getTrainingTemplates, createTrainingTemplate, updateTrainingTemplate, deleteTrainingTemplate } from '$lib/pocketbase';
	import type { TrainingTemplate, TrainingType, TrainingPhase } from '$lib/types';
	import { TRAINING_TYPE_LABELS, PHASE_LABELS, TRAINING_PHASES } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';

	let templates: TrainingTemplate[] = [];
	let loading = true;
	let showForm = false;
	let editing: TrainingTemplate | null = null;
	let saving = false;

	// Form
	let formName = '';
	let formType: TrainingType = 'all_round';
	let formWarmup = '';
	let formTechnique = '';
	let formCore1 = '';
	let formCore2 = '';
	let formGame = '';
	let formNotes = '';

	const allTypes = Object.entries(TRAINING_TYPE_LABELS) as [TrainingType, string][];

	onMount(loadTemplates);

	async function loadTemplates() {
		loading = true;
		try {
			templates = await getTrainingTemplates();
		} catch (e) {
			console.error('Failed to load templates:', e);
		} finally {
			loading = false;
		}
	}

	function startEdit(t: TrainingTemplate) {
		editing = t;
		formName = t.name;
		formType = t.type;
		formWarmup = t.warmup || '';
		formTechnique = t.technique || '';
		formCore1 = t.core1 || '';
		formCore2 = t.core2 || '';
		formGame = t.game || '';
		formNotes = t.notes || '';
		showForm = true;
	}

	function resetForm() {
		editing = null;
		formName = '';
		formType = 'all_round';
		formWarmup = '';
		formTechnique = '';
		formCore1 = '';
		formCore2 = '';
		formGame = '';
		formNotes = '';
		showForm = false;
	}

	async function handleSubmit() {
		if (!formName.trim()) return;
		saving = true;
		try {
			const data = {
				name: formName.trim(),
				type: formType,
				warmup: formWarmup,
				technique: formTechnique,
				core1: formCore1,
				core2: formCore2,
				game: formGame,
				notes: formNotes,
				team: $selectedTeamId || undefined,
				season: $selectedSeasonId || undefined,
			};
			if (editing) {
				await updateTrainingTemplate(editing.id, data);
			} else {
				await createTrainingTemplate(data);
			}
			resetForm();
			await loadTemplates();
		} catch (e) {
			console.error('Failed to save template:', e);
			alert('Fout bij opslaan');
		} finally {
			saving = false;
		}
	}

	async function handleDelete(t: TrainingTemplate) {
		if (!confirm(`"${t.name}" verwijderen?`)) return;
		try {
			await deleteTrainingTemplate(t.id);
			await loadTemplates();
		} catch (e) {
			alert('Fout bij verwijderen');
		}
	}
</script>

<svelte:head>
	<title>Trainingstemplates - SideLine</title>
</svelte:head>

<div class="space-y-6">
	<div class="flex justify-between items-center">
		<div>
			<h2 class="text-xl font-bold text-gray-900 dark:text-white">Trainingstemplates</h2>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">Standaard trainingen per type</p>
		</div>
		<button class="btn-primary" on:click={() => { resetForm(); showForm = !showForm; }}>
			{showForm ? 'Sluiten' : 'Nieuw template'}
		</button>
	</div>

	<!-- Form -->
	{#if showForm}
		<form class="card space-y-4" on:submit|preventDefault={handleSubmit}>
			<h3 class="font-semibold text-gray-900 dark:text-white">
				{editing ? 'Template bewerken' : 'Nieuw template'}
			</h3>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
				<div>
					<label class="label" for="t-name">Naam *</label>
					<input id="t-name" class="input" type="text" bind:value={formName} required placeholder="bijv. Opslag intensief" />
				</div>
				<div>
					<label class="label" for="t-type">Type</label>
					<select id="t-type" class="input" bind:value={formType}>
						{#each allTypes as [value, label]}
							<option {value}>{label}</option>
						{/each}
					</select>
				</div>
			</div>

			<div class="space-y-3">
				<div>
					<label class="label" for="t-warmup">{PHASE_LABELS.warmup}</label>
					<textarea id="t-warmup" class="input" rows="2" bind:value={formWarmup} placeholder="Beschrijf de warm-up oefeningen..."></textarea>
				</div>
				<div>
					<label class="label" for="t-tech">{PHASE_LABELS.technique}</label>
					<textarea id="t-tech" class="input" rows="2" bind:value={formTechnique} placeholder="Technische oefeningen..."></textarea>
				</div>
				<div>
					<label class="label" for="t-core1">{PHASE_LABELS.core1}</label>
					<textarea id="t-core1" class="input" rows="2" bind:value={formCore1} placeholder="Kernoefening 1..."></textarea>
				</div>
				<div>
					<label class="label" for="t-core2">{PHASE_LABELS.core2}</label>
					<textarea id="t-core2" class="input" rows="2" bind:value={formCore2} placeholder="Kernoefening 2..."></textarea>
				</div>
				<div>
					<label class="label" for="t-game">{PHASE_LABELS.game}</label>
					<textarea id="t-game" class="input" rows="2" bind:value={formGame} placeholder="Wedstrijdvorm / game..."></textarea>
				</div>
				<div>
					<label class="label" for="t-notes">Extra notities</label>
					<textarea id="t-notes" class="input" rows="2" bind:value={formNotes} placeholder="Aandachtspunten, materiaal, etc."></textarea>
				</div>
			</div>

			<div class="flex gap-2">
				<button type="submit" class="btn-primary flex-1" disabled={saving}>
					{saving ? 'Opslaan...' : editing ? 'Bijwerken' : 'Toevoegen'}
				</button>
				<button type="button" class="btn-secondary" on:click={resetForm}>Annuleren</button>
			</div>
		</form>
	{/if}

	<!-- Template list -->
	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if templates.length === 0}
		<div class="card text-center py-12 text-gray-500 dark:text-gray-400">
			<p class="mb-2">Nog geen templates aangemaakt</p>
			<p class="text-sm">Maak standaard trainingen aan die je kunt hergebruiken in je jaarplan.</p>
		</div>
	{:else}
		<div class="space-y-3">
			{#each templates as template}
				<div class="card">
					<div class="flex justify-between items-start mb-3">
						<div>
							<h3 class="font-semibold text-gray-900 dark:text-white">{template.name}</h3>
							<span class="text-xs px-2 py-0.5 rounded-full bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-400 font-medium">
								{TRAINING_TYPE_LABELS[template.type] || template.type}
							</span>
						</div>
						<div class="flex gap-1">
							<button class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-400 hover:text-primary-600 text-sm" on:click={() => startEdit(template)}>
								Bewerk
							</button>
							<button class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-400 hover:text-red-500 text-sm" on:click={() => handleDelete(template)}>
								Verwijder
							</button>
						</div>
					</div>
					<!-- Phases summary -->
					<div class="grid grid-cols-1 gap-1.5 text-sm">
						{#each TRAINING_PHASES as phase}
							{#if template[phase]}
								<div class="flex gap-2">
									<span class="text-xs font-medium text-gray-400 dark:text-gray-500 w-28 flex-shrink-0">{PHASE_LABELS[phase]}</span>
									<span class="text-gray-700 dark:text-gray-300 line-clamp-1">{template[phase]}</span>
								</div>
							{/if}
						{/each}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
