<script lang="ts">
	import VisibilityProvider from "src/providers/VisibilityProvider.svelte";
	import MDT from "./pages/MDT.svelte";
	import MugshotCamera from "./components/MugshotCamera.svelte";
	import ComplaintForm from "./pages/ComplaintForm.svelte";
	import ApplicationForm from "./pages/ApplicationForm.svelte";
	import ImpoundForm from "./pages/ImpoundForm.svelte";
	import { SvelteQueryDevtools } from "@tanstack/svelte-query-devtools";
	import { QueryClientProvider } from "@tanstack/svelte-query";
	import { queryClient } from "./utils/query-client";
	import { onMount } from "svelte";
	import { setupInputDebug } from "./utils/debugInputBlocker";
	import { seedPreferences } from "./utils/preferences";

	let cleanupInputDebug: (() => void) | undefined;
	let showComplaintForm = $state(false);
	let showApplicationForm = $state(false);
	let applicationDept = $state("");
	let showImpoundForm = $state(false);
	let impoundVehicle = $state<{ plate: string; model?: string; netId: number; owner?: string; stolen?: boolean; bolo?: boolean; priorImpounds?: number } | null>(null);

	onMount(() => {
		// Before anything reads a preference: KVP outlives localStorage, so this
		// is what makes the saved zoom and window size survive a restart.
		seedPreferences();

		if (import.meta.env && import.meta.env.DEV) {
			cleanupInputDebug = setupInputDebug();
		}

		// Listen for complaint form trigger (outside VisibilityProvider so it works for civilians)
		const handleMessage = (event: MessageEvent) => {
			if (event.data?.action === 'showComplaintForm') {
				showComplaintForm = true;
			}
			// Job application form — one command per department opens it with that
			// department preset. Outside VisibilityProvider so civilians can apply.
			if (event.data?.action === 'showApplicationForm') {
				applicationDept = event.data.data?.department ?? "";
				showApplicationForm = true;
			}
			// On-site impound form — like the complaint form, it lives outside the
			// MDT so it works at the roadside without the tablet being open.
			if (event.data?.action === 'showImpoundForm') {
				impoundVehicle = event.data.data ?? null;
				showImpoundForm = true;
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
	<ApplicationForm show={showApplicationForm} department={applicationDept} onClose={() => { showApplicationForm = false; applicationDept = ""; }} />
	<ImpoundForm show={showImpoundForm} vehicle={impoundVehicle} onClose={() => { showImpoundForm = false; impoundVehicle = null; }} />
	<SvelteQueryDevtools />
</QueryClientProvider>