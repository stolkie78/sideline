<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { getTeams, getSeasons, getTeamAccessForUser, grantTeamAccess } from '$lib/pocketbase';
	import { pb } from '$lib/pocketbase';
	import {
		selectedTeamId,
		selectedSeasonId,
		teams as teamsStore,
		seasons as seasonsStore,
	} from '$lib/stores/context';
	import { authUser, isAuthenticated, AUTH_ENABLED } from '$lib/stores/auth';
	import type { Team, Season } from '$lib/types';

	let darkMode = true;
	let showContextPicker = false;
	let menuOpen = false;
	let localTeams: Team[] = [];
	let localSeasons: Season[] = [];
	let authReady = false;

	onMount(async () => {
		const saved = localStorage.getItem('darkMode');
		darkMode = saved !== null ? saved === 'true' : true;
		applyTheme();

		// Mark auth as ready - pb.authStore is already loaded from localStorage at this point
		authReady = true;

		const isPublicPath = $page.url.pathname === '/login' || $page.url.pathname === '/auth-debug';
		if (AUTH_ENABLED && !pb.authStore.isValid && !isPublicPath) {
			goto(`${base}/login`);
			return;
		}

		try {
			const allTeams = await getTeams();
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

			teamsStore.set(localTeams);
			seasonsStore.set(localSeasons);

			if (!$selectedTeamId && localTeams.length > 0) {
				$selectedTeamId = localTeams[0].id;
			}
			if (!$selectedSeasonId && localSeasons.length > 0) {
				$selectedSeasonId = localSeasons[0].id;
			}
		} catch (e) {
			console.error('Failed to load teams/seasons:', e);
		}
	});

	$: if (browser && authReady && AUTH_ENABLED && !$isAuthenticated && $page.url.pathname !== '/login' && $page.url.pathname !== '/auth-debug') {
		goto(`${base}/login`);
	}

	// Close menu on navigation
	$: if ($page.url.pathname) {
		menuOpen = false;
	}

	function handleLogout() {
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

	$: currentTeamName = localTeams.find((t) => t.id === $selectedTeamId)?.name || 'Team';
	$: currentSeasonName = localSeasons.find((s) => s.id === $selectedSeasonId)?.name || 'Seizoen';

	const navItems = [
		{ href: '/', label: 'Dashboard' },
		{ href: '/players', label: 'Spelers' },
		{ href: '/trainings', label: 'Trainingen' },
		{ href: '/matches', label: 'Wedstrijden' },
		{ href: '/periodisering', label: 'Periodisering' },
		{ href: '/reports', label: 'Rapporten' },
		{ href: '/config', label: 'Configuratie' },
	];
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
		<main class="px-4 py-6 max-w-lg mx-auto">
			<slot />
		</main>
	{:else}
	<!-- Header -->
	<header class="sticky top-0 z-50 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800">
		<div class="flex items-center justify-between px-5 py-3 max-w-2xl mx-auto">
			<!-- Left: Logo + Title -->
			<a href="{base}/" class="flex items-center gap-3">
				<img src="/logo.svg" alt="SideLine" class="h-9 w-9 rounded-lg" />
				<div class="leading-tight">
					<span class="text-base font-bold text-gray-900 dark:text-white">SideLine</span>
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
		<nav class="fixed top-0 right-0 z-50 w-72 h-full bg-white dark:bg-gray-900 shadow-2xl border-l border-gray-200 dark:border-gray-800 overflow-y-auto">
			<div class="p-6">
				<!-- Close button -->
				<div class="flex justify-end mb-6">
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
						<label class="text-sm font-medium text-gray-600 dark:text-gray-400 block mb-1.5">Team</label>
						<select class="input" bind:value={$selectedTeamId}>
							{#each localTeams as team}
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
								</div>
							</div>
						{/if}
						<button on:click={handleLogout} class="w-full btn-secondary">
							Uitloggen
						</button>
					</div>
				{/if}
			</div>
		</nav>
	{/if}

	<!-- Main content -->
	<main class="px-5 py-6 max-w-2xl mx-auto">
		<slot />
	</main>
	{/if}
</div>
