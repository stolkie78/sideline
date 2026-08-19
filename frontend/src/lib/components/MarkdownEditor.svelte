<script lang="ts">
	import { marked } from 'marked';
	import { createEventDispatcher } from 'svelte';

	export let value = '';
	export let placeholder = 'Schrijf je training beschrijving... (Markdown ondersteund)';
	export let minRows = 8;

	let showPreview = false;
	let textarea: HTMLTextAreaElement;

	const dispatch = createEventDispatcher();

	$: renderedHtml = marked(value || '', { breaks: true });

	function insertAtCursor(before: string, after = '') {
		if (!textarea) return;
		const start = textarea.selectionStart;
		const end = textarea.selectionEnd;
		const selected = value.slice(start, end);
		const insertion = before + (selected || 'tekst') + after;
		value = value.slice(0, start) + insertion + value.slice(end);
		dispatch('change', value);
		// Restore cursor position
		setTimeout(() => {
			textarea.focus();
			const newPos = start + before.length + (selected || 'tekst').length;
			textarea.setSelectionRange(newPos, newPos);
		}, 0);
	}

	function insertLink() {
		const url = prompt('URL invoeren:', 'https://');
		if (url) {
			insertAtCursor('[', `](${url})`);
		}
	}

	function insertImage() {
		const url = prompt('Afbeelding URL invoeren:', 'https://');
		if (url) {
			const alt = prompt('Beschrijving (alt tekst):', 'afbeelding');
			value = value + `\n![${alt || 'afbeelding'}](${url})\n`;
			dispatch('change', value);
		}
	}

	function handleInput() {
		dispatch('change', value);
	}
</script>

<div class="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
	<!-- Toolbar -->
	<div class="flex items-center gap-1 px-2 py-1.5 bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex-wrap">
		<button type="button" class="toolbar-btn" title="Kop" on:click={() => insertAtCursor('## ', '\n')}>
			<span class="font-bold text-xs">H</span>
		</button>
		<button type="button" class="toolbar-btn" title="Vet" on:click={() => insertAtCursor('**', '**')}>
			<span class="font-bold text-xs">B</span>
		</button>
		<button type="button" class="toolbar-btn" title="Cursief" on:click={() => insertAtCursor('*', '*')}>
			<span class="italic text-xs">I</span>
		</button>
		<span class="w-px h-4 bg-gray-300 dark:bg-gray-600 mx-1"></span>
		<button type="button" class="toolbar-btn" title="Lijst" on:click={() => insertAtCursor('- ', '\n')}>
			<span class="text-xs">☰</span>
		</button>
		<button type="button" class="toolbar-btn" title="Genummerde lijst" on:click={() => insertAtCursor('1. ', '\n')}>
			<span class="text-xs">1.</span>
		</button>
		<button type="button" class="toolbar-btn" title="Checkbox" on:click={() => insertAtCursor('- [ ] ', '\n')}>
			<span class="text-xs">☑</span>
		</button>
		<span class="w-px h-4 bg-gray-300 dark:bg-gray-600 mx-1"></span>
		<button type="button" class="toolbar-btn" title="Link" on:click={insertLink}>
			<span class="text-xs">🔗</span>
		</button>
		<button type="button" class="toolbar-btn" title="Afbeelding" on:click={insertImage}>
			<span class="text-xs">🖼️</span>
		</button>
		<span class="w-px h-4 bg-gray-300 dark:bg-gray-600 mx-1"></span>
		<button type="button" class="toolbar-btn" title="Scheidingslijn" on:click={() => { value += '\n---\n'; dispatch('change', value); }}>
			<span class="text-xs">—</span>
		</button>

		<!-- Preview toggle -->
		<div class="ml-auto">
			<button type="button"
				class="text-xs px-2 py-1 rounded-lg transition-colors {showPreview ? 'bg-primary-100 text-primary-700 dark:bg-primary-900/30 dark:text-primary-400' : 'text-gray-500 hover:text-gray-700 dark:text-gray-400'}"
				on:click={() => (showPreview = !showPreview)}
			>
				{showPreview ? 'Bewerken' : 'Preview'}
			</button>
		</div>
	</div>

	<!-- Editor / Preview -->
	{#if showPreview}
		<div class="prose prose-sm dark:prose-invert max-w-none p-4 min-h-[200px] bg-white dark:bg-gray-900">
			{#if value}
				{@html renderedHtml}
			{:else}
				<p class="text-gray-400 italic">Geen inhoud</p>
			{/if}
		</div>
	{:else}
		<textarea
			bind:this={textarea}
			bind:value
			on:input={handleInput}
			{placeholder}
			rows={minRows}
			class="w-full px-4 py-3 bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 text-sm font-mono resize-y focus:outline-none"
		></textarea>
	{/if}
</div>

<style>
	.toolbar-btn {
		@apply w-7 h-7 flex items-center justify-center rounded-lg
			text-gray-600 dark:text-gray-400
			hover:bg-gray-200 dark:hover:bg-gray-700
			transition-colors cursor-pointer;
	}

	:global(.prose img) {
		@apply rounded-lg max-w-full;
	}
	:global(.prose a) {
		@apply text-primary-600 dark:text-primary-400 underline;
	}
</style>
