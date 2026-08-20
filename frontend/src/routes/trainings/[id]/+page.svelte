<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb } from '$lib/pocketbase';
	import type { Training } from '$lib/types';
	import { marked } from 'marked';

	let training: Training | null = null;
	let loading = true;

	onMount(async () => {
		try {
			training = await pb.collection('trainings').getOne<Training>($page.params.id);
		} catch (e) {
			training = null;
		}
		loading = false;
	});
</script>

<svelte:head>
	<title>Training - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if !training}
	<p class="text-center text-gray-500 py-8">Training niet gevonden</p>
{:else}
	<div class="max-w-2xl mx-auto space-y-4">
		<div class="flex justify-between items-center">
			<h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">
				Training {new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
			</h1>
			<a href="{base}/trainings/{training.id}/edit" class="btn-primary text-sm">✏️ Bewerken</a>
		</div>

		{#if training.overall_rating}
			<div class="flex items-center gap-2">
				<span class="text-sm text-gray-500">Beoordeling:</span>
				<span class="text-lg font-bold {
					training.overall_rating >= 7 ? 'text-green-600' :
					training.overall_rating >= 5 ? 'text-yellow-600' : 'text-red-600'
				}">{training.overall_rating}/10</span>
			</div>
		{/if}

		{#if training.content}
			<div class="card prose prose-sm dark:prose-invert max-w-none">
				{@html marked(training.content, { breaks: true })}
			</div>
		{:else}
			<p class="text-gray-500 italic">Geen inhoud — klik op Bewerken om een training samen te stellen.</p>
		{/if}
	</div>
{/if}
