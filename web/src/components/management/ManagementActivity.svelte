<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import Pagination from "../Pagination.svelte";

	interface AuditLog {
		id: number;
		actor_name: string;
		action: string;
		entity_type: string;
		entity_id: string | null;
		details: string | null;
		created_at: string;
	}

	interface PaginatedResponse {
		items: AuditLog[];
		total: number;
		page: number;
		perPage: number;
	}

	const ACTION_LABELS: Record<string, string> = {
		// Authentication
		mdt_login:  "Logged into MDT",
		mdt_logout: "Logged out of MDT",
		// Reports
		report_created: "Created a report",
		report_updated: "Updated a report",
		report_deleted: "Deleted a report",
		// Warrants
		warrant_issued: "Issued a warrant",
		warrant_closed: "Closed a warrant",
		// Cases
		case_created:              "Created a case",
		case_updated:              "Updated a case",
		case_deleted:              "Deleted a case",
		case_officer_assigned:     "Assigned officer to case",
		case_officer_removed:      "Removed officer from case",
		case_attachment_added:     "Added case attachment",
		case_attachment_removed:   "Removed case attachment",
		case_attachment_uploaded:  "Uploaded case attachment",
		// Evidence
		evidence_added:            "Added evidence",
		evidence_updated:          "Updated evidence",
		evidence_deleted:          "Deleted evidence",
		evidence_transferred:      "Transferred evidence custody",
		evidence_image_added:      "Added evidence image",
		evidence_image_removed:    "Removed evidence image",
		evidence_linked_case:      "Linked evidence to case",
		case_created_from_evidence:"Created case from evidence",
		// Weapons
		weapon_created: "Registered a weapon",
		weapon_updated: "Updated weapon record",
		weapon_deleted: "Deleted weapon record",
		// Vehicles
		vehicle_updated:    "Updated vehicle record",
		vehicle_impounded:  "Impounded a vehicle",
		vehicle_released:   "Released vehicle from impound",
		// Searches
		search_citizens: "Searched citizens",
		search_players:  "Searched players",
		search_officers: "Searched officers",
		// Charges / Fines / Sentencing
		fine_processed:  "Processed a fine",
		charge_updated:  "Updated a charge",
		arrest_logged:   "Logged an arrest",
		sent_to_jail:    "Sent citizen to jail",
		// Officers / Dispatch
		callsign_changed:      "Changed officer callsign",
		signal100_activated:   "Activated Signal 100",
		signal100_deactivated: "Deactivated Signal 100",
		icu_deleted:           "Deleted ICU record",
		// Cameras / Bodycams
		camera_viewed:  "Viewed camera footage",
		bodycam_viewed: "Viewed bodycam footage",
		// ── Patrols ──────────────────────────────────────────────────────────
		patrol_created:          "Created a patrol",
		patrol_deleted:          "Deleted a patrol",
		patrol_renamed:          "Renamed a patrol",
		patrol_zone_created:     "Drew patrol zone",
		patrol_zone_updated:     "Updated patrol zone",
		patrol_zone_cleared:     "Cleared patrol zone",
		patrol_officer_assigned: "Assigned officer to patrol",
		patrol_officer_removed:  "Removed officer from patrol",
		patrols_reordered:       "Reordered patrols",
	};

	const ACTION_ICONS: Record<string, { icon: string; color: string }> = {
		mdt_login:  { icon: "login",  color: "#3b82f6" },
		mdt_logout: { icon: "logout", color: "#6b7280" },
		report_created: { icon: "description", color: "#10b981" },
		report_updated: { icon: "edit_note",   color: "#f59e0b" },
		report_deleted: { icon: "delete",      color: "#ef4444" },
		warrant_issued: { icon: "gavel",       color: "#ef4444" },
		warrant_closed: { icon: "check_circle",color: "#10b981" },
		case_created:   { icon: "folder_open", color: "#3b82f6" },
		case_updated:   { icon: "folder",      color: "#f59e0b" },
		case_deleted:   { icon: "folder_delete",color: "#ef4444" },
		case_officer_assigned: { icon: "person_add",    color: "#10b981" },
		case_officer_removed:  { icon: "person_remove", color: "#ef4444" },
		evidence_added:     { icon: "inventory_2", color: "#8b5cf6" },
		evidence_updated:   { icon: "inventory_2", color: "#f59e0b" },
		evidence_deleted:   { icon: "delete",      color: "#ef4444" },
		evidence_transferred: { icon: "swap_horiz", color: "#8b5cf6" },
		weapon_created: { icon: "security",       color: "#10b981" },
		weapon_updated: { icon: "security",       color: "#f59e0b" },
		weapon_deleted: { icon: "no_encryption",  color: "#ef4444" },
		vehicle_updated:   { icon: "directions_car", color: "#f59e0b" },
		vehicle_impounded: { icon: "local_parking",  color: "#ef4444" },
		vehicle_released:  { icon: "directions_car", color: "#10b981" },
		fine_processed:  { icon: "payments",     color: "#f59e0b" },
		charge_updated:  { icon: "gavel",        color: "#f59e0b" },
		arrest_logged:   { icon: "front_hand",   color: "#ef4444" },
		sent_to_jail:    { icon: "lock",         color: "#ef4444" },
		search_citizens: { icon: "person_search",color: "#6b7280" },
		search_players:  { icon: "manage_search",color: "#6b7280" },
		search_officers: { icon: "badge",        color: "#6b7280" },
		callsign_changed:      { icon: "badge",       color: "#3b82f6" },
		signal100_activated:   { icon: "crisis_alert", color: "#ef4444" },
		signal100_deactivated: { icon: "crisis_alert", color: "#6b7280" },
		camera_viewed:  { icon: "videocam",      color: "#6b7280" },
		bodycam_viewed: { icon: "camera_alt",    color: "#6b7280" },
		// Patrols
		patrol_created:          { icon: "groups",         color: "#38bdf8" },
		patrol_deleted:          { icon: "group_remove",   color: "#ef4444" },
		patrol_renamed:          { icon: "edit",           color: "#f59e0b" },
		patrol_zone_created:     { icon: "draw",           color: "#10b981" },
		patrol_zone_updated:     { icon: "draw",           color: "#f59e0b" },
		patrol_zone_cleared:     { icon: "clear",          color: "#ef4444" },
		patrol_officer_assigned: { icon: "person_add",     color: "#10b981" },
		patrol_officer_removed:  { icon: "person_remove",  color: "#ef4444" },
		patrols_reordered:       { icon: "swap_vert",      color: "#6b7280" },
	};

	let activities: AuditLog[] = $state([]);
	let isLoading    = $state(false);
	let searchQuery  = $state("");
	let currentPage  = $state(1);
	let totalItems   = $state(0);
	let perPage      = $state(25);
	let searchTimeout: ReturnType<typeof setTimeout> | null = null;

	let totalPages = $derived(Math.max(1, Math.ceil(totalItems / perPage)));

	function getActionLabel(action: string): string {
		return ACTION_LABELS[action] ?? action.replace(/_/g, " ");
	}

	function getActionIcon(action: string): { icon: string; color: string } {
		return ACTION_ICONS[action] ?? { icon: "info", color: "rgba(59, 130, 246, 0.6)" };
	}

	// Parse details JSON and extract the most useful human-readable string.
	function getDetailLine(log: AuditLog): string {
		if (!log.details) return "";
		let d: Record<string, unknown>;
		try { d = JSON.parse(log.details); } catch { return ""; }

		// Prefer the pre-built readable label from the server
		if (typeof d.action_label === "string") return d.action_label;

		// Patrol-specific fallbacks
		if (log.action === "patrol_renamed") {
			if (d.patrol_old_name && d.patrol_new_name)
				return `"${d.patrol_old_name}" → "${d.patrol_new_name}"`;
		}
		if (log.action === "patrol_officer_assigned") {
			if (d.assigned_name && d.patrol_name)
				return `${d.assigned_name} → ${d.patrol_name}`;
		}
		if (log.action === "patrol_officer_removed") {
			if (d.removed_from) return `Removed from "${d.removed_from}"`;
		}
		if (log.action === "patrol_zone_created" || log.action === "patrol_zone_updated") {
			if (d.patrol_name && d.point_count) return `${d.patrol_name} · ${d.point_count} pts`;
		}
		if (log.action === "patrol_zone_cleared") {
			if (d.patrol_name) return `${d.patrol_name}`;
		}
		if (log.action === "patrols_reordered") {
			if (typeof d.new_order === "string") return d.new_order;
		}
		if (log.action === "patrol_created") {
			if (d.patrol_name) return String(d.patrol_name);
		}
		if (log.action === "patrol_deleted") {
			if (d.patrol_name) return String(d.patrol_name);
		}
		return "";
	}

	function getEntityLabel(log: AuditLog): string {
		if (!log.entity_id) return "";
		const typeLabels: Record<string, string> = {
			profile:         "Profile",
			report:          "Report",
			warrant:         "Warrant",
			case:            "Case",
			evidence:        "Evidence",
			vehicle:         "Vehicle",
			weapon:          "Weapon",
			citizen:         "Citizen",
			search:          "",
			dispatch:        "Channel",
			fine:            "Fine",
			charge:          "Charge",
			arrest:          "Arrest",
			icu:             "ICU",
			case_attachment: "Attachment",
			evidence_image:  "Image",
			officer:         "Officer",
			mdt_patrol:      "Patrol",
		};
		const label = typeLabels[log.entity_type] ?? log.entity_type;
		// For patrol actions entity_id is the UUID or 'order' – skip the #prefix for UUIDs
		if (log.entity_type === "mdt_patrol") {
			return label;
		}
		return label ? `${label} #${log.entity_id}` : `#${log.entity_id}`;
	}

	function formatTimestamp(value: string): string {
		if (!value) return "Unknown";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return value;
		const now  = new Date();
		const diff = now.getTime() - date.getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1)  return "Just now";
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		const days = Math.floor(hours / 24);
		if (days < 7)  return `${days}d ago`;
		return date.toLocaleDateString() + " " + date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
	}

	function formatFullTimestamp(value: string): string {
		if (!value) return "";
		const date = new Date(value);
		return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
	}

	async function loadActivity(page = 1) {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<PaginatedResponse>(
				NUI_EVENTS.AUDIT.GET_AUDIT_LOGS,
				{ limit: perPage, page, search: searchQuery.trim() || undefined },
				{ items: [], total: 0, page: 1, perPage: 25 },
			);
			if (response && response.items) {
				activities   = response.items;
				totalItems   = response.total || 0;
				currentPage  = response.page  || page;
			} else if (Array.isArray(response)) {
				activities  = response as unknown as AuditLog[];
				totalItems  = activities.length;
				currentPage = 1;
			} else {
				activities = [];
				totalItems = 0;
			}
		} catch (error) {
			console.error("Failed to load activity:", error);
			activities = [];
			totalItems = 0;
		} finally {
			isLoading = false;
		}
	}

	function handleSearch(e: Event) {
		const value = (e.target as HTMLInputElement).value;
		searchQuery = value;
		if (searchTimeout) clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => { currentPage = 1; loadActivity(1); }, 400);
	}

	onMount(() => {
		if (isEnvBrowser()) {
			activities = [
				{ id: 1, actor_name: "D2020 Sgt. J. Miller",  action: "patrol_created",          entity_type: "mdt_patrol", entity_id: "alpha-1", details: JSON.stringify({ patrol_name: "Alpha-1", patrol_color: "#38bdf8", action_label: 'Created patrol "Alpha-1"' }), created_at: new Date(Date.now() - 60000).toISOString() },
				{ id: 2, actor_name: "D2020 Det. R. Santos",   action: "patrol_officer_assigned",  entity_type: "mdt_patrol", entity_id: "alpha-1", details: JSON.stringify({ patrol_name: "Alpha-1", assigned_name: "J. Miller", action_label: 'Assigned J. Miller to patrol "Alpha-1"' }), created_at: new Date(Date.now() - 300000).toISOString() },
				{ id: 3, actor_name: "D2020 Ofc. K. Chen",     action: "patrol_zone_created",      entity_type: "mdt_patrol", entity_id: "alpha-1", details: JSON.stringify({ patrol_name: "Alpha-1", point_count: 6, action_label: 'Drew zone for patrol "Alpha-1" (6 points)' }), created_at: new Date(Date.now() - 3600000).toISOString() },
				{ id: 4, actor_name: "D2020 Lt. A. Brooks",    action: "patrol_renamed",           entity_type: "mdt_patrol", entity_id: "alpha-1", details: JSON.stringify({ patrol_old_name: "Alpha", patrol_new_name: "Alpha-1", action_label: 'Renamed patrol "Alpha" → "Alpha-1"' }), created_at: new Date(Date.now() - 7200000).toISOString() },
				{ id: 5, actor_name: "D2020 Ofc. M. Torres",   action: "report_created",           entity_type: "report",     entity_id: "RPT-042", details: null, created_at: new Date(Date.now() - 86400000).toISOString() },
			];
			totalItems = 5;
			return;
		}
		loadActivity(1);
	});
