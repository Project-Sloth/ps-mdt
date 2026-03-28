<script lang="ts">
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { fetchNui } from "../utils/fetchNui";
	import { debugLog } from "../utils/debug";
	import { mdtStore } from "../stores/mdtStore";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { onMount, type Snippet } from "svelte";

	let { children }: { children: Snippet } = $props();
	const isDev = import.meta.env.DEV;
	let _visibility = $state(isDev ? true : false);

	let store = {
		set visibility(value: boolean) {
			_visibility = value;
		},
		get visibility() {
			return _visibility;
		},
	};

	onMount(() => {
		useNuiEvent<{ visible: boolean; debugMode?: boolean }>(
			NUI_EVENTS.NAVIGATION.SET_VISIBLE,
			(data) => {
				if (data.debugMode !== undefined) {
					mdtStore.setDebugMode(data.debugMode);
				}

				debugLog("VisibilityProvider received setVisible:", data);
				store.visibility = data.visible;
			},
		);

		const keyHandler = (e: KeyboardEvent) => {
			if (store.visibility && ["Escape"].includes(e.code)) {
				fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI);
			}
		};

		window.addEventListener("keydown", keyHandler);

		return () => window.removeEventListener("keydown", keyHandler);
	});
</script>

{#if _visibility}
	{@render children()}
{/if}
