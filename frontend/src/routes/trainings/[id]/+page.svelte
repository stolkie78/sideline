<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb, getTrainingAttendance, getPlayers } from '$lib/pocketbase';
	import type { Training, TrainingAttendance, Player } from '$lib/types';
	import { ATTENDANCE_LABELS } from '$lib/types';
	import { marked } from 'marked';
	import { contextFilter } from '$lib/stores/context';

	let training: Training | null = null;
	let attendance: TrainingAttendance[] = [];
	let allPlayers: Player[] = [];
	let loading = true;

	$: presentCount = attendance.filter(a => a.status === 'present').length;

	onMount(async () => {
		try {
			const [t, players] = await Promise.all([
				pb.collection('trainings').getOne<Training>($page.params.id),
				getPlayers('status = "active"'),
			]);
			training = t;
			allPlayers = players;
			attendance = await getTrainingAttendance(t.id);
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
					<a href="{base}/trainings/{training.id}/checkin" class="btn-primary text-sm">▶️ Start Training</a>
				{/if}
				<button on:click={exportPDF} class="btn-secondary text-sm">📄 PDF</button>
				<a href="{base}/trainings/{training.id}/edit" class="btn-secondary text-sm">✏️ Bewerken</a>
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
					{presentCount}/{allPlayers.length} aanwezig
				</span>
			</div>
			{#if attendance.length === 0}
				<p class="text-sm text-gray-500 italic">Nog geen aanwezigheid geregistreerd.</p>
			{:else}
				<div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
					{#each attendance as att}
						{@const player = att.expand?.player}
						<div class="flex items-center gap-2 p-2 rounded-lg bg-gray-50 dark:bg-gray-800 text-sm">
							<span class="w-2 h-2 rounded-full {
								att.status === 'present' ? 'bg-green-500' :
								att.status === 'absent' ? 'bg-red-500' :
								att.status === 'sick' ? 'bg-yellow-500' : 'bg-orange-500'
							}"></span>
							<span class="text-gray-700 dark:text-gray-300 truncate">
								{player ? player.name : '...'}
							</span>
							{#if att.happiness}
								<span class="text-xs" title="Happiness">{['😢','😕','😐','😊','🤩'][att.happiness - 1]}</span>
							{/if}
							{#if att.fitness}
								<span class="text-xs" title="Fitness">{['🥱','😴','💪','🔥','⚡'][att.fitness - 1]}</span>
							{/if}
							<span class="text-xs text-gray-400 ml-auto">{ATTENDANCE_LABELS[att.status]}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		{#if training.content}
			<div class="card prose prose-sm dark:prose-invert max-w-none">
				{@html marked(training.content, { breaks: true })}
			</div>
		{:else}
			<p class="text-gray-500 italic">Geen inhoud — klik op Bewerken om een training samen te stellen.</p>
		{/if}
	</div>
{/if}
