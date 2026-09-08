<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { QuestionnaireQuestion } from '$lib/types';

	export let questions: QuestionnaireQuestion[] = [];
	export let answers: Record<string, string | number> = {};
	export let readonly = false;
	export let saving = false;

	const dispatch = createEventDispatcher<{ submit: Record<string, string | number> }>();

	// Work on a local copy so cancelling doesn't mutate the parent's state.
	let local: Record<string, string | number> = { ...answers };

	function submit() {
		dispatch('submit', local);
	}

	$: allAnswered = questions.every((q) => {
		const v = local[q.id];
		return v !== undefined && v !== null && String(v).trim() !== '';
	});
</script>

<div class="space-y-4">
	{#each questions as q, i (q.id)}
		<div class="space-y-1.5">
			<p class="text-sm font-medium text-gray-700 dark:text-gray-300">{i + 1}. {q.text}</p>
			{#if q.type === 'text'}
				<textarea
					class="input text-sm w-full"
					rows="2"
					disabled={readonly}
					bind:value={local[q.id]}
				/>
			{:else if q.type === 'choice'}
				<div class="flex flex-wrap gap-2">
					{#each q.options || [] as opt}
						<button
							type="button"
							disabled={readonly}
							class="px-3 py-1.5 rounded-full text-sm font-medium border transition-colors {
								local[q.id] === opt
									? 'bg-primary-600 text-white border-primary-600'
									: 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border-gray-300 dark:border-gray-600'
							}"
							on:click={() => (local[q.id] = opt)}
						>
							{opt}
						</button>
					{/each}
				</div>
			{:else if q.type === 'scale'}
				<div class="flex items-center gap-2 flex-wrap">
					{#each Array.from({ length: (q.scale_max ?? 5) - (q.scale_min ?? 1) + 1 }, (_, n) => (q.scale_min ?? 1) + n) as n}
						<button
							type="button"
							disabled={readonly}
							class="w-9 h-9 rounded-lg text-sm font-bold border transition-colors {
								local[q.id] === n
									? 'bg-primary-600 text-white border-primary-600'
									: 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border-gray-300 dark:border-gray-600'
							}"
							on:click={() => (local[q.id] = n)}
						>
							{n}
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{/each}

	{#if !readonly}
		<button type="button" class="btn-primary w-full" disabled={!allAnswered || saving} on:click={submit}>
			{saving ? 'Versturen...' : 'Versturen'}
		</button>
	{/if}
</div>
