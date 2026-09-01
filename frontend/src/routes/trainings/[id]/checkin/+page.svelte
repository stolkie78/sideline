<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { pb, getTrainingAttendance, getPlayers, createTrainingAttendance, updateTrainingAttendance } from '$lib/pocketbase';
	import type { Training, TrainingAttendance, Player } from '$lib/types';

	const HAPPINESS_EMOJIS = ['😢', '😕', '😐', '😊', '🤩'];
	const HAPPINESS_LABELS = ['Baal', 'Meh', 'Oké', 'Blij', 'Super!'];
	const FITNESS_EMOJIS = ['🥱', '😴', '💪', '🔥', '⚡'];
	const FITNESS_LABELS = ['Moe', 'Sloom', 'Goed', 'Fit', 'Top!'];

	let training: Training | null = null;
	let players: Player[] = [];
	let attendance: Record<string, TrainingAttendance> = {};
	let loading = true;

	// Current player being checked in
	let currentPlayerIndex = 0;
	let selectedHappiness = 0;
	let selectedFitness = 0;
	let checkedInIds: Set<string> = new Set();
	let saving = false;
	let showConfirmation = false;
	let allDone = false;

	$: currentPlayer = players[currentPlayerIndex] || null;
	$: progress = players.length > 0 ? Math.round((checkedInIds.size / players.length) * 100) : 0;
	$: checkedInCount = checkedInIds.size;

	onMount(async () => {
		try {
			training = await pb.collection('trainings').getOne<Training>($page.params.id);
			players = await getPlayers('status = "active"');
			const att = await getTrainingAttendance($page.params.id);
			// Map existing attendance by player id
			for (const a of att) {
				attendance[a.player] = a;
				if (a.happiness && a.fitness) {
					checkedInIds.add(a.player);
				}
			}
			checkedInIds = checkedInIds;
			// Skip to first unchecked player
			skipToNextUnchecked();
		} catch (e) {
			console.error(e);
		}
		loading = false;
	});

	function skipToNextUnchecked() {
		const idx = players.findIndex((p, i) => !checkedInIds.has(p.id));
		if (idx >= 0) {
			currentPlayerIndex = idx;
		} else {
			allDone = true;
		}
		selectedHappiness = 0;
		selectedFitness = 0;
	}

	async function submitCheckin() {
		if (!currentPlayer || selectedHappiness === 0 || selectedFitness === 0) return;
		saving = true;

		try {
			const existing = attendance[currentPlayer.id];
			const data = {
				happiness: selectedHappiness,
				fitness: selectedFitness,
				status: existing?.status || 'present' as const,
			};

			if (existing) {
				await updateTrainingAttendance(existing.id, data);
			} else {
				await createTrainingAttendance({
					training: $page.params.id,
					player: currentPlayer.id,
					status: 'present',
					...data,
				});
			}

			checkedInIds.add(currentPlayer.id);
			checkedInIds = checkedInIds;

			// Show fun confirmation
			showConfirmation = true;
			setTimeout(() => {
				showConfirmation = false;
				skipToNextUnchecked();
			}, 1200);
		} catch (e) {
			console.error(e);
		}
		saving = false;
	}

	function selectPlayer(index: number) {
		currentPlayerIndex = index;
		const p = players[index];
		const existing = attendance[p.id];
		selectedHappiness = existing?.happiness || 0;
		selectedFitness = existing?.fitness || 0;
		allDone = false;
	}
</script>

