<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { pb, getContextPlayers, updateMatch, getMatchPlayerStats, createMatchPlayerStats, updateMatchPlayerStats, deleteMatchPlayerStats, getTeamAccessForTeam } from '$lib/pocketbase';
	import type { Player, PlayerPosition, SetScore, Match, MatchPlayerStats, MatchStatus } from '$lib/types';
	import { getMatchStatus } from '$lib/utils/match';
	import type { TeamAccess } from '$lib/pocketbase';
	import { POSITION_LABELS } from '$lib/types';
	import { selectedTeamId, selectedSeasonId } from '$lib/stores/context';

	$: returnTo = $page.url.searchParams.get('returnTo') || `${base}/matches`;

	let players: Player[] = [];
	let match: Match | null = null;
	let existingStats: MatchPlayerStats[] = [];
	let loading = true;
	let saving = false;

	// Match form
	let matchDate = '';
	let matchTime = '19:30';
	let opponent = '';
	let homeAway: 'home' | 'away' = 'home';
	let matchStatus: MatchStatus = 'open';
	let generalNotes = '';

	// Coaches
	let coachMembers: TeamAccess[] = [];
	let selectedCoaches: string[] = [];

	// Set scores
	let setScores: SetScore[] = [];

	function addSet() {
		if (setScores.length < 5) {
			setScores = [...setScores, { team: null, opponent: null }];
			for (const pid of lineup) {
				if (!perSetData[pid]) perSetData[pid] = {};
				perSetData[pid][setScores.length] = { position: '', points: 0 };
			}
			perSetData = perSetData;
		}
	}

	function removeSet() {
		if (setScores.length > 1) {
			const removing = setScores.length;
			setScores = setScores.slice(0, -1);
			for (const pid of lineup) {
				if (perSetData[pid]) delete perSetData[pid][removing];
			}
			perSetData = perSetData;
			if (activeTab > setScores.length) activeTab = setScores.length;
		}
	}

	// Set scores are stored home-first (scoresheet order): scoreTeam = home sets, scoreOpponent = away sets.
	$: scoreTeam = setScores.filter(s => s.team !== null && s.opponent !== null && (s.team ?? 0) > (s.opponent ?? 0)).length;
	$: scoreOpponent = setScores.filter(s => s.team !== null && s.opponent !== null && (s.opponent ?? 0) > (s.team ?? 0)).length;
	$: ourSets = homeAway === 'home' ? scoreTeam : scoreOpponent;
	$: theirSets = homeAway === 'home' ? scoreOpponent : scoreTeam;
	$: homeLabel = homeAway === 'home' ? 'Wij' : (opponent || 'Tegenstander');
	$: awayLabel = homeAway === 'home' ? (opponent || 'Tegenstander') : 'Wij';

	let activeTab = 0;
	let lineup: string[] = [];

	function toggleLineup(playerId: string) {
		if (lineup.includes(playerId)) {
			lineup = lineup.filter(id => id !== playerId);
		} else {
			lineup = [...lineup, playerId];
			if (!perSetData[playerId]) perSetData[playerId] = {};
			for (let s = 1; s <= setScores.length; s++) {
				if (!perSetData[playerId][s]) {
					const defaultPos = (players.find(p => p.id === playerId)?.position || [])[0] || '';
					perSetData[playerId][s] = { position: defaultPos, points: 0 };
				}
			}
			perSetData = perSetData;
		}
	}

	let perSetData: Record<string, Record<number, { position: string; points: number }>> = {};
	let playerNotes: Record<string, string> = {};

	const allPositions = Object.entries(POSITION_LABELS) as [PlayerPosition, string][];

	onMount(async () => {
		try {
			const id = $page.params.id;
			match = await pb.collection('matches').getOne<Match>(id, { expand: 'created_by' });

			matchDate = match.date.slice(0, 10);
			matchTime = match.date.slice(11, 16) || '19:30';
			opponent = match.opponent;
			homeAway = (match.home_away as 'home' | 'away') || 'home';
			matchStatus = getMatchStatus(match);
			generalNotes = match.general_notes || '';
			selectedCoaches = Array.isArray(match.coach) ? match.coach : match.coach ? [match.coach] : [];

			// Load coaches
			if ($selectedTeamId) {
				try {
					const allAccess = await getTeamAccessForTeam($selectedTeamId);
					coachMembers = allAccess.filter(a => a.is_trainer);
				} catch (e) { /* ignore */ }
			}

			setScores = match.set_scores && Array.isArray(match.set_scores) && match.set_scores.length > 0
				? [...match.set_scores]
				: [{ team: null, opponent: null }, { team: null, opponent: null }, { team: null, opponent: null }];

			players = await getContextPlayers($selectedTeamId, $selectedSeasonId, { activeOnly: true });

			// Load existing stats
			existingStats = await getMatchPlayerStats(id);

			// Rebuild lineup and perSetData from existing stats
			lineup = existingStats.map(s => s.player);
			for (const p of players) {
				playerNotes[p.id] = '';
				perSetData[p.id] = {};
				const defaultPos = (p.position || [])[0] || '';
				for (let s = 1; s <= setScores.length; s++) {
					perSetData[p.id][s] = { position: defaultPos, points: 0 };
				}
			}

			// Populate from existing stats
			for (const stat of existingStats) {
				if (stat.notes) playerNotes[stat.player] = stat.notes;
				if (stat.position_points && Array.isArray(stat.position_points)) {
					for (const pp of stat.position_points) {
						if (!perSetData[stat.player]) perSetData[stat.player] = {};
						perSetData[stat.player][pp.set] = { position: pp.position, points: pp.points };
					}
				}
			}
			perSetData = perSetData;
		} catch (e) {
			console.error('Failed to load match:', e);
		} finally {
			loading = false;
		}
	});

	function setFullSet(playerId: string, setNum: number) {
		const sd = perSetData[playerId][setNum];
		sd.points = sd.points === 25 ? 0 : 25;
		perSetData = perSetData;
	}

	function playerTotal(pid: string): number {
		const data = perSetData[pid] || {};
		return Object.values(data).reduce((s, d) => s + (d.points || 0), 0);
	}

	async function handleSubmit() {
		if (!opponent.trim() || !match) return;
		saving = true;
		try {
			const filledSets = setScores.filter(s => s.team !== null || s.opponent !== null);

			await updateMatch(match.id, {
				date: new Date(`${matchDate}T${matchTime}`).toISOString(),
				opponent: opponent.trim(),
				status: matchStatus,
				home_away: homeAway,
				score_team: scoreTeam || undefined,
				score_opponent: scoreOpponent || undefined,
				set_scores: filledSets.length > 0 ? filledSets : undefined,
				general_notes: generalNotes || undefined,
				coach: selectedCoaches,
			});

			// Delete old stats and recreate
			for (const stat of existingStats) {
				await deleteMatchPlayerStats(stat.id);
			}

			const promises = lineup.map(pid => {
				const setData = perSetData[pid] || {};
				const posPoints: { set: number; position: string; points: number }[] = [];

				for (const [setStr, data] of Object.entries(setData)) {
					if (data.position && data.points > 0) {
						posPoints.push({
							set: parseInt(setStr),
							position: data.position,
							points: data.points,
						});
					}
				}

				return createMatchPlayerStats({
					match: match!.id,
					player: pid,
					position_points: posPoints.length > 0 ? posPoints : undefined,
					notes: playerNotes[pid] || undefined,
				});
			});
			await Promise.all(promises);

			goto(returnTo);
		} catch (e) {
			console.error('Failed to update match:', e);
			alert('Fout bij bijwerken wedstrijd');
		} finally {
			saving = false;
		}
	}

	async function handleDelete() {
		if (!match) return;
		if (!confirm('Weet je zeker dat je deze wedstrijd wilt verwijderen?')) return;
		try {
			for (const stat of existingStats) {
				await deleteMatchPlayerStats(stat.id);
			}
			await pb.collection('matches').delete(match.id);
			goto(returnTo);
		} catch (e) {
			console.error('Failed to delete match:', e);
			alert('Fout bij verwijderen');
		}
	}
