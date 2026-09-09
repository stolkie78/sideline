<script lang="ts">
	import type { PlayerLoad } from '$lib/utils/load';

	export let load: PlayerLoad | null = null;
	export let title = '📊 Belasting';
	export let compact = false;

	// Grove richtlijn voor jeugdvolleybal; puur om de balk te schalen.
	const MAX_HOURS = 10;

	$: pct = load ? Math.min(100, (load.totalHoursPerWeek / MAX_HOURS) * 100) : 0;
	$: level = !load
		? ''
		: load.totalHoursPerWeek >= 8
			? 'hoog'
			: load.totalHoursPerWeek >= 5
				? 'gemiddeld'
				: 'laag';
	$: barColor =
		level === 'hoog' ? 'bg-red-500' : level === 'gemiddeld' ? 'bg-amber-500' : 'bg-emerald-500';
</script>

<div class="card space-y-3">
	<div class="flex items-baseline justify-between">
		<h3 class="font-semibold text-gray-800 dark:text-gray-200">{title}</h3>
		{#if load}
			<span class="text-xs text-gray-400">laatste {load.weeks} weken</span>
		{/if}
	</div>

	{#if !load}
		<p class="text-sm text-gray-500 dark:text-gray-400">Laden...</p>
	{:else if load.lines.length === 0}
		<p class="text-sm text-gray-500 dark:text-gray-400">
			Nog geen trainingen, wedstrijden of extra activiteiten geregistreerd.
		</p>
	{:else}
		<div>
			<div class="flex items-end gap-2">
				<span class="text-3xl font-bold text-gray-800 dark:text-gray-200">{load.totalHoursPerWeek}</span>
				<span class="text-sm text-gray-500 dark:text-gray-400 mb-1">uur per week ({level})</span>
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
							{line.hoursPerWeek} u/wk
						</span>
					</div>
				{/each}
			</div>
		{/if}

		<p class="text-xs text-gray-400">
			Gerekend met {load.trainingCount} bijgewoonde trainingen en {load.matchCount} wedstrijden,
			plus de extra activiteiten uit het spelersprofiel.
		</p>
	{/if}
</div>
