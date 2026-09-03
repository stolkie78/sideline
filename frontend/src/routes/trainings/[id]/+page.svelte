<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb, getTrainingAttendance } from '$lib/pocketbase';
	import type { Training, TrainingAttendance } from '$lib/types';
	import { marked } from 'marked';

	let training: Training | null = null;
	let attendance: TrainingAttendance[] = [];
	let loading = true;

	$: presentCount = attendance.filter(a => a.status === 'present').length;

	onMount(async () => {
		try {
			training = await pb.collection('trainings').getOne<Training>($page.params.id);
			attendance = await getTrainingAttendance(training.id);
		} catch (e) {
			training = null;
		}
		loading = false;
	});

	function exportPDF() {
		window.print();
	}
</script>

<svelte:head>
	<title>Training - SetBaas</title>
	<style>
		@media print {
			nav, header, .no-print, button, a.btn-primary { display: none !important; }
			body { background: white !important; color: black !important; }
			.card { border: none !important; box-shadow: none !important; padding: 0 !important; }
			.dark\:prose-invert { color: black !important; }
			.print-header { display: block !important; }
		}
	</style>
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
			<div class="flex gap-2 no-print">
				{#if training.status === 'open'}
					<a href="{base}/trainings/{training.id}/checkin" class="btn-primary text-sm">Start Training</a>
				{:else if training.status === 'active'}
					<a href="{base}/trainings/{training.id}/checkout" class="btn-primary text-sm">Afronden</a>
				{/if}
				<button on:click={exportPDF} class="btn-secondary text-sm">PDF</button>
				<a href="{base}/trainings/{training.id}/edit?returnTo={base}/trainings/{training.id}" class="btn-secondary text-sm">Bewerken</a>
			</div>
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

		<!-- Aanwezigheid -->
		<div class="card">
			<div class="flex justify-between items-center mb-3">
				<h2 class="font-semibold text-gray-900 dark:text-gray-100">👥 Aanwezigheid</h2>
				<span class="text-sm font-medium {presentCount > 0 ? 'text-green-600' : 'text-gray-400'}">
					{presentCount}/{attendance.length} aanwezig
				</span>
			</div>
			{#if attendance.length === 0}
				<p class="text-sm text-gray-500 italic">Nog geen aanwezigheid geregistreerd.</p>
			{:else}
				<div class="flex flex-wrap gap-2">
					{#each attendance as att}
						{@const player = att.expand?.player}
						<span class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm {
							att.status === 'present'
								? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
								: 'bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400'
						}">
							{att.status === 'present' ? '✅' : '❌'}
							{player ? player.name : '...'}
						</span>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Resultaten (voor gesloten trainingen) -->
		{#if training.status === 'closed' && (training.overall_rating || training.general_comments)}
			<div class="card space-y-3">
				<h2 class="font-semibold text-gray-900 dark:text-gray-100">📊 Resultaten</h2>
				{#if training.overall_rating}
					<div class="flex items-center gap-2">
						<span class="text-sm text-gray-600 dark:text-gray-400">Score:</span>
						<span class="text-lg font-bold {
							training.overall_rating >= 7 ? 'text-green-600' :
							training.overall_rating >= 5 ? 'text-yellow-600' : 'text-red-600'
						}">{training.overall_rating}/10</span>
					</div>
				{/if}
				{#if training.general_comments}
					<div>
						<span class="text-sm text-gray-600 dark:text-gray-400 block mb-1">Opmerkingen:</span>
						<p class="text-gray-800 dark:text-gray-200">{training.general_comments}</p>
					</div>
				{/if}
				<!-- Per-speler scores -->
				{#if attendance.some(a => a.player_rating)}
					<div class="mt-2">
						<span class="text-sm text-gray-600 dark:text-gray-400 block mb-2">Spelersscores:</span>
						<div class="flex flex-wrap gap-2">
							{#each attendance.filter(a => a.player_rating) as att}
								{@const player = att.expand?.player}
								<span class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm bg-gray-100 dark:bg-gray-800">
									{player ? player.name : '...'}
									<span class="font-bold {
										(att.player_rating || 0) >= 7 ? 'text-green-600' :
										(att.player_rating || 0) >= 5 ? 'text-yellow-600' : 'text-red-600'
									}">{att.player_rating}/10</span>
								</span>
							{/each}
						</div>
					</div>
				{/if}
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
