<script lang="ts">
	import { onMount } from "svelte";
	import { formatDate, formatDateTime } from "../utils/datetime";
	import ImpoundFormFields from "../components/impound/ImpoundFormFields.svelte";
	import SkeletonList from "../components/SkeletonList.svelte";
	import type { ImpoundDuration, ImpoundReason, ImpoundLot } from "../interfaces/IImpound";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import Pagination from "../components/Pagination.svelte";

	import type { AuthService } from "../services/authService.svelte";
	import { permissionHint } from "../utils/permissionHint";

	let { tabService, authService }: {
		tabService: ReturnType<typeof createTabService>;
		authService?: AuthService;
	} = $props();

	// ═══ Impound ═══
	interface ImpoundRecord {
		id: number;
		status: "active" | "released";
		plate?: string;
		reason: string | null;
		notes: string | null;
		lot: string | null;
		fee: number;
		fee_paid: number;
		storage?: number;
		days_held?: number;
		total?: number;
		hold_type?: 'immediate' | 'timed' | 'indefinite';
		hold_until?: number | null;
		hold_label?: string | null;
		hold_releasable?: boolean;
		hold_reason?: string | null;
		hold_seconds_left?: number;
		override_reason?: string | null;
		photo?: string | null;
		linkedreport: number | null;
		officer_name: string | null;
		time: number;
		released_at?: number | null;
		released_by_name?: string | null;
		model?: string;
		owner_name?: string | null;
		owner_citizenid?: string | null;
	}
	// Use the shared definitions rather than re-declaring them here — a local copy is
	// how the reason's `hold` field went missing in the first place.

	// Whether the server has the feature switched on at all. Declared before the
	// permissions below because they read it — a $derived referencing a $state
	// declared further down is a temporal dead zone error at module evaluation,
	// not a Svelte quirk that resolves itself.
	//
	// Starts false so a slow or failed config load hides the impound controls
	// rather than offering buttons that will be refused. A refusal after the
	// click is a worse answer than a control that was never there.
	let impoundEnabled = $state(false);

	let canImpound = $derived(impoundEnabled && (authService ? (authService.hasPermission("vehicle_impound") ?? false) : true));
	let canRelease = $derived(impoundEnabled && (authService ? (authService.hasPermission("vehicle_impound_release") ?? false) : true));
	function holdLeft(seconds: number): string {
		const d = Math.floor(seconds / 86400);
		const h = Math.floor((seconds % 86400) / 3600);
		if (d > 0) return `${d}d ${h}h left`;
		if (h > 0) return `${h}h left`;
		return `${Math.max(1, Math.floor(seconds / 60))}m left`;
	}

	let canOverride = $derived(impoundEnabled && (authService ? (authService.hasPermission("vehicle_impound_override") ?? false) : true));

	let impoundDurations = $state<ImpoundDuration[]>([]);
	let defaultDuration = $state("");

	// Early release: cutting a hold short is deliberate, so it needs a reason.
	let overrideOpen = $state(false);
	let overridePlate = $state("");
	let overrideReason = $state("");

	let impoundHistory = $state<ImpoundRecord[]>([]);
	let impoundBusy    = $state(false);
	let showHistory    = $state(false);
	// The active impound for the selected vehicle (if any).
	let activeImpound  = $derived(impoundHistory.find(r => r.status === "active") ?? null);

	// Impound config (reasons + lots), loaded once.
	let impoundReasons = $state<ImpoundReason[]>([]);
	let impoundLots    = $state<ImpoundLot[]>([]);
	let requireFeePaid = $state(true);
	let impoundStorage = $state<{ perDay: number; maxDays: number }>({ perDay: 0, maxDays: 0 });
	let impoundCfgLoaded = false;

	// Impound modal
	let showImpoundModal = $state(false);
	let imReason = $state("");
	let imFee    = $state(0);
	let imLot    = $state("");
	let imDuration = $state("");
	let imNotes  = $state("");
	let imPhoto  = $state("");

	// Lightbox for the impound photo on the vehicle profile.
	let photoLightbox = $state<string | null>(null);

	// Impound lot view
	let showLotView  = $state(false);
	let lotVehicles  = $state<ImpoundRecord[]>([]);

	// A busy lot rendered every held vehicle at once, so the modal just kept scrolling.
	// Same treatment as the callsign grid: a page at a time, with a button for the rest.
	let lotPageSize  = $state(10);
	let lotShown     = $state(10);
	let lotLoading   = $state(false);
	let lotFilter    = $state("all");   // lot id or "all"
	let lotSearch    = $state("");

	async function loadImpoundConfig() {
		if (impoundCfgLoaded) return;
		try {
			const res = await fetchNui<{ enabled?: boolean; reasons: ImpoundReason[]; lots: ImpoundLot[]; durations: ImpoundDuration[]; defaultFee: number; requireFeePaid: boolean; maxFee: number; defaultDuration: string; storage: { perDay: number; maxDays: number }; lotPageSize?: number }>(
				NUI_EVENTS.IMPOUND.GET_IMPOUND_CONFIG, {},
				{ enabled: false, reasons: [], lots: [], durations: [], defaultFee: 500, requireFeePaid: true, maxFee: 50000, defaultDuration: "immediate", storage: { perDay: 0, maxDays: 0 }, lotPageSize: 10 });
			impoundEnabled = res?.enabled === true;
			impoundReasons = res?.reasons ?? [];
			impoundLots = res?.lots ?? [];
			impoundDurations = res?.durations ?? [];
			defaultDuration = res?.defaultDuration || impoundDurations[0]?.id || "";
			impoundStorage = res?.storage ?? { perDay: 0, maxDays: 0 };
			requireFeePaid = res?.requireFeePaid ?? true;
			if (typeof res?.maxFee === "number") maxFee = res.maxFee;
			if (typeof res?.lotPageSize === "number" && res.lotPageSize > 0) lotPageSize = res.lotPageSize;
			impoundCfgLoaded = true;
		} catch { /* leave empty */ }
	}

	async function loadImpoundHistory(plate: string) {
		try {
			const res = await fetchNui<{ entries: ImpoundRecord[] }>(
				NUI_EVENTS.IMPOUND.GET_IMPOUND_HISTORY, { plate }, { entries: [] });
			impoundHistory = res?.entries ?? [];
		} catch {
			impoundHistory = [];
		}
	}

	function lotLabel(id: string | null): string {
		if (!id) return "Unknown lot";
		return impoundLots.find(l => l.id === id)?.label ?? id;
	}

	function money(n: number | null | undefined): string {
		return "$" + (n ?? 0).toLocaleString();
	}

	async function openImpoundModal() {
		await loadImpoundConfig();
		const first = impoundReasons[0];
		imReason = first?.label ?? "";
		imFee = first?.fee ?? 0;
		imLot = impoundLots[0]?.id ?? "";
		// Start on the hold the pre-selected reason recommends, not the global default,
		// so the form is never internally inconsistent the moment it opens.
		const rec = impoundReasons[0]?.hold ?? defaultDuration;
		imDuration = impoundDurations.some((d) => d.id === rec) ? rec : defaultDuration;
		imNotes = "";
		imPhoto = "";
		showImpoundModal = true;
	}

	// Picking a reason pre-fills its configured fee (still editable).
	function onReasonChange(label: string) {
		imReason = label;
		const r = impoundReasons.find(x => x.label === label);
		if (r) imFee = r.fee;
	}

	// Fee editor, modelled on the license-points editor: steppers + quick chips,
	// so a fee can be set without ever touching the keyboard.
	const FEE_STEP = 50;
	const FEE_PRESETS = [100, 250, 500, 1000];
	let maxFee = $state(50000);

	function adjustFee(delta: number) {
		const next = Math.round((imFee + delta) / 1) ;
		imFee = Math.min(maxFee, Math.max(0, next));
	}
	// The fee this reason is configured for — lets us show a "reset" affordance.
	let reasonDefaultFee = $derived(impoundReasons.find(r => r.label === imReason)?.fee ?? 0);
	let feeIsCustom = $derived(imFee !== reasonDefaultFee);

	async function submitImpound() {
		const plate = selectedVehicle?.plate;
		if (!plate || impoundBusy) return;
		if (!imReason) { globalNotifications.error("Pick an impound reason"); return; }
		impoundBusy = true;
		try {
			const res = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.IMPOUND.IMPOUND_VEHICLE,
				{ plate, reason: imReason, fee: imFee, lot: imLot, duration: imDuration, notes: imNotes.trim() || undefined, photo: imPhoto.trim() || undefined },
				{ success: true, message: "Impounded" });
			if (res?.success) {
				globalNotifications.success(res.message || "Vehicle impounded");
				showImpoundModal = false;
				if (selectedVehicle) selectedVehicle = { ...selectedVehicle, core_state: 2 };
				await loadImpoundHistory(plate);
				await refreshVehicles();
			} else {
				globalNotifications.error(res?.message || "Failed to impound vehicle");
			}
		} catch {
			globalNotifications.error("Failed to impound vehicle");
		} finally {
			impoundBusy = false;
		}
	}

	async function payFee(plate: string) {
		if (impoundBusy) return;
		impoundBusy = true;
		try {
			const res = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.IMPOUND.PAY_IMPOUND_FEE, { plate }, { success: true, message: "Fee collected" });
			if (res?.success) {
				globalNotifications.success(res.message || "Fee collected");
				await loadImpoundHistory(plate);
				if (showLotView) await loadLot();
			} else {
				globalNotifications.error(res?.message || "Failed to collect fee");
			}
		} catch {
			globalNotifications.error("Failed to collect fee");
		} finally {
			impoundBusy = false;
		}
	}

	async function releaseVehicle(plate: string, override?: { reason: string }) {
		if (impoundBusy) return;
		impoundBusy = true;
		try {
			const res = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.IMPOUND.RELEASE_IMPOUND,
				{ plate, override: !!override, overrideReason: override?.reason },
				{ success: true, message: "Released" });
			if (res?.success) {
				globalNotifications.success(res.message || "Vehicle released");
				if (selectedVehicle?.plate === plate) {
					selectedVehicle = { ...selectedVehicle, core_state: 0 };
					await loadImpoundHistory(plate);
				}
				if (showLotView) await loadLot();
				await refreshVehicles();
			} else {
				globalNotifications.error(res?.message || "Failed to release vehicle");
			}
		} catch {
			globalNotifications.error("Failed to release vehicle");
		} finally {
			impoundBusy = false;
		}
	}

	async function loadLot() {
		lotLoading = true;
		try {
			await loadImpoundConfig();
			const res = await fetchNui<{ vehicles: ImpoundRecord[] }>(
				NUI_EVENTS.IMPOUND.GET_IMPOUND_LOT, {}, { vehicles: [] });
			lotVehicles = res?.vehicles ?? [];
			lotShown = lotPageSize;
		} catch {
			lotVehicles = [];
		} finally {
			lotLoading = false;
		}
	}

	async function openLotView() {
		showLotView = true;
		await loadLot();
	}

	let lotFiltered = $derived.by(() => {
		const q = lotSearch.trim().toLowerCase();
		return lotVehicles.filter(v => {
			if (lotFilter !== "all" && v.lot !== lotFilter) return false;
			if (!q) return true;
			return (v.plate ?? "").toLowerCase().includes(q)
				|| (v.owner_name ?? "").toLowerCase().includes(q)
				|| (v.reason ?? "").toLowerCase().includes(q);
		});
	});

	// Narrowing the list should start you at the top of the new results, not partway
	// into a page that no longer exists.
	$effect(() => {
		const _key = `${lotSearch}|${lotFilter}`;
		void _key;
		lotShown = lotPageSize;
	});

	let lotVisible  = $derived(lotFiltered.slice(0, lotShown));
	let lotHasMore  = $derived(lotShown < lotFiltered.length);
	let lotRemaining = $derived(lotFiltered.length - lotShown);

	function loadMoreLot() {
		lotShown = Math.min(lotShown + lotPageSize, lotFiltered.length);
	}

	let lotUnpaidTotal = $derived(
		lotFiltered.filter(v => !v.fee_paid).reduce((sum, v) => sum + (v.total ?? v.fee ?? 0), 0)
	);

	interface Vehicle {
		id: number;
		model: string;
		label: string;
		plate: string;
		owner: string;
		class: string;
		type: string;
		flags: string[];
		image?: string;
		seenIn?: number;
		points?: number;
		status?: string;
		reason?: string;
		registered?: boolean;
		registrationReason?: string;
		core_state?: number;
		/** Sitting in an impound lot right now. */
		impounded?: boolean;
	}

	interface VehicleDetails extends Vehicle {
		// mdt_vehicle_points, delivered as `points` by the vehicles backend.
		points?: number;
		brand?: string;
		information?: string;
		stolen?: boolean;
		boloactive?: boolean;
		core_state?: number;
		reason?: string;
		bolos?: Array<{
			id: number;
			reportId: string;
			notes: string;
			status: string;
			type: string;
		}>;
	}

	let vehicleList: Vehicle[] = $state([]);
	let searchQuery = $state("");
	let loading = $state(false);
	// Type on the rune, not the variable: with the annotation on the left the
	// checker collapses the value to `never` and every field access fails.
	let selectedVehicle = $state<VehicleDetails | null>(null);
	let vehicleDetailLoading = $state(false);
	let vehicleDetailError = $state<string | null>(null);
	let editingNotes = $state(false);
	let notesValue = $state("");
	let notesSaving = $state(false);
	let imageModalOpen = $state(false);
	let imageUrlInput = $state("");
	let imageSaving = $state(false);
	let vehicleLightboxOpen = $state(false);
	let vehicleImageBroken = $state(false)

	$effect(() => {
		if (selectedVehicle) vehicleImageBroken = false;
	});

	$effect(() => {
		if (selectedVehicle) {
			editingNotes = false;
			notesValue = "";
		}
	});

	function startEditNotes() {
		notesValue = selectedVehicle?.information || "";
		editingNotes = true;
	}

	async function saveNotes() {
		if (!selectedVehicle) return;
		notesSaving = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.UPDATE_VEHICLE, {
				plate: selectedVehicle.plate,
				information: notesValue,
			});
			if (response?.success) {
				selectedVehicle = { ...selectedVehicle, information: notesValue };
				editingNotes = false;
				globalNotifications.success("Notes saved");
			} else {
				globalNotifications.error(response?.message || "Failed to save notes");
			}
		} catch {
			globalNotifications.error("Failed to save notes");
		}
		notesSaving = false;
	}

	function openVehicleLightbox() {
		if (!selectedVehicle?.image || selectedVehicle.image.startsWith('https://docs.fivem.net')) return;
		vehicleLightboxOpen = true;
	}

	function openImageModal() {
		imageUrlInput = selectedVehicle?.image?.startsWith('https://docs.fivem.net') ? "" : (selectedVehicle?.image ?? "");
		imageModalOpen = true;
	}

	async function saveVehicleImage() {
		const url = imageUrlInput.trim();
		if (!url || !selectedVehicle || imageSaving) return;
		imageSaving = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.UPDATE_VEHICLE, {
				plate: selectedVehicle.plate,
				image: url,
			});
			if (response?.success) {
				selectedVehicle = { ...selectedVehicle, image: url };
				vehicleList = vehicleList.map(v => v.plate === selectedVehicle?.plate ? { ...v, image: url } : v);
				globalNotifications.success("Vehicle image updated");
				imageModalOpen = false;
			} else {
				globalNotifications.error(response?.message || "Failed to update image");
			}
		} catch {
			globalNotifications.error("Failed to update image");
		}
		imageSaving = false;
	}

	// Feature toggles + permission, provided by the backend (getVehicles / getVehicle).
	let features = $state({ points: true, insurance: true, registration: true });
	let visualMaxPoints = $state(12);
	let canEditPoints = $state(false);

	// Points editing: a local draft the officer adjusts before saving.
	let pointsDraft = $state(0);
	let pointsSaving = $state(false);

	let savedPoints = $derived<number>(selectedVehicle?.points ?? 0);
	let pointsDirty = $derived<boolean>(pointsDraft !== savedPoints);
	let pointsDelta = $derived<number>(pointsDraft - savedPoints);

	const POINT_PRESETS = [1, 2, 3, 6];

	function adjustPoints(delta: number) {
		pointsDraft = Math.max(0, Math.min(1000, pointsDraft + delta));
	}

	function resetPoints() {
		pointsDraft = 0;
	}

	// Visual pip strip: filled pips up to visualMax, with a "+N" overflow badge.
	let pointPips = $derived.by(() => {
		const max = Math.max(1, visualMaxPoints);
		const filled = Math.min(pointsDraft, max);
		const overflow = Math.max(0, pointsDraft - max);
		return { max, filled, overflow };
	});

	function isVehicleInsured(v?: { status?: string } | null): boolean {
		// Anything that isn't the configured "uninsured" status counts as insured.
		return (v?.status || "valid").toLowerCase() !== "uninsured";
	}

	function isVehicleRegistered(v?: { registered?: boolean } | null): boolean {
		// Defaults to registered when the field is absent (fail open / feature off).
		return v?.registered !== false;
	}

	// Columns drop out of the list grid when their feature is disabled:
	// points (0.6fr), insurance (0.8fr) and registration (0.8fr).
	let listGridColumns = $derived(
		[
			"28px",  // avatar
			"2fr",   // vehicle
			"1fr",   // plate
			"1.5fr", // owner
			"0.8fr", // class
			features.points ? "0.6fr" : null,       // points
			features.insurance ? "0.8fr" : null,    // insurance
			features.registration ? "0.8fr" : null, // registration
			"1.5fr", // flags
		].filter(Boolean).join(" "),
	);

	let linkedReports: Array<{ id: number; title: string; type: string; datecreated: string; authorplaintext: string }> = $state([]);
	let linkedReportsLoading = $state(false);

	let statusFilter = $state("all");

	let vehiclePage = $state(1);
	let vehiclePerPage = $state(25);

	let allFilteredVehicles = $derived.by(() => {
		let list = vehicleList;

		// Status filter
		if (statusFilter !== "all") {
			if (statusFilter === "active") {
				list = list.filter(v => (v.status === "valid" || !v.status) && v.core_state === 0);
			} else if (statusFilter === "garaged") {
				list = list.filter(v => v.core_state === 1);
			} else if (statusFilter === "impounded") {
				list = list.filter(v => v.impounded || v.core_state === 2 || v.status === "impounded");
			} else if (statusFilter === "stolen") {
				list = list.filter(v => v.status === "stolen" || v.flags?.includes("Stolen"));
			}
		}

		// Text search
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			list = list.filter(({ label, plate, owner, class: vehicleClass, type }) =>
				[label, plate, owner, vehicleClass, type].some(val => val?.toLowerCase().includes(query))
			);
		}

		return list;
	});

	let filteredVehicles = $derived.by(() => {
		const start = (vehiclePage - 1) * vehiclePerPage;
		return allFilteredVehicles.slice(start, start + vehiclePerPage);
	});

	// Reset page on search
	$effect(() => {
		searchQuery;
		vehiclePage = 1;
	});

	function getFlagClass(flag: string): string {
		switch (flag) {
			case "Impounded": return "pill pill-blue";
			case "Stolen": return "pill pill-red";
			case "Active Warrant": return "pill pill-red";
			case "Bolo": return "pill pill-orange";
			case "Flight Risk": return "pill pill-orange";
			default: return "pill pill-grey";
		}
	}

	function getStatusClass(status: string): string {
		switch (status?.toLowerCase()) {
			case "stolen": return "status-stolen";
			case "bolo": return "status-bolo";
			case "suspended": return "status-suspended";
			case "expired": return "status-expired";
			case "impounded": return "status-impounded";
			case "uninsured": return "status-uninsured";
			case "valid": return "status-valid";
			case "clear": return "status-valid";
			default: return "status-valid";
		}
	}

	$effect(() => {
		const target = tabService.pendingTarget;
		if (target?.tab === "Vehicles" && target.id) {
			const id = tabService.consumeTarget("Vehicles");
			if (id) viewVehicle(String(id));
		}
	});

	async function viewVehicle(plate: string) {
		vehicleDetailError = null;
		vehicleDetailLoading = true;
		selectedVehicle = null;
		if (isEnvBrowser()) {
			const match = vehicleList.find(
				(vehicle) => vehicle.plate?.toLowerCase() === plate.toLowerCase(),
			);
			if (match) {
				selectedVehicle = {
					...match,
					information: "",
					stolen: match.flags?.includes("Stolen") || false,
					boloactive: match.flags?.includes("Bolo") || false,
					bolos: [],
				};
				features = { points: true, insurance: true, registration: true };
				canEditPoints = true;
				pointsDraft = match.points ?? 0;
				linkedReports = [
					{ id: 42, title: "Armed Robbery - Fleeca Bank", type: "Incident Report", datecreated: "2026-03-19", authorplaintext: "D2020 Ofc. Smith" },
				];
			}
			vehicleDetailLoading = false;
			return;
		}

		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLE, { plate });
			if (response?.vehicle) {
				selectedVehicle = response.vehicle;
				if (response.features) features = { points: !!response.features.points, insurance: !!response.features.insurance, registration: !!response.features.registration };
				canEditPoints = !!response.canEditPoints;
				pointsDraft = response.vehicle.points ?? 0;
				// Impound record + history for this vehicle.
				showHistory = false;
				loadImpoundConfig();
				loadImpoundHistory(plate);
			} else {
				vehicleDetailError = response?.message || "Failed to load vehicle";
			}
		} catch (error) {
			globalNotifications.error("Failed to load vehicle");
			vehicleDetailError = "Failed to load vehicle";
		} finally {
			vehicleDetailLoading = false;
		}

		// Load linked reports
		if (selectedVehicle) {
			linkedReportsLoading = true;
			try {
				const reportsResponse = await fetchNui<{ success: boolean; reports: typeof linkedReports }>(
					NUI_EVENTS.VEHICLE.GET_REPORTS_BY_PLATE,
					{ plate: selectedVehicle!.plate },
					{ success: true, reports: [] },
				);
				linkedReports = reportsResponse?.reports || [];
			} catch {
				linkedReports = [];
			}
			linkedReportsLoading = false;
		}
	}

	function goToReport(reportId: number | string) {
		openReportInEditor(String(reportId));
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	function closeVehicle() {
		selectedVehicle = null;
		vehicleDetailError = null;
		vehicleDetailLoading = false;
		pointsSaving = false;
		linkedReports = [];
		editingNotes = false;
		notesValue = "";
		notesSaving = false;
	}

	async function savePoints() {
		if (!selectedVehicle || pointsSaving || !pointsDirty) return;
		pointsSaving = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.UPDATE_VEHICLE, {
				plate: selectedVehicle.plate,
				points: pointsDraft,
			});
			if (!response?.success) {
				globalNotifications.error(response?.message || "Failed to update points");
				return;
			}
			selectedVehicle = { ...selectedVehicle, points: pointsDraft };
			vehicleList = vehicleList.map((vehicle) =>
				vehicle.plate === selectedVehicle?.plate
					? { ...vehicle, points: pointsDraft }
					: vehicle,
			);
			globalNotifications.success("Points updated");
		} catch (error) {
			globalNotifications.error("Failed to update points");
		} finally {
			pointsSaving = false;
		}
	}

	function applyVehiclesResponse(response: any) {
		vehicleList = Array.isArray(response?.vehicles) ? response.vehicles : [];
		if (response?.features) {
			features = { points: !!response.features.points, insurance: !!response.features.insurance, registration: !!response.features.registration };
		}
		if (typeof response?.canEditPoints === "boolean") {
			canEditPoints = response.canEditPoints;
		}
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			features = { points: true, insurance: true, registration: true };
			canEditPoints = true;
			vehicleList = [
				{ id: 1, model: 'sultan', label: 'Karin Sultan', plate: 'ABC 123', owner: 'Marcus Johnson', class: 'Sports', type: 'car', flags: ['Stolen'], status: 'stolen', points: 3 },
				{ id: 2, model: 'adder', label: 'Truffade Adder', plate: 'XYZ 789', owner: 'Sarah Williams', class: 'Super', type: 'car', flags: [], status: 'valid', points: 0 },
				{ id: 3, model: 'bati801', label: 'Pegassi Bati 801', plate: 'MOT 456', owner: 'David Chen', class: 'Motorcycles', type: 'bike', flags: ['Bolo'], status: 'bolo', points: 1 },
				{ id: 4, model: 'zentorno', label: 'Pegassi Zentorno', plate: 'SPD 001', owner: 'LSPD Fleet', class: 'Super', type: 'car', flags: [], status: 'valid', points: 0 },
				{ id: 5, model: 'sanchez', label: 'Sanchez', plate: 'DRT 321', owner: 'James Miller', class: 'Off-Road', type: 'bike', flags: ['Active Warrant'], status: 'impounded', points: 6, registered: false, registrationReason: 'No active registration' },
				{ id: 6, model: 'futo', label: 'Karin Futo', plate: 'INS 404', owner: 'Olivia Brown', class: 'Sports', type: 'car', flags: [], status: 'uninsured', reason: 'No active insurance', points: 2, registered: true },
			];
			loading = false;
		} else {
			loading = true;
			try {
				const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLES);
				applyVehiclesResponse(response);
			} catch (error) {
				globalNotifications.error("Failed to load vehicles");
				vehicleList = [];
			}
			loading = false;
		}
	});

	async function refreshVehicles() {
		if (isEnvBrowser()) return;
		loading = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLES);
			applyVehiclesResponse(response);
		} catch (error) {
			globalNotifications.error("Failed to load vehicles");
			vehicleList = [];
		}
		loading = false;
	}
