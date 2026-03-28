<script lang="ts">
	import type { PermissionRole as Role } from "@/services/managementService.svelte";

	let {
		role,
		permissions,
		onUpdate,
	}: {
		role: Role;
		permissions: string[];
		onUpdate: (perms: string[]) => void;
	} = $props();

	let selected = $state(new Set<string>((role.permissions || []) as string[]));
	const isBoss = role.isBoss === true;

	$effect(() => {
		selected = new Set<string>(role.permissions || []);
	});

	function formatPermissionName(permission: string): string {
		return permission
			.replace(/_/g, " ")
			.replace(/\b\w/g, (c) => c.toUpperCase());
	}

	function togglePermission(permission: string) {
		if (selected.has(permission)) {
			selected.delete(permission);
		} else {
			selected.add(permission);
		}
		selected = new Set(selected);
		onUpdate(Array.from(selected));
	}
</script>

<div class="role-column">
	<div class="role-header">
		<span class="role-name">{role.label}</span>
		{#if isBoss}
			<span class="boss-tag">All</span>
		{/if}
	</div>
	<div class="permission-list">
		{#if permissions.length === 0}
			<div class="empty-perm">No permissions</div>
		{/if}
		{#each permissions as permission}
			<label class="permission-row">
				<span class="perm-label">{formatPermissionName(permission)}</span>
				<input
					type="checkbox"
					checked={selected.has(permission) || isBoss}
					disabled={isBoss}
					onchange={() => togglePermission(permission)}
				/>
			</label>
		{/each}
	</div>
</div>

<style>
	.role-column {
		flex: 1;
		min-width: 180px;
		border-right: 1px solid rgba(255, 255, 255, 0.04);
		display: flex;
		flex-direction: column;
	}

	.role-column:last-child {
		border-right: none;
	}

	.role-header {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 10px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.role-name {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.boss-tag {
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		color: #6ee7b7;
		background: rgba(16, 185, 129, 0.12);
		border: 1px solid rgba(16, 185, 129, 0.2);
		padding: 1px 6px;
		border-radius: 4px;
	}

	.permission-list {
		flex: 1;
		overflow-y: auto;
	}

	.permission-list::-webkit-scrollbar {
		width: 4px;
	}

	.permission-list::-webkit-scrollbar-track {
		background: transparent;
	}

	.permission-list::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.08);
		border-radius: 2px;
	}

	.permission-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 6px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.02);
		cursor: pointer;
		transition: background 0.1s ease;
	}

	.permission-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.permission-row:last-child {
		border-bottom: none;
	}

	.perm-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.6);
	}

	.permission-row input[type="checkbox"] {
		width: 14px;
		height: 14px;
		accent-color: rgba(var(--accent-rgb), 0.7);
		cursor: pointer;
	}

	.permission-row input[type="checkbox"]:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.empty-perm {
		padding: 14px;
		color: rgba(255, 255, 255, 0.45);
		font-size: 11px;
		text-align: center;
	}
</style>
