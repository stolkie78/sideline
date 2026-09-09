<script lang="ts">
	import type { PlayerLoad } from '$lib/utils/load';

	export let load: PlayerLoad | null = null;
	export let title = '📊 Belasting';
	export let compact = false;
	/** Toon vorige/volgende maand-knoppen (bijv. in het rapportageoverzicht). */
	export let showMonthNav = false;
	export let onPrevMonth: (() => void) | null = null;
	export let onNextMonth: (() => void) | null = null;

	// Grove richtlijn voor jeugdvolleybal per maand; puur om de balk te schalen.
	const MAX_HOURS = 40;

	$: pct = load ? Math.min(100, (load.totalHours / MAX_HOURS) * 100) : 0;
	$: level = !load ? '' : load.totalHours >= 32 ? 'hoog' : load.totalHours >= 20 ? 'gemiddeld' : 'laag';
	$: barColor =
		level === 'hoog' ? 'bg-red-500' : level === 'gemiddeld' ? 'bg-amber-500' : 'bg-emerald-500';
</script>

<div class="card space-y-3">
	<div class="flex items-baseline justify-between gap-2">
		<h3 class="font-semibold text-gray-800 dark:text-gray-200">{title}</h3>
		{#if load}
			<div class="flex items-center gap-1 text-xs text-gray-400">
				{#if showMonthNav}
					<button
						type="button"
						class="px-1.5 py-0.5 rounded hover:bg-gray-100 dark:hover:bg-gray-700"
						on:click={() => onPrevMonth?.()}
						aria-label="Vorige maand"
					>
						‹
					</button>
				{/if}
				<span class="capitalize">{load.month.label}</span>
				{#if showMonthNav}
					<button
						type="button"
						class="px-1.5 py-0.5 rounded hover:bg-gray-100 dark:hover:bg-gray-700"
						on:click={() => onNextMonth?.()}
						aria-label="Volgende maand"
					>
						›
					</button>
				{/if}
			</div>
		{/if}
	</div>

	{#if !load}
		<p class="text-sm text-gray-500 dark:text-gray-400">Laden...</p>
	{:else if load.lines.length === 0}
		<p class="text-sm text-gray-500 dark:text-gray-400">
			Geen trainingen, wedstrijden of extra activiteiten in deze maand.
		</p>
	{:else}
		<div>
			<div class="flex items-end gap-2">
				<span class="text-3xl font-bold text-gray-800 dark:text-gray-200">{load.totalHours}</span>
				<span class="text-sm text-gray-500 dark:text-gray-400 mb-1">uur deze maand ({level})</span>
			</div>
			<div class="w-full h-2 bg-gray-100 dark:bg-gray-700 rounded-full mt-2 overflow-hidden">
				<div class="h-full {barColor} rounded-full transition-all" style="width: {pct}%"></div>
			</div>
		</div>

		{#if !compact}
			<div class="space-y-1.5">
				{#each load.lines as line}
					<div class="flex items-center justify-between p-2 bg-gray-50 dark:bg-gray-800 rounded-lg">
						<div class="min-w-0">
							<p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">{line.label}</p>
							{#if line.detail}
								<p class="text-xs text-gray-500 dark:text-gray-400 truncate">{line.detail}</p>
							{/if}
						</div>
						<span class="text-sm font-semibold text-gray-700 dark:text-gray-300 whitespace-nowrap ml-3">
							{line.hours} u
						</span>
					</div>
				{/each}
			</div>
		{/if}

		<p class="text-xs text-gray-400">
			Geplande trainingen en wedstrijden min gemelde afwezigheid, plus de extra activiteiten uit
			het spelersprofiel.
		</p>
	{/if}
</div>
