<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import {
		DEFAULT_TIME,
		DEFAULT_DATE,
		TIME_FORMAT_OPTIONS,
		DATE_FORMAT_OPTIONS,
		TIMING,
		APP_INFO,
	} from "../constants";

	let info = $derived(APP_INFO[authService.jobType] || APP_INFO.leo);
	import type { AuthService } from "../services/authService.svelte";

	interface Props {
		authService: AuthService;
		onOpacityStyleChange: (opacityStyle: string) => void;
	}

	let { authService, onOpacityStyleChange }: Props = $props();

	let currentTime = $state(DEFAULT_TIME);
	let currentDate = $state(DEFAULT_DATE);
	let opacityTimeout: ReturnType<typeof setTimeout> | null = $state(null);
	let documentOpacity = $state(1);

	/**
	 * Reactive statement for the opacity style string.
	 */
	const opacityStyle = $derived(`opacity: ${documentOpacity}`);

	/**
	 * Watch for opacity style changes and notify parent.
	 */
	$effect(() => {
		onOpacityStyleChange(opacityStyle);
	});

	function handleTopBarEnter() {
		if (opacityTimeout) {
			clearTimeout(opacityTimeout);
			opacityTimeout = null;
		}
		documentOpacity = 0.5;
	}

	function handleTopBarLeave() {
		if (opacityTimeout) {
			clearTimeout(opacityTimeout);
		}

		opacityTimeout = setTimeout(() => {
			documentOpacity = 1;
			opacityTimeout = null;
		}, TIMING.topBarOpacityDelay);
	}

	/**
	 * Initializes the time update interval and cleans up on component destruction.
	 */
	onMount(() => {
		const timeInterval = setInterval(() => {
			const now = new Date();
			currentTime = now.toLocaleTimeString("en-US", TIME_FORMAT_OPTIONS);
			currentDate = now.toLocaleDateString("en-US", DATE_FORMAT_OPTIONS);
		}, TIMING.timeUpdateInterval);

		return () => {
			clearInterval(timeInterval);
			if (opacityTimeout) {
				clearTimeout(opacityTimeout);
			}
		};
	});
</script>

<div
	class="top-bar"
	role="region"
	onmouseenter={handleTopBarEnter}
	onmouseleave={handleTopBarLeave}
>
	<div class="user-info">
		{#if authService.isAuthorized}
			{authService.playerInfo().rank}
			{authService.playerInfo().firstName}
			{authService.playerInfo().lastName} | {authService.playerInfo().id} |
			{authService.playerInfo().department}
		{:else}
			{info.title} - {info.subtitle}
		{/if}
	</div>
	<div class="time-info">
		{currentTime} | {currentDate}
	</div>
</div>

<style>
	.top-bar {
		background: rgba(13, 13, 13, 0.7);
		min-height: 55px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0 20px;
		color: var(--primary-text);
		font-size: 14px;
		font-weight: 500;
		border-bottom: 1px solid var(--border-primary);
		z-index: 10;
		position: relative;
		cursor: default;
	}

	:global([data-job-type="ems"]) .top-bar {
		background: rgba(18, 10, 10, 0.8);
		border-bottom-color: rgba(220, 50, 50, 0.12);
	}

	:global([data-job-type="doj"]) .top-bar {
		background: rgba(8, 12, 20, 0.8);
		border-bottom-color: rgba(180, 150, 60, 0.12);
	}

	.user-info,
	.time-info {
		color: var(--primary-text);
	}
</style>
