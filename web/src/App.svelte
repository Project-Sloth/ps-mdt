<script lang="ts">
	import VisibilityProvider from "src/providers/VisibilityProvider.svelte";
	import MDT from "./pages/MDT.svelte";
	import MugshotCamera from "./components/MugshotCamera.svelte";
	import ComplaintForm from "./pages/ComplaintForm.svelte";
	import { SvelteQueryDevtools } from "@tanstack/svelte-query-devtools";
	import { QueryClientProvider } from "@tanstack/svelte-query";
	import { queryClient } from "./utils/query-client";
	import { onMount } from "svelte";
	import { setupInputDebug } from "./utils/debugInputBlocker";

	let cleanupInputDebug: (() => void) | undefined;
	let showComplaintForm = $state(false);

	onMount(() => {
		if (import.meta.env && import.meta.env.DEV) {
			cleanupInputDebug = setupInputDebug();
		}

		// Listen for complaint form trigger (outside VisibilityProvider so it works for civilians)
		const handleMessage = (event: MessageEvent) => {
			if (event.data?.action === 'showComplaintForm') {
				showComplaintForm = true;
			}
		};
		window.addEventListener('message', handleMessage);

		return () => {
			window.removeEventListener('message', handleMessage);
			if (cleanupInputDebug) {
				cleanupInputDebug();
			}
		};
	});
</script>


<QueryClientProvider client={queryClient}>
	<VisibilityProvider>
		<MDT />
	</VisibilityProvider>
	<MugshotCamera />
	<ComplaintForm show={showComplaintForm} onClose={() => { showComplaintForm = false; }} />
	<SvelteQueryDevtools />
</QueryClientProvider>
