<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { pb, getPlayers, getTeamPlayers, updateTraining, getTrainingAttendance, createTrainingAttendance, updateTrainingAttendance, deleteTrainingAttendance, getTrainingTemplates } from '$lib/pocketbase';
	import type { Player, Training, TrainingAttendance, AttendanceStatus, TrainingTemplate } from '$lib/types';
	import { ATTENDANCE_LABELS, TRAINING_TYPE_LABELS, PHASE_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';

	let training: Training | null = null;
	let players: Player[] = [];
	let templates: TrainingTemplate[] = [];
	let existingAttendance: TrainingAttendance[] = [];
	let loading = true;
	let saving = false;

	// Training form
	let trainingDate = '';
	let overallRating = 7;
	let generalComments = '';
	let selectedTemplate = '';
	let trainingStatus: 'open' | 'closed' = 'closed';

	// Phase fields
	let formWarmup = '';
	let formTechnique = '';
	let formCore1 = '';
	let formCore2 = '';
	let formGame = '';

	// Per-player attendance & rating
	let playerData: Record<string, {
		id?: string; // existing attendance record id
		status: AttendanceStatus;
		rating: number;
		notes: string;
	}> = {};

	onMount(async () => {
		try {
			const id = $page.params.id;
			training = await pb.collection('trainings').getOne<Training>(id);

			trainingDate = training.date.slice(0, 16);
			overallRating = training.overall_rating || 7;
			generalComments = training.general_comments || '';
			selectedTemplate = training.template || '';
			trainingStatus = (training.status as 'open' | 'closed') || 'closed';
			formWarmup = training.warmup || '';
			formTechnique = training.technique || '';
			formCore1 = training.core1 || '';
			formCore2 = training.core2 || '';
			formGame = training.game || '';

			// Load templates
			templates = await getTrainingTemplates();

			// Load players
			if ($selectedTeamId && $selectedSeasonId) {
				const teamPlayers = await getTeamPlayers($selectedTeamId, $selectedSeasonId);
				players = teamPlayers
					.map((tp) => tp.expand?.player)
					.filter((p): p is Player => !!p && p.status === 'active');
			}
			if (players.length === 0) {
				players = await getPlayers('status = "active"');
			}

			// Load existing attendance
			existingAttendance = await getTrainingAttendance(id);

			// Initialize player data
			for (const p of players) {
				const existing = existingAttendance.find(a => a.player === p.id);
				if (existing) {
					playerData[p.id] = {
						id: existing.id,
						status: existing.status as AttendanceStatus,
						rating: existing.player_rating || 7,
						notes: existing.player_notes || '',
					};
				} else {
					playerData[p.id] = { status: 'present', rating: 7, notes: '' };
				}
			}
		} catch (e) {
			console.error('Failed to load training:', e);
		} finally {
			loading = false;
		}
	});

	function cycleStatus(playerId: string) {
		const order: AttendanceStatus[] = ['present', 'absent', 'sick', 'injured'];
		const current = playerData[playerId].status;
		const nextIdx = (order.indexOf(current) + 1) % order.length;
		playerData[playerId].status = order[nextIdx];
		playerData = playerData;
	}

	function applyTemplate() {
		const t = templates.find(tp => tp.id === selectedTemplate);
		if (t) {
			formWarmup = t.warmup || '';
			formTechnique = t.technique || '';
			formCore1 = t.core1 || '';
			formCore2 = t.core2 || '';
			formGame = t.game || '';
			if (t.notes) generalComments = t.notes;
		}
	}

	async function handleSubmit() {
		if (!training) return;
		saving = true;
		try {
			// Update training
			await updateTraining(training.id, {
				date: new Date(trainingDate).toISOString(),
				overall_rating: trainingStatus === 'closed' ? overallRating : undefined,
				general_comments: generalComments || undefined,
				template: selectedTemplate || undefined,
				status: trainingStatus,
				warmup: formWarmup || undefined,
				technique: formTechnique || undefined,
				core1: formCore1 || undefined,
				core2: formCore2 || undefined,
				game: formGame || undefined,
			});

			// Update/create attendance records (only when closed)
			if (trainingStatus === 'closed') {
				const promises = players.map(async (p) => {
					const pd = playerData[p.id];
					const data = {
						training: training!.id,
						player: p.id,
						status: pd.status,
						player_rating: pd.status === 'present' ? pd.rating : undefined,
						player_notes: pd.notes || undefined,
					};

					if (pd.id) {
						return updateTrainingAttendance(pd.id, data);
					} else {
						return createTrainingAttendance(data);
					}
				});
				await Promise.all(promises);
			}

			goto('/trainings');
		} catch (e) {
			console.error('Failed to update training:', e);
			alert('Fout bij bijwerken training');
		} finally {
			saving = false;
		}
	}

	async function handleDelete() {
		if (!training) return;
		if (!confirm('Weet je zeker dat je deze training wilt verwijderen?')) return;
		try {
			// Delete attendance first
			for (const a of existingAttendance) {
				await deleteTrainingAttendance(a.id);
			}
			await pb.collection('trainings').delete(training.id);
			goto('/trainings');
		} catch (e) {
			console.error('Failed to delete training:', e);
			alert('Fout bij verwijderen');
		}
	}
</script>

<svelte:head>
	<title>Bewerk Training - SideLine</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if training}
	<form class="space-y-4" on:submit|preventDefault={handleSubmit}>
		<div class="flex justify-between items-center">
			<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Bewerk Training</h2>
			<button type="button" class="text-red-500 hover:text-red-700 text-sm font-semibold" on:click={handleDelete}>
				🗑️ Verwijderen
			</button>
		</div>

		<div class="card space-y-4">
			<!-- Status toggle -->
			<div>
				<label class="label">Status</label>
				<div class="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-700">
					<button type="button"
						class="flex-1 py-3 text-sm font-semibold transition-colors {trainingStatus === 'open' ? 'bg-amber-500 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
						on:click={() => (trainingStatus = 'open')}>
						Open
					</button>
					<button type="button"
						class="flex-1 py-3 text-sm font-semibold transition-colors {trainingStatus === 'closed' ? 'bg-green-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
						on:click={() => (trainingStatus = 'closed')}>
						Afgerond
					</button>
				</div>
			</div>

			<div>
				<label class="label" for="date">Datum & Tijd</label>
				<input id="date" class="input" type="datetime-local" bind:value={trainingDate} required />
			</div>

			<!-- Template selector -->
			{#if templates.length > 0 && trainingStatus === 'open'}
				<div>
					<label class="label">Template</label>
					<div class="flex gap-2">
						<select class="input flex-1" bind:value={selectedTemplate}>
							<option value="">— Geen template —</option>
							{#each templates as t}
								<option value={t.id}>{t.name} ({TRAINING_TYPE_LABELS[t.type]})</option>
							{/each}
						</select>
						<button type="button" class="btn-secondary text-sm px-3" on:click={applyTemplate} disabled={!selectedTemplate}>
							Toepassen
						</button>
					</div>
				</div>
			{/if}

			{#if trainingStatus === 'closed'}
				<div>
					<label class="label">Algemene score: {overallRating}/10</label>
					<input type="range" min="1" max="10" step="1" bind:value={overallRating} class="w-full h-3 accent-primary-600" />
				</div>
			{/if}
		</div>

		<!-- Player Attendance (only when closed) -->
		{#if trainingStatus === 'closed'}
		<div class="card">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200 mb-3">Aanwezigheid & Scores</h3>
			<div class="space-y-3">
				{#each players as player (player.id)}
					{@const pd = playerData[player.id]}
					{#if pd}
						<div class="border border-gray-100 dark:border-gray-700 rounded-xl p-3">
							<div class="flex items-center gap-3">
								<button type="button"
									class="touch-target flex-shrink-0 w-20 py-2 rounded-lg text-xs font-semibold text-center transition-colors {
										pd.status === 'present' ? 'bg-green-100 text-green-700' :
										pd.status === 'absent' ? 'bg-red-100 text-red-700' :
										pd.status === 'sick' ? 'bg-yellow-100 text-yellow-700' :
										'bg-orange-100 text-orange-700'
									}"
									on:click={() => cycleStatus(player.id)}>
									{ATTENDANCE_LABELS[pd.status]}
								</button>
								<span class="flex-1 font-medium text-sm truncate">{player.name}</span>
								{#if pd.status === 'present'}
									<div class="flex items-center gap-1">
										<input type="number" min="1" max="10"
											class="w-12 text-center rounded-lg border border-gray-200 dark:border-gray-600 dark:bg-gray-700 dark:text-white py-1 text-sm font-bold"
											bind:value={playerData[player.id].rating} />
										<span class="text-xs text-gray-400">/10</span>
									</div>
								{/if}
							</div>
							{#if pd.status === 'present'}
								<input type="text"
									class="mt-2 w-full text-xs rounded-lg border border-gray-100 dark:border-gray-600 dark:bg-gray-700 dark:text-white px-3 py-2"
									placeholder="Notities voor {player.name}..."
									bind:value={playerData[player.id].notes} />
							{/if}
						</div>
					{/if}
				{/each}
			</div>
		</div>
		{/if}

		<!-- Training phases -->
		<div class="card space-y-4">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200">Trainingsfases</h3>
			<div>
				<label class="label">{PHASE_LABELS.warmup}</label>
				<textarea class="input" rows="2" bind:value={formWarmup} placeholder="Warm-up / kracht oefeningen..."></textarea>
			</div>
			<div>
				<label class="label">{PHASE_LABELS.technique}</label>
				<textarea class="input" rows="2" bind:value={formTechnique} placeholder="Technische oefeningen..."></textarea>
			</div>
			<div>
				<label class="label">{PHASE_LABELS.core1}</label>
				<textarea class="input" rows="2" bind:value={formCore1} placeholder="Kernoefening 1..."></textarea>
			</div>
			<div>
				<label class="label">{PHASE_LABELS.core2}</label>
				<textarea class="input" rows="2" bind:value={formCore2} placeholder="Kernoefening 2..."></textarea>
			</div>
			<div>
				<label class="label">{PHASE_LABELS.game}</label>
				<textarea class="input" rows="2" bind:value={formGame} placeholder="Wedstrijdvorm / game..."></textarea>
			</div>
			<div>
				<label class="label">Opmerkingen</label>
				<textarea class="input" rows="2" bind:value={generalComments} placeholder="Extra aandachtspunten..."></textarea>
			</div>
		</div>

		<button type="submit" class="btn-primary w-full text-lg py-4" disabled={saving}>
			{saving ? 'Opslaan...' : 'Wijzigingen opslaan'}
		</button>
		<a href="/trainings" class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{:else}
	<p class="text-center text-gray-500 py-8">Training niet gevonden</p>
{/if}
