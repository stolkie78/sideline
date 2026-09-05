<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { getClubs, getTeams, getSeasons, getTeamAccessForUser, grantTeamAccess } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import {
		selectedClubId,
		selectedTeamId,
		selectedSeasonId,
		clubs as clubsStore,
		teams as teamsStore,
		seasons as seasonsStore,
		teamsInClub,
	} from '$lib/stores/context';
	import { authUser, isAuthenticated, AUTH_ENABLED } from '$lib/stores/auth';
	import { userRole, isCoachOrAdmin, loadUserRoles, clearUserRoles } from '$lib/stores/role';
	import type { Club, Team, Season } from '$lib/types';
	import { version } from '../../package.json';

	let darkMode = true;
	let showContextPicker = false;
	let menuOpen = false;
	let localClubs: Club[] = [];
	let localTeams: Team[] = [];
	let localSeasons: Season[] = [];
	let authReady = false;

	onMount(async () => {
		const saved = localStorage.getItem('darkMode');
		darkMode = saved !== null ? saved === 'true' : true;
		applyTheme();

		// Mark auth as ready - pb.authStore is already loaded from localStorage at this point
		authReady = true;

		const isPublicPath = $page.url.pathname === '/login' || $page.url.pathname === '/auth-debug' || $page.url.pathname.startsWith('/invite');
		if (AUTH_ENABLED && !pb.authStore.isValid && !isPublicPath) {
			goto(`${base}/login`);
			return;
		}

		try {
			const allTeams = await getTeams();
			localClubs = await getClubs();
			localSeasons = await getSeasons();

			// If auth is enabled, filter teams by user access
			if (AUTH_ENABLED && pb.authStore.isValid) {
				const model = (pb.authStore as any).record || (pb.authStore as any).model;
				if (model) {
					const userId = model.id;
					const access = await getTeamAccessForUser(userId);

					if (access.length === 0 && allTeams.length > 0) {
						// First user: auto-grant admin on all existing teams
						for (const team of allTeams) {
							await grantTeamAccess({ user: userId, team: team.id, role: 'admin' });
						}
						localTeams = allTeams;
					} else {
						// Filter to accessible teams only
						const accessibleIds = new Set(access.map(a => a.team));
						localTeams = allTeams.filter(t => accessibleIds.has(t.id));
					}
				} else {
					localTeams = allTeams;
				}
			} else {
				localTeams = allTeams;
			}

			clubsStore.set(localClubs);
			teamsStore.set(localTeams);
			seasonsStore.set(localSeasons);

			// Keep the club selection in sync with the accessible teams
			const clubIdsWithTeams = new Set(localTeams.map((t) => t.club).filter(Boolean) as string[]);
			if (!$selectedClubId || (clubIdsWithTeams.size > 0 && !clubIdsWithTeams.has($selectedClubId))) {
				$selectedClubId = localTeams.find((t) => t.club)?.club || localClubs[0]?.id || '';
			}

			const selectableTeams = teamsInClub(localTeams, $selectedClubId);
			if (!selectableTeams.some((t) => t.id === $selectedTeamId)) {
				$selectedTeamId = selectableTeams[0]?.id || '';
			}
			if (!$selectedSeasonId && localSeasons.length > 0) {
				$selectedSeasonId = localSeasons[0].id;
			}

			// Load user roles after teams are ready
			if (AUTH_ENABLED && pb.authStore.isValid) {
				await loadUserRoles();
			}
		} catch (e) {
			console.error('Failed to load teams/seasons:', e);
		}
	});

	$: if (browser && authReady && AUTH_ENABLED && !$isAuthenticated && $page.url.pathname !== '/login' && $page.url.pathname !== '/auth-debug' && !$page.url.pathname.startsWith('/invite')) {
		goto(`${base}/login`);
	}

	// Close menu on navigation
	$: if ($page.url.pathname) {
		menuOpen = false;
	}

	function handleLogout() {
		clearUserRoles();
		authUser.logout();
		goto(`${base}/login`);
	}

	function toggleDarkMode() {
		darkMode = !darkMode;
		localStorage.setItem('darkMode', String(darkMode));
		applyTheme();
	}

	function applyTheme() {
		if (browser) {
			document.documentElement.classList.toggle('dark', darkMode);
		}
	}

	$: visibleTeams = teamsInClub(localTeams, $selectedClubId);

	function handleClubChange() {
		if (!visibleTeams.some((t) => t.id === $selectedTeamId)) {
			$selectedTeamId = visibleTeams[0]?.id || '';
		}
	}

	$: currentClubName = localClubs.find((c) => c.id === $selectedClubId)?.name || 'Club';
	$: currentTeamName = localTeams.find((t) => t.id === $selectedTeamId)?.name || 'Team';
	$: currentSeasonName = localSeasons.find((s) => s.id === $selectedSeasonId)?.name || 'Seizoen';

	const allNavItems = [
		{ href: '/', label: 'Dashboard', roles: ['admin', 'coach', 'player'] },
		{ href: '/players', label: 'Spelers', roles: ['admin', 'coach'] },
		{ href: '/trainings', label: 'Trainingen', roles: ['admin', 'coach'] },
		{ href: '/matches', label: 'Wedstrijden', roles: ['admin', 'coach'] },
		{ href: '/periodisering', label: 'Periodisering', roles: ['admin', 'coach'] },
		{ href: '/reports', label: 'Rapporten', roles: ['admin', 'coach'] },
		{ href: '/config', label: 'Configuratie', roles: ['admin'] },
	];

	$: navItems = allNavItems.filter(item =>
		!$userRole || item.roles.includes($userRole)
	);
</script>

