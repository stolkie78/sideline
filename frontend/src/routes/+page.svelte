<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { getPlayers, getTrainings, getMatches } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Player, Training, Match } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';
	import { marked } from 'marked';

	let players: Player[] = [];
	let trainings: Training[] = [];
	let matches: Match[] = [];
	let loading = true;

	// Upcoming items (future dates)
	$: upcomingMatches = matches
		.filter(m => new Date(m.date) >= new Date())
		.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
		.slice(0, 5);

	$: readyTrainings = trainings
		.filter(t => t.content && t.content.trim().length > 0)
		.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
		.slice(0, 3);

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
	<title>SetBaas - Dashboard</title>
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

		<!-- Upcoming Matches -->
		{#if upcomingMatches.length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">📅 Komende wedstrijden</h2>
					<a href="{base}/matches" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					{#each upcomingMatches as match}
						<a href="{base}/matches/{match.id}" class="block p-3 rounded-lg bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 transition">
							<div class="flex justify-between items-start">
								<div>
									<span class="text-sm font-medium text-gray-800 dark:text-gray-200">{match.opponent}</span>
									<span class="text-xs text-gray-400 ml-1">{match.home_away === 'home' ? '(Thuis)' : '(Uit)'}</span>
								</div>
							</div>
							<div class="text-xs text-gray-500 dark:text-gray-400 mt-1 space-x-3">
								<span>📆 {new Date(match.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}</span>
								<span>⏰ {new Date(match.date).toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit' })}</span>
								{#if match.location}
									<span>📍 {match.location}</span>
								{/if}
							</div>
						</a>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Ready Trainings -->
		{#if readyTrainings.length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">📋 Klaargezette trainingen</h2>
					<a href="{base}/trainings" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					{#each readyTrainings as training}
						<a href="{base}/trainings/{training.id}/edit" class="block p-3 rounded-lg bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 transition">
							<div class="flex justify-between items-center">
								<span class="text-sm text-gray-700 dark:text-gray-300">
									{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
								</span>
								{#if training.overall_rating}
									<span class="text-sm font-semibold {
										training.overall_rating >= 7 ? 'text-green-600' :
										training.overall_rating >= 5 ? 'text-yellow-600' : 'text-red-600'
									}">
										{training.overall_rating}/10
									</span>
								{/if}
							</div>
							<div class="text-xs text-gray-500 dark:text-gray-400 mt-1 line-clamp-2 prose prose-sm dark:prose-invert max-w-none">
								{@html marked(training.content?.slice(0, 200) || '', { breaks: true })}
							</div>
						</a>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Recent Matches (played) -->
		{#if matches.filter(m => m.score_team !== undefined && m.score_team !== null).length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">🏐 Uitslagen</h2>
					<a href="{base}/matches" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					{#each matches.filter(m => m.score_team !== undefined && m.score_team !== null).slice(0, 5) as match}
						{@const won = match.score_team > match.score_opponent}
						<div class="flex justify-between items-center py-2 border-b border-gray-100 dark:border-gray-800 last:border-0">
							<div>
								<span class="text-sm font-medium text-gray-800 dark:text-gray-200">{match.opponent}</span>
								<span class="text-xs text-gray-400 ml-1.5">{match.home_away === 'home' ? 'Thuis' : 'Uit'}</span>
							</div>
							<span class="text-sm font-bold {won ? 'text-green-600' : 'text-red-500'}">
								{match.score_team}–{match.score_opponent}
							</span>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</div>
{/if}
