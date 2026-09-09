<script lang="ts">
	import { linkedPlayer } from '$lib/stores/role';
</script>

<svelte:head>
	<title>SetBaas - Ouderdashboard</title>
</svelte:head>

<!--
	Placeholder: the parent role exists in the access model and can be selected,
	but its dashboard has not been designed yet. Deliberately kept blank rather
	than showing the coach or player dashboard, which would expose the wrong
	data to a parent.
-->
<div class="card text-center py-12">
	<p class="text-4xl mb-3">👨‍👩‍👦</p>
	<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">Ouderdashboard</h2>
	<p class="text-gray-500 dark:text-gray-400 mt-2">
		Dit onderdeel is nog in ontwikkeling.<br />
		Binnenkort vind je hier de informatie over je kind.
	</p>
</div>
