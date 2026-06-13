<script lang="ts">
	/**
	 * Push-to-talk bridge for using the radio while the MDT is open.
	 *
	 * The MDT holds full NUI focus, so the game never sees the PTT keypress.
	 * This component (which lives inside the focused NUI) captures the key the
	 * client resolved — the player's real radio keybind where detectable — and
	 * forwards press/release to the client, which drives the active voice system
	 * (pma-voice / SaltyChat / YACA). Renders nothing.
	 */
	import { onMount, onDestroy } from "svelte";
	import { useNuiEvent } from "@/utils/useNuiEvent";
	import { NUI_EVENTS } from "@/constants/nuiEvents";
	import { fetchNui } from "@/utils/fetchNui";

	let enabled = $state(false);
	let pttKey = $state("");
	let talking = false;

	// A "mouse:<n>" token means the radio key is a mouse button (n = MouseEvent
	// .button: 0 left, 1 middle, 2 right, 3 back, 4 forward). Anything else is a
	// keyboard key (KeyboardEvent.code or a character).
	const isMouse = $derived(pttKey.startsWith("mouse:"));
	const mouseButton = $derived(
		isMouse ? parseInt(pttKey.slice("mouse:".length), 10) : -1,
	);

	// The client pushes { enabled, key } when the MDT opens. `key` is either a
	// KeyboardEvent.code (e.g. "AltLeft", "CapsLock") for named keys, a single
	// character (e.g. "R") for letter/number keys, or "mouse:<n>" for a mouse
	// button.
	useNuiEvent<{ enabled?: boolean; key?: string }>(
		NUI_EVENTS.RADIO.CONFIG,
		(data) => {
			enabled = data?.enabled === true;
			pttKey = (data?.key ?? "").toString();
		},
	);

	function matches(e: KeyboardEvent): boolean {
		if (!pttKey || isMouse) return false;
		return (
			e.code === pttKey ||
			e.key === pttKey ||
			e.key.toLowerCase() === pttKey.toLowerCase()
		);
	}

	function setTalking(state: boolean) {
		if (state === talking) return; // de-dupe key auto-repeat
		talking = state;
		fetchNui(NUI_EVENTS.RADIO.PTT, { talking: state }).catch(() => {});
	}

	function onKeyDown(e: KeyboardEvent) {
		if (!enabled || e.repeat) return;
		if (matches(e)) setTalking(true);
	}
	function onKeyUp(e: KeyboardEvent) {
		if (!enabled) return;
		if (matches(e)) setTalking(false);
	}
	function onMouseDown(e: MouseEvent) {
		if (!enabled || !isMouse) return;
		if (e.button === mouseButton) {
			e.preventDefault(); // suppress middle-click autoscroll etc.
			setTalking(true);
		}
	}
	function onMouseUp(e: MouseEvent) {
		if (!enabled || !isMouse) return;
		if (e.button === mouseButton) {
			e.preventDefault();
			setTalking(false);
		}
	}
	// Losing focus (alt-tab, etc.) must release the key, or the player gets
	// stuck transmitting.
	function onBlur() {
		setTalking(false);
	}

	onMount(() => {
		window.addEventListener("keydown", onKeyDown);
		window.addEventListener("keyup", onKeyUp);
		window.addEventListener("mousedown", onMouseDown);
		window.addEventListener("mouseup", onMouseUp);
		window.addEventListener("blur", onBlur);
	});

	onDestroy(() => {
		window.removeEventListener("keydown", onKeyDown);
		window.removeEventListener("keyup", onKeyUp);
		window.removeEventListener("mousedown", onMouseDown);
		window.removeEventListener("mouseup", onMouseUp);
		window.removeEventListener("blur", onBlur);
		setTalking(false);
	});
</script>