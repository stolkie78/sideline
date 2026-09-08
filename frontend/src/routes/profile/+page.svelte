<script lang="ts">
	import { onMount } from 'svelte';
	import { getFileUrl, getUnlinkedTeamPlayers, linkPlayerToUser, updatePlayerProfile } from '$lib/pocketbase';
	import { authUser } from '$lib/stores/auth';
	import { linkedPlayer, loadUserRoles, userClubAccess } from '$lib/stores/role';
	import { clubs as clubsStore, teams as teamsStore, seasons as seasonsStore, teamsInClub, selectedSeasonId } from '$lib/stores/context';
	import type { Player } from '$lib/types';

	let saving = false;
	let saveSuccess = false;
	let saveError = '';
	let formBio = '';
	let formPhoto: FileList | null = null;

	// --- Self-link flow (no player linked to this account yet) ---
	let linking = false;
	let linkError = '';
	let linkClubId = '';
	let linkTeamId = '';
	let candidates: Player[] = [];
	let loadingCandidates = false;

	$: linkTeams = teamsInClub($teamsStore, linkClubId);

	onMount(() => {
		if ($linkedPlayer) {
			formBio = $linkedPlayer.bio || '';
		} else {
			// Pre-select the first club/team the user has access to
			linkClubId = $userClubAccess[0]?.club || $clubsStore[0]?.id || '';
		}
	});

	$: if (!$linkedPlayer && linkClubId && !linkTeamId) {
		linkTeamId = linkTeams[0]?.id || '';
	}

	$: if (!$linkedPlayer && linkTeamId && $selectedSeasonId) {
		loadCandidates(linkTeamId, $selectedSeasonId);
	}

	async function loadCandidates(teamId: string, seasonId: string) {
		loadingCandidates = true;
		try {
			candidates = await getUnlinkedTeamPlayers(teamId, seasonId);
		} catch (e) {
			console.error('Failed to load unlinked players:', e);
			candidates = [];
		} finally {
			loadingCandidates = false;
		}
	}

	async function handleLink(player: Player) {
		if (!$authUser) return;
		linking = true;
		linkError = '';
		try {
			await linkPlayerToUser(player.id, $authUser.id);
			await loadUserRoles();
			formBio = $linkedPlayer?.bio || '';
		} catch (e) {
			console.error('Failed to link player:', e);
			linkError = 'Koppelen mislukt. Probeer het opnieuw of vraag je coach om hulp.';
		} finally {
			linking = false;
		}
	}

	async function handleSaveProfile() {
		if (!$linkedPlayer) return;
		saving = true;
		saveSuccess = false;
		saveError = '';
		try {
			const data = new FormData();
			data.append('bio', formBio.trim());
			if (formPhoto && formPhoto[0]) data.append('photo', formPhoto[0]);
			await updatePlayerProfile($linkedPlayer.id, data);
			await loadUserRoles();
			formPhoto = null;
			saveSuccess = true;
		} catch (e) {
			console.error('Failed to save profile:', e);
			saveError = 'Opslaan mislukt. Probeer het opnieuw.';
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>SetBaas - Mijn profiel</title>
</svelte:head>

<div class="space-y-6">
	<h1 class="text-xl font-bold text-gray-800 dark:text-gray-200">👤 Mijn profiel</h1>

	{#if $linkedPlayer}
		<form class="card space-y-4" on:submit|preventDefault={handleSaveProfile}>
			<div class="flex items-center gap-4">
				{#if $linkedPlayer.photo}
					<img src={getFileUrl($linkedPlayer, $linkedPlayer.photo)} alt={$linkedPlayer.name}
						class="w-20 h-20 rounded-full object-cover" />
				{:else}
					<div class="w-20 h-20 rounded-full bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center text-primary-700 dark:text-primary-400 font-bold text-2xl">
						{$linkedPlayer.name.charAt(0).toUpperCase()}
					</div>
				{/if}
				<div>
					<p class="font-semibold text-gray-800 dark:text-gray-200">{$linkedPlayer.name}</p>
					<p class="text-xs text-gray-400 dark:text-gray-500">{$authUser?.email}</p>
				</div>
			</div>

			<div>
				<label class="label" for="photo">Nieuwe foto</label>
				<input id="photo" class="input" type="file" accept="image/*" bind:files={formPhoto} />
			</div>

			<div>
				<label class="label" for="bio">Over mij</label>
				<textarea id="bio" class="input" rows="3" maxlength="300" bind:value={formBio}
					placeholder="Vertel iets leuks over jezelf... (bijnaam, motto, favoriete slag)"></textarea>
				<p class="text-xs text-gray-400 dark:text-gray-500 mt-1">{formBio.length}/300</p>
			</div>

			{#if saveError}
				<p class="text-sm text-red-500 dark:text-red-400">{saveError}</p>
			{/if}
			{#if saveSuccess}
				<p class="text-sm text-green-600 dark:text-green-400">✓ Profiel opgeslagen</p>
			{/if}

			<button type="submit" class="btn-primary w-full" disabled={saving}>
				{saving ? 'Opslaan...' : '✓ Opslaan'}
			</button>
		</form>
	{:else}
		<div class="card space-y-4">
			<p class="text-gray-600 dark:text-gray-400 text-sm">
				Je account is nog niet gekoppeld aan een spelersprofiel. Kies hieronder je team en klik op je naam om jezelf te koppelen.
			</p>

			<div class="grid grid-cols-2 gap-3">
				<div>
					<label class="label" for="link-club">Club</label>
					<select id="link-club" class="input" bind:value={linkClubId} on:change={() => (linkTeamId = '')}>
						{#each $clubsStore as club}
							<option value={club.id}>{club.name}</option>
						{/each}
					</select>
				</div>
				<div>
					<label class="label" for="link-team">Team</label>
					<select id="link-team" class="input" bind:value={linkTeamId} disabled={linkTeams.length === 0}>
						{#each linkTeams as team}
							<option value={team.id}>{team.name}</option>
						{/each}
					</select>
				</div>
			</div>

			{#if linkError}
				<p class="text-sm text-red-500 dark:text-red-400">{linkError}</p>
			{/if}

			{#if loadingCandidates}
				<div class="flex justify-center py-4">
					<div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600"></div>
				</div>
			{:else if candidates.length === 0}
				<p class="text-sm text-gray-400 dark:text-gray-500 py-2">
					Geen ongekoppelde spelers gevonden in dit team. Vraag je coach om je toe te voegen aan het team, of je e-mailadres in te vullen bij je spelersprofiel.
				</p>
			{:else}
				<div class="space-y-2">
					{#each candidates as player (player.id)}
						<button type="button"
							class="w-full flex items-center gap-3 p-3 rounded-xl border border-gray-200 dark:border-gray-700 hover:border-primary-400 hover:bg-primary-50 dark:hover:bg-primary-900/10 transition-colors text-left disabled:opacity-50"
							disabled={linking}
							on:click={() => handleLink(player)}>
							{#if player.photo}
								<img src={getFileUrl(player, player.photo)} alt={player.name} class="w-10 h-10 rounded-full object-cover" />
							{:else}
								<div class="w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-500 font-bold text-sm">
									{player.name.charAt(0).toUpperCase()}
								</div>
							{/if}
							<span class="font-medium text-gray-800 dark:text-gray-200">{player.name}</span>
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>
