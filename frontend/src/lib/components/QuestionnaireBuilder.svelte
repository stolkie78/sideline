<script lang="ts">
	import type { QuestionnaireQuestion, QuestionType } from '$lib/types';
	import { QUESTION_TYPE_LABELS } from '$lib/types';

	// Two-way bound list of questions — parent owns the array, this component
	// only mutates it in place then reassigns to trigger reactivity.
	export let questions: QuestionnaireQuestion[] = [];

	function addQuestion() {
		questions = [
			...questions,
			{ id: crypto.randomUUID(), type: 'text', text: '', options: [], scale_min: 1, scale_max: 5 },
		];
	}

	function removeQuestion(id: string) {
		questions = questions.filter((q) => q.id !== id);
	}

	function updateType(id: string, type: string) {
		questions = questions.map((q) => (q.id === id ? { ...q, type: type as QuestionType } : q));
	}

	function addOption(id: string) {
		questions = questions.map((q) =>
			q.id === id ? { ...q, options: [...(q.options || []), ''] } : q
		);
	}

	function removeOption(id: string, idx: number) {
		questions = questions.map((q) =>
			q.id === id ? { ...q, options: (q.options || []).filter((_, i) => i !== idx) } : q
		);
	}
</script>

<div class="space-y-3">
	{#each questions as q, i (q.id)}
		<div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3 space-y-2">
			<div class="flex items-center gap-2">
				<span class="text-xs font-bold text-gray-400 w-5">{i + 1}.</span>
				<input
					class="input flex-1 text-sm"
					type="text"
					placeholder="Vraagtekst"
					bind:value={q.text}
				/>
				<button
					type="button"
					class="p-2 text-gray-400 hover:text-red-600"
					title="Vraag verwijderen"
					on:click={() => removeQuestion(q.id)}
				>
					🗑
				</button>
			</div>
			<div class="flex gap-2 pl-7">
				<select class="input text-sm" value={q.type} on:change={(e) => updateType(q.id, e.currentTarget.value)}>
					{#each Object.entries(QUESTION_TYPE_LABELS) as [value, label]}
						<option {value}>{label}</option>
					{/each}
				</select>
			</div>

			{#if q.type === 'choice'}
				<div class="pl-7 space-y-1">
					{#each q.options || [] as _, oi}
						<div class="flex gap-2">
							<input
								class="input text-sm flex-1"
								type="text"
								placeholder={`Optie ${oi + 1}`}
								bind:value={q.options[oi]}
							/>
							<button type="button" class="px-2 text-gray-400 hover:text-red-600" on:click={() => removeOption(q.id, oi)}>✕</button>
						</div>
					{/each}
					<button type="button" class="text-xs font-medium text-primary-600 hover:text-primary-800" on:click={() => addOption(q.id)}>
						+ Optie toevoegen
					</button>
				</div>
			{:else if q.type === 'scale'}
				<div class="pl-7 flex items-center gap-2 text-sm">
					<label class="text-xs text-gray-500 dark:text-gray-400">Van</label>
					<input class="input text-sm w-16" type="number" bind:value={q.scale_min} />
					<label class="text-xs text-gray-500 dark:text-gray-400">tot</label>
					<input class="input text-sm w-16" type="number" bind:value={q.scale_max} />
				</div>
			{/if}
		</div>
	{/each}

	<button type="button" class="btn-secondary w-full text-sm" on:click={addQuestion}>
		+ Vraag toevoegen
	</button>
</div>
