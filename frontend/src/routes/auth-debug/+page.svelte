<script lang="ts">
	import { pb } from '$lib/pocketbase';
	import { authUser, isAuthenticated } from '$lib/stores/auth';
	import { onMount } from 'svelte';

	let debugInfo = '';
	let loginResult = '';

	onMount(() => {
		updateDebug();
	});

	function updateDebug() {
		const model = (pb.authStore as any).record || (pb.authStore as any).model;
		debugInfo = JSON.stringify({
			isValid: pb.authStore.isValid,
			token: pb.authStore.token ? pb.authStore.token.substring(0, 20) + '...' : null,
			hasRecord: !!(pb.authStore as any).record,
			hasModel: !!(pb.authStore as any).model,
			modelId: model?.id || null,
			modelEmail: model?.email || null,
			storeUser: $authUser ? { id: $authUser.id, email: $authUser.email } : null,
			isAuthenticated: $isAuthenticated
		}, null, 2);
	}

	async function testLogin() {
		try {
			const result = await pb.collection('users').authWithPassword('coach@setbaas.app', 'SetBaas2026!');
			loginResult = 'SUCCESS: ' + JSON.stringify({ id: result.record?.id, email: result.record?.email, token: result.token?.substring(0, 20) });
			updateDebug();
		} catch (e: any) {
			loginResult = 'ERROR: ' + e.message;
		}
	}
</script>

<div class="p-8 font-mono text-sm">
	<h1 class="text-2xl mb-4">Auth Debug</h1>
	
	<h2 class="text-lg font-bold mt-4">Current State:</h2>
	<pre class="bg-gray-100 p-4 rounded mb-4 whitespace-pre-wrap">{debugInfo}</pre>
	
	<button on:click={testLogin} class="bg-blue-500 text-white px-4 py-2 rounded mb-4">
		Test Login (coach@setbaas.app)
	</button>
	
	<h2 class="text-lg font-bold mt-4">Login Result:</h2>
	<pre class="bg-gray-100 p-4 rounded whitespace-pre-wrap">{loginResult}</pre>
	
	<button on:click={() => { window.location.href = '/'; }} class="bg-green-500 text-white px-4 py-2 rounded mt-4">
		Navigate to / (full reload)
	</button>
</div>
