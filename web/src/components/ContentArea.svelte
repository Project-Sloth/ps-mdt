<script lang="ts">
	import { onMount } from "svelte";
	import {
		PLACEHOLDER_COMPONENTS,
		TAB_TO_COMPONENT_MAP,
		getTabsForJob,
		getTabLabel,
		type ComponentId,
		type MDTTab,
	} from "../constants";
	import type { AuthService } from "../services/authService.svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { readPrefs, onPrefsReady } from "../utils/preferences";
	import LoginOverlay from "./LoginOverlay.svelte";
	import SOPAgreementOverlay from "./SOPAgreementOverlay.svelte";
	import PlaceholderContent from "./PlaceholderContent.svelte";
	import AccessRestricted from "./AccessRestricted.svelte";
	import CivilianView from "../pages/CivilianView.svelte";
	import Dashboard from "../pages/Dashboard.svelte";
	import Reports from "../pages/Reports.svelte";
	import Warrants from "../pages/Warrants.svelte";
	import Charges from "../pages/Charges.svelte";
	import Roster from "../pages/Roster.svelte";
	import Map from "../pages/Map.svelte";
	import Citizens from "../pages/Citizens.svelte";
	import Bolos from "../pages/Bolos.svelte";
	import Vehicles from "../pages/Vehicles.svelte";
	import Weapons from "../pages/Weapons.svelte";
	import Cases from "../pages/Cases.svelte";
	import Evidence from "../pages/Evidence.svelte";
	import Cameras from "../pages/Cameras.svelte";
	import Bodycams from "../pages/Bodycams.svelte";
	import Awards from "../pages/Awards.svelte";
	import IA from "../pages/IA.svelte";
	import PPR from "../pages/PPR.svelte";
	import FTO from "../pages/FTO.svelte";
	import SOP from "../pages/SOP.svelte";
	import Management from "@/pages/Management.svelte";
	import Settings from "../pages/Settings.svelte";
	import CourtCases from "../pages/doj/CourtCases.svelte";
	import CourtCalendar from "../pages/doj/CourtCalendar.svelte";
	import WarrantReview from "../pages/doj/WarrantReview.svelte";
	import CourtOrders from "../pages/doj/CourtOrders.svelte";
	import LegalDocuments from "../pages/doj/LegalDocuments.svelte";
	import type { createInstanceStateService } from "../services/instanceStateService.svelte";
	import type { createTabService } from "../services/tabService.svelte";
	import BulletInBoard from "@/pages/BulletInBoard.svelte";

	interface Props {
		authService: AuthService;
		tabService: ReturnType<typeof createTabService>;
		instanceStateService: ReturnType<typeof createInstanceStateService>;
	}

	let { authService, tabService, instanceStateService }: Props = $props();

	let contentZoom = $state("130%");
	let sopAgreed = $state(false);
	let sopChecked = $state(false);
	let sopIntroduction = $state("");
	let sopMissionStatement = $state("");

	function applyZoomFromPrefs() {
		const zoom = readPrefs().uiZoom;
		if (typeof zoom === "number" && zoom >= 100 && zoom <= 200) {
			contentZoom = `${zoom}%`;
		}
	}

	onMount(() => {
		applyZoomFromPrefs();
		// The KVP copy may land after this mounts, e.g. on the first open after
		// a resource restart — without this the zoom stayed at its default
		// until the player visited the Preferences page.
		return onPrefsReady(applyZoomFromPrefs);
	});

	// Check SOP agreement when auth becomes authorized
	$effect(() => {
		if (authService.isAuthorized && !sopChecked) {
			checkSOPAgreement();
		}
	});

	async function checkSOPAgreement() {
		try {
			const result = await fetchNui<{ agreed: boolean; introduction?: string; mission_statement?: string }>(
				NUI_EVENTS.SOP.CHECK_SOP_AGREEMENT,
				{},
				{ agreed: true, introduction: "", mission_statement: "" },
			);
			sopAgreed = result?.agreed ?? true;
			sopIntroduction = result?.introduction ?? "";
			sopMissionStatement = result?.mission_statement ?? "";
		} catch {
			sopAgreed = true; // Don't block on error
		} finally {
			sopChecked = true;
		}
	}

	function handleSOPAcknowledged() {
		sopAgreed = true;
	}

	function getActiveComponent(): ComponentId {
		return tabService.getActiveComponent();
	}

	function isPlaceholderComponent(componentId: ComponentId): boolean {
		return PLACEHOLDER_COMPONENTS.includes(componentId);
	}

	/**
	 * Maps page IDs to the permissions required to view them.
	 * If any one of the listed permissions is present, access is granted.
	 * Pages not listed here (dashboard, settings, roster, map) are always accessible.
	 */
	const PAGE_PERMISSIONS: Record<string, string[]> = {
		citizens: ["citizens_search"],
		bolos: ["bolos_view", "bolos_create"],
		vehicles: ["vehicles_search"],
		weapons: ["weapons_search", "weapons_add"],
		cases: ["cases_view", "cases_create"],
		evidence: ["evidence_view", "evidence_create"],
		reports: ["reports_view", "reports_create"],
		warrants: ["warrants_view", "warrants_issue"],
		charges: ["charges_view", "charges_edit"],
		cameras: ["cameras_view", "dashcams_view"],
		bodycams: ["bodycams_view"],
		ia: ["ia_view"],
		sop: ["sop_view", "sop_manage"],
		bulletin_board: ["bulletin_view"],
		calendar: ["court_view", "training_view"],
		management: ["management_settings", "management_bulletins", "management_activity", "management_permissions", "management_tracking"],
		// No entry for `settings`: that page is the officer's own preferences
		// (default tab, UI scale), not department configuration. The chief-level
		// screen is `management`.
	};

	const DOJ_SHARED_PAGES = ["reports", "citizens", "cases", "evidence", "charges"];

	function canAccessPage(pageId: string): boolean {
		if (authService.jobType === "doj" && DOJ_SHARED_PAGES.includes(pageId)) return true;
		const requiredPerms = PAGE_PERMISSIONS[pageId];
		if (!requiredPerms) return true;
		return authService.hasAnyPermission(...requiredPerms);
	}

	/**
	 * Switching tabs means moving the *active instance*, not just the global
	 * activeTab — getActiveComponent() reads the instance, so setting only the
	 * global value leaves the screen exactly where it was.
	 */
	function goToTab(tab: MDTTab) {
		const active = tabService.getActiveInstance();
		if (active) {
			tabService.setInstanceTab(active.id, tab);
		} else {
			tabService.setActiveTab(tab);
		}
	}

	/** Sections this officer may open, offered when they land on a locked one. */
	function getAccessibleTabs(current: ComponentId) {
		return getTabsForJob(authService.jobType)
			.filter((tab) => !authService.hasRawPermission(`tab_hidden_${tab.name.toLowerCase()}`))
			.map((tab) => ({
				tab: tab.name,
				icon: tab.icon,
				label: getTabLabel(tab.name as MDTTab),
				component: TAB_TO_COMPONENT_MAP[tab.name as keyof typeof TAB_TO_COMPONENT_MAP],
			}))
			.filter(
				(entry) =>
					entry.component !== current &&
					entry.component !== "dashboard" &&
					canAccessPage(entry.component),
			)
			.slice(0, 6);
	}

	function getPageLabel(pageId: string): string {
		const labels: Record<string, string> = {
			citizens: "Citizens",
			bolos: "BOLOs",
			vehicles: "Vehicles",
			weapons: "Weapons",
			cases: "Cases",
			evidence: "Evidence",
			reports: "Reports",
			warrants: "Warrants",
			charges: "Charges",
			awards: "Awards",
			cameras: "Cameras",
			calendar: "Calendar",
			bodycams: "Bodycams",
			management: "Settings",
			sop: "SOP",
			bulletin_board: "Bulletin Board",
			settings: "Preferences",
		};
		return labels[pageId] || pageId;
	}
