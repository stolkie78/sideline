<script lang="ts">
	import { base } from '$app/paths';
	import { getQuestionnairesForPlayer, submitQuestionnaireResponse } from '$lib/pocketbase';
	import { linkedPlayer, rolesLoaded } from '$lib/stores/role';
	import { selectedTeamId } from '$lib/stores/context';
	import type { Questionnaire, QuestionnaireResponse } from '$lib/types';
	import QuestionnaireAnswerForm from '$lib/components/QuestionnaireAnswerForm.svelte';

	let items: { questionnaire: Questionnaire; response: QuestionnaireResponse | null }[] = [];
	let loading = true;
	let loadedContext = '';
	let openId: string | null = null;
	let saving = false;

	$: playerId = $linkedPlayer?.id;

	// Both the player link and active team are resolved asynchronously by the
	// layout. Refetch when either part of that context becomes available.
	$: context = $rolesLoaded && playerId && $selectedTeamId
		? `${playerId}:${$selectedTeamId}`
		: '';
	$: if (context && context !== loadedContext) {
		loadedContext = context;
		load(playerId, $selectedTeamId);
	}
	$: if ($rolesLoaded && !playerId) loading = false;

	async function load(currentPlayerId = playerId, teamId = $selectedTeamId) {
		if (!currentPlayerId || !teamId) return;
		loading = true;
		try {
			items = await getQuestionnairesForPlayer(teamId, currentPlayerId);
		} catch (e) {
			console.error('Failed to load inbox:', e);
		} finally {
			loading = false;
		}
	}

	async function submit(questionnaireId: string, answers: Record<string, string | number>) {
		if (!playerId) return;
		saving = true;
		try {
			await submitQuestionnaireResponse({ questionnaire: questionnaireId, player: playerId, answers });
			openId = null;
			await load();
		} catch (e) {
			console.error('Failed to submit response:', e);
			alert('Fout bij versturen antwoord');
		} finally {
			saving = false;
		}
	}

	$: pending = items.filter((i) => !i.response && i.questionnaire.status === 'active');
	$: answered = items.filter((i) => i.response);
</script>

<svelte:head>
	<title>Inbox - SetBaas</title>
</svelte:head>

<div class="space-y-6">
	<div class="card py-4 text-center">
		<p class="text-lg font-bold text-gray-800 dark:text-gray-200">📬 Inbox</p>
		<p class="text-sm text-gray-500 dark:text-gray-400">Vragenlijsten van je coach. Privéberichten volgen later.</p>
	</div>

	{#if loading}
		<div class="flex justify-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if !$linkedPlayer}
		<div class="card text-center py-8">
			<p class="text-gray-500 dark:text-gray-400">Je account is nog niet gekoppeld aan een spelersprofiel.</p>
		</div>
	{:else}
		<div>
			<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">🆕 Nieuw ({pending.length})</h2>
			{#if pending.length === 0}
				<p class="text-sm text-gray-400">Geen nieuwe vragenlijsten</p>
			{:else}
				<div class="space-y-3">
					{#each pending as item (item.questionnaire.id)}
						<div class="card space-y-2">
							<div class="flex justify-between items-center">
								<p class="font-semibold text-gray-800 dark:text-gray-200">{item.questionnaire.name}</p>
								{#if openId !== item.questionnaire.id}
									<button class="btn-primary text-xs px-3 py-2" on:click={() => (openId = item.questionnaire.id)}>
										Beantwoorden
									</button>
								{/if}
							</div>
							{#if openId === item.questionnaire.id}
								<QuestionnaireAnswerForm
									questions={item.questionnaire.questions || []}
									saving={saving}
									on:submit={(e) => submit(item.questionnaire.id, e.detail)}
								/>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<div>
			<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">✅ Beantwoord ({answered.length})</h2>
			{#if answered.length === 0}
				<p class="text-sm text-gray-400">Nog niets beantwoord</p>
			{:else}
				<div class="space-y-3">
					{#each answered as item (item.questionnaire.id)}
						<div class="card space-y-2">
							<p class="font-semibold text-gray-800 dark:text-gray-200">{item.questionnaire.name}</p>
							<QuestionnaireAnswerForm
								questions={item.questionnaire.questions || []}
								answers={item.response?.answers || {}}
								readonly
							/>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>
