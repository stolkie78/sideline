<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import type { PlayerCompetency, Competency } from '$lib/types';
	import { CATEGORY_LABELS } from '$lib/types';

	export let data: PlayerCompetency[] = [];
	export let competencies: Competency[] = [];

	let canvas: HTMLCanvasElement;
	let chart: any = null;

	// Group data by competency
	$: chartData = buildChartData(data);

	function buildChartData(records: PlayerCompetency[]) {
		const grouped: Record<string, { dates: string[]; ratings: number[]; label: string }> = {};

		for (const record of records) {
			const compId = record.competency;
			const compName = record.expand?.competency?.name || competencies.find(c => c.id === compId)?.name || compId;

			if (!grouped[compId]) {
				grouped[compId] = { dates: [], ratings: [], label: compName };
			}
			grouped[compId].dates.push(new Date(record.date).toLocaleDateString('nl-NL', { day: '2-digit', month: 'short' }));
			grouped[compId].ratings.push(record.rating);
		}

		return grouped;
	}

	const colors = [
		'#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6',
		'#ec4899', '#06b6d4', '#84cc16', '#f97316', '#6366f1',
	];

	async function renderChart() {
		if (!canvas || Object.keys(chartData).length === 0) return;

		const { Chart, registerables } = await import('chart.js');
		Chart.register(...registerables);

		if (chart) chart.destroy();

		const datasets = Object.values(chartData).map((group, i) => ({
			label: group.label,
			data: group.ratings,
			borderColor: colors[i % colors.length],
			backgroundColor: colors[i % colors.length] + '20',
			tension: 0.3,
			pointRadius: 5,
			pointHoverRadius: 7,
		}));

		// Use dates from the longest dataset
		const longestDates = Object.values(chartData).reduce(
			(longest, g) => (g.dates.length > longest.length ? g.dates : longest),
			[] as string[]
		);

		chart = new Chart(canvas, {
			type: 'line',
			data: { labels: longestDates, datasets },
			options: {
				responsive: true,
				maintainAspectRatio: false,
				scales: {
					y: {
						min: 0,
						max: 10,
						ticks: { stepSize: 1 },
						title: { display: true, text: 'Score' },
					},
				},
				plugins: {
					legend: {
						position: 'bottom',
						labels: { boxWidth: 12, padding: 8 },
					},
				},
				interaction: {
					intersect: false,
					mode: 'index',
				},
			},
		});
	}

	onMount(renderChart);
	afterUpdate(renderChart);
</script>

<div class="w-full h-64">
	<canvas bind:this={canvas}></canvas>
</div>
