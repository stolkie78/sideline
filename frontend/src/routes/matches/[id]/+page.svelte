<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { pb, getMatchAttendance, getPlayers } from '$lib/pocketbase';
	import type { Match, MatchAttendance, Player } from '$lib/types';
	import { ATTENDANCE_LABELS } from '$lib/types';

	let match: Match | null = null;
	let attendance: MatchAttendance[] = [];
	let allPlayers: Player[] = [];
	let loading = true;

	$: presentCount = attendance.filter(a => a.status === 'present').length;

	onMount(async () => {
		try {
			const [m, players] = await Promise.all([
				pb.collection('matches').getOne<Match>($page.params.id),
				getPlayers('status = "active"'),
			]);
			match = m;
			allPlayers = players;
			attendance = await getMatchAttendance(m.id);
		} catch (e) {
			match = null;
		}
		loading = false;
	});

	function formatDate(d: string) {
		if (!d) return '';
		return new Date(d).toLocaleDateString('nl-NL', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
	}
</script>

<svelte:head>
	<title>{match?.opponent || 'Wedstrijd'} - SetBaas</title>
</svelte:head>

{#if loading}
	<p class="text-center text-gray-500 py-8">Laden...</p>
{:else if !match}
	<p class="text-center text-gray-500 py-8">Wedstrijd niet gevonden</p>
{:else}
	<div class="max-w-2xl mx-auto space-y-6">
		<div class="flex justify-between items-center">
			<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
				{match.home_away === 'home' ? 'Thuis' : 'Uit'} vs {match.opponent}
			</h1>
			<a href="{base}/matches/{match.id}/edit" class="btn-primary text-sm">✏️ Bewerken</a>
		</div>

		<div class="card space-y-4">
			<!-- Aanwezigheid -->
			<div class="flex justify-between items-center">
				<h2 class="font-semibold text-gray-900 dark:text-gray-100">👥 Aanwezigheid</h2>
				<span class="text-sm font-medium {presentCount > 0 ? 'text-green-600' : 'text-gray-400'}">
					{presentCount}/{allPlayers.length} aanwezig
				</span>
			</div>
			{#if attendance.length === 0}
				<p class="text-sm text-gray-500 italic">Nog geen aanwezigheid geregistreerd.</p>
			{:else}
				<div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
					{#each attendance as att}
						{@const player = att.expand?.player}
						<div class="flex items-center gap-2 p-2 rounded-lg bg-gray-50 dark:bg-gray-800 text-sm">
							<span class="w-2 h-2 rounded-full {
								att.status === 'present' ? 'bg-green-500' :
								att.status === 'absent' ? 'bg-red-500' :
								att.status === 'sick' ? 'bg-yellow-500' : 'bg-orange-500'
							}"></span>
							<span class="text-gray-700 dark:text-gray-300 truncate">
								{player ? player.name : '...'}
							</span>
							<span class="text-xs text-gray-400 ml-auto">{ATTENDANCE_LABELS[att.status]}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<div class="card space-y-4">
			<div class="grid grid-cols-2 gap-4">
				<div>
					<span class="text-sm text-gray-500">Datum</span>
					<p class="font-medium text-gray-900 dark:text-gray-100">{formatDate(match.date)}</p>
				</div>
				<div>
					<span class="text-sm text-gray-500">Locatie</span>
					<p class="font-medium text-gray-900 dark:text-gray-100">{match.location || '—'}</p>
				</div>
			</div>

			{#if match.score_team !== undefined && match.score_team !== null}
				<div>
					<span class="text-sm text-gray-500">Uitslag</span>
					<p class="text-3xl font-bold {match.score_team > match.score_opponent ? 'text-green-600' : 'text-red-500'}">
						{match.score_team} – {match.score_opponent}
					</p>
				</div>
			{/if}

			{#if match.set_scores && match.set_scores.length > 0}
				<div>
					<span class="text-sm text-gray-500">Sets</span>
					<div class="flex gap-3 mt-1">
						{#each match.set_scores as set, i}
							<span class="px-3 py-1 rounded bg-gray-100 dark:bg-gray-700 text-sm font-mono">
								Set {i+1}: {set.team ?? '?'}–{set.opponent ?? '?'}
							</span>
						{/each}
					</div>
				</div>
			{/if}

			{#if match.notes}
				<div>
					<span class="text-sm text-gray-500">Notities</span>
					<p class="text-gray-800 dark:text-gray-200 whitespace-pre-wrap">{match.notes}</p>
				</div>
			{/if}
		</div>
	</div>
{/if}
