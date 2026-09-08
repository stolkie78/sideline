<script lang="ts">
	import { pb, getAttendanceForPlayer, setPlayerAttendance, getPendingQuestionnaires } from '$lib/pocketbase';
	import { linkedPlayer, rolesLoaded } from '$lib/stores/role';
	import { selectedTeamId, selectedSeasonId, contextFilter } from '$lib/stores/context';
	import type { Training, Match, TrainingAttendance, MatchAttendance, AttendanceStatus, Questionnaire } from '$lib/types';
	import { marked } from 'marked';
	import { base } from '$app/paths';
	import AttendanceStatusSwitcher from '$lib/components/AttendanceStatusSwitcher.svelte';

	let trainings: Training[] = [];
	let matches: Match[] = [];
	let trainingAttendance: TrainingAttendance[] = [];
	let matchAttendance: MatchAttendance[] = [];
	let pendingQuestionnaires: Questionnaire[] = [];
	let loading = true;
	let submitting: Record<string, boolean> = {};
	let lightboxTraining: Training | null = null;
	let loadedContext = '';
	let showAllTrainings = false;
	let showAllMatches = false;

	$: playerId = $linkedPlayer?.id;

	// The player link and roster context both arrive asynchronously after
	// login. Query only after all IDs are available and reload on context
	// changes, so a fresh browser session cannot remain permanently empty.
	$: context = $rolesLoaded && playerId && $selectedTeamId && $selectedSeasonId
		? `${playerId}:${$selectedTeamId}:${$selectedSeasonId}`
		: '';
	$: if (context && context !== loadedContext) {
		loadedContext = context;
		loadData(playerId, $selectedTeamId, $selectedSeasonId);
	}
	$: if ($rolesLoaded && !playerId) loading = false;

	async function loadData(
		currentPlayerId = playerId,
		teamId = $selectedTeamId,
		seasonId = $selectedSeasonId
	) {
		if (!currentPlayerId || !teamId || !seasonId) return;
		loading = true;
		try {
			const filter = contextFilter(teamId, seasonId);
			const now = new Date().toISOString().slice(0, 10);

			const [t, m, att, pendingQ] = await Promise.all([
				pb.collection('trainings').getFullList<Training>({
					sort: 'date',
					// Any upcoming training that isn't finished yet (open or
					// currently active) — a training marked "closed" is done
					// and no longer needs a response.
					filter: [filter, `date >= "${now}"`, 'status != "closed"'].filter(Boolean).join(' && '),
				}),
				pb.collection('matches').getFullList<Match>({
					sort: 'date',
					filter: [filter, `date >= "${now}"`].filter(Boolean).join(' && '),
				}),
				getAttendanceForPlayer(currentPlayerId),
				getPendingQuestionnaires(teamId, currentPlayerId),
			]);

			trainings = t;
			matches = m;
			trainingAttendance = att.training;
			matchAttendance = att.match;
			pendingQuestionnaires = pendingQ;
		} catch (e) {
			console.error('Failed to load player dashboard:', e);
		} finally {
			loading = false;
		}
	}

	// `avail`/`match` params are passed explicitly (rather than read via
	// closure) so Svelte's dependency tracking for `{@const}` inside `{#each}`
	// recognizes the dependency and re-evaluates immediately after a status
	// change — reading the outer array only via closure does NOT trigger a
	// re-render until something else causes a refresh (e.g. a page reload).
	function getTrainingStatus(trainingId: string, records: TrainingAttendance[]): AttendanceStatus {
		return records.find(a => a.training === trainingId)?.status || 'present';
	}

	function getMatchStatus(matchId: string, records: MatchAttendance[]): AttendanceStatus {
		return records.find(a => a.match === matchId)?.status || 'present';
	}

	function getTrainingReason(trainingId: string, records: TrainingAttendance[]): string {
		return records.find(a => a.training === trainingId)?.reason || '';
	}

	function getMatchReason(matchId: string, records: MatchAttendance[]): string {
		return records.find(a => a.match === matchId)?.reason || '';
	}

	async function submitStatus(type: 'training' | 'match', id: string, status: AttendanceStatus, reason?: string) {
		if (!playerId) return;
		const key = `${type}-${id}`;
		submitting[key] = true;
		try {
			const existingReason = type === 'training' ? getTrainingReason(id, trainingAttendance) : getMatchReason(id, matchAttendance);
			const data: any = { player: playerId, status, reason: reason !== undefined ? reason : existingReason };
			if (type === 'training') data.training = id;
			else data.match = id;
			const result = await setPlayerAttendance(data);
			if (type === 'training') {
				const idx = trainingAttendance.findIndex(a => a.training === id);
				if (idx >= 0) trainingAttendance[idx] = result as TrainingAttendance;
				else trainingAttendance = [...trainingAttendance, result as TrainingAttendance];
			} else {
				const idx = matchAttendance.findIndex(a => a.match === id);
				if (idx >= 0) matchAttendance[idx] = result as MatchAttendance;
				else matchAttendance = [...matchAttendance, result as MatchAttendance];
			}
		} catch (e) {
			console.error('Failed to submit attendance:', e);
		} finally {
			submitting[key] = false;
			submitting = submitting; // trigger reactivity
		}
	}

	$: visibleTrainings = showAllTrainings ? trainings : trainings.slice(0, 1);
	$: visibleMatches = showAllMatches ? matches : matches.slice(0, 1);
