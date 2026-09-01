<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { pb } from '$lib/pocketbase';
	import { marked } from 'marked';
	import type { Training } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';

	let trainings: Training[] = [];
	let loading = true;
	let expandedId: string | null = null;

	onMount(async () => {
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			trainings = await pb.collection('trainings').getFullList<Training>({
				sort: '-date',
				filter: filter || undefined,
				expand: 'template,created_by',
			});
		} catch (e) {
			console.error('Failed to load trainings:', e);
		} finally {
			loading = false;
		}
	});

	function toggleExpand(id: string) {
		expandedId = expandedId === id ? null : id;
	}
</script>

<svelte:head>
	<title>Trainingen - SetBaas</title>
</svelte:head>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Trainingen</h2>
		<a href="{base}/trainings/new" class="btn-primary">+ Training</a>
	</div>

	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if trainings.length === 0}
		<div class="card text-center py-8 text-gray-500 dark:text-gray-400">
			<p>Nog geen trainingen geregistreerd</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each trainings as training}
				<div class="card">
					<div class="flex justify-between items-center">
						<div class="flex items-center gap-2">
							{#if training.status === 'open'}
								<span class="w-2 h-2 rounded-full bg-amber-500 flex-shrink-0"></span>
							{:else if training.status === 'active'}
								<span class="w-2 h-2 rounded-full bg-green-500 animate-pulse flex-shrink-0"></span>
							{:else}
								<span class="w-2 h-2 rounded-full bg-green-500 flex-shrink-0"></span>
							{/if}
							<div>
								<span class="font-semibold text-sm">
									{new Date(training.date).toLocaleDateString('nl-NL', {
										weekday: 'short', day: 'numeric', month: 'short', year: 'numeric'
									})}
								</span>
								<span class="text-xs text-gray-400 ml-2">
									{new Date(training.date).toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit', hour12: false })}
								</span>
								{#if training.expand?.template}
									<span class="text-xs text-primary-600 dark:text-primary-400 ml-2">{training.expand.template.name}</span>
								{/if}
							</div>
						</div>
						<div class="flex items-center gap-2">
							{#if training.overall_rating}
								<span class="inline-flex items-center px-2.5 py-1 rounded-full text-sm font-bold {
									training.overall_rating >= 7 ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' :
									training.overall_rating >= 5 ? 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400' :
									'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
								}">
									{training.overall_rating}/10
								</span>
							{/if}
							{#if training.content}
								<button
									type="button"
									class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-primary-600 transition-colors text-sm"
									title="Bekijk training"
									on:click={() => toggleExpand(training.id)}
								>
									{expandedId === training.id ? '▲ Sluit' : '▼ Bekijk'}
								</button>
							{/if}
							<a href="{base}/trainings/{training.id}/checkin" class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-green-600 transition-colors text-sm" title="Check-in">
								🏐
							</a>
							<a href="{base}/trainings/{training.id}/edit" class="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-primary-600 transition-colors text-sm" title="Bewerken">
								Bewerk
							</a>
						</div>
					</div>
					{#if training.general_comments && expandedId !== training.id}
						<p class="text-sm text-gray-600 dark:text-gray-400 mt-2 line-clamp-2">{training.general_comments}</p>
					{/if}
					{#if training.expand?.created_by}
						<p class="text-xs text-gray-400 dark:text-gray-500 mt-1">Aangemaakt door {training.expand.created_by.name || training.expand.created_by.email}</p>
					{/if}

					<!-- Expanded markdown content -->
					{#if expandedId === training.id && training.content}
						<div class="mt-4 pt-4 border-t border-gray-100 dark:border-gray-700">
							<div class="prose prose-sm dark:prose-invert max-w-none">
								{@html marked(training.content, { breaks: true })}
							</div>
							{#if training.general_comments}
								<div class="mt-4 pt-3 border-t border-gray-100 dark:border-gray-700">
									<p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Opmerkingen</p>
									<p class="text-sm text-gray-700 dark:text-gray-300">{training.general_comments}</p>
								</div>
							{/if}
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>
