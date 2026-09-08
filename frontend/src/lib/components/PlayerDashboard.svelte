<script lang="ts">
	import { pb, getAvailabilityForPlayer, setAvailability } from '$lib/pocketbase';
	import { linkedPlayer, rolesLoaded } from '$lib/stores/role';
	import { selectedTeamId, selectedSeasonId, contextFilter } from '$lib/stores/context';
	import type { Training, Match, PlayerAvailability, AvailabilityStatus } from '$lib/types';
	import { marked } from 'marked';

	let trainings: Training[] = [];
	let matches: Match[] = [];
	let availability: PlayerAvailability[] = [];
	let loading = true;
	let submitting: Record<string, boolean> = {};
	let lightboxTraining: Training | null = null;
	let hasLoaded = false;

	$: playerId = $linkedPlayer?.id;

	// Wait for the (async) user-role/linked-player lookup to finish before
	// deciding what to show. Loading immediately on mount would race with
	// `loadUserRoles()` in +layout.svelte — `$linkedPlayer` is still null at
	// that point, causing an early bail-out with a permanently empty
	// dashboard even though the player IS linked, just not resolved yet.
	$: if ($rolesLoaded && !hasLoaded) {
		hasLoaded = true;
		if (playerId) {
			loadData();
		} else {
			loading = false;
		}
	}

	async function loadData() {
		if (!playerId) { loading = false; return; }
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			const now = new Date().toISOString().slice(0, 10);

			const [t, m, a] = await Promise.all([
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
				getAvailabilityForPlayer(playerId),
			]);

			trainings = t.slice(0, 4);
			matches = m.slice(0, 4);
			availability = a;
		} catch (e) {
			console.error('Failed to load player dashboard:', e);
		} finally {
			loading = false;
		}
	}

	function getTrainingStatus(trainingId: string): AvailabilityStatus | null {
		const a = availability.find(a => a.training === trainingId);
		return a?.status || null;
	}

	function getMatchStatus(matchId: string): AvailabilityStatus | null {
		const a = availability.find(a => a.match === matchId);
		return a?.status || null;
	}

	async function submitAvailability(type: 'training' | 'match', id: string, status: AvailabilityStatus) {
		if (!playerId) return;
		const key = `${type}-${id}`;
		submitting[key] = true;
		try {
			const data: any = { player: playerId, status };
			if (type === 'training') data.training = id;
			else data.match = id;
			const result = await setAvailability(data);
			// Update local availability
			const idx = availability.findIndex(a => type === 'training' ? a.training === id : a.match === id);
			if (idx >= 0) availability[idx] = result;
			else availability = [...availability, result];
		} catch (e) {
			console.error('Failed to submit availability:', e);
		} finally {
			submitting[key] = false;
			submitting = submitting; // trigger reactivity
		}
	}

	const STATUS_COLORS: Record<AvailabilityStatus, string> = {
		available: 'bg-green-500',
		unavailable: 'bg-red-500',
		uncertain: 'bg-yellow-500',
	};

	const STATUS_LABELS: Record<AvailabilityStatus, string> = {
		available: '✓ Beschikbaar',
		unavailable: '✗ Niet beschikbaar',
		uncertain: '? Onzeker',
	};

	const availabilityOptions: AvailabilityStatus[] = ['available', 'unavailable', 'uncertain'];
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
			<p class="text-sm text-gray-500 dark:text-gray-400">Geef je beschikbaarheid op voor trainingen en wedstrijden.</p>
		</div>

		<!-- Upcoming Trainings -->
		<div>
			<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">🏋️ Trainingen</h2>
			{#if trainings.length === 0}
				<p class="text-sm text-gray-400">Geen komende trainingen</p>
			{:else}
				<div class="space-y-3">
					{#each trainings as training}
						{@const current = getTrainingStatus(training.id)}
						{@const key = `training-${training.id}`}
						<div class="card py-3 px-4">
							<div class="flex items-center justify-between mb-2">
								<div>
									<span class="font-medium text-gray-800 dark:text-gray-200">
										{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
									</span>
									{#if current}
										<span class="ml-2 inline-block w-2 h-2 rounded-full {STATUS_COLORS[current]}"></span>
									{/if}
								</div>
								{#if training.content}
									<button
										class="text-xs font-medium text-primary-600 hover:text-primary-800 dark:hover:text-primary-400"
										on:click={() => lightboxTraining = training}
									>
										👁 Bekijken
									</button>
								{/if}
							</div>
							<div class="flex gap-2">
								{#each availabilityOptions as status}
									<button
										class="flex-1 text-xs py-2 px-2 rounded-lg font-medium transition-all
											{current === status
												? status === 'available' ? 'bg-green-600 text-white' : status === 'unavailable' ? 'bg-red-600 text-white' : 'bg-yellow-500 text-white'
												: 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'}"
										disabled={submitting[key]}
										on:click={() => submitAvailability('training', training.id, status)}
									>
										{STATUS_LABELS[status]}
									</button>
								{/each}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Upcoming Matches -->
		<div>
			<h2 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">🏐 Wedstrijden</h2>
			{#if matches.length === 0}
				<p class="text-sm text-gray-400">Geen komende wedstrijden</p>
			{:else}
				<div class="space-y-3">
					{#each matches as match}
						{@const current = getMatchStatus(match.id)}
						{@const key = `match-${match.id}`}
						<div class="card py-3 px-4">
							<div class="flex items-center justify-between mb-2">
								<div>
									<span class="font-medium text-gray-800 dark:text-gray-200">
										{new Date(match.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
									</span>
									<span class="text-sm text-gray-500 dark:text-gray-400 ml-2">
										vs {match.opponent}
										<span class="text-xs">({match.home_away === 'home' ? 'Thuis' : 'Uit'})</span>
									</span>
									{#if current}
										<span class="ml-2 inline-block w-2 h-2 rounded-full {STATUS_COLORS[current]}"></span>
									{/if}
								</div>
							</div>
							<div class="flex gap-2">
								{#each availabilityOptions as status}
									<button
										class="flex-1 text-xs py-2 px-2 rounded-lg font-medium transition-all
											{current === status
												? status === 'available' ? 'bg-green-600 text-white' : status === 'unavailable' ? 'bg-red-600 text-white' : 'bg-yellow-500 text-white'
												: 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'}"
										disabled={submitting[key]}
										on:click={() => submitAvailability('match', match.id, status)}
									>
										{STATUS_LABELS[status]}
									</button>
								{/each}
							</div>
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
