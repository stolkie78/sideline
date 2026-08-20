<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';
	import { getPlayers, createTraining, createTrainingAttendance, getTeamPlayers, getTrainingTemplates } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Player, AttendanceStatus, TrainingTemplate } from '$lib/types';
	import { ATTENDANCE_LABELS, TRAINING_TYPE_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { authUser } from '$lib/stores/auth';
	import MarkdownEditor from '$lib/components/MarkdownEditor.svelte';
	import { aiConfig, DEFAULT_SYSTEM_PROMPT } from '$lib/stores/ai';

	let aiPrompt = '';
	let aiGenerating = false;
	let aiError = '';

	// Current periodization
	let currentPeriod: any = null;

	async function generateWithAI() {
		if (!aiPrompt.trim() || !$aiConfig.apiKey) return;
		aiGenerating = true;
		aiError = '';
		try {
			// Build context with periodization goals
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

			const controller = new AbortController();
			const timeout = setTimeout(() => controller.abort(), 60000);
			const res = await fetch(`${base}/api/ai`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					prompt: fullPrompt,
					provider: $aiConfig.provider,
					apiKey: $aiConfig.apiKey,
					model: $aiConfig.model || undefined,
					systemPrompt: $aiConfig.systemPrompt || DEFAULT_SYSTEM_PROMPT
				}),
				signal: controller.signal
			});
			clearTimeout(timeout);
			const data = await res.json();
			if (!res.ok) {
				aiError = data.error || 'Onbekende fout';
			} else {
				formContent = data.content || '';
			}
		} catch (e) {
			aiError = String(e);
		} finally {
			aiGenerating = false;
		}
	}

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

			// Load current periodization period
			const today = new Date().toISOString().slice(0, 10);
			try {
				const periods = await pb.collection('season_periods').getFullList({
					filter: `start_date <= "${today}" && end_date >= "${today}"${$selectedTeamId ? ` && team = "${$selectedTeamId}"` : ''}`,
					sort: '-start_date'
				});
				if (periods.length > 0) currentPeriod = periods[0];
			} catch (e) { /* no periods configured */ }

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
	<title>Nieuwe Training - SetBaas</title>
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
						<p class="text-xs text-purple-600 dark:text-purple-400">ℹ️ De periodiseringsdoelen worden automatisch meegestuurd als context voor de AI.</p>
					{/if}
					<div class="flex gap-2">
						<input
							class="input flex-1"
							type="text"
							bind:value={aiPrompt}
							placeholder="bijv. Training voor meiden B, focus op bovenhands spel en verdediging, 90 min"
							on:keydown={(e) => e.key === 'Enter' && generateWithAI()}
						/>
						<button
							type="button"
							class="btn-primary text-sm whitespace-nowrap"
							disabled={aiGenerating || !aiPrompt.trim()}
							on:click={generateWithAI}
						>
							{aiGenerating ? '⏳...' : '✨ Genereer'}
						</button>
					</div>
					{#if aiError}
						<p class="text-xs text-red-500">{aiError}</p>
					{/if}
				</div>
			{:else}
				<a href="{base}/config" class="text-xs text-gray-400 hover:text-primary-500">
					💡 Configureer een AI-model in Configuratie → AI om trainingen te genereren
				</a>
			{/if}

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
