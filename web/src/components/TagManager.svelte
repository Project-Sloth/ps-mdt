<script lang="ts">
	export let tags: string[];
	export let availableTags: string[];
	export let onAddTag: (tag: string) => void;
	export let onRemoveTag: (tag: string) => void;

	let newTag = "";

	function addTag() {
		if (newTag.trim()) {
			onAddTag(newTag.trim());
			newTag = "";
		}
	}

	function removeTag(tag: string) {
		onRemoveTag(tag);
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === "Enter") {
			event.preventDefault();
			addTag();
		}
	}
</script>

<section class="tag-manager" aria-label="Report tags">
	<div class="tag-header">
		<h3 class="tag-title">Tags</h3>
		<div class="tag-input-group">
			<label for="new-tag-input" class="sr-only">Add new tag</label>
			<input
				id="new-tag-input"
				type="text"
				bind:value={newTag}
				on:keydown={handleKeydown}
				placeholder="Add tag..."
				class="tag-input"
				aria-describedby="tag-instructions"
			/>
			<button
				type="button"
				on:click={addTag}
				disabled={!newTag.trim()}
				class="add-tag-btn"
				aria-label="Add tag"
			>
				Add
			</button>
		</div>
	</div>

	<div id="tag-instructions" class="sr-only">
		Press Enter or click Add button to add a new tag. Click the X button to
		remove tags.
	</div>

	{#if tags.length > 0}
		<div class="tags-container" role="list" aria-label="Current tags">
			{#each tags as tag}
				<div class="tag" role="listitem">
					<span class="tag-text">{tag}</span>
					<button
						type="button"
						on:click={() => removeTag(tag)}
						class="remove-tag-btn"
						aria-label="Remove {tag} tag"
					>
						×
					</button>
				</div>
			{/each}
		</div>
	{:else}
		<p class="no-tags">No tags added</p>
	{/if}

	{#if availableTags.length > 0}
		<div class="suggested-tags">
			<h4 class="suggested-title">Suggested Tags</h4>
			<div
				class="suggested-container"
				role="list"
				aria-label="Suggested tags"
			>
				{#each availableTags as tag}
					<button
						type="button"
						on:click={() => onAddTag(tag)}
						class="suggested-tag"
						disabled={tags.includes(tag)}
						aria-label="Add suggested tag: {tag}"
					>
						{tag}
					</button>
				{/each}
			</div>
		</div>
	{/if}
</section>

<style>
	.tag-manager {
		padding: 1rem;
		background: var(--surface-elevated);
		border-radius: 0.5rem;
		margin-bottom: 1rem;
	}

	.tag-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		gap: 1rem;
	}

	.tag-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: var(--text-primary);
		margin: 0;
	}

	.tag-input-group {
		display: flex;
		gap: 0.5rem;
	}

	.tag-input {
		padding: 0.375rem 0.75rem;
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		background: var(--surface-color);
		color: var(--text-primary);
		font-size: 0.875rem;
		min-width: 150px;
	}

	.tag-input:focus {
		outline: 2px solid var(--primary-color);
		outline-offset: 2px;
		border-color: var(--primary-color);
	}

	.add-tag-btn {
		padding: 0.375rem 0.75rem;
		background: var(--primary-color);
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.add-tag-btn:hover:not(:disabled) {
		background: var(--primary-dark);
	}

	.add-tag-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.tags-container {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.tag {
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.25rem 0.5rem;
		background: var(--accent-color);
		color: var(--accent-text);
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.tag-text {
		color: inherit;
	}

	.remove-tag-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1rem;
		height: 1rem;
		background: transparent;
		color: inherit;
		border: none;
		border-radius: 50%;
		font-size: 0.875rem;
		font-weight: bold;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.remove-tag-btn:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.no-tags {
		color: var(--text-secondary);
		font-style: italic;
		margin: 0;
		padding: 1rem 0;
		text-align: center;
	}

	.suggested-tags {
		border-top: 1px solid var(--border-color);
		padding-top: 1rem;
	}

	.suggested-title {
		font-size: 0.875rem;
		font-weight: 600;
		color: var(--text-secondary);
		margin: 0 0 0.5rem 0;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.suggested-container {
		display: flex;
		flex-wrap: wrap;
		gap: 0.375rem;
	}

	.suggested-tag {
		padding: 0.25rem 0.5rem;
		background: var(--surface-color);
		color: var(--text-secondary);
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		font-size: 0.75rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.suggested-tag:hover:not(:disabled) {
		background: var(--surface-elevated);
		color: var(--text-primary);
		border-color: var(--primary-color);
	}

	.suggested-tag:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}
</style>
