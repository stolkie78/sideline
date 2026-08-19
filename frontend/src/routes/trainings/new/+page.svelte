<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getPlayers, createTraining, createTrainingAttendance, getTeamPlayers, getTrainingTemplates } from '$lib/pocketbase';
	import type { Player, AttendanceStatus, TrainingTemplate } from '$lib/types';
	import { ATTENDANCE_LABELS, TRAINING_TYPE_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { authUser } from '$lib/stores/auth';
	import MarkdownEditor from '$lib/components/MarkdownEditor.svelte';

	let players: Player[] = [];
	let templates: TrainingTemplate[] = [];
	let loading = true;
	let saving = false;

	// Training form
	let trainingDate = new Date().toISOString().slice(0, 16);
	let overallRating = 7;
	let generalComments = '';
	let selectedTemplate = '';
	let trainingStatus: 'open' | 'closed' = 'open';

	// Training content (markdown)
	let formContent = '';

	// Per-player attendance & rating
	let playerData: Record<string, {
		status: AttendanceStatus;
		rating: number;
		notes: string;
	}> = {};

	onMount(async () => {
		try {
			// Load templates (global, not filtered by team/season)
			templates = await getTrainingTemplates();

			// Load team players for current context, fallback to all active players
			if ($selectedTeamId && $selectedSeasonId) {
				const teamPlayers = await getTeamPlayers($selectedTeamId, $selectedSeasonId);
				players = teamPlayers
					.map((tp) => tp.expand?.player)
					.filter((p): p is Player => !!p && p.status === 'active');
			}
			if (players.length === 0) {
				players = await getPlayers('status = "active"');
			}
			// Initialize player data
			for (const p of players) {
				playerData[p.id] = { status: 'present', rating: 7, notes: '' };
			}
		} catch (e) {
			console.error('Failed to load players:', e);
		} finally {
			loading = false;
		}
	});

	function applyTemplate() {
		const t = templates.find(tp => tp.id === selectedTemplate);
		if (t) {
			formContent = t.content || '';
			if (t.notes) generalComments = t.notes;
		}
	}

	function cycleStatus(playerId: string) {
		const order: AttendanceStatus[] = ['present', 'absent', 'sick', 'injured'];
		const current = playerData[playerId].status;
		const nextIdx = (order.indexOf(current) + 1) % order.length;
		playerData[playerId].status = order[nextIdx];
		playerData = playerData; // trigger reactivity
	}

	async function handleSubmit() {
		saving = true;
		try {
			// 1. Create training
			const training = await createTraining({
				date: new Date(trainingDate).toISOString(),
				overall_rating: trainingStatus === 'closed' ? overallRating : undefined,
				general_comments: generalComments || undefined,
				team: $selectedTeamId || undefined,
				season: $selectedSeasonId || undefined,
				template: selectedTemplate || undefined,
				status: trainingStatus,
				content: formContent || undefined,
				created_by: $authUser?.id || undefined,
			});

			// 2. Create attendance records (only when closed)
			if (trainingStatus === 'closed') {
				const promises = players.map((p) => {
					const pd = playerData[p.id];
					return createTrainingAttendance({
						training: training.id,
						player: p.id,
						status: pd.status,
						player_rating: pd.status === 'present' ? pd.rating : undefined,
						player_notes: pd.notes || undefined,
					});
				});
				await Promise.all(promises);
			}

			goto(`${base}/trainings`);
		} catch (e) {
			console.error('Failed to save training:', e);
			alert('Fout bij opslaan training');
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Nieuwe Training - SideLine</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<form class="space-y-4" on:submit|preventDefault={handleSubmit}>
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Nieuwe Training</h2>

		<!-- Training details -->
		<div class="card space-y-4">
			<!-- Status toggle -->
			<div>
				<label class="label">Status</label>
				<div class="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-700">
					<button type="button"
						class="flex-1 py-3 text-sm font-semibold transition-colors {trainingStatus === 'open' ? 'bg-amber-500 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
						on:click={() => (trainingStatus = 'open')}>
						Open (voorbereid)
					</button>
					<button type="button"
						class="flex-1 py-3 text-sm font-semibold transition-colors {trainingStatus === 'closed' ? 'bg-green-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
						on:click={() => (trainingStatus = 'closed')}>
						Afgerond
					</button>
				</div>
				<p class="text-xs text-gray-400 mt-1">
					{trainingStatus === 'open' ? 'Training staat klaar — scores invullen kan later.' : 'Training is afgelopen — vul scores en aanwezigheid in.'}
				</p>
			</div>

			<div>
				<label class="label" for="date">Datum & Tijd</label>
				<input id="date" class="input" type="datetime-local" bind:value={trainingDate} required />
			</div>

			<!-- Template selector -->
			{#if templates.length > 0 && trainingStatus === 'open'}
				<div>
					<label class="label">Training template</label>
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

			<!-- Score only when closed -->
			{#if trainingStatus === 'closed'}
				<div>
					<label class="label">Algemene score: {overallRating}/10</label>
					<input
						type="range" min="1" max="10" step="1"
						bind:value={overallRating}
						class="w-full h-3 accent-primary-600"
					/>
				</div>
			{/if}
		</div>

		<!-- Player Attendance - Quick Input (only when closed) -->
		{#if trainingStatus === 'closed'}
		<div class="card">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200 mb-3">Aanwezigheid & Scores</h3>
			<div class="space-y-3">
				{#each players as player (player.id)}
					{@const pd = playerData[player.id]}
					<div class="border border-gray-100 dark:border-gray-700 rounded-xl p-3">
						<div class="flex items-center gap-3">
							<button
								type="button"
								class="touch-target flex-shrink-0 w-20 py-2 rounded-lg text-xs font-semibold text-center transition-colors {
									pd.status === 'present' ? 'bg-green-100 text-green-700' :
									pd.status === 'absent' ? 'bg-red-100 text-red-700' :
									pd.status === 'sick' ? 'bg-yellow-100 text-yellow-700' :
									'bg-orange-100 text-orange-700'
								}"
								on:click={() => cycleStatus(player.id)}
							>
								{ATTENDANCE_LABELS[pd.status]}
							</button>
							<span class="flex-1 font-medium text-sm truncate">{player.name}</span>
							{#if pd.status === 'present'}
								<div class="flex items-center gap-1">
									<input
										type="number" min="1" max="10"
										class="w-12 text-center rounded-lg border border-gray-200 dark:border-gray-600 dark:bg-gray-700 dark:text-white py-1 text-sm font-bold"
										bind:value={playerData[player.id].rating}
									/>
									<span class="text-xs text-gray-400 dark:text-gray-500">/10</span>
								</div>
							{/if}
						</div>
						{#if pd.status === 'present'}
							<input
								type="text"
								class="mt-2 w-full text-xs rounded-lg border border-gray-100 dark:border-gray-600 dark:bg-gray-700 dark:text-white px-3 py-2 focus:border-primary-300 focus:outline-none"
								placeholder="Notities voor {player.name}..."
								bind:value={playerData[player.id].notes}
							/>
						{/if}
					</div>
				{/each}
			</div>
		</div>
		{/if}

		<!-- Training content -->
		<div class="card space-y-4">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200">Training Beschrijving</h3>
			<MarkdownEditor bind:value={formContent} placeholder="Beschrijf de training... (gebruik kopjes voor fases, bijv. ## Warm-up)" />
			<div>
				<label class="label">Opmerkingen</label>
				<textarea class="input" rows="2" bind:value={generalComments} placeholder="Extra aandachtspunten..."></textarea>
			</div>
		</div>

		<!-- Submit -->
		<button type="submit" class="btn-primary w-full text-lg py-4" disabled={saving}>
			{saving ? 'Opslaan...' : trainingStatus === 'open' ? 'Training klaarzetten' : 'Training Opslaan'}
		</button>

		<a href="{base}/trainings" class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{/if}
