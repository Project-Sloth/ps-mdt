import { fetchNui } from "../utils/fetchNui";
import { isEnvBrowser } from "../utils/misc";
import { NUI_EVENTS } from "../constants/nuiEvents";
import { ALL_PERMISSION_KEYS } from "../constants/management";

export interface PermissionRole {
	key: string;
	label: string;
	permissions?: string[];
	isBoss?: boolean;
}

export interface PermissionRolesResponse {
	job: string;
	label: string;
	roles: PermissionRole[];
	permissions?: string[];
}

export function createManagementService() {
	let roles = $state<PermissionRole[]>([]);
	let jobLabel = $state("Law Enforcement");
	let jobName = $state("police");
	let permissions = $state<string[]>([]);
	let isLoading = $state(false);
	let isSaving = $state(false);
	let statusMessage = $state<{ text: string; type: "success" | "error" } | null>(null);

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	async function loadRoles() {
		if (isEnvBrowser()) {
			permissions = [...ALL_PERMISSION_KEYS];
			// Dev mock: roles with escalating permissions (labels match whatever the job grades are)
			const basicPerms = ["citizens_search", "bolos_view", "vehicles_search", "weapons_search", "reports_view", "warrants_view", "charges_view"];
			const midPerms = [...basicPerms, "reports_create", "cases_view", "evidence_view", "bolos_create", "dispatch_attach", "dispatch_route"];
			const seniorPerms = [...midPerms, "cases_create", "cases_edit", "evidence_create", "evidence_transfer", "reports_delete", "warrants_issue", "cameras_view", "bodycams_view", "citizens_edit_licenses", "vehicles_edit_dmv"];
			const commandPerms = [...seniorPerms, "cases_delete", "evidence_upload", "warrants_close", "charges_edit", "management_activity", "management_bulletins", "roster_manage_officers", "roster_manage_certifications"];
			roles = [
				{ key: "0", label: "Grade 0", permissions: basicPerms, isBoss: false },
				{ key: "1", label: "Grade 1", permissions: midPerms, isBoss: false },
				{ key: "2", label: "Grade 2", permissions: seniorPerms, isBoss: false },
				{ key: "3", label: "Grade 3", permissions: commandPerms, isBoss: false },
				{ key: "4", label: "Grade 4", permissions: [...ALL_PERMISSION_KEYS], isBoss: true },
			];
			return;
		}

		try {
			isLoading = true;
			const response = await fetchNui<PermissionRolesResponse>(
				NUI_EVENTS.MANAGEMENT.GET_PERMISSION_ROLES,
			);
			if (response?.roles) {
				roles = response.roles;
				jobLabel = response.label || jobLabel;
				jobName = response.job || jobName;
				permissions = response.permissions || permissions;
			}
		} catch {
			roles = [];
		} finally {
			isLoading = false;
		}
	}

	function togglePermission(roleKey: string, permission: string) {
		const role = roles.find((r) => r.key === roleKey);
		if (!role || role.isBoss) return;

		const perms = new Set(role.permissions || []);
		if (perms.has(permission)) {
			perms.delete(permission);
		} else {
			perms.add(permission);
		}

		const newPerms = Array.from(perms);
		roles = roles.map((r) =>
			r.key === roleKey ? { ...r, permissions: newPerms } : r,
		);
	}

	function roleHasPermission(roleKey: string, permission: string): boolean {
		const role = roles.find((r) => r.key === roleKey);
		if (!role) return false;
		if (role.isBoss) return true;
		return (role.permissions || []).includes(permission);
	}

	function enableCategoryForRole(roleKey: string, permissionKeys: string[]) {
		const role = roles.find((r) => r.key === roleKey);
		if (!role || role.isBoss) return;
		const perms = new Set(role.permissions || []);
		for (const key of permissionKeys) perms.add(key);
		roles = roles.map((r) =>
			r.key === roleKey ? { ...r, permissions: Array.from(perms) } : r,
		);
	}

	function disableCategoryForRole(roleKey: string, permissionKeys: string[]) {
		const role = roles.find((r) => r.key === roleKey);
		if (!role || role.isBoss) return;
		const perms = new Set(role.permissions || []);
		for (const key of permissionKeys) perms.delete(key);
		roles = roles.map((r) =>
			r.key === roleKey ? { ...r, permissions: Array.from(perms) } : r,
		);
	}

	async function saveRole(roleKey: string) {
		const role = roles.find((r) => r.key === roleKey);
		if (!role) return;

		try {
			isSaving = true;
			await fetchNui(NUI_EVENTS.MANAGEMENT.UPDATE_PERMISSION_ROLE, {
				job: jobName,
				grade: roleKey,
				permissions: role.permissions || [],
			});
			showStatus(`Permissions saved for ${role.label}`);
		} catch {
			showStatus("Failed to save permissions", "error");
		} finally {
			isSaving = false;
		}
	}

	async function saveAllRoles() {
		try {
			isSaving = true;
			for (const role of roles) {
				if (role.isBoss) continue;
				await fetchNui(NUI_EVENTS.MANAGEMENT.UPDATE_PERMISSION_ROLE, {
					job: jobName,
					grade: role.key,
					permissions: role.permissions || [],
				});
			}
			showStatus("All permissions saved");
		} catch {
			showStatus("Failed to save permissions", "error");
		} finally {
			isSaving = false;
		}
	}

	return {
		loadRoles,
		togglePermission,
		roleHasPermission,
		enableCategoryForRole,
		disableCategoryForRole,
		saveRole,
		saveAllRoles,
		showStatus,
		get roles() { return roles; },
		get jobLabel() { return jobLabel; },
		get jobName() { return jobName; },
		get permissions() { return permissions; },
		get isLoading() { return isLoading; },
		get isSaving() { return isSaving; },
		get statusMessage() { return statusMessage; },
	};
}

export type ManagementService = ReturnType<typeof createManagementService>;