</script>

<div class="activity-panel">
	<div class="activity-topbar">
		<input
			type="text"
			placeholder="Search activity..."
			value={searchQuery}
			oninput={handleSearch}
			class="search-input"
		/>
		<span class="result-count">{totalItems} entries</span>
	</div>

	{#if isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading activity...</p>
		</div>
	{:else}
		<div class="activity-list">
			{#each activities as log (log.id)}
				{@const iconData   = getActionIcon(log.action)}
				{@const detailLine = getDetailLine(log)}
				{@const entityLabel= getEntityLabel(log)}
				<div class="activity-row">
					<div class="activity-icon" style="background:{iconData.color}18;color:{iconData.color}">
						<span class="material-icons">{iconData.icon}</span>
					</div>
					<div class="activity-body">
						<div class="activity-top-row">
							<span class="activity-action">{getActionLabel(log.action)}</span>
							{#if entityLabel}
								<span class="activity-entity">{entityLabel}</span>
							{/if}
						</div>
						{#if detailLine}
							<span class="activity-detail">{detailLine}</span>
						{/if}
					</div>
					<div class="activity-meta">
						<span class="activity-officer">{log.actor_name || "Unknown"}</span>
						<span class="activity-time" title={formatFullTimestamp(log.created_at)}>{formatTimestamp(log.created_at)}</span>
					</div>
				</div>
			{:else}
				<div class="empty-state">
					{searchQuery ? "No results matching your search." : "No recent activity."}
				</div>
			{/each}
		</div>

		<Pagination
			currentPage={currentPage}
			totalItems={totalItems}
			perPage={perPage}
			onPageChange={(p) => loadActivity(p)}
			onPerPageChange={(pp) => { perPage = pp; loadActivity(1); }}
		/>
	{/if}
</div>

<style>
	.activity-panel {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: transparent;
		overflow: hidden;
	}

	.activity-topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 36px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.search-input {
		flex: 1;
		max-width: 360px;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
	}
	.search-input:focus { outline: none; }
	.search-input::placeholder { color: rgba(255, 255, 255, 0.2); }

	.result-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
		margin-left: auto;
	}

	.activity-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}
	.activity-list::-webkit-scrollbar       { width: 4px; }
	.activity-list::-webkit-scrollbar-track { background: transparent; }
	.activity-list::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.06); border-radius: 2px; }

	.activity-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 7px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}
	.activity-row:hover       { background: rgba(255, 255, 255, 0.02); }
	.activity-row:last-child  { border-bottom: none; }

	.activity-icon {
		width: 28px;
		height: 28px;
		min-width: 28px;
		border-radius: 5px;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.activity-icon .material-icons { font-size: 14px; }

	.activity-body {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
		min-width: 0;
	}

	.activity-top-row {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.activity-action {
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-weight: 500;
	}

	.activity-entity {
		font-size: 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
		background: rgba(var(--accent-rgb), 0.08);
		padding: 1px 5px;
		border-radius: 3px;
	}

	.activity-detail {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.activity-meta {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 1px;
		flex-shrink: 0;
	}
	.activity-officer {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		white-space: nowrap;
	}
	.activity-time {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 200px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0%   { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>