</script>

<svelte:head>
	<title>SetBaas - Mijn Dashboard</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if !$linkedPlayer}
	<div class="card text-center py-12">
		<p class="text-4xl mb-3">👋</p>
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Welkom bij SetBaas</h2>
		<p class="text-gray-500 dark:text-gray-400 mt-2">Je account is nog niet gekoppeld aan een spelersprofiel.<br/>Neem contact op met je coach.</p>
	</div>
{:else}
	<div class="space-y-6">
		<!-- Welcome -->
		<div class="card py-4 text-center">
			<p class="text-lg font-bold text-gray-800 dark:text-gray-200">
				👋 Hoi {$linkedPlayer.name}!
			</p>
			<p class="text-sm text-gray-500 dark:text-gray-400">Geef je aanwezigheid op voor trainingen en wedstrijden.</p>
		</div>

		<!-- Pending Questionnaires -->
		{#if pendingQuestionnaires.length > 0}
			<a href="{base}/inbox" class="card flex items-center justify-between gap-3 bg-primary-50 dark:bg-primary-900/20 border-2 border-primary-300 dark:border-primary-700 hover:shadow-md transition-shadow">
				<div>
					<p class="font-semibold text-gray-800 dark:text-gray-200">📋 {pendingQuestionnaires.length} nieuwe vragenlijst{pendingQuestionnaires.length === 1 ? '' : 'en'}</p>
					<p class="text-sm text-gray-500 dark:text-gray-400">Bekijk je Inbox om te beantwoorden</p>
				</div>
				<span class="text-primary-600 dark:text-primary-400 text-xl">→</span>
			</a>
		{/if}

		<!-- Upcoming Trainings -->
		<div>
			<div class="flex items-center justify-between mb-3">
				<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200">🏋️ Trainingen</h2>
				{#if trainings.length > 1}
					<button
						class="text-xs font-medium text-primary-600 hover:text-primary-800 dark:hover:text-primary-400"
						on:click={() => showAllTrainings = !showAllTrainings}
					>
						{showAllTrainings ? '▲ Toon alleen volgende' : `▼ Toon alle (${trainings.length})`}
					</button>
				{/if}
			</div>
			{#if trainings.length === 0}
				<p class="text-sm text-gray-400">Geen komende trainingen</p>
			{:else}
				<div class="space-y-3">
					{#each visibleTrainings as training}
						{@const current = getTrainingStatus(training.id, trainingAttendance)}
						{@const key = `training-${training.id}`}
						<div class="card py-3 px-4 space-y-2">
							{#if training.content}
								<div class="flex justify-end">
									<button
										class="text-xs font-medium text-primary-600 hover:text-primary-800 dark:hover:text-primary-400"
										on:click={() => lightboxTraining = training}
									>
										👁 Bekijken
									</button>
								</div>
							{/if}
							<AttendanceStatusSwitcher
								label={new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
								status={current}
								reason={getTrainingReason(training.id, trainingAttendance)}
								on:change={(e) => submitStatus('training', training.id, e.detail)}
								on:reason={(e) => submitStatus('training', training.id, current, e.detail)}
							/>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Upcoming Matches -->
		<div>
			<div class="flex items-center justify-between mb-3">
				<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200">🏐 Wedstrijden</h2>
				{#if matches.length > 1}
					<button
						class="text-xs font-medium text-primary-600 hover:text-primary-800 dark:hover:text-primary-400"
						on:click={() => showAllMatches = !showAllMatches}
					>
						{showAllMatches ? '▲ Toon alleen volgende' : `▼ Toon alle (${matches.length})`}
					</button>
				{/if}
			</div>
			{#if matches.length === 0}
				<p class="text-sm text-gray-400">Geen komende wedstrijden</p>
			{:else}
				<div class="space-y-3">
					{#each visibleMatches as match}
						{@const current = getMatchStatus(match.id, matchAttendance)}
						{@const key = `match-${match.id}`}
						<div class="card py-3 px-4 space-y-2">
							<AttendanceStatusSwitcher
								label={new Date(match.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
								sublabel={`vs ${match.opponent} (${match.home_away === 'home' ? 'Thuis' : 'Uit'})`}
								status={current}
								reason={getMatchReason(match.id, matchAttendance)}
								on:change={(e) => submitStatus('match', match.id, e.detail)}
								on:reason={(e) => submitStatus('match', match.id, current, e.detail)}
							/>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
{/if}

<!-- Training content lightbox -->
{#if lightboxTraining}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm" on:click={() => lightboxTraining = null}>
		<div class="bg-white dark:bg-gray-900 w-full h-full md:w-[90%] md:h-[90%] md:rounded-2xl shadow-2xl flex flex-col overflow-hidden" on:click|stopPropagation>
			<div class="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
				<h2 class="text-lg font-bold text-gray-800 dark:text-gray-100">
					{new Date(lightboxTraining.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
				</h2>
				<button class="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-500 hover:text-gray-800 dark:hover:text-gray-200 transition-colors text-xl" on:click={() => lightboxTraining = null}>
					✕
				</button>
			</div>
			<div class="flex-1 overflow-y-auto px-6 py-6 md:px-12 md:py-8">
				<div class="prose prose-lg dark:prose-invert max-w-none">
					{@html marked(lightboxTraining.content || '', { breaks: true })}
				</div>
			</div>
		</div>
	</div>
{/if}
