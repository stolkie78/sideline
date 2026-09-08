<script lang="ts">
	// Personal player landing page. Reachable via the "Mijn training" nav item
	// for anyone flagged `is_player` on the current club — including coaches
	// or admins who also play — regardless of their permission role. Viewers
	// see the same content directly on the main dashboard ("/").
	import PlayerDashboard from '$lib/components/PlayerDashboard.svelte';
</script>

<PlayerDashboard />
