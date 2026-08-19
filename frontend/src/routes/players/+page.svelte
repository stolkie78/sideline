<script lang="ts">
	import { onMount } from 'svelte';
	import { getPlayers, getFileUrl, createPlayer } from '$lib/pocketbase';
	import type { Player } from '$lib/types';
	import { POSITION_LABELS, STATUS_LABELS } from '$lib/types';

	let players: Player[] = [];
	let loading = true;
	let showForm = false;

	// Form state
	let formName = '';
	let formPositions: PlayerPosition[] = [];
	let formStatus = 'active';
	let formJersey = '';
	let formPhoto: FileList | null = null;
	let saving = false;

	const allPositions = Object.entries(POSITION_LABELS) as [PlayerPosition, string][];

	function togglePosition(pos: PlayerPosition) {
		if (formPositions.includes(pos)) {
			formPositions = formPositions.filter(p => p !== pos);
		} else {
			formPositions = [...formPositions, pos];
		}
	}

	onMount(async () => {
		await loadPlayers();
	});

	async function loadPlayers() {
		loading = true;
		try {
			players = await getPlayers();
		} catch (e) {
			console.error('Failed to load players:', e);
		} finally {
			loading = false;
		}
	}

	async function handleSubmit() {
		if (!formName.trim()) return;
		saving = true;

		try {
			const data = new FormData();
			data.append('name', formName.trim());
			data.append('position', JSON.stringify(formPositions));
			data.append('status', formStatus);
			if (formJersey) data.append('jersey_number', formJersey);
			if (formPhoto && formPhoto[0]) data.append('photo', formPhoto[0]);

			await createPlayer(data);
			showForm = false;
			formName = '';
			formPositions = [];
			formJersey = '';
			formPhoto = null;
			await loadPlayers();
		} catch (e) {
			console.error('Failed to create player:', e);
			alert('Fout bij aanmaken speler');
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Spelers - SideLine</title>
</svelte:head>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Spelers</h2>
		<button class="btn-primary" on:click={() => (showForm = !showForm)}>
			{showForm ? '✕ Sluiten' : '+ Speler'}
		</button>
	</div>

	<!-- Add Player Form -->
	{#if showForm}
		<form class="card space-y-3" on:submit|preventDefault={handleSubmit}>
			<div>
				<label class="label" for="name">Naam *</label>
				<input id="name" class="input" type="text" bind:value={formName} required placeholder="Volledige naam" />
			</div>

			<div class="grid grid-cols-2 gap-3">
				<div>
					<label class="label">Positie(s)</label>
					<div class="space-y-1.5">
						{#each allPositions as [value, label]}
							<label class="flex items-center gap-2 cursor-pointer">
								<input
									type="checkbox"
									checked={formPositions.includes(value)}
									on:change={() => togglePosition(value)}
									class="w-5 h-5 rounded border-gray-300 dark:border-gray-600 text-primary-600 focus:ring-primary-500 dark:bg-gray-800"
								/>
								<span class="text-sm">{label}</span>
							</label>
						{/each}
					</div>
				</div>
				<div>
					<label class="label" for="jersey">Rugnummer</label>
					<input id="jersey" class="input" type="number" bind:value={formJersey} min="1" max="99" />
				</div>
			</div>

			<div>
				<label class="label" for="photo">Foto</label>
				<input id="photo" class="input" type="file" accept="image/*" bind:files={formPhoto} />
			</div>

			<button type="submit" class="btn-primary w-full" disabled={saving}>
				{saving ? 'Opslaan...' : 'Speler toevoegen'}
			</button>
		</form>
	{/if}

	<!-- Player List -->
	{#if loading}
		<div class="flex justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
		</div>
	{:else if players.length === 0}
		<div class="card text-center py-8 text-gray-500 dark:text-gray-400 dark:text-gray-500">
			
			<p>Nog geen spelers toegevoegd</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each players as player}
				<a href="{base}/players/{player.id}" class="card flex items-center gap-3 hover:shadow-md transition-shadow">
					<!-- Avatar -->
					<div class="w-12 h-12 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden flex-shrink-0">
						{#if player.photo}
							<img
								src={getFileUrl(player, player.photo)}
								alt={player.name}
								class="w-full h-full object-cover"
							/>
						{:else}
							<span class="text-primary-600 font-bold text-lg">
								{player.name.charAt(0).toUpperCase()}
							</span>
						{/if}
					</div>

					<!-- Info -->
					<div class="flex-1 min-w-0">
						<div class="flex items-center gap-2">
							<span class="font-semibold text-gray-800 truncate">{player.name}</span>
							{#if player.jersey_number}
								<span class="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">
									#{player.jersey_number}
								</span>
							{/if}
						</div>
						<div class="text-sm text-gray-500 dark:text-gray-400 dark:text-gray-500">
							{(player.position || []).map(p => POSITION_LABELS[p] || p).join(', ') || '—'}
						</div>
					</div>

					<!-- Status badge -->
					<span class="text-xs px-2 py-1 rounded-full {
						player.status === 'active' ? 'bg-green-100 text-green-700' :
						player.status === 'injured' ? 'bg-red-100 text-red-700' :
						'bg-gray-100 text-gray-700'
					}">
						{STATUS_LABELS[player.status]}
					</span>
				</a>
			{/each}
		</div>
	{/if}
</div>
