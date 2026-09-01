<script lang="ts">
	import { base } from '$app/paths';
	import { getPlayers, getTrainings, getMatches, updateTraining } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import type { Player, Training, Match, TrainingAttendance } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';
	import { contextFilter } from '$lib/stores/context';
	import { userRole } from '$lib/stores/role';
	import { marked } from 'marked';
	import PlayerDashboard from '$lib/components/PlayerDashboard.svelte';
	import { browser } from '$app/environment';

	let players: Player[] = [];
	let trainings: Training[] = [];
	let matches: Match[] = [];
	let loading = true;
	let expandedTraining: string | null = null;

	// Attendance per training: { trainingId: { present: N, total: N } }
	let attendanceCounts: Record<string, { present: number; total: number }> = {};

	function printTraining(training: Training) {
		const date = new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
		const html = `<!DOCTYPE html><html><head><title>Training ${date}</title><style>body{font-family:sans-serif;max-width:700px;margin:0 auto;padding:20px}h1{font-size:1.3em;border-bottom:2px solid #2563eb;padding-bottom:8px}h2{font-size:1.1em;margin-top:16px}</style></head><body><h1>🏐 Training ${date}</h1>${marked(training.content || '', { breaks: true })}</body></html>`;
		const w = window.open('', '_blank');
		if (w) { w.document.write(html); w.document.close(); w.print(); }
	}

	// Upcoming items (future dates)
	$: upcomingMatches = matches
		.filter(m => new Date(m.date) >= new Date())
		.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
		.slice(0, 2);

	$: activeTraining = trainings.find(t => t.status === 'active') || null;

	$: openTrainings = trainings
		.filter(t => t.status === 'open')
		.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
		.slice(0, 5);

	$: closedTrainingCount = trainings.filter(t => t.status === 'closed').length;

	// Reactive: reload when context stores change (fixes empty data after login)
	$: if (browser) loadDashboard($selectedTeamId, $selectedSeasonId);

	async function loadDashboard(_teamId: string | null, _seasonId: string | null) {
		try {
			const filter = contextFilter(_teamId, _seasonId);
			[players, trainings, matches] = await Promise.all([
				getPlayers('status = "active"'),
				pb.collection('trainings').getFullList<Training>({ sort: '-date', filter: filter || undefined }),
				pb.collection('matches').getFullList<Match>({ sort: '-date', filter: filter || undefined }),
			]);

			// Load attendance counts for all trainings
			attendanceCounts = {};
			const allAttendance = await pb.collection('training_attendance').getFullList<TrainingAttendance>({ fields: 'training,status' });
			for (const a of allAttendance) {
				if (!attendanceCounts[a.training]) attendanceCounts[a.training] = { present: 0, total: 0 };
				attendanceCounts[a.training].total++;
				if (a.status === 'present') attendanceCounts[a.training].present++;
			}
			attendanceCounts = attendanceCounts;
		} catch (e) {
			console.error('Failed to load dashboard data:', e);
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>SetBaas - Dashboard</title>
</svelte:head>

{#if $userRole === 'player'}
	<PlayerDashboard />
{:else if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<div class="space-y-6">
		<!-- Quick Stats -->
		<div class="grid grid-cols-3 gap-3">
			<div class="card text-center py-6">
				<div class="text-3xl md:text-4xl font-bold text-primary-600">{players.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Spelers</div>
			</div>
			<div class="card text-center py-6">
				<div class="text-3xl md:text-4xl font-bold text-green-600">{trainings.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Trainingen</div>
			</div>
			<div class="card text-center py-6">
				<div class="text-3xl md:text-4xl font-bold text-amber-600">{matches.length}</div>
				<div class="text-sm text-gray-500 dark:text-gray-400 mt-1">Wedstrijden</div>
			</div>
		</div>

		<!-- Quick Actions -->
		<div class="grid grid-cols-2 gap-3">
			<a href="{base}/trainings/new" class="btn-primary text-center text-base py-4">
				Nieuwe training
			</a>
			<a href="{base}/matches/new" class="btn-primary text-center text-base py-4">
				Nieuwe wedstrijd
			</a>
		</div>

		<!-- Trainingen + Wedstrijden: side by side on tablet+ -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6">

		<!-- Trainingen -->
		{#if activeTraining || openTrainings.length > 0 || closedTrainingCount > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">🏋️ Trainingen</h2>
					<a href="{base}/trainings" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>
				<div class="space-y-3">
					<!-- Actieve training -->
					{#if activeTraining}
						{@const att = attendanceCounts[activeTraining.id]}
						<div class="rounded-xl border-2 border-green-500 bg-green-50 dark:bg-green-900/20 p-4 relative overflow-hidden">
							<div class="absolute top-0 right-0 px-2 py-0.5 bg-green-500 text-white text-[10px] font-bold rounded-bl-lg">LIVE</div>
							<a href="{base}/trainings/{activeTraining.id}" class="block">
								<div class="flex justify-between items-center">
									<span class="text-sm font-semibold text-green-700 dark:text-green-400">
										▶️ {new Date(activeTraining.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
										— {new Date(activeTraining.date).toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit', hour12: false })}
									</span>
									{#if att}
										<span class="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-300">👥 {att.present}/{att.total}</span>
									{/if}
								</div>
							</a>
							<div class="flex gap-2 mt-2">
								<a href="{base}/trainings/{activeTraining.id}" class="btn-secondary text-xs flex-1 text-center !py-2">📋 Bekijk</a>
								<a href="{base}/trainings/{activeTraining.id}/edit" class="btn-secondary text-xs flex-1 text-center !py-2">✏️ Bewerken</a>
								<button
									on:click={async () => { await updateTraining(activeTraining.id, { status: 'closed' }); loadDashboard($selectedTeamId, $selectedSeasonId); }}
									class="text-xs flex-1 text-center py-2 px-3 rounded-xl font-semibold bg-red-100 text-red-700 hover:bg-red-200 dark:bg-red-900/30 dark:text-red-400 transition-colors"
								>⏹️ Afronden</button>
							</div>
						</div>
					{/if}

					<!-- Geplande trainingen -->
					{#each openTrainings as training, i}
						{@const att = attendanceCounts[training.id]}
						{@const isNext = i === 0}
						<div class="rounded-xl p-4 {isNext ? 'border-2 border-primary-500 dark:border-primary-400 bg-primary-50/50 dark:bg-primary-900/15 ring-1 ring-primary-200 dark:ring-primary-800' : 'border border-blue-200 dark:border-blue-800 bg-blue-50/50 dark:bg-blue-900/10'}">
							<div class="flex justify-between items-center">
								<a href="{base}/trainings/{training.id}" class="text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-primary-600">
									{#if isNext}<span class="text-xs font-bold text-primary-600 dark:text-primary-400 mr-1">VOLGENDE →</span>{/if}
									{new Date(training.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}
								</a>
								<div class="flex items-center gap-2">
									{#if att}
										<span class="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300">👥 {att.present}/{att.total}</span>
									{/if}
									<span class="text-xs px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300">Gepland</span>
									<a href="{base}/trainings/{training.id}/checkin" class="text-xs text-green-600 hover:underline" title="Start Training">▶️</a>
									<a href="{base}/trainings/{training.id}/edit" class="text-xs text-primary-600 hover:underline">✏️</a>
								</div>
							</div>
							{#if training.content}
								<button on:click={() => expandedTraining = expandedTraining === training.id ? null : training.id}
									class="text-xs text-primary-600 hover:text-primary-800 mt-1">
									{expandedTraining === training.id ? '▼ Inklappen' : '▶ Bekijken'}
								</button>
								{#if expandedTraining === training.id}
									<div class="mt-2 p-3 rounded bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 prose prose-sm dark:prose-invert max-w-none">
										{@html marked(training.content, { breaks: true })}
									</div>
									<button on:click={() => printTraining(training)} class="text-xs text-gray-500 hover:text-primary-600 mt-1">📄 Exporteer als PDF</button>
								{/if}
							{/if}
						</div>
					{/each}

					<!-- Link naar afgeronde trainingen -->
					{#if closedTrainingCount > 0}
						<a href="{base}/trainings" class="block text-sm text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400 pt-1">
							✅ Afgerond ({closedTrainingCount}) →
						</a>
					{/if}
				</div>
			</div>
		{/if}

		<!-- Wedstrijden -->
		{#if upcomingMatches.length > 0 || matches.filter(m => (m.score_team || m.score_opponent) && new Date(m.date) < new Date()).length > 0}
			<div class="card">
				<div class="flex justify-between items-center mb-4">
					<h2 class="font-semibold text-gray-900 dark:text-gray-100">🏐 Wedstrijden</h2>
					<a href="{base}/matches" class="text-sm text-primary-600 hover:underline">Alles</a>
				</div>

				<!-- Komende wedstrijden -->
				{#if upcomingMatches.length > 0}
					<h3 class="text-xs font-bold uppercase text-gray-400 dark:text-gray-500 mb-2">📅 Komend</h3>
					<div class="space-y-3 mb-4">
						{#each upcomingMatches as match, i}
							{@const isNext = i === 0}
							<a href="{base}/matches/{match.id}" class="block p-3 rounded-lg transition {isNext ? 'bg-primary-50 dark:bg-primary-900/15 border-2 border-primary-500 dark:border-primary-400 ring-1 ring-primary-200 dark:ring-primary-800' : 'bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/30 border border-blue-200 dark:border-blue-800'}">
								<div class="flex justify-between items-start">
									<div>
										{#if isNext}<span class="text-xs font-bold text-primary-600 dark:text-primary-400 mr-1">VOLGENDE →</span>{/if}
										<span class="text-sm font-medium text-gray-800 dark:text-gray-200">{match.opponent}</span>
										<span class="text-xs text-gray-400 ml-1">{match.home_away === 'home' ? '(Thuis)' : '(Uit)'}</span>
									</div>
								</div>
								<div class="text-xs text-gray-500 dark:text-gray-400 mt-1 space-x-3">
									<span>📆 {new Date(match.date).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short' })}</span>
									<span>⏰ {new Date(match.date).toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit', hour12: false })}</span>
									{#if match.location}
										<span>📍 {match.location}</span>
									{/if}
								</div>
							</a>
						{/each}
					</div>
				{/if}

				<!-- Uitslagen -->
				{#if matches.filter(m => (m.score_team || m.score_opponent) && new Date(m.date) < new Date()).length > 0}
					<h3 class="text-xs font-bold uppercase text-gray-400 dark:text-gray-500 mb-2">🏆 Uitslagen</h3>
					<div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 p-3 space-y-1">
						{#each matches.filter(m => (m.score_team || m.score_opponent) && new Date(m.date) < new Date()).slice(0, 5) as match}
							{@const won = match.score_team > match.score_opponent}
							<div class="flex justify-between items-center py-2 border-b border-gray-200 dark:border-gray-700 last:border-0">
								<div>
									<span class="text-sm font-medium text-gray-800 dark:text-gray-200">{match.opponent}</span>
									<span class="text-xs text-gray-400 ml-1.5">{match.home_away === 'home' ? 'Thuis' : 'Uit'}</span>
								</div>
								<span class="text-sm font-bold {won ? 'text-green-600' : 'text-red-500'}">
									{match.score_team}–{match.score_opponent}
								</span>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
		</div><!-- end grid -->
	</div>
{/if}
