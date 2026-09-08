<script lang="ts">
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import {
		getQuestionnaire,
		getQuestionnaireResponses,
		updateQuestionnaire,
		getContextPlayers,
	} from '$lib/pocketbase';
	import type { Questionnaire, QuestionnaireResponse, Player } from '$lib/types';
	import { QUESTIONNAIRE_STATUS_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import QuestionnaireBuilder from '$lib/components/QuestionnaireBuilder.svelte';

	let questionnaire: Questionnaire | null = null;
	let responses: QuestionnaireResponse[] = [];
	let players: Player[] = [];
	let loading = true;
	let editing = false;
	let editName = '';
	let editQuestions: Questionnaire['questions'] = [];
	let saving = false;
	let loadedContext = '';

	// Wait until the layout has resolved the active roster context. A first
	// visit after login otherwise queried the player roster with empty IDs.
	$: context = $selectedTeamId && $selectedSeasonId
		? `${$selectedTeamId}:${$selectedSeasonId}`
		: '';
	$: if (context && context !== loadedContext) {
		loadedContext = context;
		load($selectedTeamId, $selectedSeasonId);
	}

	async function load(teamId = $selectedTeamId, seasonId = $selectedSeasonId) {
		loading = true;
		try {
			[questionnaire, responses, players] = await Promise.all([
				getQuestionnaire($page.params.id),
				getQuestionnaireResponses($page.params.id),
				getContextPlayers(teamId, seasonId),
			]);
		} catch (e) {
			console.error('Failed to load questionnaire:', e);
		} finally {
			loading = false;
		}
	}

	function playerResponse(playerId: string): QuestionnaireResponse | undefined {
		return responses.find((r) => r.player === playerId);
	}

	function startEdit() {
		if (!questionnaire) return;
		editName = questionnaire.name;
		editQuestions = JSON.parse(JSON.stringify(questionnaire.questions || []));
		editing = true;
	}

	async function saveEdit() {
		if (!questionnaire) return;
		saving = true;
		try {
			await updateQuestionnaire(questionnaire.id, { name: editName.trim(), questions: editQuestions });
			editing = false;
			await load();
		} catch (e) {
			console.error('Failed to save questionnaire:', e);
			alert('Fout bij opslaan');
		} finally {
			saving = false;
		}
	}

	async function toggleStatus() {
		if (!questionnaire) return;
		const next = questionnaire.status === 'active' ? 'closed' : 'active';
		await updateQuestionnaire(questionnaire.id, { status: next });
		await load();
	}
</script>

<svelte:head>
	<title>{questionnaire?.name || 'Vragenlijst'} - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if questionnaire}
	<div class="space-y-4">
		<div class="card space-y-2">
			<div class="flex justify-between items-start gap-3">
				<div>
					<h1 class="text-xl font-bold text-gray-800 dark:text-gray-200">{questionnaire.name}</h1>
					<span class="text-xs px-2 py-0.5 rounded-full font-medium {
						questionnaire.status === 'active' ? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400' :
						questionnaire.status === 'closed' ? 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300' :
						'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-400'
					}">
						{QUESTIONNAIRE_STATUS_LABELS[questionnaire.status]}
					</span>
				</div>
				<div class="flex gap-2 flex-shrink-0">
					{#if questionnaire.status === 'draft'}
						<button class="btn-secondary text-xs px-2 py-1.5" on:click={startEdit}>✏️ Bewerken</button>
					{/if}
					<button class="btn-secondary text-xs px-2 py-1.5" on:click={toggleStatus}>
						{questionnaire.status === 'active' ? 'Sluiten' : 'Activeren'}
					</button>
				</div>
			</div>
			<p class="text-sm text-gray-500 dark:text-gray-400">{responses.length}/{players.length} spelers hebben geantwoord</p>
		</div>

		{#if editing}
			<div class="card space-y-3">
				<h2 class="font-semibold text-gray-800 dark:text-gray-200">Vragenlijst bewerken</h2>
				<input class="input" type="text" bind:value={editName} />
				<QuestionnaireBuilder bind:questions={editQuestions} />
				<div class="flex gap-2">
					<button class="btn-secondary flex-1" disabled={saving} on:click={() => (editing = false)}>Annuleren</button>
					<button class="btn-primary flex-1" disabled={saving} on:click={saveEdit}>Opslaan</button>
				</div>
			</div>
		{/if}

		<!-- Per-player responses -->
		<div class="space-y-2">
			{#each players as player}
				{@const response = playerResponse(player.id)}
				<div class="card">
					<div class="flex items-center justify-between">
						<p class="font-semibold text-gray-800 dark:text-gray-200">{player.name}</p>
						{#if response}
							<span class="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400 font-medium">
								✅ Beantwoord
							</span>
						{:else}
							<span class="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400 font-medium">
								Nog geen antwoord
							</span>
						{/if}
					</div>
					{#if response}
						<div class="mt-2 space-y-1.5">
							{#each questionnaire.questions || [] as q}
								<div class="text-sm">
									<span class="text-gray-500 dark:text-gray-400">{q.text}:</span>
									<span class="font-medium text-gray-800 dark:text-gray-200 ml-1">{response.answers?.[q.id] ?? '—'}</span>
								</div>
							{/each}
						</div>
					{/if}
				</div>
			{/each}
		</div>

		<a href="{base}/players/questionnaires" class="btn-secondary w-full text-center">← Terug naar vragenlijsten</a>
	</div>
{:else}
	<div class="card text-center py-8">
		<p class="text-gray-500 dark:text-gray-400">Vragenlijst niet gevonden</p>
		<a href="{base}/players/questionnaires" class="btn-secondary mt-4">← Terug</a>
	</div>
{/if}