</script>

<svelte:head>
	<title>Bewerk Wedstrijd - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if match}
	<form class="space-y-4" on:submit|preventDefault={handleSubmit}>
		<div class="flex justify-between items-center">
			<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Bewerk Wedstrijd</h2>
			<button type="button" class="text-red-500 hover:text-red-700 text-sm font-semibold" on:click={handleDelete}>
				🗑️ Verwijderen
			</button>
		</div>

		{#if match?.expand?.created_by}
			<p class="text-xs text-gray-400 dark:text-gray-500">Aangemaakt door {match.expand.created_by.name || match.expand.created_by.email}</p>
		{/if}

		<!-- Match details -->
		<div class="card space-y-3">
			<div>
				<label class="label" for="opponent">Tegenstander *</label>
				<input id="opponent" class="input" type="text" bind:value={opponent} required placeholder="Naam tegenstander" />
			</div>

			<div class="grid grid-cols-2 gap-3">
				<div>
					<label class="label" for="date">Datum & Tijd</label>
					<div class="flex gap-2">
						<input id="date" class="input flex-1" type="date" bind:value={matchDate} required />
						<input class="input w-28" type="time" bind:value={matchTime} required />
					</div>
				</div>
				<div>
					<label class="label">Locatie</label>
					<div class="flex rounded-xl overflow-hidden border border-gray-300 dark:border-gray-600">
						<button type="button"
							class="flex-1 py-3 text-sm font-semibold transition-colors {homeAway === 'home' ? 'bg-primary-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
							on:click={() => (homeAway = 'home')}>Thuis</button>
						<button type="button"
							class="flex-1 py-3 text-sm font-semibold transition-colors {homeAway === 'away' ? 'bg-primary-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
							on:click={() => (homeAway = 'away')}>Uit</button>
					</div>
				</div>
			</div>

			<!-- Coach checkboxes -->
			{#if coachMembers.length > 0}
				<div>
					<label class="label">Coach(es)</label>
					<div class="flex flex-wrap gap-3">
						{#each coachMembers as tm}
							<label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300 cursor-pointer">
								<input type="checkbox" class="rounded border-gray-300 dark:border-gray-600 text-primary-600 focus:ring-primary-500"
									checked={selectedCoaches.includes(tm.user)}
									on:change={(e) => {
										if (e.currentTarget.checked) selectedCoaches = [...selectedCoaches, tm.user];
										else selectedCoaches = selectedCoaches.filter(id => id !== tm.user);
									}} />
								{tm.expand?.user?.name || tm.expand?.user?.email}
							</label>
						{/each}
					</div>
				</div>
			{/if}

			<!-- Set Scores -->
			<div>
				<label class="label">Setstanden <span class="font-normal text-xs text-gray-500">(thuisteam eerst)</span></label>
				<div class="flex items-center gap-2 mb-1 text-xs text-gray-500 dark:text-gray-400">
					<span class="w-10"></span>
					<span class="w-14 text-center truncate" title={homeLabel}>{homeLabel}</span>
					<span class="w-3"></span>
					<span class="w-14 text-center truncate" title={awayLabel}>{awayLabel}</span>
				</div>
				<div class="space-y-2">
					{#each setScores as set, i}
						<div class="flex items-center gap-2">
							<span class="text-xs text-gray-500 dark:text-gray-400 w-10">Set {i + 1}</span>
							<input type="number" min="0" max="50"
								class="w-14 text-center rounded-lg border border-gray-200 dark:border-gray-600 dark:bg-gray-800 py-1.5 text-sm font-bold"
								bind:value={setScores[i].team} placeholder="—" />
							<span class="text-gray-400 font-bold text-sm">-</span>
							<input type="number" min="0" max="50"
								class="w-14 text-center rounded-lg border border-gray-200 dark:border-gray-600 dark:bg-gray-800 py-1.5 text-sm font-bold"
								bind:value={setScores[i].opponent} placeholder="—" />
						</div>
					{/each}
				</div>
				<div class="flex gap-2 mt-2">
					{#if setScores.length < 5}
						<button type="button" class="text-xs text-primary-600 hover:underline" on:click={addSet}>+ Set</button>
					{/if}
					{#if setScores.length > 1}
						<button type="button" class="text-xs text-red-500 hover:underline" on:click={removeSet}>− Set</button>
					{/if}
				</div>
				{#if scoreTeam > 0 || scoreOpponent > 0}
					<div class="text-sm mt-1">
						Einduitslag: <span class="font-bold text-lg {ourSets > theirSets ? 'text-green-600' : ourSets < theirSets ? 'text-red-600' : ''}">{ourSets} - {theirSets}</span>
						<span class="text-xs text-gray-500">({ourSets > theirSets ? 'gewonnen' : ourSets < theirSets ? 'verloren' : 'gelijk'} · formulier: {scoreTeam} - {scoreOpponent})</span>
					</div>
				{/if}
			</div>

			<div>
				<label class="label" for="notes">Opmerkingen</label>
				<textarea id="notes" class="input" rows="2" bind:value={generalNotes} placeholder="Wedstrijdnotities..."></textarea>
			</div>
		</div>

		<!-- Tabs: Opstelling + per Set -->
		<div class="card p-0 overflow-hidden">
			<div class="flex overflow-x-auto border-b border-gray-200 dark:border-gray-700">
				<button type="button"
					class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
						activeTab === 0
							? 'text-primary-600 border-b-2 border-primary-600 bg-primary-50 dark:bg-primary-900/20'
							: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
					}"
					on:click={() => (activeTab = 0)}>
					Opstelling
				</button>
				{#each setScores as _, i}
					<button type="button"
						class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
							activeTab === i + 1
								? 'text-primary-600 border-b-2 border-primary-600 bg-primary-50 dark:bg-primary-900/20'
								: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
						}"
						on:click={() => (activeTab = i + 1)}>
						Set {i + 1}
					</button>
				{/each}
			</div>

			<div class="p-4">
				{#if activeTab === 0}
					<div class="space-y-2">
						<p class="text-xs text-gray-500 dark:text-gray-400 mb-2">Selecteer spelers die meespelen:</p>
						{#each players as player (player.id)}
							{@const inLineup = lineup.includes(player.id)}
							<div class="flex items-center gap-3 py-1.5">
								<button type="button"
									class="touch-target w-14 py-2 rounded-lg text-xs font-semibold {
										inLineup
											? 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400'
											: 'bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400'
									}"
									on:click={() => toggleLineup(player.id)}>
									{inLineup ? '✓ Ja' : '✕ Nee'}
								</button>
								<span class="flex-1 font-medium text-sm truncate">{player.name}</span>
								<span class="text-xs text-gray-400 dark:text-gray-500">
									{(player.position || []).map(p => POSITION_LABELS[p]).join(', ')}
								</span>
							</div>
						{/each}
					</div>
				{:else}
					{@const setNum = activeTab}
					<div class="space-y-2">
						<p class="text-xs text-gray-500 dark:text-gray-400 mb-1">
							Set {setNum} — positie en punten per speler:
						</p>
						{#each lineup as pid (pid)}
							{@const player = players.find(p => p.id === pid)}
							{@const sd = perSetData[pid]?.[setNum]}
							{#if player && sd}
								<div class="border border-gray-100 dark:border-gray-700 rounded-xl p-3">
									<div class="flex items-center gap-2 mb-2">
										<span class="font-medium text-sm flex-1 truncate">{player.name}</span>
										<span class="text-xs font-bold text-primary-600">{playerTotal(pid)} pt totaal</span>
									</div>
									<div class="flex flex-wrap gap-1.5 mb-2">
										{#each allPositions as [value, label]}
											<button type="button"
												class="px-2 py-1 rounded-lg text-xs font-medium transition-colors {
													sd.position === value
														? 'bg-primary-600 text-white'
														: 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300'
												}"
												on:click={() => {
													perSetData[pid][setNum].position = sd.position === value ? '' : value;
													perSetData = perSetData;
												}}>
												{label}
											</button>
										{/each}
									</div>
									{#if sd.position}
										<div class="flex items-center gap-2 bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-1.5">
											<span class="text-xs text-gray-500 dark:text-gray-400 flex-1">
												Punten als {POSITION_LABELS[sd.position] || sd.position}:
											</span>
											<label class="flex items-center gap-1 cursor-pointer">
												<input type="checkbox" checked={sd.points === 25}
													on:change={() => setFullSet(pid, setNum)}
													class="w-4 h-4 rounded border-gray-300 dark:border-gray-600 text-primary-600 dark:bg-gray-700" />
												<span class="text-[10px] text-gray-400">set</span>
											</label>
											<input type="number" min="0" max="100"
												class="w-16 text-center rounded-lg border border-gray-200 dark:border-gray-600 dark:bg-gray-700 py-1 text-sm font-bold"
												bind:value={perSetData[pid][setNum].points} />
											<span class="text-xs text-gray-400">pt</span>
										</div>
									{/if}
								</div>
							{/if}
						{/each}
						{#if lineup.length === 0}
							<p class="text-sm text-gray-400 text-center py-4">
								Ga eerst naar het Opstelling-tabje om spelers te selecteren.
							</p>
						{/if}
					</div>
				{/if}
			</div>
		</div>

		<div class="card space-y-2">
			<span class="label">Status wedstrijd</span>
			<div class="flex rounded-xl overflow-hidden border border-gray-200 dark:border-gray-600">
				<button type="button"
					class="flex-1 py-3 text-sm font-semibold transition-colors {matchStatus === 'open' ? 'bg-gray-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
					on:click={() => (matchStatus = 'open')}>Open</button>
				<button type="button"
					class="flex-1 py-3 text-sm font-semibold transition-colors {matchStatus === 'played' ? 'bg-green-600 text-white' : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'}"
					on:click={() => (matchStatus = 'played')}>Gespeeld</button>
			</div>
			<p class="text-xs text-gray-500 dark:text-gray-400">
				Zet op 'Gespeeld' zodra de uitslag compleet is; de wedstrijd verdwijnt dan van het dashboard.
			</p>
		</div>

		<button type="submit" class="btn-primary w-full text-lg py-4" disabled={saving}>
			{saving ? 'Opslaan...' : '✓ Wijzigingen opslaan'}
		</button>
		<a href={returnTo} class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{:else}
	<p class="text-center text-gray-500 py-8">Wedstrijd niet gevonden</p>
{/if}
