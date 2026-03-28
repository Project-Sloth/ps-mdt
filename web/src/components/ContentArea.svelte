<script lang="ts">
	import { onMount } from "svelte";
	import { PLACEHOLDER_COMPONENTS, type ComponentId } from "../constants";
	import type { AuthService } from "../services/authService.svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import LoginOverlay from "./LoginOverlay.svelte";
	import SOPAgreementOverlay from "./SOPAgreementOverlay.svelte";
	import PlaceholderContent from "./PlaceholderContent.svelte";
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
	import WarrantReview from "../pages/doj/WarrantReview.svelte";
	import CourtOrders from "../pages/doj/CourtOrders.svelte";
	import LegalDocuments from "../pages/doj/LegalDocuments.svelte";
	import type { createInstanceStateService } from "../services/instanceStateService.svelte";
	import type { createTabService } from "../services/tabService.svelte";

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

	onMount(() => {
		try {
			const saved = localStorage.getItem("ps-mdt-preferences");
			if (saved) {
				const data = JSON.parse(saved);
				if (data.uiZoom && data.uiZoom >= 100 && data.uiZoom <= 200) {
					contentZoom = `${data.uiZoom}%`;
				}
			}
		} catch {
			// Ignore
		}
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
		weapons: ["weapons_search"],
		cases: ["cases_view", "cases_create"],
		evidence: ["evidence_view", "evidence_create"],
		reports: ["reports_view", "reports_create"],
		warrants: ["warrants_view", "warrants_issue"],
		charges: ["charges_view", "charges_edit"],
		cameras: ["cameras_view"],
		bodycams: ["bodycams_view"],
		ia: ["ia_view"],
		sop: ["sop_view", "sop_manage"],
		management: ["management_settings", "management_bulletins", "management_activity", "management_permissions", "management_tracking"],
		settings: ["management_settings"],
	};

	const DOJ_SHARED_PAGES = ["reports", "citizens", "cases", "evidence", "charges"];

	function canAccessPage(pageId: string): boolean {
		if (authService.jobType === "doj" && DOJ_SHARED_PAGES.includes(pageId)) return true;
		const requiredPerms = PAGE_PERMISSIONS[pageId];
		if (!requiredPerms) return true;
		return authService.hasAnyPermission(...requiredPerms);
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
			bodycams: "Bodycams",
			management: "Settings",
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
			<div class="denied-overlay">
				<div class="denied-card">
					<span class="material-icons denied-icon">lock</span>
					<span class="denied-title">Permission Denied</span>
					<span class="denied-desc">
						You do not have permission to access <strong>{getPageLabel(activeComponent)}</strong>.
						Contact a supervisor to request access.
					</span>
					<button class="denied-btn" onclick={() => tabService.setActiveTab("Dashboard")}>
						<span class="material-icons denied-btn-icon">arrow_back</span>
						Back to Dashboard
					</button>
				</div>
			</div>
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
			<Warrants {tabService} />
		{:else if activeComponent === "charges"}
			<Charges {authService} />
		{:else if activeComponent === "awards"}
			<Awards {tabService} jobType={authService.jobType} />
		{:else if activeComponent === "roster"}
			<Roster {authService} {tabService} />
		{:else if activeComponent === "map"}
			<Map />
		{:else if activeComponent === "vehicles"}
			<Vehicles {tabService} />
		{:else if activeComponent === "weapons"}
			<Weapons />
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
		{:else if activeComponent === "management"}
			<Management {authService} />
		{:else if activeComponent === "settings"}
			<Settings />
		{:else if activeComponent === "court_cases"}
			<CourtCases {tabService} {authService} />
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

	.denied-overlay {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		background: var(--card-dark-bg);
	}

	.denied-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 16px;
		padding: 40px 48px;
		max-width: 400px;
		animation: fadeIn 0.3s ease-out;
	}

	.denied-icon {
		font-size: 42px;
		color: rgba(239, 68, 68, 0.6);
		margin-bottom: 16px;
	}

	.denied-title {
		font-size: 20px;
		font-weight: 700;
		color: rgba(239, 68, 68, 0.8);
		margin-bottom: 8px;
	}

	.denied-desc {
		font-size: 13px;
		color: rgba(255, 255, 255, 0.45);
		line-height: 1.6;
		margin-bottom: 24px;
	}

	.denied-desc strong {
		color: rgba(255, 255, 255, 0.7);
	}

	.denied-btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 10px 22px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.denied-btn:hover {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.9);
		border-color: rgba(255, 255, 255, 0.15);
	}

	.denied-btn-icon {
		font-size: 16px;
	}

	@keyframes fadeIn {
		0% { opacity: 0; transform: translateY(8px); }
		100% { opacity: 1; transform: translateY(0); }
	}
</style>
