<script lang="ts">
	import type { TagInfo } from "../../services/tagService.svelte";

	interface Props {
		tags: string[];
		availableTags: TagInfo[];
		onAddTag: (tag: string) => void;
		onRemoveTag: (index: number) => void;
		getTagColor: (tagName: string) => string;
	}

	let { tags, availableTags, onAddTag, onRemoveTag, getTagColor }: Props = $props();

	let showTagDropdown = $state(false);

	// Filter out already-selected tags
	let filteredTags = $derived(
		availableTags.filter((tag) => !tags.includes(tag.name))
	);

	function openTagDropdown() {
		showTagDropdown = true;
	}

	function addTag(tagName: string) {
		if (!tags.includes(tagName)) {
			onAddTag(tagName);
		}
		showTagDropdown = false;
	}

	function removeTag(index: number) {
		onRemoveTag(index);
	}

	function handleClickOutside(event: MouseEvent) {
		const target = event.target as HTMLElement;
		if (!target.closest(".dropdown-container")) {
			showTagDropdown = false;
		}
	}
</script>

<svelte:window on:click={handleClickOutside} />

<div class="metadata-section">
	<div class="section-title">
		<span class="section-label">TAGS</span>
		<div class="dropdown-container">
			<button
				class="add-btn"
				onclick={openTagDropdown}
				title="Add Tag"
				aria-label="Add Tag"
			>+ Add</button>
			{#if showTagDropdown}
				<div class="dropdown">
					<div class="dropdown-header">Available Tags</div>
					{#each filteredTags as tag}
						<button
							class="dropdown-item"
							onclick={() => addTag(tag.name)}
						>
							<span class="tag-color-dot" style="background-color: {tag.color}"></span>
							<span class="tag-name">{tag.name}</span>
						</button>
					{/each}
					{#if filteredTags.length === 0}
						<div class="dropdown-empty">No more tags available</div>
					{/if}
				</div>
			{/if}
		</div>
	</div>
	<div class="tags-container">
		{#each tags as tag, index}
			{@const color = getTagColor(tag)}
			<div class="tag" style="background-color: {color}20; border: 1px solid {color}40;">
				<span class="tag-dot" style="background-color: {color}"></span>
				<span class="tag-text" style="color: {color}">{tag}</span>
				<button
					class="remove-btn"
					onclick={() => removeTag(index)}
					aria-label="Remove tag"
				>
					<svg
						width="8"
						height="8"
						viewBox="0 0 24 24"
						fill="currentColor"
					>
						<path
							d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"
						/>
					</svg>
				</button>
			</div>
		{/each}
	</div>
</div>

<style>
	.metadata-section {
		padding-bottom: 12px;
		margin-bottom: 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.section-title {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}

	.section-label {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.dropdown-container {
		position: relative;
	}

	.add-btn {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		font-size: 10px;
		font-weight: 500;
		padding: 2px 6px;
		transition: color 0.1s;
	}

	.add-btn:hover {
		color: rgba(255, 255, 255, 0.5);
	}

	.dropdown {
		position: absolute;
		top: 100%;
		right: 0;
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		z-index: 10000;
		min-width: 180px;
		max-height: 200px;
		overflow-y: auto;
	}

	.dropdown-header {
		padding: 7px 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.dropdown-item {
		display: flex;
		align-items: center;
		gap: 7px;
		padding: 6px 10px;
		border: none;
		background: transparent;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		cursor: pointer;
		width: 100%;
		text-align: left;
		transition: background 0.1s;
	}

	.dropdown-item:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.dropdown-empty {
		padding: 10px;
		text-align: center;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.2);
	}

	.tag-color-dot {
		width: 7px;
		height: 7px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.tag-name {
		flex: 1;
	}

	.tags-container {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.tag {
		display: flex;
		align-items: center;
		gap: 4px;
		border-radius: 3px;
		padding: 2px 7px;
		font-size: 10px;
		font-weight: 500;
	}

	.tag-dot {
		width: 5px;
		height: 5px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.tag-text {
		white-space: nowrap;
	}

	.tag:hover .remove-btn {
		opacity: 1;
	}

	.remove-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 11px;
		height: 11px;
		background: rgba(239, 68, 68, 0.15);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.remove-btn:hover {
		background: rgba(239, 68, 68, 0.3);
	}

	.dropdown::-webkit-scrollbar {
		width: 3px;
	}

	.dropdown::-webkit-scrollbar-track {
		background: transparent;
	}

	.dropdown::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.dropdown::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.1);
	}
</style>
