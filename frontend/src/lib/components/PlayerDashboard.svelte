<script lang="ts">
	import { onMount } from 'svelte';
	import { pb, getAvailabilityForPlayer, setAvailability } from '$lib/pocketbase';
	import { linkedPlayer } from '$lib/stores/role';
	import { selectedTeamId, selectedSeasonId, contextFilter } from '$lib/stores/context';
	import type { Training, Match, PlayerAvailability, AvailabilityStatus } from '$lib/types';

	let trainings: Training[] = [];
	let matches: Match[] = [];
	let availability: PlayerAvailability[] = [];
	let loading = true;
	let submitting: Record<string, boolean> = {};

	$: playerId = $linkedPlayer?.id;

	onMount(loadData);

	async function loadData() {
		if (!playerId) { loading = false; return; }
		try {
			const filter = contextFilter($selectedTeamId, $selectedSeasonId);
			const now = new Date().toISOString().slice(0, 10);

			const [t, m, a] = await Promise.all([
				pb.collection('trainings').getFullList<Training>({
					sort: 'date',
					filter: [filter, `date >= "${now}"`, 'status = "open"'].filter(Boolean).join(' && '),
				}),
				pb.collection('matches').getFullList<Match>({
					sort: 'date',
					filter: [filter, `date >= "${now}"`].filter(Boolean).join(' && '),
				}),
				getAvailabilityForPlayer(playerId),
			]);

			trainings = t.slice(0, 5);
			matches = m.slice(0, 5);
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