<svelte:head>
	<script>
		if (localStorage.getItem('darkMode') !== 'false') {
			document.documentElement.classList.add('dark');
		}
	</script>
</svelte:head>

<div class="min-h-screen">
	{#if !$isAuthenticated && $page.url.pathname !== '/login'}
		<div class="flex justify-center items-center min-h-screen">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if $page.url.pathname === '/login'}
		<main class="px-4 py-6 max-w-lg md:max-w-xl mx-auto">
			<slot />
		</main>
	{:else}
	<!-- Header -->
	<header class="sticky top-0 z-50 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800">
		<div class="flex items-center justify-between px-5 py-3 max-w-2xl md:max-w-4xl lg:max-w-5xl mx-auto">
			<!-- Left: Logo + Title -->
			<a href="{base}/" class="flex items-center gap-3">
				<img src="/logo.svg" alt="SetBaas" class="h-10 w-10" />
				<div class="leading-tight">
					<span class="text-lg font-bold text-gray-900 dark:text-white tracking-tight">SetBaas</span>
					<span class="block text-[11px] text-gray-500 dark:text-gray-400">{currentTeamName} · {currentSeasonName}</span>
				</div>
			</a>

			<!-- Right: Actions -->
			<div class="flex items-center gap-2">
				<button
					on:click={toggleDarkMode}
					class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-500 dark:text-gray-400"
					aria-label="Toggle dark mode"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						{#if darkMode}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
						{:else}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
						{/if}
					</svg>
				</button>

				<!-- Hamburger -->
				<button
					on:click={() => (menuOpen = !menuOpen)}
					class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-700 dark:text-gray-300"
					aria-label="Menu"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						{#if menuOpen}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						{:else}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
						{/if}
					</svg>
				</button>
			</div>
		</div>
	</header>

	<!-- Slide-down menu -->
	{#if menuOpen}
		<!-- Backdrop -->
		<div class="fixed inset-0 z-40 bg-black/30 backdrop-blur-sm" on:click={() => (menuOpen = false)} on:keydown={() => {}}></div>

		<!-- Menu panel -->
		<nav class="fixed top-0 right-0 z-50 w-72 h-full bg-white dark:bg-gray-900 shadow-2xl border-l border-gray-200 dark:border-gray-800 overflow-y-auto flex flex-col">
			<div class="p-6 flex-1">
				<!-- Close button -->
				<div class="flex justify-between items-center mb-6">
					<div class="flex items-center gap-2">
						<img src="/logo.svg" alt="SetBaas" class="h-8 w-8" />
						<span class="text-lg font-bold text-gray-900 dark:text-white tracking-tight">SetBaas</span>
					</div>
					<button on:click={() => (menuOpen = false)} class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500">
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				<!-- Nav links -->
				<div class="space-y-1 mb-8">
					{#each navItems as item}
						<a
							href={item.href}
							class="block px-4 py-3 rounded-xl text-base font-medium transition-colors
								{$page.url.pathname === item.href || ($page.url.pathname.startsWith(item.href) && item.href !== '/')
									? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400'
									: 'text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'}"
						>
							{item.label}
						</a>
					{/each}
				</div>

				<!-- Context picker -->
				<div class="border-t border-gray-200 dark:border-gray-700 pt-6 space-y-4">
					<p class="text-xs font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Context</p>
					<div>
						<label class="text-sm font-medium text-gray-600 dark:text-gray-400 block mb-1.5">Club</label>
						<select class="input" bind:value={$selectedClubId} on:change={handleClubChange}>
							{#each localClubs as club}
								<option value={club.id}>{club.name}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="text-sm font-medium text-gray-600 dark:text-gray-400 block mb-1.5">Team</label>
						<select class="input" bind:value={$selectedTeamId}>
							{#each visibleTeams as team}
								<option value={team.id}>{team.name}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="text-sm font-medium text-gray-600 dark:text-gray-400 block mb-1.5">Seizoen</label>
						<select class="input" bind:value={$selectedSeasonId}>
							{#each localSeasons as season}
								<option value={season.id}>{season.name}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Logout -->
				{#if AUTH_ENABLED}
					<div class="border-t border-gray-200 dark:border-gray-700 pt-6 mt-6">
						{#if $authUser}
							<div class="flex items-center gap-3 mb-4">
								<div class="w-9 h-9 rounded-full bg-primary-100 dark:bg-primary-900/30 flex items-center justify-center text-primary-700 dark:text-primary-400 font-bold text-sm">
									{($authUser.name || $authUser.email || '?').charAt(0).toUpperCase()}
								</div>
								<div class="min-w-0 flex-1">
									<span class="text-sm font-medium text-gray-800 dark:text-gray-200 block truncate">{$authUser.name || '—'}</span>
									<span class="text-xs text-gray-400 dark:text-gray-500 block truncate">{$authUser.email}</span>
								{#if $userRole}
									<span class="inline-block mt-1 text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full
										{$userRole === 'admin' ? 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400' :
										 $userRole === 'coach' ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400' :
										 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400'}"
									>{$userRole}</span>
								{/if}
								</div>
							</div>
						{/if}
						<button on:click={handleLogout} class="w-full btn-secondary">
							Uitloggen
						</button>
					</div>
				{/if}
			</div>

			<!-- Version footer -->
			<div class="p-6 pt-0">
				<div class="border-t border-gray-200 dark:border-gray-700 pt-4 text-center">
					<span class="text-xs text-gray-400 dark:text-gray-600">SetBaas v{version}</span>
				</div>
			</div>
		</nav>
	{/if}

	<!-- Main content -->
	<main class="px-5 py-6 max-w-2xl md:max-w-4xl lg:max-w-5xl mx-auto">
		<slot />
	</main>
	{/if}
</div>
