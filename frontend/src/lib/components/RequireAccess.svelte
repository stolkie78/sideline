<script lang="ts">
	import { isAdmin, canEdit, rolesLoaded } from '$lib/stores/role';
	import AccessDenied from '$lib/components/AccessDenied.svelte';

	/**
	 * `admin` — configuration, clubs/teams/seasons and the player roster.
	 * `edit`  — day-to-day recording: trainings, matches, competency scores.
	 */
	export let level: 'admin' | 'edit' = 'edit';
	export let message = level === 'admin'
		? 'Deze pagina is alleen beschikbaar voor beheerders.'
		: 'Je hebt leesrechten. Alleen beheerders en gebruikers kunnen dit invullen.';

	$: allowed = level === 'admin' ? $isAdmin : $canEdit;
</script>

<!--
	Guards a route subtree. Hiding a button is not access control: without this
	the page is still reachable by typing its URL.
-->
{#if !$rolesLoaded}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if allowed}
	<slot />
{:else}
	<AccessDenied {message} />
{/if}
