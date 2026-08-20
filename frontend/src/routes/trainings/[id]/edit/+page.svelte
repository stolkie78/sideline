<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { pb, getPlayers, getTeamPlayers, updateTraining, getTrainingAttendance, createTrainingAttendance, updateTrainingAttendance, deleteTrainingAttendance, getTrainingTemplates } from '$lib/pocketbase';
	import type { Player, Training, TrainingAttendance, AttendanceStatus, TrainingTemplate } from '$lib/types';
	import { ATTENDANCE_LABELS, TRAINING_TYPE_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import MarkdownEditor from '$lib/components/MarkdownEditor.svelte';
	import { aiConfig, DEFAULT_SYSTEM_PROMPT } from '$lib/stores/ai';

	let aiPrompt = '';
	let aiGenerating = false;
	let aiError = '';
	let currentPeriod: any = null;

	async function generateWithAI() {
		if (!aiPrompt.trim() || !$aiConfig.apiKey) return;
		aiGenerating = true;
		aiError = '';
		try {
			let fullPrompt = aiPrompt;
			if (currentPeriod) {
				const goals = [];
				if (currentPeriod.goals_technical) goals.push(`Technisch: ${currentPeriod.goals_technical}`);
				if (currentPeriod.goals_tactical) goals.push(`Tactisch: ${currentPeriod.goals_tactical}`);
				if (currentPeriod.goals_physical) goals.push(`Fysiek: ${currentPeriod.goals_physical}`);
				if (currentPeriod.goals_mental) goals.push(`Mentaal: ${currentPeriod.goals_mental}`);
				if (goals.length > 0) {
					fullPrompt += `\n\nHuidige periodisering: "${currentPeriod.name}" (fase: ${currentPeriod.phase || 'onbekend'})\nDoelen voor deze periode:\n${goals.join('\n')}`;
				}
			}
			const res = await fetch(`${base}/api/ai`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					prompt: fullPrompt,
					provider: $aiConfig.provider,
					apiKey: $aiConfig.apiKey,
					model: $aiConfig.model || undefined,
					systemPrompt: $aiConfig.systemPrompt || DEFAULT_SYSTEM_PROMPT
				})
			});
			const data = await res.json();
			if (!res.ok) aiError = data.error || 'Onbekende fout';
			else formContent = data.content || '';
		} catch (e) { aiError = String(e); }
		finally { aiGenerating = false; }
	}

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

	// Training content (markdown)
	let formContent = '';

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
			training = await pb.collection('trainings').getOne<Training>(id, { expand: 'created_by' });

			trainingDate = training.date.slice(0, 16);
			overallRating = training.overall_rating || 7;
			generalComments = training.general_comments || '';
			selectedTemplate = training.template || '';
			trainingStatus = (training.status as 'open' | 'closed') || 'closed';
			formContent = training.content || '';

			// Load templates
			templates = await getTrainingTemplates();

			// Load current periodization period
			const today = new Date().toISOString().slice(0, 10);
			try {
				const periods = await pb.collection('season_periods').getFullList({
					filter: `start_date <= "${today}" && end_date >= "${today}"${$selectedTeamId ? ` && team = "${$selectedTeamId}"` : ''}`,
					sort: '-start_date'
				});
				if (periods.length > 0) currentPeriod = periods[0];
			} catch (e) { /* no periods configured */ }

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
			formContent = t.content || '';
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
				content: formContent || undefined,
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

			goto(`${base}/trainings`);
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
			goto(`${base}/trainings`);
		} catch (e) {
			console.error('Failed to delete training:', e);
			alert('Fout bij verwijderen');
		}
	}
</script>

<svelte:head>
	<title>Bewerk Training - SetBaas</title>
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

		{#if training?.expand?.created_by}
			<p class="text-xs text-gray-400 dark:text-gray-500">Aangemaakt door {training.expand.created_by.name || training.expand.created_by.email}</p>
		{/if}

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

		<!-- Training content -->
		<div class="card space-y-4">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200">Training Beschrijving</h3>

			<!-- Current Periodization -->
			{#if currentPeriod}
				<div class="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
					<div class="flex items-center gap-2 mb-2">
						<span class="text-sm font-semibold text-blue-700 dark:text-blue-300">📅 Huidige periode: {currentPeriod.name}</span>
						{#if currentPeriod.phase}
							<span class="text-xs px-2 py-0.5 rounded-full bg-blue-100 dark:bg-blue-800 text-blue-600 dark:text-blue-300">{currentPeriod.phase}</span>
						{/if}
					</div>
					<div class="grid grid-cols-2 gap-1 text-xs text-gray-600 dark:text-gray-400">
						{#if currentPeriod.goals_technical}<p>🎯 <strong>Technisch:</strong> {currentPeriod.goals_technical}</p>{/if}
						{#if currentPeriod.goals_tactical}<p>🧠 <strong>Tactisch:</strong> {currentPeriod.goals_tactical}</p>{/if}
						{#if currentPeriod.goals_physical}<p>💪 <strong>Fysiek:</strong> {currentPeriod.goals_physical}</p>{/if}
						{#if currentPeriod.goals_mental}<p>🧘 <strong>Mentaal:</strong> {currentPeriod.goals_mental}</p>{/if}
					</div>
				</div>
			{/if}

			<!-- AI Generate -->
			{#if $aiConfig.apiKey}
				<div class="p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg space-y-2">
					<label class="label text-purple-700 dark:text-purple-300">🤖 Genereer met AI</label>
					{#if currentPeriod}
						<p class="text-xs text-purple-600 dark:text-purple-400">ℹ️ De periodiseringsdoelen worden automatisch meegestuurd als context.</p>
					{/if}
					<div class="flex gap-2">
						<input class="input flex-1" type="text" bind:value={aiPrompt}
							placeholder="bijv. Focus op bovenhands spel, 90 min"
							on:keydown={(e) => e.key === 'Enter' && generateWithAI()} />
						<button type="button" class="btn-primary text-sm whitespace-nowrap"
							disabled={aiGenerating || !aiPrompt.trim()} on:click={generateWithAI}>
							{aiGenerating ? '⏳...' : '✨ Genereer'}
						</button>
					</div>
					{#if aiError}<p class="text-xs text-red-500">{aiError}</p>{/if}
				</div>
			{/if}

			<MarkdownEditor bind:value={formContent} placeholder="Beschrijf de training... (gebruik kopjes voor fases, bijv. ## Warm-up)" />
			<div>
				<label class="label">Opmerkingen</label>
				<textarea class="input" rows="2" bind:value={generalComments} placeholder="Extra aandachtspunten..."></textarea>
			</div>
		</div>

		<button type="submit" class="btn-primary w-full text-lg py-4" disabled={saving}>
			{saving ? 'Opslaan...' : 'Wijzigingen opslaan'}
		</button>
		<a href="{base}/trainings" class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{:else}
	<p class="text-center text-gray-500 py-8">Training niet gevonden</p>
{/if}
