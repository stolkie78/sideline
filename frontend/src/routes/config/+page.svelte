<script lang="ts">
	import { onMount } from 'svelte';
	import {
		getCompetencies,
		createCompetency,
		updateCompetency,
		deleteCompetency,
		getTeams,
		getSeasons,
		createTeam,
		createSeason,
		getTeamAccessForTeam,
		grantTeamAccess,
		revokeTeamAccess,
		updateTeamAccess,
		findUserByEmail,
		pb,
	} from '$lib/pocketbase';
	import type { TeamAccess } from '$lib/pocketbase';
	import { teams as teamsStore, seasons as seasonsStore, selectedTeamId } from '$lib/stores/context';
	import type { Competency, CompetencyCategory, Team, Season } from '$lib/types';
	import { CATEGORY_LABELS } from '$lib/types';

	// Tab state
	let activeTab: 'competencies' | 'teams' | 'templates' | 'access' = 'competencies';

	// === Competencies ===
	let competencies: Competency[] = [];
	let loadingComp = true;
	let showCompForm = false;
	let editingComp: Competency | null = null;

	let compName = '';
	let compCategory: CompetencyCategory = 'technical';
	let savingComp = false;

	const allCategories = Object.entries(CATEGORY_LABELS) as [CompetencyCategory, string][];

	onMount(async () => {
		await Promise.all([loadCompetencies(), loadTeamsSeasons()]);
	});

	async function loadCompetencies() {
		loadingComp = true;
		try {
			competencies = await getCompetencies();
		} catch (e) {
			console.error('Failed to load competencies:', e);
		} finally {
			loadingComp = false;
		}
	}

	function startEditComp(comp: Competency) {
		editingComp = comp;
		compName = comp.name;
		compCategory = comp.category;
		showCompForm = true;
	}

	function resetCompForm() {
		editingComp = null;
		compName = '';
		compCategory = 'technical';
		showCompForm = false;
	}

	async function handleCompSubmit() {
		if (!compName.trim()) return;
		savingComp = true;
		try {
			if (editingComp) {
				await updateCompetency(editingComp.id, { name: compName.trim(), category: compCategory });
			} else {
				await createCompetency({ name: compName.trim(), category: compCategory });
			}
			resetCompForm();
			await loadCompetencies();
		} catch (e) {
			console.error('Failed to save competency:', e);
			alert('Fout bij opslaan competentie');
		} finally {
			savingComp = false;
		}
	}

	async function handleDeleteComp(comp: Competency) {
		if (!confirm(`"${comp.name}" verwijderen? Gekoppelde scores worden ook verwijderd.`)) return;
		try {
			await deleteCompetency(comp.id);
			await loadCompetencies();
		} catch (e) {
			console.error('Failed to delete competency:', e);
			alert('Fout bij verwijderen (mogelijk zijn er nog scores aan gekoppeld)');
		}
	}

	// === Teams & Seasons ===
	let teams: Team[] = [];
	let seasons: Season[] = [];
	let loadingTeams = true;

	let newTeamName = '';
	let savingTeam = false;
	let newStartYear = new Date().getFullYear();
	let newEndYear = new Date().getFullYear() + 1;
	let savingSeason = false;

	async function loadTeamsSeasons() {
		loadingTeams = true;
		try {
			[teams, seasons] = await Promise.all([getTeams(), getSeasons()]);
			teamsStore.set(teams);
			seasonsStore.set(seasons);
		} catch (e) {
			console.error('Failed to load teams/seasons:', e);
		} finally {
			loadingTeams = false;
		}
	}

	async function handleAddTeam() {
		if (!newTeamName.trim()) return;
		savingTeam = true;
		try {
			await createTeam(newTeamName.trim());
			newTeamName = '';
			await loadTeamsSeasons();
		} catch (e) {
			console.error('Failed to create team:', e);
			alert('Fout bij aanmaken team');
		} finally {
			savingTeam = false;
		}
	}

	async function handleAddSeason() {
		savingSeason = true;
		try {
			await createSeason({
				name: `${newStartYear}-${newEndYear}`,
				start_year: newStartYear,
				end_year: newEndYear,
			});
			await loadTeamsSeasons();
		} catch (e) {
			console.error('Failed to create season:', e);
			alert('Fout bij aanmaken seizoen');
		} finally {
			savingSeason = false;
		}
	}

	// === Team Access ===
	let accessList: TeamAccess[] = [];
	let loadingAccess = false;
	let inviteEmail = '';
	let inviteRole = 'coach';
	let inviteError = '';
	let inviting = false;

	const ROLE_LABELS: Record<string, string> = {
		admin: 'Admin',
		coach: 'Coach',
		viewer: 'Kijker',
	};

	async function loadAccess() {
		if (!$selectedTeamId) return;
		loadingAccess = true;
		try {
			accessList = await getTeamAccessForTeam($selectedTeamId);
		} catch (e) {
			console.error('Failed to load access:', e);
		} finally {
			loadingAccess = false;
		}
	}

	async function handleInvite() {
		if (!inviteEmail.trim() || !$selectedTeamId) return;
		inviteError = '';
		inviting = true;
		try {
			const user = await findUserByEmail(inviteEmail.trim());
			if (!user) {
				inviteError = 'Gebruiker niet gevonden. Ze moeten eerst inloggen via Google.';
				return;
			}
			// Check if already has access
			const existing = accessList.find(a => a.user === user.id);
			if (existing) {
				inviteError = 'Deze gebruiker heeft al toegang tot dit team.';
				return;
			}
			await grantTeamAccess({ user: user.id, team: $selectedTeamId, role: inviteRole });
			inviteEmail = '';
			await loadAccess();
		} catch (e: any) {
			inviteError = e?.message || 'Fout bij uitnodigen';
		} finally {
			inviting = false;
		}
	}

	async function handleRoleChange(access: TeamAccess, newRole: string) {
		try {
			await updateTeamAccess(access.id, { role: newRole });
			await loadAccess();
		} catch (e) {
			alert('Fout bij wijzigen rol');
		}
	}

	async function handleRevoke(access: TeamAccess) {
		const name = access.expand?.user?.name || access.expand?.user?.email || '?';
		if (!confirm(`Toegang voor ${name} intrekken?`)) return;
		try {
			await revokeTeamAccess(access.id);
			await loadAccess();
		} catch (e) {
			alert('Fout bij intrekken toegang');
		}
	}
