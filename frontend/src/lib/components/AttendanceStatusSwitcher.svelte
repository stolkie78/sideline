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
	<!--
		The label and the badge are two separate buttons rather than one row
		button, so the optional "action" slot can sit between them: a link
		nested inside a button is invalid and swallows its own clicks. Both
		buttons cycle, so the whole row stays tappable apart from the action.
	-->
	<div class="flex items-center gap-2 rounded-xl transition-all {styles.card}">
		<button
			type="button"
			class="flex-1 min-w-0 text-left font-medium text-gray-800 dark:text-gray-200 p-3 pr-0 rounded-l-xl active:scale-[0.98]"
			on:click={cycle}
		>
			{label}
			{#if sublabel}
				<span class="text-xs text-gray-400 ml-1">{sublabel}</span>
			{/if}
		</button>
		{#if $$slots.action}
			<slot name="action" />
		{/if}
		<button
			type="button"
			class="p-3 pl-0 rounded-r-xl active:scale-[0.98]"
			on:click={cycle}
			aria-label="Status wijzigen"
		>
			<span class="block text-xs font-semibold px-2 py-1 rounded-lg {styles.badge}">
				{ATTENDANCE_LABELS[status]}
			</span>
		</button>
	</div>
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
