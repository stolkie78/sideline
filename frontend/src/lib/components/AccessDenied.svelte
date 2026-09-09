<script lang="ts">
	export let title = 'Geen toegang';
	export let message = 'Je hebt niet de juiste rechten voor deze pagina.';
</script>

<div class="card text-center py-12">
	<p class="text-4xl mb-3">🔒</p>
	<h2 class="text-xl font-bold text-gray-800 dark:text-gray-200">{title}</h2>
	<p class="text-gray-500 dark:text-gray-400 mt-2">{message}</p>
</div>
