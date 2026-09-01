<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb, getTrainingAttendance, getPlayers, updateTrainingAttendance, updateTraining } from '$lib/pocketbase';
	import type { Training, TrainingAttendance, Player, AttendanceStatus } from '$lib/types';

	let training: Training | null = null;
	let players: Player[] = [];
	let attendance: Record<string, TrainingAttendance> = {};
	let loading = true;
	let saving = false;

	// Attendance toggles
	let playerStatus: Record<string, AttendanceStatus> = {};

	// Scores
	let overallRating = 7;
	let generalComments = '';

	// Per-player scores
	let playerRatings: Record<string, number> = {};
	let playerNotes: Record<string, string> = {};

	$: presentCount = Object.values(playerStatus).filter(s => s === 'present').length;
	$: presentPlayers = players.filter(p => playerStatus[p.id] === 'present');

	onMount(async () => {
		try {
			training = await pb.collection('trainings').getOne<Training>($page.params.id);
			players = await getPlayers('status = "active"');
			const att = await getTrainingAttendance($page.params.id);

			for (const a of att) {
				attendance[a.player] = a;
				playerStatus[a.player] = a.status;
				playerRatings[a.player] = a.player_rating || 7;
				playerNotes[a.player] = a.player_notes || '';
			}
			// Players without attendance default to present
			for (const p of players) {
				if (!playerStatus[p.id]) playerStatus[p.id] = 'present';
				if (!playerRatings[p.id]) playerRatings[p.id] = 7;
				if (!playerNotes[p.id]) playerNotes[p.id] = '';
			}
			playerStatus = playerStatus;

			overallRating = training.overall_rating || 7;
			generalComments = training.general_comments || '';
		} catch (e) {
			console.error(e);
		}
		loading = false;
	});

	function togglePlayer(playerId: string) {
		playerStatus[playerId] = playerStatus[playerId] === 'present' ? 'absent' : 'present';
		playerStatus = playerStatus;
	}

	async function finishTraining() {
		if (!training) return;
		saving = true;
		try {
			// Save attendance + per-player scores
			for (const p of players) {
				const existing = attendance[p.id];
				const data: any = {
					status: playerStatus[p.id],
					player_rating: playerRatings[p.id] || undefined,
					player_notes: playerNotes[p.id] || undefined,
				};
				if (existing) {
					await updateTrainingAttendance(existing.id, data);
				}
			}

			// Update training: rating, comments, close
			await updateTraining(training.id, {
				overall_rating: overallRating,
				general_comments: generalComments,
				status: 'closed',
			});

			goto(`${base}/trainings/${training.id}`);
		} catch (e) {
			console.error(e);
			alert('Fout bij afronden training');
		}
		saving = false;
	}
</script>

<svelte:head>
	<title>Training afronden - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center items-center min-h-[60vh]">
		<div class="animate-spin rounded-full h-12 w-12 border-b-3 border-primary-600"></div>
	</div>
{:else if !training}
	<p class="text-center text-gray-500 py-12 text-lg">Training niet gevonden</p>
{:else}
	<div class="max-w-lg mx-auto px-4 py-6 space-y-6">
		<div class="text-center">
			<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">⏹️ Training afronden</h1>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
				{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long' })}
			</p>
		</div>

		<!-- Aanwezigheid -->
		<div class="card !p-5 space-y-3">
			<div class="flex justify-between items-center">
				<h2 class="font-bold text-gray-900 dark:text-gray-100">👥 Aanwezigheid</h2>
				<span class="text-sm font-medium text-green-600">{presentCount}/{players.length}</span>
			</div>
			<div class="space-y-1">
				{#each players as player}
					{@const isPresent = playerStatus[player.id] === 'present'}
					<button
						type="button"
						class="w-full flex items-center gap-3 p-3 rounded-xl transition-all active:scale-[0.98]
							{isPresent ? 'bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800' : 'bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800'}"
						on:click={() => togglePlayer(player.id)}
					>
						<span class="text-xl">{isPresent ? '✅' : '❌'}</span>
						<span class="flex-1 text-left font-medium text-gray-800 dark:text-gray-200">{player.name}</span>
					</button>
				{/each}
			</div>
		</div>

		<!-- Beoordeling -->
		<div class="card !p-5 space-y-4">
			<h2 class="font-bold text-gray-900 dark:text-gray-100">⭐ Beoordeling</h2>

			<div>
				<label class="text-sm font-medium text-gray-700 dark:text-gray-300 block mb-2">
					Trainingsscore: <span class="text-lg font-bold {
						overallRating >= 7 ? 'text-green-600' : overallRating >= 5 ? 'text-yellow-600' : 'text-red-600'
					}">{overallRating}/10</span>
				</label>
				<input type="range" min="1" max="10" bind:value={overallRating}
					class="w-full h-3 rounded-full appearance-none cursor-pointer accent-primary-600" />
				<div class="flex justify-between text-xs text-gray-400 mt-1">
					<span>1</span><span>5</span><span>10</span>
				</div>
			</div>

			<div>
				<label class="text-sm font-medium text-gray-700 dark:text-gray-300 block mb-1">Opmerkingen</label>
				<textarea
					bind:value={generalComments}
					rows="3"
					class="input w-full"
					placeholder="Hoe ging de training? Tips, aandachtspunten..."
				></textarea>
			</div>
		</div>

		<!-- Per-speler scores (alleen present) -->
		{#if presentPlayers.length > 0}
			<div class="card !p-5 space-y-3">
				<h2 class="font-bold text-gray-900 dark:text-gray-100">📊 Spelersscores</h2>
				<p class="text-xs text-gray-500">Optioneel — geef individuele scores</p>
				{#each presentPlayers as player}
					<div class="flex items-center gap-3 p-2 rounded-lg bg-gray-50 dark:bg-gray-800">
						<span class="text-sm font-medium text-gray-800 dark:text-gray-200 w-20 truncate">{player.name}</span>
						<input type="range" min="1" max="10" bind:value={playerRatings[player.id]}
							class="flex-1 h-2 rounded-full appearance-none cursor-pointer accent-primary-600" />
						<span class="text-sm font-bold w-8 text-center {
							playerRatings[player.id] >= 7 ? 'text-green-600' : playerRatings[player.id] >= 5 ? 'text-yellow-600' : 'text-red-600'
						}">{playerRatings[player.id]}</span>
					</div>
				{/each}
			</div>
		{/if}

		<!-- Afronden knop -->
		<button
			on:click={finishTraining}
			class="w-full py-5 rounded-2xl text-xl font-bold bg-gradient-to-r from-red-500 to-red-600 text-white shadow-lg hover:shadow-xl active:scale-95 transition-all"
			disabled={saving}
		>
			{saving ? '⏳ Opslaan...' : '⏹️ Training afronden'}
		</button>

		<a href="{base}/trainings/{training.id}" class="block text-center text-sm text-gray-400 hover:text-primary-600">
			← Terug zonder afronden
		</a>
	</div>
{/if}
