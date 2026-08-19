<script lang="ts">
	import { onMount } from 'svelte';
	import { getTeams, getSeasons, createTeam, createSeason } from '$lib/pocketbase';
	import { teams as teamsStore, seasons as seasonsStore } from '$lib/stores/context';
	import type { Team, Season } from '$lib/types';

	let teams: Team[] = [];
	let seasons: Season[] = [];
	let loading = true;

	let newTeamName = '';
	let savingTeam = false;
	let newStartYear = new Date().getFullYear();
	let newEndYear = new Date().getFullYear() + 1;
	let savingSeason = false;

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		try {
			[teams, seasons] = await Promise.all([getTeams(), getSeasons()]);
			teamsStore.set(teams);
			seasonsStore.set(seasons);
		} catch (e) {
			console.error('Failed to load data:', e);
		} finally {
			loading = false;
		}
	}

	async function handleAddTeam() {
		if (!newTeamName.trim()) return;
		savingTeam = true;
		try {
			await createTeam(newTeamName.trim());
			newTeamName = '';
			await loadData();
		} catch (e) {
			console.error('Failed to create team:', e);
			alert('Fout bij aanmaken team');
		} finally {
			savingTeam = false;
		}
	}

	async function handleAddSeason() {
		if (newEndYear <= newStartYear) {
			alert('Eindjaar moet hoger zijn dan startjaar');
			return;
		}
		savingSeason = true;
		try {
			await createSeason({
				name: `${newStartYear}-${newEndYear}`,
				start_year: newStartYear,
				end_year: newEndYear,
			});
			newStartYear = newEndYear;
			newEndYear = newEndYear + 1;
			await loadData();
		} catch (e) {
			console.error('Failed to create season:', e);
			alert('Fout bij aanmaken seizoen');
		} finally {
			savingSeason = false;
		}
	}
</script>

<svelte:head>
	<title>Instellingen - SideLine</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else}
	<div class="space-y-6">
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">⚙️ Instellingen</h2>

		<!-- Teams -->
		<div class="card space-y-3">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200">Teams</h3>

			{#if teams.length > 0}
				<div class="space-y-1">
					{#each teams as team}
						<div class="flex items-center gap-2 py-2 px-3 rounded-lg bg-gray-50 dark:bg-gray-800">
							<span class="text-lg">🏐</span>
							<span class="font-medium text-sm">{team.name}</span>
						</div>
					{/each}
				</div>
			{:else}
				<p class="text-sm text-gray-500 dark:text-gray-400">Nog geen teams</p>
			{/if}

			<form class="flex gap-2" on:submit|preventDefault={handleAddTeam}>
				<input
					class="input flex-1"
					type="text"
					placeholder="Bijv. Zovoc MB1"
					bind:value={newTeamName}
					required
				/>
				<button type="submit" class="btn-primary" disabled={savingTeam}>
					{savingTeam ? '...' : '+ Team'}
				</button>
			</form>
		</div>

		<!-- Seasons -->
		<div class="card space-y-3">
			<h3 class="font-semibold text-gray-800 dark:text-gray-200">Seizoenen</h3>

			{#if seasons.length > 0}
				<div class="space-y-1">
					{#each seasons as season}
						<div class="flex items-center gap-2 py-2 px-3 rounded-lg bg-gray-50 dark:bg-gray-800">
							<span class="text-lg">📅</span>
							<span class="font-medium text-sm">{season.name}</span>
							<span class="text-xs text-gray-500 dark:text-gray-400">
								({season.start_year} – {season.end_year})
							</span>
						</div>
					{/each}
				</div>
			{:else}
				<p class="text-sm text-gray-500 dark:text-gray-400">Nog geen seizoenen</p>
			{/if}

			<form class="flex gap-2 items-end" on:submit|preventDefault={handleAddSeason}>
				<div class="flex-1">
					<label class="label text-xs">Van</label>
					<input class="input" type="number" min="2020" max="2050" bind:value={newStartYear} />
				</div>
				<div class="flex-1">
					<label class="label text-xs">Tot</label>
					<input class="input" type="number" min="2020" max="2050" bind:value={newEndYear} />
				</div>
				<button type="submit" class="btn-primary whitespace-nowrap" disabled={savingSeason}>
					{savingSeason ? '...' : '+ Seizoen'}
				</button>
			</form>
		</div>

		<a href="{base}/" class="btn-secondary w-full text-center">← Terug</a>
	</div>
{/if}
