<script lang="ts">
	import { onMount } from 'svelte';
	import { getSeasonPeriods, createSeasonPeriod, updateSeasonPeriod, deleteSeasonPeriod } from '$lib/pocketbase';
	import type { SeasonPeriod, SeasonPhase } from '$lib/types';
	import { SEASON_PHASE_LABELS, SEASON_PHASE_COLORS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';

	let periods: SeasonPeriod[] = [];
	let loading = true;

	// Period form
	let showPeriodForm = false;
	let editingPeriod: SeasonPeriod | null = null;
	let savingPeriod = false;
	let periodName = '';
	let periodPhase: SeasonPhase = 'preparation';
	let periodStart = '';
	let periodEnd = '';
	let periodTechnical = '';
	let periodTactical = '';
	let periodPhysical = '';
	let periodMental = '';
	let periodNotes = '';

	const allPhases = Object.entries(SEASON_PHASE_LABELS) as [SeasonPhase, string][];

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			periods = await getSeasonPeriods(filter || '');
		} catch (e) {
			console.error('Failed to load periods:', e);
		} finally {
			loading = false;
		}
	}

	function resetPeriodForm() {
		editingPeriod = null;
		periodName = '';
		periodPhase = 'preparation';
		periodStart = '';
		periodEnd = '';
		periodTechnical = '';
		periodTactical = '';
		periodPhysical = '';
		periodMental = '';
		periodNotes = '';
		showPeriodForm = false;
	}

	function startEditPeriod(p: SeasonPeriod) {
		editingPeriod = p;
		periodName = p.name;
		periodPhase = p.phase;
		periodStart = p.start_date.slice(0, 10);
		periodEnd = p.end_date.slice(0, 10);
		periodTechnical = p.goals_technical || '';
		periodTactical = p.goals_tactical || '';
		periodPhysical = p.goals_physical || '';
		periodMental = p.goals_mental || '';
		periodNotes = p.notes || '';
		showPeriodForm = true;
	}

	async function handlePeriodSubmit() {
		if (!periodName.trim() || !periodStart || !periodEnd) return;
		savingPeriod = true;
		try {
			const data = {
				name: periodName.trim(),
				phase: periodPhase,
				start_date: new Date(periodStart).toISOString(),
				end_date: new Date(periodEnd).toISOString(),
				goals_technical: periodTechnical || undefined,
				goals_tactical: periodTactical || undefined,
				goals_physical: periodPhysical || undefined,
				goals_mental: periodMental || undefined,
				notes: periodNotes || undefined,
				team: $selectedTeamId || undefined,
				season: $selectedSeasonId || undefined,
			};
			if (editingPeriod) {
				await updateSeasonPeriod(editingPeriod.id, data);
			} else {
				await createSeasonPeriod(data);
			}
			resetPeriodForm();
			await loadData();
		} catch (e) {
			console.error('Failed to save period:', e);
			alert('Fout bij opslaan');
		} finally {
			savingPeriod = false;
		}
	}

	async function handleDeletePeriod(p: SeasonPeriod) {
		if (!confirm(`"${p.name}" verwijderen?`)) return;
		try {
			await deleteSeasonPeriod(p.id);
			await loadData();
		} catch (e) {
			alert('Fout bij verwijderen');
		}
	}
</script>

<svelte:head>
	<title>Periodisering - SideLine</title>
</svelte:head>