</script>

<svelte:head>
	<title>Configuratie - SideLine</title>
</svelte:head>

<div class="space-y-4">
	<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Configuratie</h2>

	<!-- Tab bar -->
	<div class="flex overflow-x-auto border-b border-gray-200 dark:border-gray-700">
		<button
			class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
				activeTab === 'competencies'
					? 'text-primary-600 border-b-2 border-primary-600'
					: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
			}"
			on:click={() => (activeTab = 'competencies')}>
			Competenties
		</button>
		<button
			class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
				activeTab === 'teams'
					? 'text-primary-600 border-b-2 border-primary-600'
					: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
			}"
			on:click={() => (activeTab = 'teams')}>
			Teams & Seizoenen
		</button>
		<button
			class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
				activeTab === 'templates'
					? 'text-primary-600 border-b-2 border-primary-600'
					: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
			}"
			on:click={() => (activeTab = 'templates')}>
			Templates
		</button>
		<button
			class="px-4 py-3 text-sm font-semibold whitespace-nowrap transition-colors {
				activeTab === 'access'
					? 'text-primary-600 border-b-2 border-primary-600'
					: 'text-gray-500 dark:text-gray-400 hover:text-gray-700'
			}"
			on:click={() => { activeTab = 'access'; loadAccess(); }}>
			Toegang
		</button>
	</div>

	<!-- Competencies Tab -->
	{#if activeTab === 'competencies'}
		<div class="space-y-3">
			<div class="flex justify-between items-center">
				<p class="text-sm text-gray-500 dark:text-gray-400">Beheer competenties voor spelerbeoordeling</p>
				<button class="btn-primary text-sm" on:click={() => { resetCompForm(); showCompForm = !showCompForm; }}>
					{showCompForm ? '✕ Sluiten' : '+ Competentie'}
				</button>
			</div>

			<!-- Add/Edit form -->
			{#if showCompForm}
				<form class="card space-y-3" on:submit|preventDefault={handleCompSubmit}>
					<h3 class="font-semibold text-sm text-gray-700 dark:text-gray-300">
						{editingComp ? 'Competentie bewerken' : 'Nieuwe competentie'}
					</h3>
					<div>
						<label class="label" for="comp-name">Naam *</label>
						<input id="comp-name" class="input" type="text" bind:value={compName} required placeholder="bijv. Bovenhands, Blok, Opslag..." />
					</div>
					<div>
						<label class="label" for="comp-cat">Categorie</label>
						<select id="comp-cat" class="input" bind:value={compCategory}>
							{#each allCategories as [value, label]}
								<option {value}>{label}</option>
							{/each}
						</select>
					</div>
					<div class="flex gap-2">
						<button type="submit" class="btn-primary flex-1" disabled={savingComp}>
							{savingComp ? 'Opslaan...' : editingComp ? '✓ Bijwerken' : '✓ Toevoegen'}
						</button>
						{#if editingComp}
							<button type="button" class="btn-secondary" on:click={resetCompForm}>Annuleren</button>
						{/if}
					</div>
				</form>
			{/if}

			<!-- Competency list -->
			{#if loadingComp}
				<div class="flex justify-center py-8">
					<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
				</div>
			{:else if competencies.length === 0}
				<div class="card text-center py-8 text-gray-500 dark:text-gray-400">
					
					<p>Nog geen competenties toegevoegd</p>
				</div>
			{:else}
				{#each allCategories as [catKey, catLabel]}
					{@const catComps = competencies.filter(c => c.category === catKey)}
					{#if catComps.length > 0}
						<div class="card">
							<h3 class="text-xs font-bold uppercase text-gray-400 dark:text-gray-500 mb-2">{catLabel}</h3>
							<div class="space-y-1.5">
								{#each catComps as comp}
									<div class="flex items-center justify-between py-1.5 border-b border-gray-50 dark:border-gray-700 last:border-0">
										<span class="text-sm font-medium text-gray-700 dark:text-gray-300">{comp.name}</span>
										<div class="flex items-center gap-1">
											<button
												class="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-primary-600 transition-colors text-xs"
												on:click={() => startEditComp(comp)}
												title="Bewerken">
												✏️
											</button>
											<button
												class="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-red-500 transition-colors text-xs"
												on:click={() => handleDeleteComp(comp)}
												title="Verwijderen">
												🗑️
											</button>
										</div>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				{/each}
			{/if}
		</div>

	<!-- Teams & Seasons Tab -->
	{:else if activeTab === 'teams'}
		<div class="space-y-4">
			<!-- Teams -->
			<div class="card space-y-3">
				<h3 class="font-semibold text-gray-800 dark:text-gray-200">Teams</h3>
				{#if teams.length > 0}
					<div class="space-y-1">
						{#each teams as team}
							<div class="flex items-center gap-2 py-1.5 border-b border-gray-50 dark:border-gray-700 last:border-0">
								<span class="text-sm font-medium flex-1">{team.name}</span>
							</div>
						{/each}
					</div>
				{/if}
				<form class="flex gap-2" on:submit|preventDefault={handleAddTeam}>
					<input class="input flex-1" type="text" bind:value={newTeamName} placeholder="Nieuw team..." />
					<button type="submit" class="btn-primary text-sm" disabled={savingTeam}>+</button>
				</form>
			</div>

			<!-- Seasons -->
			<div class="card space-y-3">
				<h3 class="font-semibold text-gray-800 dark:text-gray-200">Seizoenen</h3>
				{#if seasons.length > 0}
					<div class="space-y-1">
						{#each seasons as season}
							<div class="flex items-center gap-2 py-1.5 border-b border-gray-50 dark:border-gray-700 last:border-0">
								<span class="text-sm font-medium flex-1">{season.name}</span>
							</div>
						{/each}
					</div>
				{/if}
				<form class="flex gap-2 items-end" on:submit|preventDefault={handleAddSeason}>
					<div class="flex-1">
						<label class="label text-xs">Van</label>
						<input class="input" type="number" bind:value={newStartYear} min="2020" max="2040" />
					</div>
					<div class="flex-1">
						<label class="label text-xs">Tot</label>
						<input class="input" type="number" bind:value={newEndYear} min="2020" max="2040" />
					</div>
					<button type="submit" class="btn-primary text-sm" disabled={savingSeason}>+</button>
				</form>
			</div>
		</div>

	<!-- Templates Tab -->
	{:else if activeTab === 'templates'}
		<div class="space-y-3">
			<div class="flex justify-between items-center">
				<p class="text-sm text-gray-500 dark:text-gray-400">Herbruikbare trainingstemplates voor snelle planning</p>
				<a href="{base}/config/templates" class="btn-primary text-sm">Beheren</a>
			</div>
		</div>

	<!-- Access Tab -->
	{:else if activeTab === 'access'}
		<div class="space-y-4">
			<p class="text-sm text-gray-500 dark:text-gray-400">
				Beheer wie toegang heeft tot het huidige team. Gebruikers moeten eerst inloggen via Google.
			</p>

			<!-- Invite form -->
			<form class="card space-y-3" on:submit|preventDefault={handleInvite}>
				<h3 class="font-semibold text-gray-800 dark:text-gray-200">Gebruiker uitnodigen</h3>
				<div class="flex gap-2">
					<input
						class="input flex-1"
						type="email"
						bind:value={inviteEmail}
						placeholder="E-mailadres..."
						required
					/>
					<select class="input w-28" bind:value={inviteRole}>
						<option value="admin">Admin</option>
						<option value="coach">Coach</option>
						<option value="viewer">Kijker</option>
					</select>
					<button type="submit" class="btn-primary text-sm" disabled={inviting}>
						{inviting ? '...' : 'Toevoegen'}
					</button>
				</div>
				{#if inviteError}
					<p class="text-sm text-red-500 dark:text-red-400">{inviteError}</p>
				{/if}
			</form>

			<!-- Access list -->
			{#if loadingAccess}
				<div class="flex justify-center py-4">
					<div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600"></div>
				</div>
			{:else if accessList.length === 0}
				<div class="card text-center py-8 text-gray-500 dark:text-gray-400">
					Nog geen gebruikers met toegang
				</div>
			{:else}
				<div class="card">
					<h3 class="font-semibold text-gray-800 dark:text-gray-200 mb-3">Teamleden</h3>
					<div class="space-y-2">
						{#each accessList as access}
							<div class="flex items-center gap-3 py-2 border-b border-gray-50 dark:border-gray-700 last:border-0">
								<div class="flex-1 min-w-0">
									<span class="text-sm font-medium text-gray-800 dark:text-gray-200 block truncate">
										{access.expand?.user?.name || '—'}
									</span>
									<span class="text-xs text-gray-400 dark:text-gray-500 block truncate">
										{access.expand?.user?.email || ''}
									</span>
								</div>
								<select
									class="input w-24 py-1 text-xs"
									value={access.role}
									on:change={(e) => handleRoleChange(access, e.currentTarget.value)}>
									<option value="admin">Admin</option>
									<option value="coach">Coach</option>
									<option value="viewer">Kijker</option>
								</select>
								<button
									class="text-xs text-red-500 hover:underline"
									on:click={() => handleRevoke(access)}>
									Verwijder
								</button>
							</div>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>
