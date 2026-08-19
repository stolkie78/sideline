<script lang="ts">
	import { goto } from '$app/navigation';
	import { authUser } from '$lib/stores/auth';
	import { pb } from '$lib/pocketbase';
	import { tick } from 'svelte';

	let loading = false;
	let error = '';

	// Email/password form
	let email = '';
	let password = '';
	let showEmailLogin = false;

	async function loginWithGoogle() {
		loading = true;
		error = '';
		try {
			await authUser.login();
			await tick();
			window.location.href = base + '/';
		} catch (e: any) {
			console.error('Login failed:', e);
			error = e?.message || 'Inloggen mislukt. Is Google OAuth geconfigureerd?';
		} finally {
			loading = false;
		}
	}

	async function loginWithEmail() {
		if (!email.trim() || !password) return;
		loading = true;
		error = '';
		try {
			await pb.collection('users').authWithPassword(email.trim(), password);
			const model = (pb.authStore as any).record || (pb.authStore as any).model;
			authUser.set(model as any);
			await tick();
			window.location.href = base + '/';
		} catch (e: any) {
			console.error('Email login failed:', e);
			error = 'Onjuist e-mailadres of wachtwoord.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Inloggen - SideLine</title>
</svelte:head>

<div class="flex flex-col items-center justify-center min-h-[70vh] px-4">
	<div class="card w-full max-w-sm text-center space-y-6 py-8">
		<!-- Logo -->
		<img
			src="/logo.svg"
			alt="SideLine"
			class="h-24 w-24 mx-auto rounded-2xl object-cover shadow-lg dark:shadow-none dark:drop-shadow-[0_0_12px_rgba(255,255,255,0.15)]"
		/>

		<div>
			<h1 class="text-2xl font-bold text-gray-800 dark:text-gray-200">SideLine</h1>
			<p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
				Volleybal Team Management
			</p>
		</div>

		{#if error}
			<div class="bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-400 text-sm rounded-xl px-4 py-3">
				{error}
			</div>
		{/if}

		<!-- Google login -->
		<button
			on:click={loginWithGoogle}
			disabled={loading}
			class="btn w-full py-3.5 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600
				   text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700
				   shadow-sm font-medium text-base gap-3"
		>
			{#if loading && !showEmailLogin}
				<div class="animate-spin rounded-full h-5 w-5 border-b-2 border-gray-600"></div>
				Bezig met inloggen...
			{:else}
				<svg class="w-5 h-5" viewBox="0 0 24 24">
					<path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
					<path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
					<path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
					<path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
				</svg>
				Inloggen met Google
			{/if}
		</button>

		<!-- Divider -->
		<div class="flex items-center gap-3">
			<div class="flex-1 border-t border-gray-200 dark:border-gray-700"></div>
			<span class="text-xs text-gray-400 dark:text-gray-500">of</span>
			<div class="flex-1 border-t border-gray-200 dark:border-gray-700"></div>
		</div>

		<!-- Email/password login -->
		{#if showEmailLogin}
			<form class="space-y-3 text-left" on:submit|preventDefault={loginWithEmail}>
				<div>
					<label class="label" for="login-email">E-mail</label>
					<input id="login-email" class="input" type="email" bind:value={email} required placeholder="je@email.nl" />
				</div>
				<div>
					<label class="label" for="login-pass">Wachtwoord</label>
					<input id="login-pass" class="input" type="password" bind:value={password} required placeholder="••••••••" />
				</div>
				<button type="submit" class="btn-primary w-full py-3" disabled={loading}>
					{loading ? 'Inloggen...' : 'Inloggen'}
				</button>
			</form>
		{:else}
			<button
				on:click={() => (showEmailLogin = true)}
				class="text-sm text-primary-600 dark:text-primary-400 hover:underline">
				Inloggen met e-mail & wachtwoord
			</button>
		{/if}

		<p class="text-xs text-gray-400 dark:text-gray-500">
			Alleen uitgenodigde teamleden kunnen inloggen.
		</p>
	</div>
</div>