<div class="space-y-6">
	<div class="flex justify-between items-center">
		<h2 class="text-xl font-bold text-gray-900 dark:text-white">Periodisering</h2>
		<button class="btn-primary" on:click={() => { resetPeriodForm(); showPeriodForm = !showPeriodForm; }}>
			{showPeriodForm ? 'Sluiten' : '+ Periode'}
		</button>
	</div>

	<p class="text-sm text-gray-500 dark:text-gray-400">Seizoensfases met doelen per competentiegebied</p>

	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else}

	<!-- Period form -->
	{#if showPeriodForm}
		<form class="card space-y-4" on:submit|preventDefault={handlePeriodSubmit}>
			<h3 class="font-semibold text-gray-900 dark:text-white">
				{editingPeriod ? 'Periode bewerken' : 'Nieuwe periode'}
			</h3>

			<div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
				<div>
					<label class="label">Naam *</label>
					<input class="input" type="text" bind:value={periodName} required placeholder="bijv. Voorbereiding aug-sep" />
				</div>
				<div>
					<label class="label">Fase</label>
					<select class="input" bind:value={periodPhase}>
						{#each allPhases as [value, label]}
							<option {value}>{label}</option>
						{/each}
					</select>
				</div>
				<div class="grid grid-cols-2 gap-2">
					<div>
						<label class="label">Van *</label>
						<input class="input" type="date" bind:value={periodStart} required />
					</div>
					<div>
						<label class="label">Tot *</label>
						<input class="input" type="date" bind:value={periodEnd} required />
					</div>
				</div>
			</div>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
				<div>
					<label class="label">Technische doelen</label>
					<textarea class="input" rows="3" bind:value={periodTechnical} placeholder="Wat willen we technisch bereiken?"></textarea>
				</div>
				<div>
					<label class="label">Tactische doelen</label>
					<textarea class="input" rows="3" bind:value={periodTactical} placeholder="Tactische focus deze periode?"></textarea>
				</div>
				<div>
					<label class="label">Fysieke doelen</label>
					<textarea class="input" rows="3" bind:value={periodPhysical} placeholder="Kracht, conditie, snelheid?"></textarea>
				</div>
				<div>
					<label class="label">Mentale doelen</label>
					<textarea class="input" rows="3" bind:value={periodMental} placeholder="Teambuilding, mindset, wedstrijdmentaliteit?"></textarea>
				</div>
			</div>

			<div>
				<label class="label">Notities</label>
				<textarea class="input" rows="2" bind:value={periodNotes} placeholder="Overige opmerkingen..."></textarea>
			</div>

			<div class="flex gap-2">
				<button type="submit" class="btn-primary flex-1" disabled={savingPeriod}>
					{savingPeriod ? 'Opslaan...' : editingPeriod ? 'Bijwerken' : 'Toevoegen'}
				</button>
				<button type="button" class="btn-secondary" on:click={resetPeriodForm}>Annuleren</button>
			</div>
		</form>
	{/if}

	<!-- Periods list -->
	{#if periods.length === 0}
		<div class="card text-center py-12 text-gray-500 dark:text-gray-400">
			<p class="mb-2">Nog geen periodes gedefinieerd</p>
			<p class="text-sm">Verdeel het seizoen in fases en stel doelen per competentiegebied.</p>
		</div>
	{:else}
		<div class="space-y-3">
			{#each periods as period}
				{@const isCurrent = new Date(period.start_date) <= new Date() && new Date(period.end_date) >= new Date()}
				<div class="card {isCurrent ? 'ring-2 ring-primary-500' : ''}">
					<div class="flex justify-between items-start mb-3">
						<div>
							<div class="flex items-center gap-2 mb-1">
								<h3 class="font-semibold text-gray-900 dark:text-white">{period.name}</h3>
								{#if isCurrent}
									<span class="text-[10px] px-1.5 py-0.5 rounded bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-400 font-semibold">NU</span>
								{/if}
							</div>
							<div class="flex items-center gap-2">
								<span class="text-xs px-2 py-0.5 rounded-full font-medium {SEASON_PHASE_COLORS[period.phase]}">
									{SEASON_PHASE_LABELS[period.phase]}
								</span>
								<span class="text-xs text-gray-400">
									{new Date(period.start_date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' })} – {new Date(period.end_date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' })}
								</span>
							</div>
						</div>
						<div class="flex gap-1">
							<button class="text-xs text-primary-600 hover:underline" on:click={() => startEditPeriod(period)}>Bewerk</button>
							<button class="text-xs text-red-500 hover:underline" on:click={() => handleDeletePeriod(period)}>Verwijder</button>
						</div>
					</div>

					<!-- Goals grid -->
					<div class="grid grid-cols-2 gap-3 mt-3">
						{#if period.goals_technical}
							<div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3">
								<span class="text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Technisch</span>
								<p class="text-sm text-gray-700 dark:text-gray-300 mt-1 whitespace-pre-line">{period.goals_technical}</p>
							</div>
						{/if}
						{#if period.goals_tactical}
							<div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3">
								<span class="text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Tactisch</span>
								<p class="text-sm text-gray-700 dark:text-gray-300 mt-1 whitespace-pre-line">{period.goals_tactical}</p>
							</div>
						{/if}
						{#if period.goals_physical}
							<div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3">
								<span class="text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Fysiek</span>
								<p class="text-sm text-gray-700 dark:text-gray-300 mt-1 whitespace-pre-line">{period.goals_physical}</p>
							</div>
						{/if}
						{#if period.goals_mental}
							<div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3">
								<span class="text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Mentaal</span>
								<p class="text-sm text-gray-700 dark:text-gray-300 mt-1 whitespace-pre-line">{period.goals_mental}</p>
							</div>
						{/if}
					</div>

					{#if period.notes}
						<p class="text-sm text-gray-500 dark:text-gray-400 mt-3 italic">{period.notes}</p>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
	{/if}
</div>
