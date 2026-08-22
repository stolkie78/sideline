<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { getPlayer, updatePlayer, deletePlayer, getFileUrl } from '$lib/pocketbase';
	import type { Player, PlayerPosition } from '$lib/types';
	import { POSITION_LABELS, STATUS_LABELS } from '$lib/types';

	let player: Player | null = null;
	let loading = true;
	let saving = false;

	// Form state
	let formName = '';
	let formPositions: PlayerPosition[] = [];
	let formStatus = 'active';
	let formJersey = '';
	let formEmail = '';
	let formPhoto: FileList | null = null;

	const allPositions = Object.entries(POSITION_LABELS) as [PlayerPosition, string][];

	function togglePosition(pos: PlayerPosition) {
		if (formPositions.includes(pos)) {
			formPositions = formPositions.filter(p => p !== pos);
		} else {
			formPositions = [...formPositions, pos];
		}
	}

	onMount(async () => {
		try {
			const id = $page.params.id;
			player = await getPlayer(id);
			formName = player.name;
			formPositions = player.position || [];
			formStatus = player.status || 'active';
			formJersey = player.jersey_number?.toString() || '';
			formEmail = player.email || '';
		} catch (e) {
			console.error('Failed to load player:', e);
		} finally {
			loading = false;
		}
	});

	async function handleSubmit() {
		if (!formName.trim() || !player) return;
		saving = true;

		try {
			const data = new FormData();
			data.append('name', formName.trim());
			for (const pos of formPositions) {
				data.append('position', pos);
			}
			if (formPositions.length === 0) {
				data.append('position', '');
			}
			data.append('status', formStatus);
			if (formJersey) data.append('jersey_number', formJersey);
			data.append('email', formEmail.trim());
			if (formPhoto && formPhoto[0]) data.append('photo', formPhoto[0]);

			await updatePlayer(player.id, data);
			goto(`${base}/players/${player.id}`);
		} catch (e) {
			console.error('Failed to update player:', e);
			alert('Fout bij bijwerken speler');
		} finally {
			saving = false;
		}
	}

	async function handleDelete() {
		if (!player) return;
		if (!confirm(`Weet je zeker dat je ${player.name} wilt verwijderen?`)) return;
		try {
			await deletePlayer(player.id);
			goto(`${base}/players`);
		} catch (e) {
			console.error('Failed to delete player:', e);
			alert('Fout bij verwijderen (mogelijk zijn er nog gekoppelde gegevens)');
		}
	}
</script>

<svelte:head>
	<title>Bewerk Speler - SetBaas</title>
</svelte:head>

{#if loading}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if player}
	<form class="space-y-4" on:submit|preventDefault={handleSubmit}>
		<div class="flex justify-between items-center">
			<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Bewerk Speler</h2>
			<button type="button" class="text-red-500 hover:text-red-700 text-sm font-semibold" on:click={handleDelete}>
				🗑️ Verwijderen
			</button>
		</div>

		<div class="card space-y-3">
			<!-- Current photo -->
			{#if player.photo}
				<div class="flex items-center gap-3">
					<img src={getFileUrl(player, player.photo)} alt={player.name}
						class="w-16 h-16 rounded-full object-cover" />
					<span class="text-xs text-gray-500 dark:text-gray-400">Huidige foto</span>
				</div>
			{/if}

			<div>
				<label class="label" for="name">Naam *</label>
				<input id="name" class="input" type="text" bind:value={formName} required placeholder="Volledige naam" />
			</div>

			<div>
				<label class="label" for="email">Email (voor login als teamlid)</label>
				<input id="email" class="input" type="email" bind:value={formEmail} placeholder="speler@email.com" />
				{#if player?.user_id}
					<p class="text-xs text-green-600 dark:text-green-400 mt-1">✓ Gekoppeld aan gebruikersaccount</p>
				{/if}
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
				<div class="space-y-3">
					<div>
						<label class="label" for="jersey">Rugnummer</label>
						<input id="jersey" class="input" type="number" bind:value={formJersey} min="1" max="999" />
					</div>
					<div>
						<label class="label" for="status">Status</label>
						<select id="status" class="input" bind:value={formStatus}>
							{#each Object.entries(STATUS_LABELS) as [value, label]}
								<option {value}>{label}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>

			<div>
				<label class="label" for="photo">Nieuwe foto</label>
				<input id="photo" class="input" type="file" accept="image/*" bind:files={formPhoto} />
			</div>
		</div>

		<button type="submit" class="btn-primary w-full" disabled={saving}>
			{saving ? 'Opslaan...' : '✓ Wijzigingen opslaan'}
		</button>
		<a href="{base}/players/{player.id}" class="btn-secondary w-full text-center">Annuleren</a>
	</form>
{:else}
	<p class="text-center text-gray-500 py-8">Speler niet gevonden</p>
{/if}