<svelte:head>
	<title>Check-in - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center items-center min-h-[60vh]">
		<div class="animate-spin rounded-full h-12 w-12 border-b-3 border-primary-600"></div>
	</div>
{:else if !training}
	<p class="text-center text-gray-500 py-12 text-lg">Training niet gevonden</p>
{:else}
	<div class="max-w-lg mx-auto px-4 py-6 space-y-6">
		<!-- Header -->
		<div class="text-center">
			<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">🏐 Check-in</h1>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
				{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long' })}
			</p>
		</div>

		<!-- Progress bar -->
		<div class="relative">
			<div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
				<div class="h-full bg-gradient-to-r from-green-400 to-green-600 rounded-full transition-all duration-500 ease-out"
					style="width: {progress}%"></div>
			</div>
			<p class="text-center text-xs text-gray-500 mt-1">{checkedInCount} / {players.length} ingecheckt</p>
		</div>

		{#if showConfirmation}
			<!-- Fun confirmation animation -->
			<div class="flex flex-col items-center justify-center py-16 animate-bounce-in">
				<div class="text-7xl mb-4">✅</div>
				<p class="text-2xl font-bold text-green-600 dark:text-green-400">Top!</p>
			</div>
		{:else if allDone}
			<!-- All done! -->
			<div class="text-center py-12 space-y-4">
				<div class="text-7xl">🎉</div>
				<h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Iedereen ingecheckt!</h2>
				<p class="text-gray-500">Alle {players.length} spelers zijn klaar.</p>
				<a href="/trainings/{training.id}" class="inline-block mt-4 btn-primary text-lg px-8 py-3">
					← Terug naar training
				</a>
			</div>
		{:else if currentPlayer}
			<!-- Current player check-in -->
			<div class="card !p-6 space-y-6">
				<!-- Player name -->
				<div class="text-center">
					<div class="text-4xl mb-2">👤</div>
					<h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100">{currentPlayer.name}</h2>
					{#if currentPlayer.jersey_number}
						<span class="text-sm text-gray-400">#{currentPlayer.jersey_number}</span>
					{/if}
				</div>

				<!-- Happiness -->
				<div>
					<p class="text-center font-semibold text-gray-700 dark:text-gray-300 mb-3">Hoe voel je je? 😊</p>
					<div class="flex justify-center gap-2">
						{#each HAPPINESS_EMOJIS as emoji, i}
							{@const value = i + 1}
							<button
								type="button"
								class="flex flex-col items-center gap-1 p-3 rounded-2xl transition-all duration-200 touch-target
									{selectedHappiness === value
										? 'bg-amber-100 dark:bg-amber-900/40 scale-110 ring-2 ring-amber-400 shadow-lg'
										: 'bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700'}"
								on:click={() => selectedHappiness = value}
							>
								<span class="text-3xl sm:text-4xl {selectedHappiness === value ? 'animate-wiggle' : ''}">{emoji}</span>
								<span class="text-[10px] sm:text-xs text-gray-500 dark:text-gray-400 font-medium">{HAPPINESS_LABELS[i]}</span>
							</button>
						{/each}
					</div>
				</div>

				<!-- Fitness -->
				<div>
					<p class="text-center font-semibold text-gray-700 dark:text-gray-300 mb-3">Hoe fit ben je? 💪</p>
					<div class="flex justify-center gap-2">
						{#each FITNESS_EMOJIS as emoji, i}
							{@const value = i + 1}
							<button
								type="button"
								class="flex flex-col items-center gap-1 p-3 rounded-2xl transition-all duration-200 touch-target
									{selectedFitness === value
										? 'bg-blue-100 dark:bg-blue-900/40 scale-110 ring-2 ring-blue-400 shadow-lg'
										: 'bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700'}"
								on:click={() => selectedFitness = value}
							>
								<span class="text-3xl sm:text-4xl {selectedFitness === value ? 'animate-wiggle' : ''}">{emoji}</span>
								<span class="text-[10px] sm:text-xs text-gray-500 dark:text-gray-400 font-medium">{FITNESS_LABELS[i]}</span>
							</button>
						{/each}
					</div>
				</div>

				<!-- Submit -->
				<button
					type="button"
					class="w-full py-4 rounded-2xl text-lg font-bold transition-all duration-200
						{selectedHappiness > 0 && selectedFitness > 0
							? 'bg-gradient-to-r from-green-500 to-green-600 text-white shadow-lg hover:shadow-xl active:scale-95'
							: 'bg-gray-200 dark:bg-gray-700 text-gray-400 cursor-not-allowed'}"
					disabled={selectedHappiness === 0 || selectedFitness === 0 || saving}
					on:click={submitCheckin}
				>
					{#if saving}
						Opslaan...
					{:else if selectedHappiness > 0 && selectedFitness > 0}
						✅ Check in!
					{:else}
						Kies je gevoel en fitheid
					{/if}
				</button>
			</div>
		{/if}

		<!-- Player list (toggle) -->
		{#if !allDone && !showConfirmation}
			<div class="card !p-4">
				<p class="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 uppercase tracking-wider">Spelers</p>
				<div class="flex flex-wrap gap-2">
					{#each players as player, i}
						<button
							type="button"
							class="px-3 py-1.5 rounded-full text-sm font-medium transition-all
								{checkedInIds.has(player.id)
									? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400'
									: i === currentPlayerIndex
										? 'bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-400 ring-2 ring-primary-400'
										: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400'}"
							on:click={() => selectPlayer(i)}
						>
							{checkedInIds.has(player.id) ? '✓ ' : ''}{player.name.split(' ')[0]}
						</button>
					{/each}
				</div>
			</div>
		{/if}
	</div>
{/if}

<style>
	@keyframes wiggle {
		0%, 100% { transform: rotate(0deg); }
		25% { transform: rotate(-12deg); }
		75% { transform: rotate(12deg); }
	}
	@keyframes bounce-in {
		0% { transform: scale(0.3); opacity: 0; }
		50% { transform: scale(1.1); }
		100% { transform: scale(1); opacity: 1; }
	}
	:global(.animate-wiggle) {
		animation: wiggle 0.4s ease-in-out;
	}
	:global(.animate-bounce-in) {
		animation: bounce-in 0.5s ease-out;
	}
</style>
