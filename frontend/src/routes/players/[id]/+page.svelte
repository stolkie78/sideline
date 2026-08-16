<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import {
		getPlayer,
		getFileUrl,
		getCompetencies,
		getPlayerCompetencies,
		createPlayerCompetency,
	} from '$lib/pocketbase';
	import type { Player, Competency, PlayerCompetency } from '$lib/types';
	import { POSITION_LABELS, STATUS_LABELS, CATEGORY_LABELS } from '$lib/types';
	import CompetencyChart from '$lib/components/CompetencyChart.svelte';

	let player: Player | null = null;
	let competencies: Competency[] = [];
	let playerCompetencies: PlayerCompetency[] = [];
	let loading = true;
	let selectedCompetency = '';
	let showRatingForm = false;

	// Rating form
	let ratingValue = 5;
	let ratingNotes = '';
	let savingRating = false;

	$: playerId = $page.params.id;

	onMount(async () => {
		try {
			[player, competencies] = await Promise.all([
				getPlayer(playerId),
				getCompetencies(),
			]);
			await loadCompetencyData();
		} catch (e) {
			console.error('Failed to load player:', e);
		} finally {
			loading = false;
		}
	});

	async function loadCompetencyData() {
		playerCompetencies = await getPlayerCompetencies(playerId, selectedCompetency || undefined);
	}

	async function handleCompetencyFilter() {
		await loadCompetencyData();
	}

	async function saveRating() {
		if (!selectedCompetency) return;
		savingRating = true;
		try {
			await createPlayerCompetency({
				player: playerId,
				competency: selectedCompetency,
				rating: ratingValue,
				date: new Date().toISOString(),
				notes: ratingNotes || undefined,
			});
			showRatingForm = false;
			ratingNotes = '';
			ratingValue = 5;
			await loadCompetencyData();
		} catch (e) {
			console.error('Failed to save rating:', e);
			alert('Fout bij opslaan beoordeling');
		} finally {
			savingRating = false;
		}
	}
</script>

<svelte:head>
	<title>{player?.name || 'Speler'} - SideLine</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if player}
	<div class="space-y-4">
		<!-- Player Header -->
		<div class="card flex items-center gap-4">
			<div class="w-16 h-16 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden flex-shrink-0">
				{#if player.photo}
					<img src={getFileUrl(player, player.photo)} alt={player.name} class="w-full h-full object-cover" />
				{:else}
					<span class="text-primary-600 font-bold text-2xl">{player.name.charAt(0)}</span>
				{/if}
			</div>
			<div class="flex-1">
				<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">{player.name}</h2>
				<p class="text-sm text-gray-500 dark:text-gray-400">{(player.position || []).map(p => POSITION_LABELS[p] || p).join(', ') || '—'}</p>
				<span class="text-xs px-2 py-0.5 rounded-full {
					player.status === 'active' ? 'bg-green-100 text-green-700' :
					player.status === 'injured' ? 'bg-red-100 text-red-700' :
					'bg-gray-100 text-gray-700'
				}">
					{STATUS_LABELS[player.status]}
				</span>
			</div>
			<a href="/players/{player.id}/edit" class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-primary-600 transition-colors" title="Bewerken">
				✏️
			</a>
		</div>

		<!-- Competency Section -->
		<div class="card space-y-3">
			<div class="flex justify-between items-center">
				<h3 class="font-semibold text-gray-800 dark:text-gray-200">Competenties</h3>
				<button
					class="btn-primary text-xs px-3 py-2"
					on:click={() => (showRatingForm = !showRatingForm)}
					disabled={!selectedCompetency}
				>
					+ Score
				</button>
			</div>

			<!-- Competency filter -->
			<select
				class="input"
				bind:value={selectedCompetency}
				on:change={handleCompetencyFilter}
			>
				<option value="">Alle competenties</option>
				{#each competencies as comp}
					<option value={comp.id}>{comp.name} ({CATEGORY_LABELS[comp.category]})</option>
				{/each}
			</select>

			<!-- Rating Form -->
			{#if showRatingForm && selectedCompetency}
				<form class="bg-gray-50 rounded-xl p-3 space-y-2" on:submit|preventDefault={saveRating}>
					<div>
						<label class="label">Score: {ratingValue}/10</label>
						<input
							type="range"
							min="1"
							max="10"
							step="1"
							bind:value={ratingValue}
							class="w-full h-3 accent-primary-600"
						/>
						<div class="flex justify-between text-xs text-gray-400 dark:text-gray-500">
							<span>1</span><span>5</span><span>10</span>
						</div>
					</div>
					<div>
						<input
							class="input text-sm"
							type="text"
							placeholder="Opmerking (optioneel)"
							bind:value={ratingNotes}
						/>
					</div>
					<button type="submit" class="btn-primary w-full" disabled={savingRating}>
						{savingRating ? 'Opslaan...' : 'Score opslaan'}
					</button>
				</form>
			{/if}

			<!-- Chart -->
			{#if playerCompetencies.length > 0}
				<CompetencyChart data={playerCompetencies} {competencies} />
			{:else}
				<p class="text-sm text-gray-400 text-center py-4">
					Nog geen scores vastgelegd. Selecteer een competentie en klik "+ Score".
				</p>
			{/if}
		</div>

		<!-- Back button -->
		<a href="/players" class="btn-secondary w-full text-center">← Terug naar spelers</a>
	</div>
{:else}
	<div class="card text-center py-8">
		<p class="text-gray-500 dark:text-gray-400 dark:text-gray-500">Speler niet gevonden</p>
		<a href="/players" class="btn-secondary mt-4">← Terug</a>
	</div>
{/if}
