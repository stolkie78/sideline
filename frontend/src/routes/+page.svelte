<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { getPlayers, getTrainings, getMatches } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Player, Training, Match } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';

	let players: Player[] = [];
	let trainings: Training[] = [];
	let matches: Match[] = [];
	let loading = true;

	onMount(async () => {
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			[players, trainings, matches] = await Promise.all([
				getPlayers('status = "active"'),
				pb.collection('trainings').getFullList<Training>({ sort: '-date', filter: filter || undefined }),
				pb.collection('matches').getFullList<Match>({ sort: '-date', filter: filter || undefined }),
			]);
		} catch (e) {
			console.error('Failed to load dashboard data:', e);
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>SideLine - Dashboard</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<div class="space-y-6">
		<!-- Quick Stats -->
		<div class="grid grid-cols-3 gap-3">
			<div class="card text-center py-6">
				<div class="text-3xl font-bold text-primary-600">{players.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Spelers</div>
			</div>
			<div class="card text-center py-6">
				<div class="text-3xl font-bold text-green-600">{trainings.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Trainingen</div>
			</div>
			<div class="card text-center py-6">
				<div class="text-3xl font-bold text-amber-600">{matches.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Wedstrijden</div>
			</div>
		</div>

		<!-- Quick Actions -->
		<div class="grid grid-cols-2 gap-3">
			<a href="{base}/trainings/new" class="btn-primary text-center text-base py-4">
				Nieuwe training
			</a>
			<a href="{base}/matches/new" class="btn-primary text-center text-base py-4">
				Nieuwe wedstrijd
			</a>
		</div>

		<!-- Recent Trainings -->
		{#if trainings.length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">Laatste trainingen</h2>
					<a href="{base}/trainings" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					{#each trainings.slice(0, 3) as training}
						<div class="flex justify-between items-center py-2 border-b border-gray-100 dark:border-gray-800 last:border-0">
							<span class="text-sm text-gray-700 dark:text-gray-300">{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}</span>
							{#if training.overall_rating}
								<span class="text-sm font-semibold {
									training.overall_rating >= 7 ? 'text-green-600' :
									training.overall_rating >= 5 ? 'text-yellow-600' : 'text-red-600'
								}">
									{training.overall_rating}/10
								</span>
							{/if}
						</div>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Recent Matches -->
		{#if matches.length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">Laatste wedstrijden</h2>
					<a href="{base}/matches" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					{#each matches.slice(0, 3) as match}
						{@const won = match.score_team !== undefined && match.score_opponent !== undefined && match.score_team > match.score_opponent}
						<div class="flex justify-between items-center py-2 border-b border-gray-100 dark:border-gray-800 last:border-0">
							<div>
								<span class="text-sm font-medium text-gray-800 dark:text-gray-200">{match.opponent}</span>
								<span class="text-xs text-gray-400 ml-1.5">{match.home_away === 'home' ? 'Thuis' : 'Uit'}</span>
							</div>
							{#if match.score_team !== undefined && match.score_opponent !== undefined}
								<span class="text-sm font-bold {won ? 'text-green-600' : 'text-red-500'}">
									{match.score_team}–{match.score_opponent}
								</span>
							{/if}
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</div>
{/if}
