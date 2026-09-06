<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import {
		getClubs,
		createClub,
		getClubAccessForClub,
		grantClubAccess,
		findUserByEmail,
		createUserAsAdmin,
	} from '$lib/pocketbase';
	import type { Club } from '$lib/types';
	import { isPlatformAdmin } from '$lib/stores/auth';

	// This page is intentionally narrow: a platform admin can only bootstrap a
	// new club and hand it its first admin. Once a club has an admin, all
	// further team/member management happens in the regular /config screen.
	let clubs: Club[] = [];
	let ownedClubIds = new Set<string>();
	let loading = true;

	// New club form
	let newClubName = '';
	let newClubShortName = '';
	let newClubCity = '';
	let creatingClub = false;
	let createClubError = '';

	// First-admin form state, keyed by club id
	let firstAdminName: Record<string, string> = {};
	let firstAdminEmail: Record<string, string> = {};
	let assigningClubId = '';
	let assignError: Record<string, string> = {};
	let assignSuccess: Record<string, string> = {};

	onMount(async () => {
		if (!$isPlatformAdmin) {
			goto(`${base}/`);
			return;
		}
		await loadClubs();
	});

	async function loadClubs() {
		loading = true;
		try {
			clubs = await getClubs();
			const owned = new Set<string>();
			for (const club of clubs) {
				const access = await getClubAccessForClub(club.id);
				if (access.length > 0) owned.add(club.id);
			}
			ownedClubIds = owned;
		} catch (e) {
			console.error('Failed to load clubs:', e);
		} finally {
			loading = false;
		}
	}

	async function handleCreateClub() {
		if (!newClubName.trim()) return;
		createClubError = '';
		creatingClub = true;
		try {
			await createClub({
				name: newClubName.trim(),
				short_name: newClubShortName.trim() || undefined,
				city: newClubCity.trim() || undefined,
			});
			newClubName = '';
			newClubShortName = '';
			newClubCity = '';
			await loadClubs();
		} catch (e: any) {
			createClubError = e?.message || 'Fout bij aanmaken club';
		} finally {
			creatingClub = false;
		}
	}

	async function handleAssignFirstAdmin(club: Club) {
		const name = (firstAdminName[club.id] || '').trim();
		const email = (firstAdminEmail[club.id] || '').trim();
		if (!name || !email) return;

		assignError = { ...assignError, [club.id]: '' };
		assignSuccess = { ...assignSuccess, [club.id]: '' };
		assigningClubId = club.id;
		try {
			let user = await findUserByEmail(email);
			if (!user) {
				user = await createUserAsAdmin({ name, email });
			}
			await grantClubAccess({ user: user.id, club: club.id, role: 'admin' });
			const isGmail = email.toLowerCase().endsWith('@gmail.com');
			assignSuccess = {
				...assignSuccess,
				[club.id]: isGmail
					? `✅ ${name} is admin van ${club.name} — kan inloggen met Google`
					: `✅ ${name} is admin van ${club.name}`,
			};
			await loadClubs();
		} catch (e: any) {
			assignError = { ...assignError, [club.id]: e?.message || 'Fout bij toewijzen admin' };
		} finally {
			assigningClubId = '';
		}
	}
</script>

<svelte:head>
	<title>Clubs beheren - SetBaas</title>
</svelte:head>

<div class="space-y-6">
	<div>
		<h1 class="text-xl font-bold text-gray-900 dark:text-white">Clubs beheren</h1>
		<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
			Als club admin kun je nieuwe clubs aanmaken en de eerste admin toewijzen.
			Verder beheer (teams, leden) gebeurt daarna via Configuratie door die admin zelf.
		</p>
	</div>

	<div class="card space-y-3">
		<h2 class="font-semibold text-gray-800 dark:text-gray-200">Nieuwe club aanmaken</h2>
		<div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
			<input class="input" placeholder="Naam *" bind:value={newClubName} />
			<input class="input" placeholder="Afkorting" bind:value={newClubShortName} />
			<input class="input" placeholder="Plaats" bind:value={newClubCity} />
		</div>
		{#if createClubError}
			<p class="text-sm text-red-500">{createClubError}</p>
		{/if}
		<button class="btn-primary" disabled={creatingClub || !newClubName.trim()} on:click={handleCreateClub}>
			{creatingClub ? 'Bezig...' : 'Club aanmaken'}
		</button>
	</div>

	{#if loading}
		<p class="text-sm text-gray-500 dark:text-gray-400">Laden...</p>
	{:else}
		<div class="card space-y-4">
			<h2 class="font-semibold text-gray-800 dark:text-gray-200">Clubs</h2>
			{#each clubs as club}
				<div class="border-b border-gray-100 dark:border-gray-700 last:border-0 pb-4 last:pb-0">
					<div class="flex items-center justify-between">
						<span class="font-medium text-gray-800 dark:text-gray-200">{club.name}</span>
						{#if ownedClubIds.has(club.id)}
							<span class="text-xs text-green-600 dark:text-green-400">Heeft al een admin</span>
						{:else}
							<span class="text-xs text-amber-600 dark:text-amber-400">Nog geen admin</span>
						{/if}
					</div>

					{#if !ownedClubIds.has(club.id)}
						<div class="mt-2 grid grid-cols-1 sm:grid-cols-3 gap-2">
							<input class="input" placeholder="Naam" bind:value={firstAdminName[club.id]} />
							<input class="input" placeholder="E-mail" bind:value={firstAdminEmail[club.id]} />
							<button
								class="btn-secondary"
								disabled={assigningClubId === club.id || !(firstAdminName[club.id] || '').trim() || !(firstAdminEmail[club.id] || '').trim()}
								on:click={() => handleAssignFirstAdmin(club)}>
								{assigningClubId === club.id ? 'Bezig...' : 'Maak admin'}
							</button>
						</div>
						{#if assignError[club.id]}
							<p class="mt-1 text-sm text-red-500">{assignError[club.id]}</p>
						{/if}
						{#if assignSuccess[club.id]}
							<p class="mt-1 text-sm text-green-600 dark:text-green-400">{assignSuccess[club.id]}</p>
						{/if}
					{/if}
				</div>
			{/each}
			{#if clubs.length === 0}
				<p class="text-sm text-gray-500 dark:text-gray-400">Nog geen clubs.</p>
			{/if}
		</div>
	{/if}
</div>
