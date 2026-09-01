<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { getPlayers, getTrainings } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Player, Training, TrainingAttendance } from '$lib/types';

	const HAPPINESS_EMOJIS = ['😢', '😕', '😐', '😊', '🤩'];
	const FITNESS_EMOJIS = ['🥱', '😴', '💪', '🔥', '⚡'];

	let players: Player[] = [];
	let trainings: Training[] = [];
	let loading = true;

	interface PlayerWellness {
		player: Player;
		entries: { date: string; happiness: number; fitness: number }[];
		avgHappiness: number;
		avgFitness: number;
		latestHappiness: number;
		latestFitness: number;
		trend: 'up' | 'down' | 'stable';
	}

	let playerWellness: PlayerWellness[] = [];

	onMount(async () => {
		try {
			[players, trainings] = await Promise.all([
				getPlayers('status = "active"'),
				getTrainings(),
			]);

			const allAttendance = await pb.collection('training_attendance').getFullList<TrainingAttendance>({
				expand: 'training',
				sort: 'created',
			});

			// Group by player
			const byPlayer: Record<string, { date: string; happiness: number; fitness: number }[]> = {};
			for (const att of allAttendance) {
				if (!att.happiness && !att.fitness) continue;
				if (!byPlayer[att.player]) byPlayer[att.player] = [];
				const t = trainings.find(tr => tr.id === att.training);
				byPlayer[att.player].push({
					date: t?.date || att.created,
					happiness: att.happiness || 0,
					fitness: att.fitness || 0,
				});
			}

			playerWellness = players.map(player => {
				const entries = (byPlayer[player.id] || []).sort((a, b) => a.date.localeCompare(b.date));
				const withH = entries.filter(e => e.happiness > 0);
				const withF = entries.filter(e => e.fitness > 0);

				const avgH = withH.length > 0 ? withH.reduce((s, e) => s + e.happiness, 0) / withH.length : 0;
				const avgF = withF.length > 0 ? withF.reduce((s, e) => s + e.fitness, 0) / withF.length : 0;

				const latest = entries[entries.length - 1];
				const prev = entries.length >= 2 ? entries[entries.length - 2] : null;

				let trend: 'up' | 'down' | 'stable' = 'stable';
				if (latest && prev) {
					const latestAvg = (latest.happiness + latest.fitness) / 2;
					const prevAvg = (prev.happiness + prev.fitness) / 2;
					if (latestAvg > prevAvg + 0.5) trend = 'up';
					else if (latestAvg < prevAvg - 0.5) trend = 'down';
				}

				return {
					player,
					entries,
					avgHappiness: Math.round(avgH * 10) / 10,
					avgFitness: Math.round(avgF * 10) / 10,
					latestHappiness: latest?.happiness || 0,
					latestFitness: latest?.fitness || 0,
					trend,
				};
			})
			.filter(pw => pw.entries.length > 0)
			.sort((a, b) => b.avgHappiness + b.avgFitness - a.avgHappiness - a.avgFitness);
		} catch (e) {
			console.error('Failed to load wellness data:', e);
		} finally {
			loading = false;
		}
	});

	function emojiFor(type: 'happiness' | 'fitness', value: number): string {
		if (value === 0) return '—';
		const arr = type === 'happiness' ? HAPPINESS_EMOJIS : FITNESS_EMOJIS;
		return arr[Math.min(value, 5) - 1] || '—';
	}

	function scoreColor(value: number): string {
		if (value >= 4) return 'text-green-600';
		if (value >= 3) return 'text-yellow-600';
		if (value >= 2) return 'text-orange-600';
		return 'text-red-600';
	}
</script>

<svelte:head>
	<title>Welzijn Rapport - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<div class="space-y-4">
		<div class="flex items-center gap-2">
			<a href="{base}/reports" class="text-primary-600 text-sm">← Rapportages</a>
		</div>

		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">😊💪 Welzijn & Fitheid</h2>

		<!-- Team averages -->
		{#if playerWellness.length > 0}
			{@const teamH = playerWellness.reduce((s, p) => s + p.avgHappiness, 0) / playerWellness.length}
			{@const teamF = playerWellness.reduce((s, p) => s + p.avgFitness, 0) / playerWellness.length}
			<div class="card">
				<div class="grid grid-cols-2 gap-4 text-center">
					<div>
						<div class="text-3xl mb-1">{emojiFor('happiness', Math.round(teamH))}</div>
						<div class="text-lg font-bold {scoreColor(teamH)}">{teamH.toFixed(1)}/5</div>
						<div class="text-xs text-gray-500">Team Happiness</div>
					</div>
					<div>
						<div class="text-3xl mb-1">{emojiFor('fitness', Math.round(teamF))}</div>
						<div class="text-lg font-bold {scoreColor(teamF)}">{teamF.toFixed(1)}/5</div>
						<div class="text-xs text-gray-500">Team Fitheid</div>
					</div>
				</div>
			</div>
		{/if}

		{#if playerWellness.length === 0}
			<div class="card text-center py-8 text-gray-500">
				<p>Nog geen check-in data beschikbaar.</p>
				<p class="text-sm mt-2">Gebruik de 🏐 Check-in bij trainingen om data te verzamelen.</p>
			</div>
		{:else}
			<!-- Per player -->
			<div class="space-y-2">
				{#each playerWellness as pw}
					<div class="card">
						<div class="flex items-center gap-3 mb-3">
							<span class="font-semibold text-sm flex-1 truncate">{pw.player.name}</span>
							<span class="text-sm">
								{#if pw.trend === 'up'}📈{:else if pw.trend === 'down'}📉{:else}➡️{/if}
							</span>
						</div>

						<!-- Current & average -->
						<div class="grid grid-cols-2 gap-3 mb-3">
							<div class="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-3 text-center">
								<div class="text-xs text-gray-500 mb-1">Happiness</div>
								<div class="flex items-center justify-center gap-2">
									<span class="text-2xl">{emojiFor('happiness', pw.latestHappiness)}</span>
									<span class="text-sm font-bold {scoreColor(pw.avgHappiness)}">gem. {pw.avgHappiness}</span>
								</div>
							</div>
							<div class="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-3 text-center">
								<div class="text-xs text-gray-500 mb-1">Fitheid</div>
								<div class="flex items-center justify-center gap-2">
									<span class="text-2xl">{emojiFor('fitness', pw.latestFitness)}</span>
									<span class="text-sm font-bold {scoreColor(pw.avgFitness)}">gem. {pw.avgFitness}</span>
								</div>
							</div>
						</div>

						<!-- History sparkline (emoji timeline) -->
						{#if pw.entries.length > 1}
							<div class="flex gap-1 overflow-x-auto pb-1">
								{#each pw.entries.slice(-10) as entry}
									<div class="flex flex-col items-center min-w-[2rem]" title="{new Date(entry.date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' })}">
										<span class="text-xs">{emojiFor('happiness', entry.happiness)}</span>
										<span class="text-xs">{emojiFor('fitness', entry.fitness)}</span>
										<span class="text-[9px] text-gray-400">{new Date(entry.date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'numeric' })}</span>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
{/if}
