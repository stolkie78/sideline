<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { pb } from '$lib/pocketbase';

	let status: 'loading' | 'valid' | 'expired' | 'error' | 'accepted' = 'loading';
	let invitation: any = null;
	let clubName = '';
	let errorMsg = '';

	// Registration form
	let email = '';
	let password = '';
	let passwordConfirm = '';
	let name = '';
	let registering = false;
	let regError = '';

	onMount(async () => {
		const token = $page.params.token;
		try {
			// Resolved server side: the invitations collection is not readable
			// from the browser, and the token itself is the only credential.
			const res = await fetch(`${base}/api/invite/accept?token=${encodeURIComponent(token ?? '')}`);
			if (res.status === 404 || res.status === 410) {
				status = 'expired';
				return;
			}
			if (!res.ok) throw new Error((await res.json())?.error || 'Kon uitnodiging niet laden');

			invitation = await res.json();
			email = invitation.email;
			clubName = invitation.clubName;

			// If the user is already logged in, auto-accept
			if (pb.authStore.isValid) {
				await acceptInvitation();
				return;
			}

			status = 'valid';
		} catch (e: any) {
			status = 'error';
			errorMsg = e?.message || 'Kon uitnodiging niet laden';
		}
	});

	async function acceptInvitation() {
		try {
			// Granting access happens server side with superuser rights — the
			// invitee must not be able to write club_access themselves.
			const res = await fetch(`${base}/api/invite/accept`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ token: $page.params.token, userId: pb.authStore.record?.id })
			});
			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				if (res.status === 404 || res.status === 410) {
					status = 'expired';
					return;
				}
				throw new Error(err?.error || 'Fout bij accepteren');
			}

			status = 'accepted';
			setTimeout(() => goto(`${base}/`), 2000);
		} catch (e: any) {
			regError = e?.message || 'Fout bij accepteren';
		}
	}

	async function handleRegister() {
		if (!password || password !== passwordConfirm) {
			regError = 'Wachtwoorden komen niet overeen';
			return;
		}
		if (password.length < 8) {
			regError = 'Wachtwoord moet minimaal 8 tekens zijn';
			return;
		}
		registering = true;
		regError = '';
		try {
			// Create user account
			await pb.collection('users').create({
				email,
				password,
				passwordConfirm,
				name: name || email.split('@')[0],
				emailVisibility: true
			});

			// Login
			await pb.collection('users').authWithPassword(email, password);

			// Accept invitation
			await acceptInvitation();
		} catch (e: any) {
			if (e?.data?.data?.email?.code === 'validation_invalid_email_value' ||
				e?.message?.includes('already exists')) {
				regError = 'Dit emailadres is al geregistreerd. Log in en open de uitnodigingslink opnieuw.';
			} else {
				regError = e?.message || 'Registratie mislukt';
			}
		} finally {
			registering = false;
		}
	}

	async function handleLoginAndAccept() {
		registering = true;
		regError = '';
		try {
			await pb.collection('users').authWithPassword(email, password);
			await acceptInvitation();
		} catch (e: any) {
			regError = e?.message || 'Inloggen mislukt';
		} finally {
			registering = false;
		}
	}
</script>

<div class="min-h-screen bg-gray-100 dark:bg-gray-900 flex items-center justify-center p-4">
	<div class="w-full max-w-md">
		<div class="text-center mb-6">
			<img src="{base}/logo.svg" alt="SetBaas" class="h-16 mx-auto mb-2" />
		</div>

		{#if status === 'loading'}
			<div class="card text-center">
				<p class="text-gray-600 dark:text-gray-400">⏳ Uitnodiging laden...</p>
			</div>
		{:else if status === 'expired'}
			<div class="card text-center">
				<h2 class="text-xl font-bold text-red-600 mb-2">❌ Uitnodiging verlopen</h2>
				<p class="text-gray-600 dark:text-gray-400">Deze uitnodiging is niet meer geldig. Vraag een nieuwe aan bij je coach.</p>
				<a href="{base}/login" class="btn-primary inline-block mt-4">Naar login</a>
			</div>
		{:else if status === 'error'}
			<div class="card text-center">
				<h2 class="text-xl font-bold text-red-600 mb-2">⚠️ Fout</h2>
				<p class="text-gray-600 dark:text-gray-400">{errorMsg}</p>
			</div>
		{:else if status === 'accepted'}
			<div class="card text-center">
				<h2 class="text-xl font-bold text-green-600 mb-2">✅ Welkom bij {clubName}!</h2>
				<p class="text-gray-600 dark:text-gray-400">Je hebt nu toegang. Je wordt doorgestuurd...</p>
			</div>
		{:else if status === 'valid'}
			<div class="card space-y-4">
				<h2 class="text-xl font-bold text-gray-900 dark:text-gray-100 text-center">
					🏐 Uitnodiging voor {clubName}
				</h2>
				<p class="text-center text-gray-600 dark:text-gray-400">
					Je bent uitgenodigd als <strong class="text-primary-600">{invitation.role === 'admin' ? 'Admin' : invitation.role === 'user' ? 'Gebruiker' : 'Lezer'}</strong>
				</p>

				<div class="border-t dark:border-gray-700 pt-4 space-y-3">
					<h3 class="font-semibold text-gray-800 dark:text-gray-200">Maak je account aan</h3>

					<div>
						<label class="label">Email</label>
						<input class="input" type="email" bind:value={email} disabled />
					</div>
					<div>
						<label class="label">Naam</label>
						<input class="input" type="text" bind:value={name} placeholder="Je naam" />
					</div>
					<div>
						<label class="label">Wachtwoord</label>
						<input class="input" type="password" bind:value={password} placeholder="Minimaal 8 tekens" />
					</div>
					<div>
						<label class="label">Bevestig wachtwoord</label>
						<input class="input" type="password" bind:value={passwordConfirm} placeholder="Herhaal wachtwoord" />
					</div>

					{#if regError}
						<p class="text-sm text-red-500">{regError}</p>
					{/if}

					<button class="btn-primary w-full py-3" on:click={handleRegister} disabled={registering}>
						{registering ? 'Bezig...' : 'Account aanmaken & accepteren'}
					</button>

					<div class="text-center text-sm text-gray-500 dark:text-gray-400">
						Al een account? <button class="text-primary-600 hover:underline" on:click={handleLoginAndAccept}>Log in</button>
					</div>
				</div>
			</div>
		{/if}
	</div>
</div>