</script>

{#if selectedVehicle || vehicleDetailLoading || vehicleDetailError}
	<!-- Vehicle Detail View -->
	<div class="vehicles-page">
		<div class="topbar">
			<button class="back-btn" onclick={closeVehicle}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
				Back
			</button>
			{#if selectedVehicle}
				<div class="topbar-info">
					<span class="topbar-name">{selectedVehicle.label}</span>
					<span class="topbar-plate">{selectedVehicle.plate}</span>
				</div>
				<div class="topbar-flags">
					{#if selectedVehicle.stolen}
						<span class="pill pill-red">Stolen</span>
					{/if}
					{#if selectedVehicle.boloactive}
						<span class="pill pill-orange">BOLO</span>
					{/if}
					{#if features.insurance}
						<span class="pill {getStatusClass(selectedVehicle.status || 'valid')}">
							{(selectedVehicle.status || 'Valid').charAt(0).toUpperCase() + (selectedVehicle.status || 'Valid').slice(1)}{selectedVehicle.reason?.trim() ? ` (${selectedVehicle.reason.trim()})` : ''}
						</span>
					{/if}
					{#if features.registration && !isVehicleRegistered(selectedVehicle)}
						<span class="pill pill-red" title={selectedVehicle.registrationReason?.trim() || undefined}>Unregistered</span>
					{/if}
				</div>
			{/if}
		</div>

		{#if vehicleDetailLoading}
			<div class="loading-state">Loading vehicle details...</div>
		{:else if vehicleDetailError}
			<div class="error-state">{vehicleDetailError}</div>
		{:else if selectedVehicle}
			<div class="detail-scroll">
				<!-- Vehicle Info Grid -->
				<div class="info-grid">
					<div class="info-card">
						<div class="info-card-icon">
							<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M7 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0H9m-6-6h15m-6 0V6"/></svg>
							{#if selectedVehicle.image && !selectedVehicle.image.startsWith('https://docs.fivem.net') && !vehicleImageBroken}
								<!-- svelte-ignore a11y_click_events_have_key_events -->
								<!-- svelte-ignore a11y_no_static_element_interactions -->
								<img 
									src={selectedVehicle.image} 
									alt="Vehicle" 
									class="info-card-img" 
									onclick={openVehicleLightbox}
									style="cursor:zoom-in;"
									onerror={() => vehicleImageBroken = true}
								/>
							{/if}
							<button class="img-edit-btn" onclick={openImageModal} title="Set vehicle image">
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
							</button>
						</div>
						<div class="info-card-body">
							<span class="info-card-label">Owner</span>
							<span class="info-card-value">{selectedVehicle.owner}</span>
						</div>
					</div>
					<div class="info-item"><span class="info-label">Plate</span><span class="info-value mono">{selectedVehicle.plate}</span></div>
					<div class="info-item"><span class="info-label">Model</span><span class="info-value">{selectedVehicle.label}</span></div>
					<div class="info-item"><span class="info-label">Class</span><span class="info-value">{selectedVehicle.class}</span></div>
					<div class="info-item"><span class="info-label">Type</span><span class="info-value">{selectedVehicle.type}</span></div>
					<div class="info-item"><span class="info-label">Brand</span><span class="info-value">{selectedVehicle.brand || 'Unknown'}</span></div>
					<div class="info-item"><span class="info-label">Reports</span><span class="info-value">{selectedVehicle.seenIn || 0}</span></div>
					{#if features.points}
						<div class="info-item"><span class="info-label">Points</span><span class="info-value" class:accent-red={(selectedVehicle.points ?? 0) > 0}>{selectedVehicle.points ?? 0}</span></div>
					{/if}
					{#if features.insurance}
						<div class="info-item">
							<span class="info-label">Insurance</span>
							<span class="info-value" class:state-active={isVehicleInsured(selectedVehicle)} class:accent-red={!isVehicleInsured(selectedVehicle)}>
								{isVehicleInsured(selectedVehicle) ? 'Insured' : 'Uninsured'}
							</span>
						</div>
					{/if}
					{#if features.registration}
						<div class="info-item">
							<span class="info-label">Registration</span>
							<span class="info-value" class:state-active={isVehicleRegistered(selectedVehicle)} class:accent-red={!isVehicleRegistered(selectedVehicle)}>
								{isVehicleRegistered(selectedVehicle) ? 'Registered' : 'Unregistered'}
							</span>
						</div>
					{/if}
					<div class="info-item">
						<span class="info-label">State</span>
						<span class="info-value" class:state-active={selectedVehicle.core_state === 0} class:state-garaged={selectedVehicle.core_state === 1} class:state-impounded-state={selectedVehicle.core_state === 2}>
							{selectedVehicle.core_state === 0 ? 'Out' : selectedVehicle.core_state === 1 ? 'Garaged' : selectedVehicle.core_state === 2 ? 'Impounded' : 'Unknown'}
						</span>
					</div>
				</div>

				<!-- ═══ Impound ═══
				     Hidden entirely when the feature is off. The buttons inside are
				     already permission-gated, but an empty "Impound" heading with a
				     history that can never be written reads as a broken section
				     rather than an absent one.

				     The State row above and the status pill in the list stay put
				     either way: core_state 2 is a fact about the vehicle in the
				     database, and another resource can set it. Reporting a car as
				     "Garaged" because this MDT does not handle impounds would be
				     telling an officer something untrue. ═══ -->
				{#if impoundEnabled}
				<div class="section">
					<div class="section-title">
						Impound
						{#if !activeImpound}
							<button class="danger-btn" use:permissionHint={canImpound ? null : "vehicle_impound"} onclick={openImpoundModal}>Impound vehicle</button>
						{/if}
					</div>

					{#if activeImpound}
						<div class="imp-card">
							<div class="imp-card-head">
								<span class="imp-badge">Impounded</span>
								<span class="imp-lot">{lotLabel(activeImpound.lot)}</span>
							</div>

							<div class="imp-rows">
								<div class="imp-row">
									<span class="imp-label">Reason</span>
									<span class="imp-value">{activeImpound.reason || '—'}</span>
								</div>
								<div class="imp-row">
									<span class="imp-label">Officer</span>
									<span class="imp-value">{activeImpound.officer_name || '—'}</span>
								</div>
								<div class="imp-row">
									<span class="imp-label">Impounded</span>
									<span class="imp-value">{formatDateTime(activeImpound.time)}</span>
								</div>
								<div class="imp-row">
									<span class="imp-label">Fee</span>
									<span class="imp-value">
										{money(activeImpound.total ?? activeImpound.fee)}
										{#if (activeImpound.total ?? activeImpound.fee) > 0}
											<span class="imp-fee-pill" class:paid={!!activeImpound.fee_paid}>
												{activeImpound.fee_paid ? 'Paid' : 'Unpaid'}
											</span>
										{/if}
									</span>
								</div>
								{#if (activeImpound.storage ?? 0) > 0}
									<div class="imp-row">
										<span class="imp-label">Storage</span>
										<span class="imp-value imp-storage">
											{money(activeImpound.fee)} impound + {money(activeImpound.storage ?? 0)} storage
											<span class="imp-days">{activeImpound.days_held} day{activeImpound.days_held === 1 ? '' : 's'} held</span>
										</span>
									</div>
								{/if}
								{#if activeImpound.linkedreport}
									<div class="imp-row">
										<span class="imp-label">Report</span>
										<button class="imp-link" onclick={() => openReportInEditor(String(activeImpound!.linkedreport))}>
											#{activeImpound.linkedreport}
										</button>
									</div>
								{/if}
							</div>

							<div class="imp-row">
								<span class="imp-label">Hold</span>
								<span class="imp-value">
									{#if activeImpound.hold_type === 'indefinite'}
										<span class="hold-pill hold-locked">Until released by an officer</span>
									{:else if activeImpound.hold_type === 'timed' && !activeImpound.hold_releasable}
										<span class="hold-pill hold-timed">
											{activeImpound.hold_label || 'Held'} · {holdLeft(activeImpound.hold_seconds_left ?? 0)}
										</span>
										<span class="hold-until">until {formatDateTime(activeImpound.hold_until ?? 0)}</span>
									{:else}
										<span class="hold-pill hold-free">Releasable</span>
									{/if}
								</span>
							</div>

							{#if activeImpound.notes}
								<div class="imp-notes">{activeImpound.notes}</div>
							{/if}

							{#if activeImpound.photo}
								<button class="imp-photo-thumb" type="button" title="Click to enlarge"
									onclick={() => (photoLightbox = activeImpound!.photo ?? null)}>
									<img src={activeImpound.photo} alt="Vehicle condition at impound" />
									<span class="imp-photo-zoom">
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35M11 8v6M8 11h6"/></svg>
									</span>
								</button>
							{/if}

							{#if canRelease}
								<div class="imp-actions">
									{#if (activeImpound.total ?? activeImpound.fee) > 0 && !activeImpound.fee_paid}
										<button class="primary-btn" disabled={impoundBusy}
											onclick={() => payFee(selectedVehicle!.plate)}>
											Collect {money(activeImpound.total ?? activeImpound.fee)}
										</button>
									{/if}
									{#if activeImpound.hold_releasable === false}
										<button class="danger-btn" disabled={impoundBusy && canOverride}
											use:permissionHint={canOverride ? null : "vehicle_impound_override"}
											onclick={() => { overridePlate = selectedVehicle!.plate; overrideReason = ""; overrideOpen = true; }}>
											Early release
										</button>
									{/if}
									<button class="release-btn"
										disabled={impoundBusy || activeImpound.hold_releasable === false}
										title={activeImpound.hold_releasable === false ? (activeImpound.hold_reason ?? '') : ''}
										onclick={() => releaseVehicle(selectedVehicle!.plate)}>
										Release vehicle
									</button>
								</div>
								{#if activeImpound.hold_releasable === false}
									<div class="imp-gate-hint">
										{activeImpound.hold_reason}
									</div>
								{:else if requireFeePaid && (activeImpound.total ?? activeImpound.fee) > 0 && !activeImpound.fee_paid}
									<div class="imp-hint">The fee must be collected before this vehicle can be released.</div>
								{:else}
									<div class="imp-hint">Releasing returns the vehicle to the owner's garage.</div>
								{/if}
							{/if}
						</div>
					{:else}
						<div class="imp-empty">This vehicle is not impounded.</div>
					{/if}

					{#if impoundHistory.filter(r => r.status === 'released').length > 0}
						<button class="imp-history-toggle" onclick={() => showHistory = !showHistory}>
							{showHistory ? 'Hide' : 'Show'} impound history ({impoundHistory.filter(r => r.status === 'released').length})
						</button>
						{#if showHistory}
							<div class="imp-history">
								{#each impoundHistory.filter(r => r.status === 'released') as rec (rec.id)}
									<div class="imp-hist-row">
										<div class="imp-hist-main">
											<span class="imp-hist-reason">{rec.reason || 'Impounded'}</span>
											<span class="imp-hist-meta">
												{formatDate(rec.time)}
												{#if rec.released_at}→ {formatDate(rec.released_at)}{/if}
											</span>
										</div>
										<div class="imp-hist-side">
											{#if rec.fee > 0}<span class="imp-hist-fee">{money(rec.fee)}</span>{/if}
											<span class="imp-hist-officer">{rec.officer_name || '—'}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					{/if}
				</div>
				{/if}

				<div class="section">
					<div class="section-title">
						Notes
						{#if !editingNotes}
							<button class="notes-edit-btn" onclick={startEditNotes}>
								<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
								Edit
							</button>
						{/if}
					</div>
					{#if editingNotes}
						<textarea
							class="notes-textarea"
							bind:value={notesValue}
							placeholder="Enter notes..."
							maxlength={500}
							onkeydown={(e) => { if (e.key === 'Enter' && e.ctrlKey) saveNotes(); if (e.key === 'Escape') { editingNotes = false; } }}
						></textarea>
						<div class="notes-actions">
							<div style="display:flex;gap:6px;">
								<button class="notes-save-btn" onclick={saveNotes} disabled={notesSaving}>
									{notesSaving ? 'Saving...' : 'Save'}
								</button>
								<button class="notes-cancel-btn" onclick={() => { editingNotes = false; }}>Cancel</button>
							</div>
							<span class="notes-char-count" class:notes-char-warn={notesValue.length > 450}>
								{notesValue.length}/500
							</span>
						</div>
					{:else}
						{#if selectedVehicle.information?.trim()}
							<p class="section-text">{selectedVehicle.information}</p>
						{:else}
							<div class="section-empty">No notes on file.</div>
						{/if}
					{/if}
				</div>

				{#if selectedVehicle.flags?.filter(f => !f.toLowerCase().startsWith('status:')).length}
					<div class="section">
						<div class="section-title">Flags</div>
						<div class="flags-row">
							{#each selectedVehicle.flags.filter(f => !f.toLowerCase().startsWith('status:')) as flag}
								<span class={getFlagClass(flag)}>{flag}</span>
							{/each}
						</div>
					</div>
				{/if}

				{#if features.points}
					<div class="section">
						<div class="section-title">
							License Points
							{#if pointsDirty}
								<span class="points-pending">{pointsDelta > 0 ? `+${pointsDelta}` : pointsDelta} unsaved</span>
							{/if}
						</div>

						{#if canEditPoints}
							<div class="points-editor">
								<div class="points-stepper">
									<button class="pt-step" onclick={() => adjustPoints(-1)} disabled={pointsDraft <= 0} title="Remove one point" type="button" aria-label="Remove one point">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/></svg>
									</button>
									<div class="pt-value" class:pt-value-zero={pointsDraft === 0}>{pointsDraft}</div>
									<button class="pt-step" onclick={() => adjustPoints(1)} disabled={pointsDraft >= 1000} title="Add one point" type="button" aria-label="Add one point">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
									</button>
								</div>

								<div class="pt-pips" aria-hidden="true">
									{#each Array(pointPips.max) as _, i}
										<span class="pt-pip" class:pt-pip-on={i < pointPips.filled}></span>
									{/each}
									{#if pointPips.overflow > 0}
										<span class="pt-pip-overflow">+{pointPips.overflow}</span>
									{/if}
								</div>

								<div class="pt-presets">
									<span class="pt-presets-label">Quick add</span>
									{#each POINT_PRESETS as preset}
										<button class="pt-chip" onclick={() => adjustPoints(preset)} type="button">+{preset}</button>
									{/each}
									<button class="pt-chip pt-chip-reset" onclick={resetPoints} disabled={pointsDraft === 0} type="button">Reset</button>
								</div>

								<div class="pt-actions">
									<button class="pt-save" onclick={savePoints} disabled={pointsSaving || !pointsDirty} type="button">
										{pointsSaving ? "Saving..." : pointsDirty ? "Save points" : "Saved"}
									</button>
									{#if pointsDirty}
										<button class="pt-revert" onclick={() => pointsDraft = savedPoints} type="button">Revert</button>
									{/if}
								</div>
							</div>
						{:else}
							<div class="points-readonly" class:accent-red={(selectedVehicle.points ?? 0) > 0}>
								<span class="pt-readonly-value">{selectedVehicle.points ?? 0}</span>
								<span class="pt-readonly-label">points on record</span>
							</div>
						{/if}
					</div>
				{/if}

				{#if selectedVehicle.bolos && selectedVehicle.bolos.length}
					<div class="section">
						<div class="section-title">Related BOLOs</div>
						<div class="bolos-list">
							{#each selectedVehicle.bolos as bolo}
								<div class="bolo-item">
									<div class="bolo-item-top">
										<span class="bolo-item-id">{bolo.reportId}</span>
										<span class="pill pill-orange">{bolo.status}</span>
									</div>
									{#if bolo.notes}
										<p class="bolo-item-notes">{bolo.notes}</p>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}

				<div class="section">
					<div class="section-title">Linked Reports <span class="report-count">{linkedReports.length}</span></div>
					{#if linkedReportsLoading}
						<div class="section-empty">Loading reports...</div>
					{:else if linkedReports.length > 0}
						<div class="linked-reports-list">
							{#each linkedReports as lr}
								<div class="linked-report-item">
									<div class="lr-info">
										<span class="lr-title">{lr.title}</span>
										<span class="lr-meta">{lr.type} &middot; {lr.authorplaintext} &middot; {formatDate(lr.datecreated)}</span>
									</div>
									<button class="lr-view-btn" onclick={() => goToReport(lr.id)}>View</button>
								</div>
							{/each}
						</div>
					{:else}
						<div class="section-empty">No reports linked to this vehicle</div>
					{/if}
				</div>
			</div>
		{/if}
		<!-- ═══ Impound modal ═══ -->
		{#if showImpoundModal && selectedVehicle}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) showImpoundModal = false; }}>
				<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
					<div class="modal-header">
						<h3>Impound {selectedVehicle.plate}</h3>
						<button class="close-btn" aria-label="Close" onclick={() => (showImpoundModal = false)}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<line x1="18" y1="6" x2="6" y2="18"/>
								<line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>

					<div class="modal-body form-body">
						<ImpoundFormFields
							reasons={impoundReasons}
							lots={impoundLots}
							durations={impoundDurations}
							{defaultDuration}
							storage={impoundStorage}
							{maxFee}
							bind:reason={imReason}
							bind:fee={imFee}
							bind:lot={imLot}
							bind:duration={imDuration}
							bind:notes={imNotes}
							bind:photo={imPhoto}
						/>
					</div>

					<div class="modal-footer">
						<span class="modal-hint">
							{imFee > 0
								? `${money(imFee)} is charged to the owner when the vehicle is released`
								: "No fee will be charged"}
						</span>
						<div class="modal-footer-right">
							<button class="cancel-btn" disabled={impoundBusy} onclick={() => (showImpoundModal = false)}>Cancel</button>
							<button class="danger-btn" disabled={impoundBusy || !imReason} onclick={submitImpound}>Impound</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		{#if imageModalOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="img-modal-overlay" onclick={(e) => { if (e.target === e.currentTarget) imageModalOpen = false; }}>
				<div class="img-modal" onclick={(e) => e.stopPropagation()}>
					<div class="img-modal-header">
						<span>Set Vehicle Image</span>
						<button class="img-modal-close" onclick={() => imageModalOpen = false}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					</div>
					<div class="img-modal-body">
						<span class="img-modal-label">Image URL</span>
						<input
							class="img-modal-input"
							type="url"
							placeholder="https://r2.fivemanage.com/..."
							bind:value={imageUrlInput}
							onkeydown={(e) => { if (e.key === 'Enter') saveVehicleImage(); if (e.key === 'Escape') imageModalOpen = false; }}
						/>
						<span class="img-modal-hint">
							<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
							Use <a href="https://fivemanage.com" target="_blank" rel="noopener noreferrer">FiveManage</a> for permanent links.
						</span>
					</div>
					<div class="img-modal-footer">
						<button class="img-modal-cancel" onclick={() => imageModalOpen = false} disabled={imageSaving}>Cancel</button>
						<button class="img-modal-confirm" onclick={saveVehicleImage} disabled={imageSaving || !imageUrlInput.trim()}>
							{imageSaving ? "Saving…" : "Set Image"}
						</button>
					</div>
				</div>
			</div>
		{/if}
		{#if vehicleLightboxOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="img-modal-overlay" onclick={() => vehicleLightboxOpen = false}>
				<div class="vehicle-lightbox" onclick={(e) => e.stopPropagation()}>
					<button class="lightbox-close-btn" onclick={() => vehicleLightboxOpen = false}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
					</button>
					<img src={selectedVehicle?.image} alt="Vehicle" class="vehicle-lightbox-img" />
				</div>
			</div>
		{/if}
	</div>
{:else}
	<!-- Vehicle List View -->
	<div class="vehicles-page">
		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" bind:value={searchQuery} placeholder="Search vehicles by owner, plate, class..." />
			</div>
			<button class="refresh-btn" onclick={refreshVehicles} disabled={loading}>
				{loading ? "Loading..." : "Refresh"}
			</button>
		</div>

		<div class="filter-tabs">
			<button class="filter-tab" class:active={statusFilter === "all"} onclick={() => { statusFilter = "all"; vehiclePage = 1; }}>All</button>
			<button class="filter-tab" class:active={statusFilter === "active"} onclick={() => { statusFilter = "active"; vehiclePage = 1; }}>Active</button>
			<button class="filter-tab" class:active={statusFilter === "garaged"} onclick={() => { statusFilter = "garaged"; vehiclePage = 1; }}>Garaged</button>
			<button class="filter-tab" class:active={statusFilter === "impounded"} onclick={() => { statusFilter = "impounded"; vehiclePage = 1; }}>Impounded</button>
			<button class="filter-tab" class:active={statusFilter === "stolen"} onclick={() => { statusFilter = "stolen"; vehiclePage = 1; }}>Stolen</button>
			<button class="lot-open-btn" onclick={openLotView} title="Every vehicle currently in an impound lot">
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 17V7h4a3 3 0 0 1 0 6H9"/></svg>
				Impound Lot
			</button>
		</div>

		<div class="list-panel">
			<div class="list-header" style="grid-template-columns: {listGridColumns};">
			    <span></span>
				<span class="col-name">Vehicle</span>
				<span class="col-plate">Plate</span>
				<span class="col-owner">Owner</span>
				<span class="col-class">Class</span>
				{#if features.points}
					<span class="col-points">Points</span>
				{/if}
				{#if features.insurance}
					<span class="col-status">Insurance</span>
				{/if}
				{#if features.registration}
					<span class="col-status">Registration</span>
				{/if}
				<span class="col-flags">Flags</span>
			</div>
			<div class="list-body">
				{#if loading}
					<SkeletonList rows={9} thumb={false} columns={[1.4, 1.4, 1, 0.8]} />
				{:else if filteredVehicles.length === 0}
					<div class="empty-state">{searchQuery ? "No vehicles match your search." : "No vehicles found."}</div>
				{:else}
					{#each filteredVehicles as vehicle}
						<button class="vehicle-row" style="grid-template-columns: {listGridColumns};" onclick={() => viewVehicle(vehicle.plate)}>
							<div class="vehicle-avatar">
								{#if vehicle.image && !vehicle.image.startsWith('https://docs.fivem.net')}
									<img src={vehicle.image} alt="" onerror={(e) => { (e.target as HTMLImageElement).style.display = 'none'; (e.target as HTMLImageElement).nextElementSibling?.removeAttribute('style'); }} />
									<svg style="display:none" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0H9m-6-6h15m-6 0V6"/></svg>
								{:else}
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0H9m-6-6h15m-6 0V6"/></svg>
								{/if}
							</div>
							<span class="col-name">{vehicle.label}</span>
							<span class="col-plate mono">{vehicle.plate}</span>
							<span class="col-owner">{vehicle.owner}</span>
							<span class="col-class">{vehicle.class}</span>
							{#if features.points}
								<span class="col-points" class:accent-red={(vehicle.points ?? 0) > 0}>{vehicle.points ?? 0}</span>
							{/if}
							{#if features.insurance}
								<span class="col-status">
									<span 
										class="status-pill {getStatusClass(vehicle.status || 'valid')}"
										title={vehicle.reason?.trim() ? `${vehicle.status}: ${vehicle.reason}` : undefined}
										>{vehicle.status || 'Valid'}
									</span>
								</span>
							{/if}
							{#if features.registration}
								<span class="col-status">
									<span 
										class="status-pill {isVehicleRegistered(vehicle) ? 'status-registered' : 'status-unregistered'}"
										title={!isVehicleRegistered(vehicle) && vehicle.registrationReason?.trim() ? vehicle.registrationReason : undefined}
										>{isVehicleRegistered(vehicle) ? 'Registered' : 'Unregistered'}
									</span>
								</span>
							{/if}
							<span class="col-flags">
								{#each (vehicle.flags || []).filter(f => !f.toLowerCase().startsWith('status:')) as flag}
									<span class={getFlagClass(flag)}>{flag}</span>
								{/each}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Pagination
				currentPage={vehiclePage}
				totalItems={allFilteredVehicles.length}
				perPage={vehiclePerPage}
				onPageChange={(p) => { vehiclePage = p; }}
				onPerPageChange={(pp) => { vehiclePerPage = pp; vehiclePage = 1; }}
			/>
		</div>
	</div>
{/if}

	<!-- Early release: overriding a hold somebody set on purpose, so it asks why and
	     the reason goes into the audit trail under the officer's name. -->
	{#if overrideOpen}
		<div class="modal-backdrop">
			<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
				<div class="modal-header">
					<h3>Early release — {overridePlate}</h3>
					<button class="close-btn" aria-label="Close" onclick={() => (overrideOpen = false)}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
				</div>

				<div class="modal-body">
					<p class="override-warn">
						This vehicle is under a hold. Releasing it now overrides that decision and will be recorded against your name.
					</p>
					<div class="form-group">
						<span class="field-label">Reason <span class="req">*</span></span>
						<textarea class="form-input" rows="3" maxlength="300" bind:value={overrideReason}
							placeholder="Why is this vehicle being released early?"></textarea>
					</div>
				</div>

				<div class="modal-footer">
					<span class="modal-hint">Logged in the audit trail</span>
					<div class="modal-footer-right">
						<button class="cancel-btn" disabled={impoundBusy} onclick={() => (overrideOpen = false)}>Cancel</button>
						<button class="danger-btn"
							disabled={impoundBusy || overrideReason.trim().length < 3}
							onclick={async () => {
								await releaseVehicle(overridePlate, { reason: overrideReason.trim() });
								overrideOpen = false;
							}}>
							Release anyway
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Impound photo, full size -->
	{#if photoLightbox}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="imp-lightbox" onclick={() => (photoLightbox = null)}>
			<div class="imp-lightbox-card" onclick={(e) => e.stopPropagation()}>
				<button class="imp-lightbox-close" aria-label="Close" onclick={() => (photoLightbox = null)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
				<img class="imp-lightbox-img" src={photoLightbox} alt="Vehicle condition at impound" />
			</div>
		</div>
	{/if}

	<!-- ═══ Impound lot: the work list of everything currently impounded ═══ -->
	{#if showLotView}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) showLotView = false; }}>
			<div class="modal modal-wide" role="dialog" aria-modal="true" tabindex="-1">
				<div class="modal-header">
					<h3>Impound Lot</h3>
					<button class="close-btn" aria-label="Close" onclick={() => (showLotView = false)}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<line x1="18" y1="6" x2="6" y2="18"/>
							<line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
				</div>

				<div class="lot-toolbar">
					<input class="form-input lot-search" placeholder="Search plate, owner or reason…" bind:value={lotSearch} />
					<select class="form-input form-select" bind:value={lotFilter}>
						<option value="all">All lots</option>
						{#each impoundLots as l}
							<option value={l.id}>{l.label}</option>
						{/each}
					</select>
				</div>

				<div class="modal-body lot-body">
					{#if lotLoading}
						<div class="lot-empty">Loading…</div>
					{:else if lotFiltered.length === 0}
						<div class="lot-empty">No vehicles are impounded{lotSearch ? " matching that search" : ""}.</div>
					{:else}
						{#each lotVisible as v (v.id)}
							<div class="lot-row">
								<div class="lot-main">
									<div class="lot-line1">
										<span class="lot-plate">{v.plate}</span>
										<span class="lot-model">{v.model || ""}</span>
										<span class="lot-lotname">{lotLabel(v.lot)}</span>
										{#if (v.total ?? v.fee) > 0}
											<span class="imp-fee-pill" class:paid={!!v.fee_paid}>
												{money(v.total ?? v.fee)} {v.fee_paid ? "paid" : "due"}
											</span>
										{/if}
										{#if (v.days_held ?? 0) > 0}
											<span class="lot-days">{v.days_held}d</span>
										{/if}
										{#if v.hold_type === 'indefinite'}
											<span class="hold-pill hold-locked">Held</span>
										{:else if v.hold_type === 'timed' && !v.hold_releasable}
											<span class="hold-pill hold-timed">{holdLeft(v.hold_seconds_left ?? 0)}</span>
										{/if}
									</div>
									<div class="lot-line2">
										<span class="lot-reason">{v.reason || "—"}</span>
										<span class="lot-dot"></span>
										<span>{v.owner_name || "Unknown owner"}</span>
										<span class="lot-dot"></span>
										<span>{formatDate(v.time)}</span>
									</div>
								</div>

								<div class="lot-side">
									{#if canRelease}
										{#if v.fee > 0 && !v.fee_paid}
											<button class="primary-btn" disabled={impoundBusy} onclick={() => payFee(v.plate!)}>Collect</button>
										{/if}
										<button class="release-btn"
											disabled={impoundBusy || v.hold_releasable === false}
											title={v.hold_releasable === false ? (v.hold_reason ?? '') : ''}
											onclick={() => releaseVehicle(v.plate!)}>Release</button>
									{/if}
									<button class="cancel-btn" onclick={() => { showLotView = false; viewVehicle(v.plate!); }}>Open</button>
								</div>
							</div>
						{/each}

						{#if lotHasMore}
							<button class="lot-more" onclick={loadMoreLot}>
								Load more ({lotRemaining} left)
							</button>
						{/if}
					{/if}
				</div>

				<div class="modal-footer">
					<span class="modal-hint">
						<!-- Say what's on screen as well as what's held, or "24 vehicles held"
						     next to 10 rows just looks like a bug. -->
						{#if lotHasMore}
							Showing {lotVisible.length} of {lotFiltered.length} held
						{:else}
							{lotFiltered.length} vehicle{lotFiltered.length === 1 ? "" : "s"} held
						{/if}
						{#if lotUnpaidTotal > 0}· <span class="lot-unpaid">{money(lotUnpaidTotal)} outstanding</span>{/if}
					</span>
					<div class="modal-footer-right">
						<button class="cancel-btn" onclick={() => (showLotView = false)}>Close</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

<style>
	/* ===== Page ===== */
	.vehicles-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		overflow: hidden;
	}

	/* ===== Topbar ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-info {
		display: flex;
		align-items: baseline;
		gap: 8px;
	}

	.topbar-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
		font-weight: 600;
	}

	.topbar-plate {
		color: rgba(255, 255, 255, 0.3);
		font-size: 11px;
		font-family: monospace;
	}

	.topbar-flags {
		display: flex;
		gap: 5px;
		margin-left: auto;
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 5px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.back-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		flex: 1;
		max-width: 400px;
		color: rgba(255, 255, 255, 0.2);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.refresh-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.refresh-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.refresh-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ===== Filter Tabs ===== */
	.filter-tabs {
		display: flex;
		gap: 2px;
		flex-shrink: 0;
		padding: 0 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.filter-tab {
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		border-radius: 0;
		padding: 6px 10px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.filter-tab:hover {
		color: rgba(255, 255, 255, 0.6);
	}

	.filter-tab.active {
		color: rgba(96, 165, 250, 0.9);
		border-bottom-color: rgba(var(--accent-rgb), 0.5);
	}

	/* ===== List Panel ===== */
	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.list-header {
		display: grid;
		grid-template-columns: 28px 2fr 1fr 1.5fr 0.8fr 0.6fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		flex-shrink: 0;
	}

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.vehicle-avatar { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.04); display: grid; place-items: center; overflow: hidden; flex-shrink: 0; color: rgba(255,255,255,0.15); position: relative; }
	.vehicle-avatar img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
	.vehicle-avatar svg { position: relative; z-index: 0; }

	.list-body::-webkit-scrollbar { width: 4px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.vehicle-row {
		display: grid;
		grid-template-columns: 28px 2fr 1fr 1.5fr 0.8fr 0.6fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 7px 16px;
		align-items: center;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		cursor: pointer;
		transition: background 0.1s;
		width: 100%;
		text-align: left;
		font: inherit;
		color: inherit;
	}

	.vehicle-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.col-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-plate {
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
	}

	.col-owner {
		color: rgba(255, 255, 255, 0.45);
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-class {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.col-points {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 600;
	}

	.accent-red { color: rgba(248, 113, 113, 0.8) !important; }

	.col-status { display: flex; align-items: center; }
	.col-flags { display: flex; gap: 3px; flex-wrap: wrap; }

	.mono { font-family: monospace; letter-spacing: 0.5px; }

	/* ===== Pills ===== */
	.pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	/* Impounded is a location, not an accusation — it reads calmly next to Stolen/Bolo. */
	.pill-blue {
		background: rgba(59, 130, 246, 0.1);
		color: rgba(147, 197, 253, 0.85);
		border: 1px solid rgba(59, 130, 246, 0.18);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	/* ===== Status Pills ===== */
	.status-pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		text-transform: capitalize;
		letter-spacing: 0.3px;
	}

	.status-valid {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-stolen {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.status-bolo {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.status-suspended {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.status-expired {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	.status-impounded {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.status-uninsured {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.status-registered {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-unregistered {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	/* ===== Empty / Loading ===== */
	.empty-state, .loading-state, .error-state {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.error-state { color: rgba(248, 113, 113, 0.8); }

	/* ===== Detail View ===== */
	.detail-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.detail-scroll::-webkit-scrollbar { width: 4px; }
	.detail-scroll::-webkit-scrollbar-track { background: transparent; }
	.detail-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	/* Info Grid */
	.info-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 8px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
	}

	.info-card {
		grid-column: 1 / -1;
		display: flex;
		align-items: center;
		gap: 10px;
		padding-bottom: 10px;
		margin-bottom: 2px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.info-card-icon { width: 108px; height: 108px; border-radius: 3px; background: rgba(255,255,255,0.03); display: grid; place-items: center; color: rgba(255,255,255,0.15); flex-shrink: 0; overflow: hidden; position: relative; }
	.info-card-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
	.info-card-icon svg:first-child { position: relative; z-index: 0; }

	.info-card-body {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.info-card-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.info-card-value {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 600;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 4px 0;
	}

	.info-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.info-value {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 500;
	}

	.info-value.mono { font-family: monospace; letter-spacing: 0.5px; }

	.section {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
	}

	.section:last-child {
		border-bottom: none;
	}

	.section-text {
		margin: 0;
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		line-height: 1.5;
		word-break: break-word;
		white-space: pre-wrap;
	}

	.flags-row {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	/* ===== License Points Editor ===== */
	.points-pending {
		margin-left: 8px;
		font-size: 9px;
		font-weight: 700;
		letter-spacing: 0.3px;
		color: rgba(251, 191, 36, 0.85);
		background: rgba(245, 158, 11, 0.08);
		border: 1px solid rgba(245, 158, 11, 0.12);
		border-radius: 3px;
		padding: 1px 6px;
		text-transform: none;
	}

	.points-editor {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.points-stepper {
		display: flex;
		align-items: center;
		gap: 14px;
	}

	.pt-step {
		width: 30px;
		height: 30px;
		display: grid;
		place-items: center;
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.07);
		color: rgba(255, 255, 255, 0.7);
		cursor: pointer;
		transition: background 0.1s, color 0.1s, border-color 0.1s;
	}

	.pt-step:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.95);
		border-color: rgba(255, 255, 255, 0.12);
	}

	.pt-step:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.pt-value {
		min-width: 56px;
		text-align: center;
		font-family: monospace;
		font-size: 30px;
		font-weight: 700;
		line-height: 1;
		letter-spacing: 1px;
		color: rgba(248, 113, 113, 0.9);
		font-variant-numeric: tabular-nums;
	}

	.pt-value-zero {
		color: rgba(255, 255, 255, 0.85);
	}

	.pt-pips {
		display: flex;
		align-items: center;
		gap: 4px;
		flex-wrap: wrap;
	}

	.pt-pip {
		width: 16px;
		height: 6px;
		border-radius: 2px;
		background: rgba(255, 255, 255, 0.07);
		transition: background 0.1s;
	}

	.pt-pip-on {
		background: rgba(248, 113, 113, 0.7);
	}

	.pt-pip-overflow {
		margin-left: 4px;
		font-family: monospace;
		font-size: 10px;
		font-weight: 700;
		color: rgba(248, 113, 113, 0.85);
	}

	.pt-presets {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}

	.pt-presets-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-right: 2px;
	}

	.pt-chip {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 4px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 600;
		font-family: monospace;
		cursor: pointer;
		transition: background 0.1s, color 0.1s, border-color 0.1s;
	}

	.pt-chip:hover:not(:disabled) {
		background: rgba(248, 113, 113, 0.1);
		color: rgba(248, 113, 113, 0.9);
		border-color: rgba(239, 68, 68, 0.15);
	}

	.pt-chip-reset {
		font-family: inherit;
		color: rgba(255, 255, 255, 0.45);
	}

	.pt-chip-reset:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.8);
		border-color: rgba(255, 255, 255, 0.12);
	}

	.pt-chip:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.pt-actions {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.pt-save {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.12);
		padding: 5px 14px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.1s, color 0.1s;
	}

	.pt-save:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.95);
	}

	.pt-save:disabled {
		opacity: 0.35;
		cursor: not-allowed;
	}

	.pt-revert {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		padding: 5px 6px;
	}

	.pt-revert:hover {
		color: rgba(255, 255, 255, 0.7);
	}

	.points-readonly {
		display: flex;
		align-items: baseline;
		gap: 8px;
		color: rgba(255, 255, 255, 0.85);
	}

	.pt-readonly-value {
		font-family: monospace;
		font-size: 24px;
		font-weight: 700;
		line-height: 1;
	}

	.pt-readonly-label {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
	}

	/* ===== BOLOs in Detail ===== */
	.bolos-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.bolo-item {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 6px 0;
	}

	.bolo-item:last-child {
		border-bottom: none;
	}

	.bolo-item-top {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.bolo-item-id {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-family: monospace;
	}

	.bolo-item-notes {
		margin: 3px 0 0;
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		line-height: 1.4;
	}

	.report-count {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		padding: 1px 5px;
		border-radius: 3px;
		font-weight: 600;
		margin-left: 4px;
	}

	.linked-reports-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.linked-report-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 6px 0;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		transition: background 0.1s;
	}

	.linked-report-item:last-child {
		border-bottom: none;
	}

	.linked-report-item:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.lr-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
		flex: 1;
	}

	.lr-view-btn {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 500;
		padding: 3px 8px;
		border-radius: 3px;
		cursor: pointer;
		white-space: nowrap;
		flex-shrink: 0;
		transition: all 0.1s;
		opacity: 0;
	}

	.linked-report-item:hover .lr-view-btn {
		opacity: 1;
	}

	.lr-view-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.lr-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 500;
	}

	.lr-meta {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.section-empty {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
		text-align: center;
		padding: 12px 0;
	}

	.state-active { color: rgba(52, 211, 153, 0.8) !important; }
	.state-garaged { color: rgba(var(--accent-text-rgb), 0.8) !important; }
	.state-impounded-state { color: rgba(251, 191, 36, 0.8) !important; }

	/* ===== Modal ===== */
	.img-modal-overlay {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 100;
		backdrop-filter: blur(2px);
	}

	.img-modal {
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		width: min(360px, 92vw);
		display: flex;
		flex-direction: column;
	}

	.img-modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.img-modal-close {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
	}

	.img-modal-close:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.img-modal-body {
		padding: 14px 16px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.img-modal-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.img-modal-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		width: 100%;
	}

	.img-modal-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.img-modal-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.img-modal-hint {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
		line-height: 1.4;
	}

	.img-modal-hint a {
		color: rgba(var(--accent-text-rgb), 0.5);
		text-decoration: none;
		transition: color 0.1s;
	}

	.img-modal-hint a:hover {
		color: rgba(var(--accent-text-rgb), 0.85);
		text-decoration: underline;
	}

	.img-modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.img-modal-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.img-modal-cancel:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.img-modal-cancel:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.img-modal-confirm {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.img-modal-confirm:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.img-modal-confirm:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	/* ===== Image Edit / Lightbox ===== */
	.img-edit-btn {
		position: absolute;
		bottom: -1px;
		right: -1px;
		width: 22px;
		height: 22px;
		background: rgba(0, 0, 0, 0.7);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
	}

	.img-edit-btn:hover {
		color: rgba(255, 255, 255, 0.9);
		border-color: rgba(255, 255, 255, 0.2);
	}

	.vehicle-lightbox {
		position: relative;
		padding-top: 32px;
	}

	.lightbox-close-btn {
		position: absolute;
		top: 0;
		right: 0;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.6);
		cursor: pointer;
		padding: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
	}

	.lightbox-close-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		color: #fff;
	}

	.vehicle-lightbox-img {
		max-width: 90vw;
		max-height: calc(90vh - 32px);
		object-fit: contain;
		display: block;
		border-radius: 4px;
	}

	/* ===== Vehicle Notes ===== */
	.section-title {
		display: flex;
		align-items: center;
		gap: 6px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 8px;
	}

	.notes-edit-btn {
		display: flex;
		align-items: center;
		gap: 3px;
		margin-left: auto;
		background: rgba(59, 130, 246, 0.06);
		border: 1px solid rgba(59, 130, 246, 0.1);
		border-radius: 3px;
		padding: 2px 8px;
		color: rgba(147, 197, 253, 0.7);
		font-size: 9px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.12s;
		text-transform: none;
		letter-spacing: 0;
	}

	.notes-edit-btn:hover {
		background: rgba(59, 130, 246, 0.12);
		color: rgba(147, 197, 253, 0.9);
	}

	.notes-textarea {
		width: 100%;
		min-height: 80px;
		max-height: 300px;
		resize: vertical;
		overflow-y: auto;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		padding: 6px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		line-height: 1.5;
		outline: none;
		box-sizing: border-box;
		transition: border-color 0.1s;
	}

	.notes-textarea:focus {
		border-color: rgba(96, 165, 250, 0.3);
	}

	.notes-textarea::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.notes-actions {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-top: 8px;
	}

	.notes-save-btn {
		background: rgba(16, 185, 129, 0.08);
		border: 1px solid rgba(16, 185, 129, 0.15);
		color: rgba(52, 211, 153, 0.8);
		padding: 4px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.12s;
	}

	.notes-save-btn:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.14);
		color: #34d399;
	}

	.notes-save-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.notes-cancel-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.12s;
	}

	.notes-cancel-btn:hover {
		color: rgba(255, 255, 255, 0.6);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.notes-char-count {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.2);
	}

	.notes-char-warn {
		color: #f87171;
	}

	/* ═══ Impound ═══ */

	.imp-card {
		background: rgba(251, 191, 36, 0.05);
		border: 1px solid rgba(251, 191, 36, 0.25);
		border-left-width: 3px;
		border-radius: 6px;
		padding: 10px 12px;
		display: flex;
		flex-direction: column;
		gap: 9px;
	}
	.imp-card-head { display: flex; align-items: center; gap: 8px; }
	.imp-badge {
		background: rgba(251, 191, 36, 0.16);
		border: 1px solid rgba(251, 191, 36, 0.35);
		border-radius: 3px;
		color: rgba(252, 211, 77, 0.95);
		font-size: 9px;
		font-weight: 800;
		letter-spacing: 0.4px;
		text-transform: uppercase;
		padding: 2px 7px;
	}
	.imp-lot { font-size: 11px; color: rgba(255, 255, 255, 0.55); }

	.imp-rows { display: flex; flex-direction: column; gap: 5px; }
	.imp-row { display: flex; align-items: center; gap: 10px; }
	.imp-label {
		min-width: 74px;
		font-size: 9px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: rgba(255, 255, 255, 0.35);
	}
	.imp-value {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 7px;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.85);
	}
	.imp-fee-pill {
		background: rgba(239, 68, 68, 0.14);
		border: 1px solid rgba(239, 68, 68, 0.35);
		border-radius: 3px;
		color: rgba(248, 113, 113, 0.95);
		font-size: 9px;
		font-weight: 700;
		padding: 1px 6px;
		white-space: nowrap;
	}
	.imp-fee-pill.paid {
		background: rgba(16, 185, 129, 0.12);
		border-color: rgba(16, 185, 129, 0.35);
		color: rgba(52, 211, 153, 0.95);
	}
	.imp-link {
		background: none;
		border: none;
		padding: 0;
		color: rgba(125, 211, 252, 0.9);
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
	}
	.imp-link:hover { text-decoration: underline; }
	.imp-notes {
		background: rgba(255, 255, 255, 0.03);
		border-radius: 4px;
		padding: 6px 9px;
		font-size: 11px;
		line-height: 1.45;
		color: rgba(255, 255, 255, 0.7);
		white-space: pre-wrap;
		word-break: break-word;
	}
	.imp-actions { display: flex; gap: 6px; flex-wrap: wrap; }
	.imp-hint { font-size: 9px; color: rgba(255, 255, 255, 0.35); font-style: italic; }
	.imp-empty { font-size: 11px; color: rgba(255, 255, 255, 0.3); font-style: italic; }


	.imp-history-toggle {
		margin-top: 8px;
		background: none;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
	}
	.imp-history-toggle:hover { color: rgba(255, 255, 255, 0.7); }
	.imp-history { margin-top: 7px; display: flex; flex-direction: column; gap: 4px; }
	.imp-hist-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 10px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 4px;
		padding: 6px 9px;
	}
	.imp-hist-main { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
	.imp-hist-reason { font-size: 11px; color: rgba(255, 255, 255, 0.8); }
	.imp-hist-meta { font-size: 9px; color: rgba(255, 255, 255, 0.35); }
	.imp-hist-side { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
	.imp-hist-fee { font-size: 10px; color: rgba(255, 255, 255, 0.5); font-variant-numeric: tabular-nums; }
	.imp-hist-officer { font-size: 9px; color: rgba(255, 255, 255, 0.35); }

	/* ── Modals: same design language as the Add Weapon modal ── */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}
	.modal {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		width: min(540px, 92vw);
		max-height: 85vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}
	.modal-wide { width: min(720px, 94vw); }
	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.modal-header h3 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.85); }
	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 4px;
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
	}
	.close-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.modal-body { padding: 14px 16px; overflow-y: auto; }
	.form-body { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
	.form-group { display: flex; flex-direction: column; gap: 3px; }
	.form-full { grid-column: 1 / -1; }
	.field-label {
		display: flex;
		align-items: center;
		gap: 8px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}
	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		transition: border-color 0.1s;
	}
	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }
	.form-select { padding-right: 22px; font-size: 10px; cursor: pointer; }
	.form-input option { background: #1a1d23; }
	.modal-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 10px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}
	.modal-footer-right { display: flex; gap: 6px; }
	.modal-hint { font-size: 10px; color: rgba(255, 255, 255, 0.35); }
	.cancel-btn {
		background: transparent;
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}
	.cancel-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.primary-btn {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.primary-btn:hover:not(:disabled) { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }
	.primary-btn:disabled, .cancel-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.danger-btn {
		background: rgba(239, 68, 68, 0.06);
		color: rgba(248, 113, 113, 0.75);
		border: 1px solid rgba(239, 68, 68, 0.12);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.danger-btn:hover:not(:disabled) { background: rgba(239, 68, 68, 0.13); color: rgba(252, 165, 165, 0.95); }
	.danger-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.release-btn {
		background: rgba(56, 189, 248, 0.06);
		color: rgba(125, 211, 252, 0.75);
		border: 1px solid rgba(56, 189, 248, 0.12);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.release-btn:hover:not(:disabled) { background: rgba(56, 189, 248, 0.13); color: rgba(186, 230, 253, 0.95); }
	.release-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	/* ── Fee editor: steppers + quick amounts, echoing the points editor ── */
	.fee-editor {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 14px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 5px;
		padding: 9px 12px;
	}
	.fee-stepper { display: flex; align-items: center; gap: 10px; }
	.fee-step {
		width: 28px;
		height: 28px;
		display: grid;
		place-items: center;
		border-radius: 5px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.07);
		color: rgba(255, 255, 255, 0.7);
		cursor: pointer;
		transition: all 0.1s;
	}
	.fee-step:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.95);
		border-color: rgba(255, 255, 255, 0.12);
	}
	.fee-step:disabled { opacity: 0.3; cursor: not-allowed; }
	.fee-value {
		min-width: 96px;
		text-align: center;
		font-family: monospace;
		font-size: 22px;
		font-weight: 700;
		line-height: 1;
		letter-spacing: 0.5px;
		color: rgba(252, 211, 77, 0.95);
		font-variant-numeric: tabular-nums;
	}
	.fee-value-zero { color: rgba(255, 255, 255, 0.35); }
	.fee-currency { font-size: 14px; opacity: 0.6; margin-right: 1px; }
	.fee-quick { display: flex; flex-wrap: wrap; gap: 4px; justify-content: flex-end; }
	.fee-chip {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.55);
		font-size: 9px;
		font-weight: 600;
		padding: 3px 7px;
		cursor: pointer;
		transition: all 0.1s;
		font-variant-numeric: tabular-nums;
	}
	.fee-chip:hover { color: rgba(255, 255, 255, 0.9); border-color: rgba(255, 255, 255, 0.15); }
	.fee-chip.on {
		background: rgba(255, 255, 255, 0.1);
		color: rgba(255, 255, 255, 0.9);
		border-color: rgba(255, 255, 255, 0.2);
	}
	.fee-reset {
		background: none;
		border: none;
		padding: 0;
		color: rgba(125, 211, 252, 0.7);
		font-size: 9px;
		font-weight: 600;
		text-transform: none;
		letter-spacing: 0;
		cursor: pointer;
	}
	.fee-reset:hover { color: rgba(186, 230, 253, 0.95); }

	/* ── Impound lot list ── */
	.lot-open-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		margin-left: auto;
		padding: 5px 11px;
		background: rgba(251, 191, 36, 0.06);
		border: 1px solid rgba(251, 191, 36, 0.14);
		border-radius: 3px;
		color: rgba(252, 211, 77, 0.75);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.lot-open-btn:hover { background: rgba(251, 191, 36, 0.13); color: rgba(253, 224, 71, 0.95); }
	.lot-toolbar {
		display: flex;
		gap: 8px;
		padding: 12px 16px 0;
	}
	.lot-search { flex: 1; }
	.lot-body { display: flex; flex-direction: column; gap: 5px; }
	.lot-body::-webkit-scrollbar { width: 5px; }
	.lot-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 3px; }
	.lot-more {
		width: 100%;
		margin-top: 4px;
		padding: 9px;
		border-radius: 4px;
		border: 1px solid rgba(255, 255, 255, 0.07);
		background: rgba(255, 255, 255, 0.02);
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		transition: all 0.1s;
	}
	.lot-more:hover {
		color: rgba(255, 255, 255, 0.9);
		border-color: rgba(255, 255, 255, 0.16);
	}

	.lot-empty {
		padding: 30px 0;
		text-align: center;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.25);
		font-style: italic;
	}
	.lot-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 4px;
		padding: 8px 11px;
		transition: border-color 0.1s;
	}
	.lot-row:hover { border-color: rgba(255, 255, 255, 0.1); }
	.lot-main { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
	.lot-line1 { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
	.lot-plate {
		font-family: 'Courier New', monospace;
		font-size: 12px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.9);
		letter-spacing: 0.5px;
	}
	.lot-model { font-size: 10px; color: rgba(255, 255, 255, 0.4); text-transform: uppercase; }
	.lot-lotname {
		font-size: 9px;
		color: rgba(252, 211, 77, 0.7);
		background: rgba(251, 191, 36, 0.07);
		border-radius: 3px;
		padding: 1px 6px;
	}
	.lot-line2 {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}
	.lot-reason { color: rgba(255, 255, 255, 0.55); }
	.lot-dot { width: 2px; height: 2px; border-radius: 50%; background: rgba(255, 255, 255, 0.2); }
	.lot-side { display: flex; align-items: center; gap: 5px; flex-shrink: 0; }
	.lot-unpaid { color: rgba(248, 113, 113, 0.8); font-weight: 600; }

	/* Hold state */
	.hold-pill { border-radius: 3px; padding: 1px 6px; font-size: 9px; font-weight: 600; }
	.hold-free { background: rgba(16, 185, 129, 0.1); color: rgba(52, 211, 153, 0.85); }
	.hold-timed { background: rgba(251, 191, 36, 0.1); color: rgba(252, 211, 77, 0.9); }
	.hold-locked { background: rgba(239, 68, 68, 0.1); color: rgba(248, 113, 113, 0.9); }
	.hold-until { margin-left: 6px; font-size: 10px; color: rgba(255, 255, 255, 0.3); }

	.imp-gate-hint {
		margin-top: 5px;
		font-size: 10px;
		font-style: italic;
		color: rgba(252, 211, 77, 0.75);
	}

	/* Early release */
	.override-warn {
		margin: 0 0 10px;
		padding: 8px 10px;
		background: rgba(239, 68, 68, 0.07);
		border: 1px solid rgba(239, 68, 68, 0.18);
		border-radius: 4px;
		font-size: 11px;
		line-height: 1.5;
		color: rgba(252, 165, 165, 0.9);
	}
	.req { color: rgba(248, 113, 113, 0.8); }
	.lot-days {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		background: rgba(255, 255, 255, 0.04);
		border-radius: 3px;
		padding: 1px 5px;
		font-variant-numeric: tabular-nums;
	}
	.imp-storage { flex-wrap: wrap; font-size: 10px; color: rgba(255, 255, 255, 0.55); }
	.imp-days {
		font-size: 9px;
		color: rgba(252, 211, 77, 0.75);
		background: rgba(251, 191, 36, 0.08);
		border-radius: 3px;
		padding: 1px 5px;
	}
	/* Fixed height, auto width: the frame ends where the photo ends. A full-width box
	   with `contain` just letterboxes a small image across the whole card. */
	.imp-photo-thumb {
		position: relative;
		align-self: flex-start;
		width: auto;
		max-width: 100%;
		height: 190px;
		padding: 0;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		overflow: hidden;
		cursor: zoom-in;
		display: block;
		transition: border-color 0.1s;
	}
	.imp-photo-thumb:hover { border-color: rgba(255, 255, 255, 0.2); }
	.imp-photo-thumb img {
		width: auto;
		max-width: 100%;
		height: 100%;
		object-fit: contain;
		display: block;
	}
	.imp-photo-zoom {
		position: absolute;
		right: 6px;
		bottom: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 22px;
		height: 22px;
		border-radius: 4px;
		background: rgba(0, 0, 0, 0.6);
		border: 1px solid rgba(255, 255, 255, 0.15);
		color: rgba(255, 255, 255, 0.85);
	}

	.imp-lightbox {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.85);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 2000;
	}
	.imp-lightbox-card {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		padding-top: 40px;
	}
	.imp-lightbox-close {
		position: absolute;
		top: 0;
		right: 0;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.6);
		cursor: pointer;
		padding: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
		z-index: 10;
	}
	.imp-lightbox-close:hover { background: rgba(255, 255, 255, 0.2); color: #fff; }
	.imp-lightbox-img {
		max-width: 90vw;
		max-height: calc(90vh - 40px);
		object-fit: contain;
		display: block;
		border-radius: 4px;
	}

</style>