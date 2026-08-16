<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getPlayers, getCompetencies, createPlayerCompetency, getTeamPlayers, pb } from '$lib/pocketbase';
	import type { Player, Competency, PlayerCompetency } from '$lib/types';
	import { CATEGORY_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';

	let players: Player[] = [];
	let competencies: Competency[] = [];
	let loading = true;
	let saving = false;

	let measurementDate = new Date().toISOString().slice(0, 10);
	let measurementLabel = '';

	// Scores: { [playerId]: { [competencyId]: { rating: number, notes: string } } }
	let scores: Record<string, Record<string, { rating: number; notes: string }>> = {};

	// Active player tab
	let activePlayerIdx = 0;

	onMount(async () => {
		try {
			// Load players
			if ($selectedTeamId && $selectedSeasonId) {
				const teamPlayers = await getTeamPlayers($selectedTeamId, $selectedSeasonId);
				players = teamPlayers
					.map((tp) => tp.expand?.player)
					.filter((p): p is Player => !!p && p.status === 'active');
			}
			if (players.length === 0) {
				players = await getPlayers('status = "active"');
			}

			competencies = await getCompetencies();

			// Load last scores to pre-fill
			for (const p of players) {
				scores[p.id] = {};
				for (const c of competencies) {
					scores[p.id][c.id] = { rating: 5, notes: '' };
				}
			}

			// Pre-fill with last known scores
			const lastScores = await pb.collection('player_competencies').getFullList<PlayerCompetency>({
				sort: '-date',
			});

			// Group by player+competency, keep only latest
			const seen = new Set<string>();
			for (const s of lastScores) {
				const key = `${s.player}_${s.competency}`;
				if (!seen.has(key)) {
					seen.add(key);
					if (scores[s.player] && scores[s.player][s.competency]) {
						scores[s.player][s.competency].rating = s.rating;
					}
				}
			}
			scores = scores;
		} catch (e) {
			console.error('Failed to load data:', e);
		} finally {
			loading = false;
		}
	});

	async function handleSubmit() {
		saving = true;
		try {
			const date = new Date(measurementDate).toISOString();
			const promises: Promise<any>[] = [];

			for (const player of players) {
				for (const comp of competencies) {
					const s = scores[player.id]?.[comp.id];
					if (s && s.rating > 0) {
						promises.push(createPlayerCompetency({
							player: player.id,
							competency: comp.id,
							rating: s.rating,
							date,
							notes: s.notes || (measurementLabel ? `Meting: ${measurementLabel}` : undefined),
						}));
					}
				}
			}

			await Promise.all(promises);
			goto('/reports/competencies');
		} catch (e) {
			console.error('Failed to save measurement:', e);
			alert('Fout bij opslaan meting');
		} finally {
			saving = false;
		}
	}

	$: activePlayer = players[activePlayerIdx];
	$: groupedComps = competencies.reduce((acc, c) => {
		if (!acc[c.category]) acc[c.category] = [];
		acc[c.category].push(c);
		return acc;
	}, {} as Record<string, Competency[]>);
</script>

<svelte:head>
	<title>Nieuwe Meting - SideLine</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<form class="space-y-4" on:submit|preventDefault={handleSubmit}>
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Nieuwe Meting</h2>

		<!-- Measurement info -->
		<div class="card space-y-3">
			<div class="grid grid-cols-2 gap-3">
				<div>
					<label class="label" for="date">Datum</label>
					<input id="date" class="input" type="date" bind:value={measurementDate} required />
				</div>
				<div>
					<label class="label" for="label">Label (optioneel)</label>
					<input id="label" class="input" type="text" bind:value={measurementLabel} placeholder="bijv. Meting 1, Halfjaar..." />
				</div>
			</div>
			<p class="text-xs text-gray-500 dark:text-gray-400">
				Score alle spelers op elke competentie (schaal 1-10). Vorige scores zijn vooringevuld.
			</p>
		</div>

		<!-- Player tabs -->
		<div class="flex overflow-x-auto gap-1.5 pb-1">
			{#each players as player, i}
				<button type="button"
					class="px-3 py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition-colors {
						activePlayerIdx === i
							? 'bg-primary-600 text-white'
							: 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300'
					}"
					on:click={() => (activePlayerIdx = i)}>
					{player.name}
				</button>
			{/each}
		</div>

		<!-- Scoring for active player -->
		{#if activePlayer && scores[activePlayer.id]}
			<div class="card space-y-4">
				<h3 class="font-semibold text-gray-800 dark:text-gray-200">
					{activePlayer.name}
					<span class="text-xs font-normal text-gray-400 ml-1">
						({activePlayerIdx + 1}/{players.length})
					</span>
				</h3>

				{#each Object.entries(groupedComps) as [category, comps]}
					<div>
						<h4 class="text-xs font-bold uppercase text-gray-400 dark:text-gray-500 mb-2">
							{CATEGORY_LABELS[category] || category}
						</h4>
						<div class="space-y-3">
							{#each comps as comp}
								{@const s = scores[activePlayer.id][comp.id]}
								{#if s}
									<div class="border border-gray-100 dark:border-gray-700 rounded-xl p-3">
										<div class="flex items-center justify-between mb-1">
											<span class="text-sm font-medium">{comp.name}</span>
											<span class="text-lg font-bold {
												s.rating >= 8 ? 'text-green-600' :
												s.rating >= 6 ? 'text-blue-600' :
												s.rating >= 4 ? 'text-yellow-600' :
												'text-red-600'
											}">{s.rating}</span>
										</div>
										<input
											type="range" min="1" max="10" step="1"
											bind:value={scores[activePlayer.id][comp.id].rating}
											class="w-full h-3 accent-primary-600"
										/>
										<div class="flex justify-between text-[10px] text-gray-400 mt-0.5">
											<span>1</span><span>5</span><span>10</span>
										</div>
									</div>
								{/if}
							{/each}
						</div>
					</div>
				{/each}

				<!-- Nav buttons -->
				<div class="flex gap-2 pt-2">
					{#if activePlayerIdx > 0}
						<button type="button" class="btn-secondary flex-1"
							on:click={() => (activePlayerIdx--)}>
							← Vorige
						</button>
					{/if}
					{#if activePlayerIdx < players.length - 1}
						<button type="button" class="btn-primary flex-1"
							on:click={() => (activePlayerIdx++)}>
							Volgende →
						</button>
					{:else}
						<button type="submit" class="btn-primary flex-1 text-lg py-4" disabled={saving}>
							{saving ? 'Opslaan...' : '✓ Meting Opslaan'}
						</button>
					{/if}
				</div>
			</div>
		{/if}

		<a href="/reports/competencies" class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{/if}
