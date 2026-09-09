<script lang="ts">
	// Personal player landing page. Reachable via the "Mijn training" nav item
	// for anyone flagged `is_player` on the current club — including coaches or
	// admins who also play. Someone whose active role is "player" already gets
	// this dashboard on "/", so this route exists for the coach-who-also-plays
	// case, where the main dashboard shows the team view instead.
	import PlayerDashboard from '$lib/components/PlayerDashboard.svelte';
</script>

<PlayerDashboard />
