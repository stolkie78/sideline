import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';
import { pb } from '$lib/pocketbase';
import type { RecordModel } from 'pocketbase';

// Toggle: set to true to require login, false for demo/open access
export const AUTH_ENABLED = true;

export interface AuthUser extends RecordModel {
	email: string;
	name: string;
	avatar?: string;
}

function getAuthModel(): AuthUser | null {
	if (!pb.authStore.isValid) return null;
	// SDK 0.21 uses .model, newer uses .record — support both
	const m = (pb.authStore as any).record || (pb.authStore as any).model;
	return m ? (m as unknown as AuthUser) : null;
}

// Reactive auth store
function createAuthStore() {
	const initial = browser ? getAuthModel() : null;
	const { subscribe, set } = writable<AuthUser | null>(initial);

	if (browser) {
		// Listen for auth changes
		pb.authStore.onChange(() => {
			set(getAuthModel());
		});
	}

	return {
		subscribe,
		set,
		login: async () => {
			const authMethods = await pb.collection('users').listAuthMethods();
			const googleProvider = authMethods.oauth2?.providers?.find(
				(p) => p.name === 'google'
			);

			if (!googleProvider) {
				throw new Error('Google OAuth niet geconfigureerd in PocketBase');
			}

			const authData = await pb.collection('users').authWithOAuth2({ provider: 'google' });
			set(getAuthModel());
			return authData;
		},
		logout: () => {
			pb.authStore.clear();
			set(null);
		},
	};
}

export const authUser = createAuthStore();
export const isAuthenticated = derived(authUser, ($user) => AUTH_ENABLED ? !!$user : true);
