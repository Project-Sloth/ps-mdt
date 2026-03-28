<script lang="ts">
	import { MANAGEMENT_PERMISSIONS } from "@/constants/management";
	import { onMount } from "svelte";

	let permissions = Object.values(MANAGEMENT_PERMISSIONS);
</script>

<div class="permissions">
	{#each permissions as permission}
		<div class="permission">{permission}</div>
	{/each}
</div>
