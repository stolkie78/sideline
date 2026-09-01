<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb } from '$lib/pocketbase';
	import type { Match } from '$lib/types';

	let match: Match | null = null;
	let loading = true;

	onMount(async () => {
		try {
			match = await pb.collection('matches').getOne<Match>($page.params.id);
		} catch (e) {
			match = null;
		}
		loading = false;
	});

	function formatDate(d: string) {
		if (!d) return '';
		return new Date(d).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
	}
</script>

<svelte:head>
	<title>{match?.opponent || 'Wedstrijd'} - SetBaas</title>
</svelte:head>

{#if loading}
	<p class="text-center text-gray-500 py-8">Laden...</p>
{:else if !match}
	<p class="text-center text-gray-500 py-8">Wedstrijd niet gevonden</p>
{:else}
	<div class="max-w-2xl mx-auto space-y-6">
		<div class="flex justify-between items-center">
			<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
				{match.home_away === 'home' ? 'Thuis' : 'Uit'} vs {match.opponent}
			</h1>
			<a href="{base}/matches/{match.id}/edit" class="btn-primary text-sm">✏️ Bewerken</a>
		</div>

		<div class="card space-y-4">
			<div class="grid grid-cols-2 gap-4">
				<div>
					<span class="text-sm text-gray-500">Datum</span>
					<p class="font-medium text-gray-900 dark:text-gray-100">{formatDate(match.date)}</p>
				</div>
				<div>
					<span class="text-sm text-gray-500">Locatie</span>
					<p class="font-medium text-gray-900 dark:text-gray-100">{match.location || '—'}</p>
				</div>
			</div>

			{#if match.score_team !== undefined && match.score_team !== null}
				<div>
					<span class="text-sm text-gray-500">Uitslag</span>
					<p class="text-3xl font-bold {match.score_team > match.score_opponent ? 'text-green-600' : 'text-red-500'}">
						{match.score_team} – {match.score_opponent}
					</p>
				</div>
			{/if}

			{#if match.set_scores && match.set_scores.length > 0}
				<div>
					<span class="text-sm text-gray-500">Sets</span>
					<div class="flex gap-3 mt-1">
						{#each match.set_scores as set, i}
							<span class="px-3 py-1 rounded bg-gray-100 dark:bg-gray-700 text-sm font-mono">
								Set {i+1}: {set.team ?? '?'}–{set.opponent ?? '?'}
							</span>
						{/each}
					</div>
				</div>
			{/if}

			{#if match.notes}
				<div>
					<span class="text-sm text-gray-500">Notities</span>
					<p class="text-gray-800 dark:text-gray-200 whitespace-pre-wrap">{match.notes}</p>
				</div>
			{/if}
		</div>
	</div>
{/if}
