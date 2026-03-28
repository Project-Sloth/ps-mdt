# MDT Persistence Guide

## Overview

The MDT automatically saves your work as you type, so you never lose data when switching between tabs or instances. Each tab remembers exactly where you left off.

## How It Works

- **Auto-save**: Changes are saved automatically after 500ms
- **Instance isolation**: Each tab keeps its own data separate
- **Instant restore**: Switch between tabs and your work is exactly as you left it
- **Clean exit**: Data is cleaned up when tabs are closed

## Quick Start

Use the `usePersistence` hook in any component that needs to save data:

```svelte
<script lang="ts">
	import { onMount } from "svelte";
	import { usePersistence } from "../hooks/usePersistence.svelte";

	interface Props {
		instanceStateService: ReturnType<typeof createInstanceStateService>;
	}

	let { instanceStateService }: Props = $props();

	// Your component state
	let searchQuery = $state("");
	let selectedItems = $state<string[]>([]);

	// Setup persistence
	const persistence = usePersistence(instanceStateService, "my-page");

	// Load saved data when component mounts
	onMount(() => {
		const saved = persistence.loadPersistedData();
		if (saved) {
			searchQuery = saved.searchQuery || "";
			selectedItems = saved.selectedItems || [];
		}
		persistence.initialize();
	});

	// Auto-save when data changes
	$effect(() => {
		persistence.debouncedSave({
			searchQuery,
			selectedItems,
		});
	});
</script>
```

That's it! Your data will automatically save and restore.

## Adding a New Page

### 1. Add your data interface to `schemas/persistenceSchema.ts`:

```typescript
export interface MyPageData {
	searchQuery: string;
	selectedItems: string[];
}
```

### 2. Add your page type to `interfaces/IMDT.ts`:

```typescript
export interface InstancePersistenceData {
	// ... existing pages
	"my-page"?: MyPageData;
}
```

### 3. Add your page type to the hook in `usePersistence.svelte.ts`:

```typescript
type PageType =
	| "report-page"
	| "citizens-page"
	// ... existing pages
	| "my-page";
```

### 4. Use the pattern shown above in your component.

## Advanced Usage

The `usePersistence` hook provides additional methods when needed:

```typescript
const persistence = usePersistence(instanceStateService, "my-page");

// Save immediately (skips debounce)
persistence.saveData(myData);

// Clear all saved data
persistence.clearPersistedData();

// Check if data has unsaved changes
if (persistence.isDirty()) {
	// Handle unsaved changes
}

// Update data partially
persistence.updateData((current) => ({
	...current,
	searchQuery: "new value",
}));
```

## Common Patterns

### Save form data:

```typescript
$effect(() => {
	persistence.debouncedSave({
		formField1: field1,
		formField2: field2,
		formField3: field3,
	});
});
```

### Load with defaults:

```typescript
onMount(() => {
	const saved = persistence.loadPersistedData();
	formField1 = saved?.formField1 || "default";
	formField2 = saved?.formField2 || 0;
});
```

### Clear on successful submit:

```typescript
async function handleSubmit() {
	const success = await submitToServer(formData);
	if (success) {
		persistence.clearPersistedData();
	}
}
```

## Troubleshooting

**Data not saving?**

- Make sure you called `persistence.initialize()` in `onMount`
- Check that `instanceStateService` prop is passed to your component

**Data not loading?**

- Verify your page type string matches exactly in all files
- Check browser console for TypeScript errors

**Performance issues?**

- The hook automatically debounces saves (500ms default)
- Avoid saving large objects frequently

That's all you need to know! The persistence system handles the complexity for you.