</script>

<div class="content-area" style="zoom: {contentZoom};">
	{#if authService.isCivilian}
		<CivilianView {authService} />
	{:else if authService.isAuthorized}
		{#if sopChecked && !sopAgreed}
			<SOPAgreementOverlay
				{authService}
				onAcknowledged={handleSOPAcknowledged}
				introduction={sopIntroduction}
				missionStatement={sopMissionStatement}
			/>
		{:else}
		{@const activeComponent = (getActiveComponent() as any) as ComponentId}

		{#if !canAccessPage(activeComponent)}
			<AccessRestricted
				pageLabel={getPageLabel(activeComponent)}
				requiredPermissions={PAGE_PERMISSIONS[activeComponent] ?? []}
				rank={authService.playerData?.job?.grade?.name ?? ""}
				callsign={authService.playerData?.metadata?.callsign ?? ""}
				department={authService.playerData?.job?.label ?? ""}
				suggestions={getAccessibleTabs(activeComponent)}
				onBack={() => goToTab("Dashboard")}
				onOpen={(tab) => goToTab(tab as MDTTab)}
			/>
		{:else if activeComponent === "dashboard"}
			<Dashboard
				signOut={authService.signOut}
				playerData={authService.playerData}
				{tabService}
				jobType={authService.jobType}
			/>
		{:else if activeComponent === "citizens"}
			<Citizens {tabService} jobType={authService.jobType} {authService} />
		{:else if (activeComponent as any) === "bolos"}
			<Bolos {tabService} />
		{:else if activeComponent === "reports"}
			<Reports {instanceStateService} {tabService} jobType={authService.jobType} />
		{:else if activeComponent === "warrants"}
			<Warrants {tabService} {authService} />
		{:else if activeComponent === "charges"}
			<Charges {authService} />
		{:else if activeComponent === "awards"}
			<Awards {tabService} jobType={authService.jobType} />
		{:else if activeComponent === "roster"}
			<Roster {authService} {tabService} />
		{:else if activeComponent === "map"}
			<Map {authService}/>
		{:else if activeComponent === "vehicles"}
			<Vehicles {tabService} {authService} />
		{:else if activeComponent === "weapons"}
			<Weapons {tabService} {authService} />
		{:else if activeComponent === "cases"}
			<Cases {tabService} />
		{:else if String(activeComponent) === "evidence"}
			<Evidence {tabService} />
		{:else if activeComponent === "cameras"}
			<Cameras />
		{:else if activeComponent === "bodycams"}
			<Bodycams />
		{:else if activeComponent === "ia"}
			<IA {tabService} {authService} />
		{:else if activeComponent === "ppr"}
			<PPR {tabService} {authService} />
		{:else if activeComponent === "fto"}
			<FTO {tabService} {authService} />
		{:else if activeComponent === "sop"}
			<SOP {authService} />
		{:else if activeComponent === "bulletin_board"}
			<BulletInBoard {authService} />
		{:else if activeComponent === "management"}
			<Management {authService} />
		{:else if activeComponent === "settings"}
			<Settings {authService} />
		{:else if activeComponent === "court_cases"}
			<CourtCases {tabService} {authService} />
		{:else if activeComponent === "calendar"}
			<CourtCalendar {tabService} {authService} />
		{:else if activeComponent === "warrant_review"}
			<WarrantReview {tabService} {authService} />
		{:else if activeComponent === "court_orders"}
			<CourtOrders {tabService} {authService} />
		{:else if activeComponent === "legal_documents"}
			<LegalDocuments {tabService} {authService} />
		{:else if isPlaceholderComponent(activeComponent)}
			<PlaceholderContent componentId={activeComponent} />
		{:else}
			<PlaceholderContent
				componentId={activeComponent}
				message="Component not found"
			/>
		{/if}
		{/if}
	{:else}
		<LoginOverlay {authService} />
	{/if}
</div>

<style>
	.content-area {
		flex: 1;
		color: rgba(255, 255, 255, 0.9);
		overflow-y: auto;
		position: relative;
	}

</style>