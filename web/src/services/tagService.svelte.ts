import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";

export interface TagInfo {
	name: string;
	color: string;
}

export interface TagServiceState {
	availableTags: TagInfo[];
	isLoading: boolean;
	lastError: string | null;
}

export function createTagService() {
	let state = $state<TagServiceState>({
		availableTags: [],
		isLoading: false,
		lastError: null,
	});

	/**
	 * Load available tags from the server
	 */
	async function loadAvailableTags(): Promise<TagInfo[]> {
		state.isLoading = true;
		state.lastError = null;

		try {
			const response = await fetchNui<any>(
				NUI_EVENTS.REPORT.GET_AVAILABLE_TAGS,
				{},
			);

			// Server returns array of { name, color, usage_count }
			const rawTags: Array<string | { name?: string; color?: string } | null> = Array.isArray(response)
				? response
				: Array.isArray(response?.data)
					? response.data
					: [];
			const tags: TagInfo[] = rawTags
				.map((tag) => {
					if (typeof tag === "string") {
						return { name: tag, color: "#6b7280" };
					}
					if (tag?.name) {
						return { name: tag.name, color: tag.color || "#6b7280" };
					}
					return null;
				})
				.filter((tag): tag is TagInfo => tag !== null);
			state.availableTags = tags;
			return tags;
		} catch (error) {
			console.error("Failed to load tags:", error);
			state.lastError = "Failed to load available tags";
			state.availableTags = [];
			return [];
		} finally {
			state.isLoading = false;
		}
	}

	/**
	 * Add a tag to a list if it doesn't already exist
	 */
	function addTag(currentTags: string[], tagToAdd: string): string[] {
		if (!currentTags.includes(tagToAdd)) {
			return [...currentTags, tagToAdd];
		}
		return currentTags;
	}

	/**
	 * Remove a tag from a list by index
	 */
	function removeTag(currentTags: string[], index: number): string[] {
		return currentTags.filter((_, i) => i !== index);
	}

	/**
	 * Remove a tag from a list by value
	 */
	function removeTagByValue(
		currentTags: string[],
		tagToRemove: string,
	): string[] {
		return currentTags.filter((tag) => tag !== tagToRemove);
	}

	/**
	 * Check if a tag is available in the system
	 */
	function isTagAvailable(tag: string): boolean {
		return state.availableTags.some((t) => t.name === tag);
	}

	/**
	 * Get filtered available tags based on current selection
	 */
	function getFilteredAvailableTags(currentTags: string[]): TagInfo[] {
		return state.availableTags.filter((tag) => !currentTags.includes(tag.name));
	}

	/**
	 * Get the color for a tag by name
	 */
	function getTagColor(tagName: string): string {
		const tag = state.availableTags.find((t) => t.name === tagName);
		return tag?.color || "#6b7280";
	}

	/**
	 * Validate a tag name
	 */
	function validateTag(tag: string): { valid: boolean; error?: string } {
		if (!tag.trim()) {
			return { valid: false, error: "Tag cannot be empty" };
		}

		if (tag.length > 50) {
			return {
				valid: false,
				error: "Tag cannot be longer than 50 characters",
			};
		}

		if (!/^[a-zA-Z0-9\s\-_]+$/.test(tag)) {
			return {
				valid: false,
				error: "Tag can only contain letters, numbers, spaces, hyphens, and underscores",
			};
		}

		return { valid: true };
	}

	return {
		get state() {
			return state;
		},
		loadAvailableTags,
		addTag,
		removeTag,
		removeTagByValue,
		isTagAvailable,
		getFilteredAvailableTags,
		getTagColor,
		validateTag,
	};
}

export type TagService = ReturnType<typeof createTagService>;
