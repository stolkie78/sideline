<script lang="ts">
	import { isAdmin, rolesLoaded } from '$lib/stores/role';
	import AccessDenied from '$lib/components/AccessDenied.svelte';
</script>

<!--
	Route guard for the whole /config subtree. Configuration is admin-only, and
	hiding the menu item alone is not enough — the URL must be protected too.
-->
{#if !$rolesLoaded}
	<div class="flex justify-center py-12">
		<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
	</div>
{:else if $isAdmin}
	<slot />
{:else}
	<AccessDenied message="Configuratie is alleen beschikbaar voor beheerders." />
{/if}
