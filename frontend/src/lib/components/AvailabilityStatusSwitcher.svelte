<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { AvailabilityStatus } from '$lib/types';
	import { AVAILABILITY_LABELS, AVAILABILITY_STYLES, AVAILABILITY_CYCLE_ORDER, AVAILABILITY_STATUSES_WITH_REASON } from '$lib/types';

	// Tap-to-cycle availability status switcher used on the player dashboard
	// so a player can indicate whether they plan to attend a training/match.
	// This is the player's own plan, separate from the trainer-recorded
	// AttendanceStatus (checked in/out afterwards). Always starts on
	// "available" (green) by default; tapping cycles to the next status.
	export let label: string;
	export let sublabel: string | undefined = undefined;
	export let status: AvailabilityStatus | null = null;
	export let reason: string = '';

	const dispatch = createEventDispatcher<{ change: AvailabilityStatus; reason: string }>();

	function cycle() {
		const current = status ?? 'available';
		const idx = AVAILABILITY_CYCLE_ORDER.indexOf(current);
		const next = AVAILABILITY_CYCLE_ORDER[(idx + 1) % AVAILABILITY_CYCLE_ORDER.length];
		dispatch('change', next);
	}

	$: effectiveStatus = status ?? 'available';
	$: needsReason = AVAILABILITY_STATUSES_WITH_REASON.includes(effectiveStatus);
	$: styles = AVAILABILITY_STYLES[effectiveStatus];
</script>

<div class="space-y-1.5">
	<button
		type="button"
		class="w-full flex items-center gap-3 p-3 rounded-xl transition-all active:scale-[0.98] {styles.card}"
		on:click={cycle}
	>
		<span class="flex-1 text-left font-medium text-gray-800 dark:text-gray-200">
			{label}
			{#if sublabel}
				<span class="text-xs text-gray-400 ml-1">{sublabel}</span>
			{/if}
		</span>
		<span class="text-xs font-semibold px-2 py-1 rounded-lg {styles.badge}">
			{AVAILABILITY_LABELS[effectiveStatus]}
		</span>
	</button>
	{#if needsReason}
		<input
			type="text"
			class="input w-full text-sm"
			placeholder="Reden (optioneel)..."
			value={reason}
			on:input={(e) => dispatch('reason', e.currentTarget.value)}
		/>
	{/if}
</div>
