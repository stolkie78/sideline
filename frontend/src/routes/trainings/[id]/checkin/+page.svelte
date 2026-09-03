<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb, getTrainingAttendance, getPlayers, createTrainingAttendance, updateTrainingAttendance, updateTraining } from '$lib/pocketbase';
	import type { Training, TrainingAttendance, Player, AttendanceStatus } from '$lib/types';
	import { ATTENDANCE_LABELS } from '$lib/types';

	const HAPPINESS_EMOJIS = ['😢', '😕', '😐', '😊', '🤩'];
	const HAPPINESS_LABELS = ['Baal', 'Meh', 'Oké', 'Blij', 'Super!'];
	const FITNESS_EMOJIS = ['🥱', '😴', '💪', '🔥', '⚡'];
	const FITNESS_LABELS = ['Moe', 'Sloom', 'Goed', 'Fit', 'Top!'];

	type WizardStep = 'attendance' | 'checkin' | 'start' | 'done';

	let training: Training | null = null;
	let players: Player[] = [];
	let existingAttendance: Record<string, TrainingAttendance> = {};
	let loading = true;

	// Wizard state
	let step: WizardStep = 'attendance';

	// Step 1: Attendance
	let playerStatus: Record<string, AttendanceStatus> = {};
	let savingAttendance = false;

	// Step 2: Check-in
	let presentPlayers: Player[] = [];
	let currentPlayerIndex = 0;
	let selectedHappiness = 0;
	let selectedFitness = 0;
	let checkedInIds: Set<string> = new Set();
	let saving = false;
	let showConfirmation = false;

	$: currentPlayer = presentPlayers[currentPlayerIndex] || null;
	$: checkinProgress = presentPlayers.length > 0 ? Math.round((checkedInIds.size / presentPlayers.length) * 100) : 0;

	// Step 3: Done
	let trainingStarted = false;

	$: presentCount = Object.values(playerStatus).filter(s => s === 'present').length;

	onMount(async () => {
		try {
			training = await pb.collection('trainings').getOne<Training>($page.params.id);
			players = await getPlayers('status = "active"');
			const att = await getTrainingAttendance($page.params.id);

			for (const a of att) {
				existingAttendance[a.player] = a;
			}

			// Initialize player statuses (default: present)
			for (const p of players) {
				const existing = existingAttendance[p.id];
				playerStatus[p.id] = existing?.status || 'present';
			}
			playerStatus = playerStatus;
		} catch (e) {
			console.error(e);
		}
		loading = false;
	});

	function cycleStatus(playerId: string) {
		const order: AttendanceStatus[] = ['present', 'absent', 'sick', 'injured'];
		const current = playerStatus[playerId];
		const idx = order.indexOf(current);
		playerStatus[playerId] = order[(idx + 1) % order.length];
		playerStatus = playerStatus;
	}

	async function saveAttendance() {
		savingAttendance = true;
		try {
			for (const p of players) {
				const existing = existingAttendance[p.id];
				const status = playerStatus[p.id];
				if (existing) {
					await updateTrainingAttendance(existing.id, { status });
					existingAttendance[p.id] = { ...existing, status };
				} else {
					const created = await createTrainingAttendance({
						training: $page.params.id,
						player: p.id,
						status,
					});
					existingAttendance[p.id] = created;
				}
			}
			// Move to check-in step
			presentPlayers = players.filter(p => playerStatus[p.id] === 'present');
			// Pre-fill checked-in from existing data
			for (const p of presentPlayers) {
				const att = existingAttendance[p.id];
				if (att?.happiness && att?.fitness) {
					checkedInIds.add(p.id);
				}
			}
			checkedInIds = checkedInIds;
			step = 'checkin';
			skipToNextUnchecked();
		} catch (e) {
			console.error(e);
		}
		savingAttendance = false;
	}

	function skipToNextUnchecked() {
		const idx = presentPlayers.findIndex(p => !checkedInIds.has(p.id));
		if (idx >= 0) {
			currentPlayerIndex = idx;
		}
		selectedHappiness = 0;
		selectedFitness = 0;
	}

	function allCheckedIn() {
		return presentPlayers.length > 0 && checkedInIds.size >= presentPlayers.length;
	}

	async function submitCheckin() {
		if (!currentPlayer || selectedHappiness === 0 || selectedFitness === 0) return;
		saving = true;
		try {
			const existing = existingAttendance[currentPlayer.id];
			if (existing) {
				await updateTrainingAttendance(existing.id, { happiness: selectedHappiness, fitness: selectedFitness });
			}
			checkedInIds.add(currentPlayer.id);
			checkedInIds = checkedInIds;

			showConfirmation = true;
			setTimeout(() => {
				showConfirmation = false;
				if (allCheckedIn()) {
					step = 'start';
				} else {
					skipToNextUnchecked();
				}
			}, 800);
		} catch (e) {
			console.error(e);
		}
		saving = false;
	}

	function selectPlayer(index: number) {
		currentPlayerIndex = index;
		const p = presentPlayers[index];
		const existing = existingAttendance[p.id];
		selectedHappiness = existing?.happiness || 0;
		selectedFitness = existing?.fitness || 0;
	}

	function skipCheckin() {
		step = 'start';
	}

	async function startTraining() {
		if (!training) return;
		try {
			await updateTraining(training.id, { status: 'active' });
			trainingStarted = true;
			step = 'done';
		} catch (e) {
			console.error('Failed to start training:', e);
			alert('Fout bij starten training. Controleer of de "active" status beschikbaar is in PocketBase (run pb-setup).');
		}
	}
