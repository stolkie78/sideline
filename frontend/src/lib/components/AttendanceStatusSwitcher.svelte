<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { AttendanceStatus } from '$lib/types';
	import { ATTENDANCE_LABELS, ATTENDANCE_STYLES, ATTENDANCE_CYCLE_ORDER, ATTENDANCE_STATUSES_WITH_REASON } from '$lib/types';

	// Tap-to-cycle attendance status switcher used across the training
	// check-in/check-out flows. Always starts on "present" (green) by
	// default; tapping the row cycles through the other statuses. Absent
	// and late reveal a free-text reason field underneath.
	export let label: string;
	export let sublabel: string | undefined = undefined;
	export let status: AttendanceStatus = 'present';
	export let reason: string = '';

	const dispatch = createEventDispatcher<{ change: AttendanceStatus; reason: string }>();

	function cycle() {
		const idx = ATTENDANCE_CYCLE_ORDER.indexOf(status);
		const next = ATTENDANCE_CYCLE_ORDER[(idx + 1) % ATTENDANCE_CYCLE_ORDER.length];
		dispatch('change', next);
	}

	$: needsReason = ATTENDANCE_STATUSES_WITH_REASON.includes(status);
	$: styles = ATTENDANCE_STYLES[status];
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
			{ATTENDANCE_LABELS[status]}
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
