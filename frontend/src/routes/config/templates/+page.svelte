<script lang="ts">
	import { onMount } from 'svelte';
	import { getTrainingTemplates, createTrainingTemplate, updateTrainingTemplate, deleteTrainingTemplate } from '$lib/pocketbase';
	import type { TrainingTemplate, TrainingType } from '$lib/types';
	import { TRAINING_TYPE_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import MarkdownEditor from '$lib/components/MarkdownEditor.svelte';

	let templates: TrainingTemplate[] = [];
	let loading = true;
	let showForm = false;
	let editing: TrainingTemplate | null = null;
	let saving = false;

	let formName = '';
	let formType: TrainingType = 'all_round';
	let formContent = '';
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
		formContent = t.content || '';
		formNotes = t.notes || '';
		showForm = true;
	}

	function resetForm() {
		editing = null;
		formName = '';
		formType = 'all_round';
		formContent = '';
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
				content: formContent,
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
	<title>Trainingstemplates - SetBaas</title>
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
			<div>
				<label class="label">Training beschrijving</label>
				<MarkdownEditor bind:value={formContent} placeholder="Beschrijf de training... (gebruik ## kopjes voor fases)" />
			</div>
			<div>
				<label class="label" for="t-notes">Extra notities</label>
				<textarea id="t-notes" class="input" rows="2" bind:value={formNotes} placeholder="Aandachtspunten, materiaal, etc."></textarea>
			</div>
			<div class="flex gap-2">
				<button type="submit" class="btn-primary flex-1" disabled={saving}>
					{saving ? 'Opslaan...' : editing ? 'Bijwerken' : 'Toevoegen'}
				</button>
				<button type="button" class="btn-secondary" on:click={resetForm}>Annuleren</button>
			</div>
		</form>
	{/if}

	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if templates.length === 0}
		<div class="card text-center py-12 text-gray-500 dark:text-gray-400">
			<p class="mb-2">Nog geen templates aangemaakt</p>
			<p class="text-sm">Maak standaard trainingen aan die je kunt hergebruiken.</p>
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
							<button class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-400 hover:text-primary-600 text-sm" on:click={() => startEdit(template)}>Bewerk</button>
							<button class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-400 hover:text-red-500 text-sm" on:click={() => handleDelete(template)}>Verwijder</button>
						</div>
					</div>
					{#if template.content}
						<p class="text-sm text-gray-600 dark:text-gray-400 line-clamp-3 whitespace-pre-line">{template.content}</p>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>