</script>

<svelte:head>
	<title>Start Training - SetBaas</title>
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
			<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">🏐 Start Training</h1>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
				{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long' })}
			</p>
		</div>

		<!-- Step indicator -->
		{#if step !== 'done'}
			<div class="flex items-center justify-center gap-2">
				<div class="flex items-center gap-1">
					<div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold
						{step === 'attendance' ? 'bg-primary-600 text-white' : 'bg-green-500 text-white'}">
						{step === 'attendance' ? '1' : '✓'}
					</div>
					<span class="text-xs font-medium {step === 'attendance' ? 'text-primary-600' : 'text-green-500'}">Aanwezigheid</span>
				</div>
				<div class="w-8 h-0.5 {step === 'attendance' ? 'bg-gray-300 dark:bg-gray-600' : 'bg-green-400'}"></div>
				<div class="flex items-center gap-1">
					<div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold
						{step === 'checkin' ? 'bg-primary-600 text-white' : step === 'start' ? 'bg-green-500 text-white' : 'bg-gray-300 dark:bg-gray-600 text-gray-500'}">
						{step === 'start' || step === 'done' ? '✓' : '2'}
					</div>
					<span class="text-xs font-medium {step === 'checkin' ? 'text-primary-600' : step === 'start' ? 'text-green-500' : 'text-gray-400'}">Check-in</span>
				</div>
				<div class="w-8 h-0.5 {step === 'start' ? 'bg-green-400' : 'bg-gray-300 dark:bg-gray-600'}"></div>
				<div class="flex items-center gap-1">
					<div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold
						{step === 'start' ? 'bg-primary-600 text-white' : 'bg-gray-300 dark:bg-gray-600 text-gray-500'}">
						3
					</div>
					<span class="text-xs font-medium {step === 'start' ? 'text-primary-600' : 'text-gray-400'}">Start</span>
				</div>
			</div>
		{/if}

		<!-- STEP 1: Attendance -->
		{#if step === 'attendance'}
			<div class="card !p-5 space-y-4">
				<div class="text-center">
					<h2 class="text-lg font-bold text-gray-900 dark:text-gray-100">📋 Wie is er?</h2>
					<p class="text-sm text-gray-500 mt-1">Tik op een speler om de status te wijzigen</p>
				</div>

				<div class="space-y-2">
					{#each players as player}
						{@const status = playerStatus[player.id]}
						<button
							type="button"
							class="w-full flex items-center gap-3 p-3 rounded-xl transition-all active:scale-[0.98]
								{status === 'present' ? 'bg-green-50 dark:bg-green-900/20 border-2 border-green-300 dark:border-green-700' :
								 status === 'absent' ? 'bg-red-50 dark:bg-red-900/20 border-2 border-red-300 dark:border-red-700' :
								 status === 'sick' ? 'bg-yellow-50 dark:bg-yellow-900/20 border-2 border-yellow-300 dark:border-yellow-700' :
								 'bg-orange-50 dark:bg-orange-900/20 border-2 border-orange-300 dark:border-orange-700'}"
							on:click={() => cycleStatus(player.id)}
						>
							<span class="flex-1 text-left font-medium text-gray-800 dark:text-gray-200">
								{player.name}
								{#if player.jersey_number}
									<span class="text-xs text-gray-400 ml-1">#{player.jersey_number}</span>
								{/if}
							</span>
							<span class="text-xs font-semibold px-2 py-1 rounded-lg
								{status === 'present' ? 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300' :
								 status === 'absent' ? 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300' :
								 status === 'sick' ? 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300' :
								 'bg-orange-100 text-orange-700 dark:bg-orange-900 dark:text-orange-300'}">
								{ATTENDANCE_LABELS[status]}
							</span>
						</button>
					{/each}
				</div>

				<div class="pt-2 space-y-2">
					<p class="text-center text-sm font-medium text-gray-600 dark:text-gray-400">
						{presentCount} van {players.length} aanwezig
					</p>
					<button
						on:click={saveAttendance}
						class="w-full py-4 rounded-2xl text-lg font-bold bg-gradient-to-r from-primary-500 to-primary-600 text-white shadow-lg hover:shadow-xl active:scale-95 transition-all"
						disabled={savingAttendance}
					>
						{savingAttendance ? 'Opslaan...' : 'Volgende: Check-in'}
					</button>
				</div>
			</div>

		<!-- STEP 2: Check-in -->
		{:else if step === 'checkin'}
			<!-- Progress -->
			<div class="relative">
				<div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
					<div class="h-full bg-gradient-to-r from-amber-400 to-amber-600 rounded-full transition-all duration-500"
						style="width: {checkinProgress}%"></div>
				</div>
				<p class="text-center text-xs text-gray-500 mt-1">{checkedInIds.size} / {presentPlayers.length} ingecheckt</p>
			</div>

			{#if showConfirmation}
				<div class="flex flex-col items-center justify-center py-16 animate-bounce-in">
					<div class="text-7xl mb-4">✅</div>
					<p class="text-2xl font-bold text-green-600 dark:text-green-400">Top!</p>
				</div>
			{:else if currentPlayer && !allCheckedIn()}
				<div class="card !p-6 space-y-6">
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
								<button type="button"
									class="flex flex-col items-center gap-1 p-3 rounded-2xl transition-all duration-200 touch-target
										{selectedHappiness === value
											? 'bg-amber-100 dark:bg-amber-900/40 scale-110 ring-2 ring-amber-400 shadow-lg'
											: 'bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700'}"
									on:click={() => selectedHappiness = value}>
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
								<button type="button"
									class="flex flex-col items-center gap-1 p-3 rounded-2xl transition-all duration-200 touch-target
										{selectedFitness === value
											? 'bg-blue-100 dark:bg-blue-900/40 scale-110 ring-2 ring-blue-400 shadow-lg'
											: 'bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700'}"
									on:click={() => selectedFitness = value}>
									<span class="text-3xl sm:text-4xl {selectedFitness === value ? 'animate-wiggle' : ''}">{emoji}</span>
									<span class="text-[10px] sm:text-xs text-gray-500 dark:text-gray-400 font-medium">{FITNESS_LABELS[i]}</span>
								</button>
							{/each}
						</div>
					</div>

					<button type="button"
						class="w-full py-4 rounded-2xl text-lg font-bold transition-all duration-200
							{selectedHappiness > 0 && selectedFitness > 0
								? 'bg-gradient-to-r from-green-500 to-green-600 text-white shadow-lg hover:shadow-xl active:scale-95'
								: 'bg-gray-200 dark:bg-gray-700 text-gray-400 cursor-not-allowed'}"
						disabled={selectedHappiness === 0 || selectedFitness === 0 || saving}
						on:click={submitCheckin}>
						{saving ? 'Opslaan...' : selectedHappiness > 0 && selectedFitness > 0 ? 'Check in!' : 'Kies gevoel en fitheid'}
					</button>
				</div>

				<!-- Player chips -->
				<div class="card !p-4">
					<div class="flex flex-wrap gap-2">
						{#each presentPlayers as player, i}
							<button type="button"
								class="px-3 py-1.5 rounded-full text-sm font-medium transition-all
									{checkedInIds.has(player.id)
										? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400'
										: i === currentPlayerIndex
											? 'bg-primary-100 text-primary-700 ring-2 ring-primary-400'
											: 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400'}"
								on:click={() => selectPlayer(i)}>
								{player.name.split(' ')[0]}
							</button>
						{/each}
					</div>
				</div>
			{:else}
				<!-- All checked in, auto-advance -->
				{(() => { step = 'start'; return ''; })()}
			{/if}

			<!-- Skip button -->
			{#if !showConfirmation}
				<button on:click={skipCheckin}
					class="w-full py-3 rounded-xl text-sm font-medium text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 bg-gray-100 dark:bg-gray-800 transition-colors">
					Sla check-in over
				</button>
			{/if}

		<!-- STEP 3: Start -->
		{:else if step === 'start'}
			<div class="text-center py-8 space-y-6">
				<div class="text-7xl">🏐</div>
				<h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Klaar om te starten!</h2>
				<div class="text-sm text-gray-500 space-y-1">
					<p>👥 {presentCount} spelers aanwezig</p>
					{#if checkedInIds.size > 0}
						<p>😊 {checkedInIds.size} spelers ingecheckt</p>
					{/if}
				</div>
				<button on:click={startTraining}
					class="w-full py-5 rounded-2xl text-xl font-bold bg-gradient-to-r from-green-500 to-green-600 text-white shadow-lg hover:shadow-xl active:scale-95 transition-all">
					Start Training!
				</button>
				<a href="{base}/trainings/{training.id}" class="inline-block text-sm text-gray-400 hover:text-primary-600">
					Terug zonder starten
				</a>
			</div>

		<!-- DONE -->
		{:else if step === 'done'}
			<div class="text-center py-12 space-y-4 animate-bounce-in">
				<div class="text-7xl">🏐</div>
				<h2 class="text-2xl font-bold text-green-600 dark:text-green-400">Training gestart!</h2>
				<p class="text-gray-500">Veel plezier en succes! 💪</p>
				<a href="{base}/" class="inline-block mt-4 btn-primary text-lg px-8 py-3">
					Dashboard
				</a>
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
	:global(.animate-wiggle) { animation: wiggle 0.4s ease-in-out; }
	:global(.animate-bounce-in) { animation: bounce-in 0.5s ease-out; }
</style>
