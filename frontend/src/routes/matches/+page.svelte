<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { getMatches } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Match } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';

	let matches: Match[] = [];
	let loading = true;

	onMount(async () => {
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			matches = await pb.collection('matches').getFullList<Match>({
				sort: '-date',
				filter: filter || undefined,
				expand: 'created_by',
			});
		} catch (e) {
			console.error('Failed to load matches:', e);
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Wedstrijden - SideLine</title>
</svelte:head>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Wedstrijden</h2>
		<div class="flex gap-2">
			<a href="{base}/matches/import" class="btn-secondary text-sm">📥 Nevobo</a>
			<a href="{base}/matches/new" class="btn-primary">+ Wedstrijd</a>
		</div>
	</div>

	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if matches.length === 0}
		<div class="card text-center py-8 text-gray-500 dark:text-gray-400 dark:text-gray-500">
			
			<p>Nog geen wedstrijden geregistreerd</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each matches as match}
				{@const won = match.score_team !== undefined && match.score_opponent !== undefined && match.score_team > match.score_opponent}
				{@const lost = match.score_team !== undefined && match.score_opponent !== undefined && match.score_team < match.score_opponent}
				<div class="card">
					<div class="flex justify-between items-start">
						<div>
							<div class="flex items-center gap-2">
								<span class="font-semibold">{match.opponent}</span>
								<span class="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400">
									{match.home_away === 'home' ? 'Thuis' : 'Uit'}
								</span>
							</div>
							<span class="text-xs text-gray-400 dark:text-gray-500">
								{new Date(match.date).toLocaleDateString('nl-NL', {
									weekday: 'short', day: 'numeric', month: 'short'
								})}
							</span>
						</div>
						<div class="flex items-center gap-2">
							{#if match.score_team !== undefined && match.score_opponent !== undefined}
								<span class="text-lg font-bold {won ? 'text-green-600' : lost ? 'text-red-600' : 'text-gray-600 dark:text-gray-300'}">
									{match.score_team} - {match.score_opponent}
								</span>
							{/if}
							<a href="{base}/matches/{match.id}/edit" class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-primary-600 transition-colors" title="Bewerken">
								✏️
							</a>
						</div>
					</div>
					<!-- Set scores -->
					{#if match.set_scores && Array.isArray(match.set_scores) && match.set_scores.length > 0}
						<div class="flex gap-2 mt-1.5">
							{#each match.set_scores as set, i}
								{#if set.team !== null && set.opponent !== null}
									<span class="text-xs px-1.5 py-0.5 rounded bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 font-mono">
										{set.team}-{set.opponent}
									</span>
								{/if}
							{/each}
						</div>
					{/if}
					{#if match.general_notes}
						<p class="text-sm text-gray-600 dark:text-gray-400 mt-2 line-clamp-2">{match.general_notes}</p>
					{/if}
					{#if match.expand?.created_by}
						<p class="text-xs text-gray-400 dark:text-gray-500 mt-1">Aangemaakt door {match.expand.created_by.name || match.expand.created_by.email}</p>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>
