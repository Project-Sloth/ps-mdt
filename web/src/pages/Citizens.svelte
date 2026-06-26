<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { openBoloDetail } from "../stores/navigationStore";
	import Pagination from "../components/Pagination.svelte";

	interface Citizen {
		id: number;
		cid: string;
		firstName: string;
		lastName: string;
		gender: string;
		dob: string;
		phone: string;
		fingerprint?: string;
		dna?: string;
		image?: string;
		occupations: string[];
		properties: number;
		vehicles: number;
		arrests: number;
		flags: string[];
		tags?: string[];
	}

	interface CustomLicenseStatus {
		id: number;
		name: string;
		description?: string;
		active: boolean;
	}

	interface CitizenProfile {
		citizenid: string;
		firstName: string;
		lastName: string;
		gender: string;
		dob: string;
		phone: string;
		fingerprint?: string;
		dna?: string;
		occupations: string[];
		properties: number;
		vehicles: number;
		arrests: number;
		flags: string[];
		image?: string;
		notes?: string;
		gallery?: Array<{
			image: string;
			label?: string;
			datecreated?: string;
		}>;
		licenses?: {
			driver?: boolean;
			weapon?: boolean;
		};
		customLicenses?: CustomLicenseStatus[];
		activeBolos?: Array<{ id: number; reportId: string; type: string; notes?: string }>;
		activeWarrants?: Array<{ reportid: number; expirydate: string }>;
		evidence?: Array<{
			id: number;
			case_id?: number;
			report_id?: number;
			title: string;
			type: string;
			serial?: string;
			notes?: string;
			location?: string;
			created_at?: string;
		}>;
		weapons?: Array<{
			id: number;
			serial: string;
			scratched: number | boolean;
			information?: string;
			weaponClass?: number;
			weaponModel?: string;
			flags?: Array<{ type: string; info: string }>;
		}>;
		linkedReports?: Array<{
			id: number;
			title: string;
			type: string;
			datecreated?: string;
		}>;
		ownedVehicles?: Array<{
			plate: string;
			vehicle: string;
		}>;
		propertiesList?: Array<{
			id: number;
			property_name: string;
		}>;
		tags?: string[];
	}

	import type { JobType } from "../interfaces/IUser";
	import type { AuthService } from "../services/authService.svelte";

	let { tabService, jobType = 'leo', authService }: { tabService: ReturnType<typeof createTabService>; jobType?: JobType; authService?: AuthService } =
		$props();

	let canManageLicenses = $derived(!isEMS && (authService?.hasPermission('citizens_edit_licenses') ?? true));

	const isEMS = $derived(jobType === 'ems');
	let searchQuery = $state("");
	let citizens: Citizen[] = $state([]);
	let loading = $state(true);
	let selectedProfile: CitizenProfile | null = $state(null);
	let copyNotice = $state("");
	let copyTimeout: ReturnType<typeof setTimeout> | null = null;

	// ── Photo URL modal state ──
	let photoModalOpen = $state(false);
	let photoUrlInput = $state("");
	let photoSaving = $state(false);

	// ── Gallery Modal ──
	let galleryOpen = $state(false);
	let galleryAddOpen = $state(false);
	let galleryAddUrl = $state("");
	let galleryAdding = $state(false);

	async function addGalleryImage() {
		const url = galleryAddUrl.trim();
		if (!url || !selectedProfile || galleryAdding) return;
		galleryAdding = true;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CITIZEN.ADD_CITIZEN_GALLERY,
				{ citizenid: selectedProfile.citizenid, image: url, label: 'Manually Added' },
				{ success: true }
			);
			if (result.success) {
				selectedProfile = {
					...selectedProfile,
					gallery: [...(selectedProfile.gallery ?? []), { image: url }]
				};
				galleryImages = [
					...(selectedProfile.image && !citizenImageBroken ? [selectedProfile.image] : []),
					...(selectedProfile.gallery ?? []).map(g => g.image)
				];
				galleryAddUrl = "";
				galleryAddOpen = false;
				globalNotifications.success("Image added");
			} else {
				globalNotifications.error("Failed to add image");
			}
		} catch {
			globalNotifications.error("Failed to add image");
		}
		galleryAdding = false;
	}

	async function removeGalleryImage(url: string) {
		if (!selectedProfile) return;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CITIZEN.REMOVE_CITIZEN_GALLERY,
				{ citizenid: selectedProfile.citizenid, image: url },
				{ success: true }
			);
			if (result.success) {
				selectedProfile = {
					...selectedProfile,
					gallery: (selectedProfile.gallery ?? []).filter(g => g.image !== url)
				};
				galleryImages = galleryImages.filter(img => img !== url);
				globalNotifications.success("Image removed");
			} else {
				globalNotifications.error("Failed to remove image");
			}
		} catch {
			globalNotifications.error("Failed to remove image");
		}
	}

	let galleryImages: string[] = $state([]);
	let lightboxOpen = $state(false);
	let lightboxUrl = $state("");

	function openGallery() {
		if (!selectedProfile) return;
		galleryImages = (selectedProfile.gallery ?? []).map(g => g.image);
		galleryOpen = true;
	}

	function openLightbox(url: string) {
		lightboxUrl = url;
		lightboxOpen = true;
	}

	function openPhotoModal() {
		photoUrlInput = "";
		photoModalOpen = true;
	}

	function closePhotoModal() {
		photoModalOpen = false;
		photoUrlInput = "";
	}

	async function confirmPhotoUrl() {
		const url = photoUrlInput.trim();
		if (!url || !selectedProfile || photoSaving) return;
		photoSaving = true;
		try {
			const result = await fetchNui<{ success: boolean; message?: string; imageUrl?: string }>(
				NUI_EVENTS.CITIZEN.UPLOAD_SUSPECT_PHOTO,
				{ citizenid: selectedProfile.citizenid, image: url },
				{ success: true, message: "Photo saved", imageUrl: url },
			);
			if (result.success) {
				citizenImageBroken = false;
				const newUrl = result.imageUrl || url;
				selectedProfile = { ...selectedProfile, image: newUrl };
				citizens = citizens.map((c) =>
					c.cid === selectedProfile!.citizenid ? { ...c, image: newUrl } : c,
				);
				globalNotifications.success(result.message || "Photo updated");
				closePhotoModal();
			} else {
				globalNotifications.error(result.message || "Failed to update photo");
			}
		} catch {
			globalNotifications.error("Failed to update photo");
		}
		photoSaving = false;
	}

	let citizenPage = $state(1);
	let citizenPerPage = $state(25);

	let allFilteredCitizens = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		if (!query) return citizens;
		return citizens.filter(({ firstName, lastName, cid, phone, fingerprint, dna }) =>
			[firstName, lastName, cid, phone, fingerprint, dna].some((val) =>
				val?.toLowerCase().includes(query),
			),
		);
	});

	let citizenTotalPages = $derived(Math.max(1, Math.ceil(allFilteredCitizens.length / citizenPerPage)));

	let filteredCitizens = $derived.by(() => {
		const start = (citizenPage - 1) * citizenPerPage;
		return allFilteredCitizens.slice(start, start + citizenPerPage);
	});

	// Notes editing
	let editingNotes = $state(false);
	let notesValue = $state("");
	let notesSaving = $state(false);

	function startEditNotes() {
		notesValue = selectedProfile?.notes || "";
		editingNotes = true;
	}

	async function saveNotes() {
		if (!selectedProfile) return;
		notesSaving = true;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CITIZEN.UPDATE_CITIZEN,
				{ citizenid: selectedProfile.citizenid, notes: notesValue },
				{ success: true },
			);
			if (result?.success) {
				selectedProfile = { ...selectedProfile, notes: notesValue };
				editingNotes = false;
				globalNotifications.success("Notes saved");
			} else {
				globalNotifications.error("Failed to save notes");
			}
		} catch {
			globalNotifications.error("Failed to save notes");
		}
		notesSaving = false;
	}

	// Reset to page 1 when search changes
	$effect(() => {
		searchQuery;
		citizenPage = 1;
	});

	async function fetchCitizens() {
		loading = true;
		try {
			const result = await fetchNui(NUI_EVENTS.CITIZEN.GET_CITIZENS);
			citizens = Array.isArray(result) ? result : [];
		} catch (error) {
			globalNotifications.error("Failed to fetch citizens");
			citizens = [];
		}
		loading = false;
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			loading = false;
			citizens = [
				{ id: 1, cid: 'ABC12345', firstName: 'Marcus', lastName: 'Rodriguez', gender: 'Male', dob: '1990-05-15', phone: '555-0142', image: '', occupations: ['Mechanic', 'Taxi Driver'], properties: 2, vehicles: 3, arrests: 1, flags: ['Active Warrant', 'Violent'], tags: ['Violent', 'Gang Member'] },
				{ id: 2, cid: 'DEF67890', firstName: 'Sarah', lastName: 'Chen', gender: 'Female', dob: '1995-11-22', phone: '555-0299', image: '', occupations: ['Doctor'], properties: 1, vehicles: 1, arrests: 0, flags: [], tags: ['Medical Alert'] },
				{ id: 3, cid: 'GHI11223', firstName: 'James', lastName: 'Wilson', gender: 'Male', dob: '1988-03-08', phone: '555-0377', image: '', occupations: ['Unemployed'], properties: 0, vehicles: 2, arrests: 5, flags: ['Flight Risk'], tags: ['Flight Risk', 'Wanted', 'Armed & Dangerous', 'Felon'] },
			];
			loadCitizenTags();
			return;
		}
		loadCitizenTags();
		await fetchCitizens();
	});

	useNuiEvent<Citizen[]>(NUI_EVENTS.CITIZEN.UPDATE_CITIZENS, (data) => {
		if (data) citizens = data;
	});

	function getPillClass(type: string): string {
		switch (type) {
			case "Active Warrant": return "flag-red";
			case "Active Bolo": return "flag-yellow";
			case "Violent": return "flag-orange";
			case "Flight Risk": return "flag-amber";
			default: return "";
		}
	}

	function getFlagClass(flag: { type: string; info: string }): string {
		switch (flag.type) {
			case "Stolen":
			case "Wanted":
				return "pill pill-red";
			default:
				return "pill pill-grey";
		}
	}

	function formatOccupations(list: string[] = []) {
		const cleaned = list.filter((item) => item && item.trim());
		return cleaned.length ? cleaned.join(", ") : "None";
	}

	function formatExpiryDate(raw: string | number): string {
		if (!raw) return "Unknown";
		const num = typeof raw === "string" ? Number(raw) : raw;
		if (!isNaN(num) && num > 1000000000) {
			const ms = num > 9999999999 ? num : num * 1000;
			const d = new Date(ms);
			return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
		}
		return String(raw);
	}

	let hasActiveWarrants = $derived((selectedProfile?.activeWarrants?.length ?? 0) > 0);
	let hasActiveBolos = $derived((selectedProfile?.activeBolos?.length ?? 0) > 0);

	// Fingerprint editing
	let editingFingerprint = $state(false);
	let fingerprintValue = $state("");

	function startEditFingerprint() {
		fingerprintValue = selectedProfile?.fingerprint || "";
		editingFingerprint = true;
	}

	async function saveFingerprint() {
		if (!selectedProfile || !editingFingerprint) return;
		editingFingerprint = false;
		const trimmed = fingerprintValue.trim();
		if (trimmed === (selectedProfile.fingerprint || "")) return;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_FINGERPRINT,
				{ citizenid: selectedProfile.citizenid, fingerprint: trimmed },
				{ success: true },
			);
			if (result?.success && selectedProfile) {
				selectedProfile.fingerprint = trimmed;
			}
		} catch { /* silent */ }
	}

	// DNA editing
	let editingDNA = $state(false);
	let dnaValue = $state("");

	function startEditDNA() {
		dnaValue = selectedProfile?.dna || "";
		editingDNA = true;
	}

	async function saveDNA() {
		if (!selectedProfile || !editingDNA) return;
		editingDNA = false;
		const trimmed = dnaValue.trim();
		if (trimmed === (selectedProfile.dna || "")) return;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_DNA,
				{ citizenid: selectedProfile.citizenid, dna: trimmed },
				{ success: true },
			);
			if (result?.success && selectedProfile) {
				selectedProfile.dna = trimmed;
			}
		} catch { /* silent */ }
	}

	async function viewProfile(citizenId: string) {
		if (isEnvBrowser()) {
			const mockProfiles: Record<string, CitizenProfile> = {
				'ABC12345': { citizenid: 'ABC12345', firstName: 'Marcus', lastName: 'Rodriguez', gender: 'Male', dob: '1990-05-15', phone: '555-0142', fingerprint: 'FP-8291-AXKF', image: '', occupations: ['Mechanic', 'Taxi Driver'], properties: 2, vehicles: 3, arrests: 1, flags: ['Active Warrant', 'Violent'], notes: 'Known associate of local gangs. Exercise caution during traffic stops.', licenses: { driver: true, weapon: false }, customLicenses: [{ id: 1, name: 'Hunting License', active: true }, { id: 2, name: 'Boating License', active: false }, { id: 3, name: 'Pilot License', active: false }], ownedVehicles: [{ plate: '03ROY490', vehicle: 'Exemplar' }, { plate: 'FAST001', vehicle: 'Sultan' }, { plate: 'LOW99X', vehicle: 'Bati 801' }], propertiesList: [{ property_name: '4 Integrity Way, Apt 30' }, { property_name: '1561 San Vitas Street' }], weapons: [{ id: 1, serial: 'WPN-4821', scratched: 0, weaponModel: 'weapon_pistol' }, { id: 2, serial: 'WPN-9012', scratched: 1, weaponModel: 'weapon_smg' }], evidence: [{ id: 1, title: 'Shell Casings', type: 'Physical', report_id: 42, notes: 'Found at scene near Vespucci' }, { id: 2, title: 'CCTV Footage', type: 'Digital', case_id: 7 }], linkedReports: [{ id: 42, title: 'Armed Robbery - Fleeca Bank', type: 'Incident' }, { id: 55, title: 'Traffic Violation - Speeding', type: 'Citation' }], activeBolos: [{ id: 1, type: 'Person', reportId: '42', notes: 'Armed and dangerous, last seen near Legion Square' }] },
				'DEF67890': { citizenid: 'DEF67890', firstName: 'Sarah', lastName: 'Chen', gender: 'Female', dob: '1995-11-22', phone: '555-0299', fingerprint: 'FP-1122-BXYZ', image: '', occupations: ['Doctor'], properties: 1, vehicles: 1, arrests: 0, flags: [], licenses: { driver: true, weapon: true }, customLicenses: [{ id: 1, name: 'Hunting License', active: false }, { id: 2, name: 'Boating License', active: true }, { id: 3, name: 'Pilot License', active: true }], ownedVehicles: [{ plate: 'MED001', vehicle: 'Schafter' }], propertiesList: [{ property_name: 'Eclipse Towers, Apt 5' }], weapons: [], evidence: [], linkedReports: [], activeBolos: [] },
				'GHI11223': { citizenid: 'GHI11223', firstName: 'James', lastName: 'Wilson', gender: 'Male', dob: '1988-03-08', phone: '555-0377', fingerprint: 'FP-3344-CDEF', image: '', occupations: [], properties: 0, vehicles: 2, arrests: 5, flags: ['Flight Risk'], licenses: { driver: false, weapon: false }, customLicenses: [{ id: 1, name: 'Hunting License', active: false }, { id: 2, name: 'Boating License', active: false }, { id: 3, name: 'Pilot License', active: false }], ownedVehicles: [{ plate: 'RUN4IT', vehicle: 'Comet' }, { plate: 'GHOST7', vehicle: 'Elegy' }], propertiesList: [], weapons: [{ id: 3, serial: 'WPN-5577', scratched: 0, weaponModel: 'weapon_assaultrifle' }], evidence: [], linkedReports: [{ id: 12, title: 'Evading Police', type: 'Incident' }], activeBolos: [] },
			};
			selectedProfile = mockProfiles[citizenId] || null;
			return;
		}
		try {
			const response = await fetchNui(NUI_EVENTS.CITIZEN.GET_CITIZEN, { citizenid: citizenId });
			if (response?.profile) {
				selectedProfile = response.profile;
				globalNotifications.success("Profile loaded");
				citizens = citizens.map((citizen) =>
					citizen.cid === response.profile.citizenid
						? { ...citizen, firstName: response.profile.firstName, lastName: response.profile.lastName, gender: response.profile.gender, dob: response.profile.dob, phone: response.profile.phone, image: response.profile.image, occupations: response.profile.occupations || citizen.occupations, properties: response.profile.properties, vehicles: response.profile.vehicles, arrests: response.profile.arrests, flags: response.profile.flags || citizen.flags }
						: citizen,
				);
			}
		} catch (error) {
			globalNotifications.error("Failed to fetch citizen profile");
		}
	}

	function closeProfile() {
		selectedProfile = null;
	}

	// ── Citizen tags ─────────────────────────────────────────────────────────
	let availableCitizenTags = $state<Array<{ name: string; color: string; job_type?: string; description?: string }>>([]);
	let showTagModal = $state(false);
	let tagBusy = $state(false);

	const viewerTagDomain = $derived(isEMS ? "ems" : "leo");
	function canManageTag(name: string): boolean {
		const info = availableCitizenTags.find((t) => t.name === name);
		if (!info || !info.job_type) return true;
		return info.job_type === "all" || info.job_type === viewerTagDomain;
	}
	let manageableTags = $derived(
		availableCitizenTags.filter((t) => t.job_type === "all" || t.job_type === viewerTagDomain),
	);

	function citizenTagColor(name: string): string {
		return availableCitizenTags.find((t) => t.name === name)?.color || "#9ca3af";
	}

	function tagPillStyle(hex: string): string {
		const c = /^#[0-9a-fA-F]{6}$/.test(hex || "") ? hex : "#9ca3af";
		const r = parseInt(c.slice(1, 3), 16);
		const g = parseInt(c.slice(3, 5), 16);
		const b = parseInt(c.slice(5, 7), 16);
		return `color:${c};border:1px solid rgba(${r},${g},${b},0.4);background:rgba(${r},${g},${b},0.15);`;
	}

	let pickableTags = $derived(
		availableCitizenTags.filter((t) => !(selectedProfile?.tags ?? []).includes(t.name)),
	);

	async function loadCitizenTags() {
		if (isEnvBrowser()) {
			availableCitizenTags = [
				{ name: "Violent", color: "#ef4444" },
				{ name: "Flight Risk", color: "#f97316" },
				{ name: "Medical Alert", color: "#f59e0b" },
			];
			return;
		}
		try {
			const res = await fetchNui<{ success?: boolean; data?: Array<{ name: string; color: string }> }>(
				NUI_EVENTS.CITIZEN.GET_CITIZEN_TAGS,
				{},
				{ success: true, data: [] },
			);
			availableCitizenTags = Array.isArray(res?.data) ? res.data : [];
		} catch {
			availableCitizenTags = [];
		}
	}

	async function addCitizenTag(tag: string) {
		if (!selectedProfile || tagBusy) return;
		const name = (tag || "").trim();
		if (!name) return;
		if ((selectedProfile.tags ?? []).includes(name)) { return; }
		if (isEnvBrowser()) {
			selectedProfile.tags = [...(selectedProfile.tags ?? []), name];
			return;
		}
		try {
			tagBusy = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.CITIZEN.ADD_CITIZEN_TAG,
				{ citizenid: selectedProfile.citizenid, tag: name },
				{ success: false },
			);
			if (result?.success) {
				selectedProfile.tags = [...(selectedProfile.tags ?? []), name];
				} else {
				globalNotifications.error(result?.message || "Failed to add tag");
			}
		} catch {
			globalNotifications.error("Failed to add tag");
		} finally {
			tagBusy = false;
		}
	}

	async function removeCitizenTag(tag: string) {
		if (!selectedProfile || tagBusy) return;
		if (isEnvBrowser()) {
			selectedProfile.tags = (selectedProfile.tags ?? []).filter((t) => t !== tag);
			return;
		}
		try {
			tagBusy = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.CITIZEN.REMOVE_CITIZEN_TAG,
				{ citizenid: selectedProfile.citizenid, tag },
				{ success: false },
			);
			if (result?.success) {
				selectedProfile.tags = (selectedProfile.tags ?? []).filter((t) => t !== tag);
			} else {
				globalNotifications.error(result?.message || "Failed to remove tag");
			}
		} catch {
			globalNotifications.error("Failed to remove tag");
		} finally {
			tagBusy = false;
		}
	}

	const SECTION_PAGE_SIZE = 3;
	let vehiclesPage = $state(1);
	let propertiesPage = $state(1);
	let weaponsPage = $state(1);
	let evidencePage = $state(1);
	let reportsPage = $state(1);
	let licensesPage = $state(1);

	// ── Charges section (separate from the other sections above) ──────────
	// Unlike linkedReports/evidence/weapons/etc., charges are NOT loaded as
	// part of the profile payload and NOT paginated client-side. A long-running
	// server can give a single citizen hundreds of charge rows over time, so
	// this fetches 20 at a time from a dedicated, indexed server endpoint
	// (idx_charges_citizenid) — "Load 20 more" appends rather than replacing,
	// so re-fetched pages never get re-requested.
	type CitizenCharge = {
		charge: string;
		total_count: number;
		total_fine?: number | null;
		total_time?: number | null;
		report_count: number;
		report_id?: number | null;
		datecreated?: string;
		charge_code?: string | null;
		charge_class?: "felony" | "misdemeanor" | "infraction" | null;
	};
	let citizenCharges = $state<CitizenCharge[]>([]);
	let chargesPage = $state(1);
	let chargesHasMore = $state(false);
	let chargesLoading = $state(false);
	let chargesLoadedFor = $state<string | null>(null); // citizenid the current list belongs to

	async function loadCitizenCharges(citizenid: string, page: number, append: boolean) {
		if (isEnvBrowser()) {
			// No backend in the browser preview — keep the section empty rather
			// than fabricating fake charge history.
			citizenCharges = [];
			chargesHasMore = false;
			chargesLoadedFor = citizenid;
			return;
		}
		chargesLoading = true;
		try {
			const res = await fetchNui<{ charges: CitizenCharge[]; hasMore: boolean }>(
				NUI_EVENTS.CITIZEN.GET_CITIZEN_CHARGES,
				{ citizenid, page },
				{ charges: [], hasMore: false },
			);
			// Guard against a fast profile switch landing a stale response: if the
			// user has since opened a different citizen, this result no longer
			// belongs anywhere — drop it instead of corrupting the new list.
			if (selectedProfile?.citizenid !== citizenid) return;
			const rows = res?.charges ?? [];
			citizenCharges = append ? [...citizenCharges, ...rows] : rows;
			chargesHasMore = res?.hasMore ?? false;
			chargesPage = page;
			chargesLoadedFor = citizenid;
		} catch {
			if (selectedProfile?.citizenid === citizenid && !append) citizenCharges = [];
			globalNotifications.error("Failed to load charges");
		} finally {
			if (selectedProfile?.citizenid === citizenid) chargesLoading = false;
		}
	}

	function loadMoreCharges() {
		if (!selectedProfile || chargesLoading || !chargesHasMore) return;
		loadCitizenCharges(selectedProfile.citizenid, chargesPage + 1, true);
	}

	// Explicit capitalize instead of relying on CSS text-transform: capitalize,
	// which is inconsistent in CEF (FiveM's NUI browser) — same caution as the
	// color-mix() avoidance elsewhere in this codebase.
	function capitalize(s: string | null | undefined): string {
		if (!s) return "";
		return s.charAt(0).toUpperCase() + s.slice(1);
	}

	$effect(() => {
		if (selectedProfile) {
			vehiclesPage = 1;
			propertiesPage = 1;
			weaponsPage = 1;
			evidencePage = 1;
			reportsPage = 1;
			licensesPage = 1;
			editingNotes = false;
			notesValue = "";
			showTagModal = false;
			loadCitizenTags();

			// Only (re)load charges when we've actually switched to a different
			// citizen — selectedProfile is also reassigned on small in-place
			// edits (notes, photo, license toggles), which must NOT re-trigger
			// a charges fetch.
			if (selectedProfile.citizenid !== chargesLoadedFor) {
				citizenCharges = [];
				chargesHasMore = false;
				chargesPage = 1;
				loadCitizenCharges(selectedProfile.citizenid, 1, false);
			}
		} else {
			citizenCharges = [];
			chargesHasMore = false;
			chargesPage = 1;
			chargesLoadedFor = null;
		}
	});

	function sectionSlice<T>(items: T[] | undefined, page: number): T[] {
		if (!items) return [];
		const start = (page - 1) * SECTION_PAGE_SIZE;
		return items.slice(start, start + SECTION_PAGE_SIZE);
	}

	function sectionTotalPages(items: unknown[] | undefined): number {
		if (!items || items.length === 0) return 1;
		return Math.ceil(items.length / SECTION_PAGE_SIZE);
	}

	let citizenImageBroken = $state(false);
	function handleImageError() { citizenImageBroken = true; }

	$effect(() => {
		if (selectedProfile) citizenImageBroken = false;
	});

	// Photo upload/mugshot
	let citizenPhotoInput: HTMLInputElement | undefined = $state();
	let uploading = $state(false);

	function openCitizenPhotoUpload() {
		citizenPhotoInput?.click();
	}

	async function handleCitizenPhotoUpload(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file || !selectedProfile) return;

		uploading = true;
		globalNotifications.info("Uploading photo...");

		try {
			const base64 = await compressImage(file);

			const result = await fetchNui<{ success: boolean; message?: string; imageUrl?: string }>(
				NUI_EVENTS.CITIZEN.UPLOAD_SUSPECT_PHOTO,
				{ citizenid: selectedProfile.citizenid, image: base64 },
				{ success: true, message: "Photo uploaded", imageUrl: base64 },
			);

			if (result.success) {
				citizenImageBroken = false;
				selectedProfile = { ...selectedProfile, image: result.imageUrl || base64 };
				citizens = citizens.map((c) =>
					c.cid === selectedProfile!.citizenid ? { ...c, image: result.imageUrl || base64 } : c,
				);
				globalNotifications.success(result.message || "Photo uploaded");
			} else {
				globalNotifications.error(result.message || "Failed to upload photo");
			}
		} catch {
			globalNotifications.error("Failed to upload photo");
		}
		uploading = false;
		input.value = "";
	}

	async function triggerCitizenMugshot() {
		if (!selectedProfile) return;
		try {
			const result = await fetchNui<{ success: boolean; message?: string; imageUrl?: string }>(
				NUI_EVENTS.CITIZEN.TRIGGER_SUSPECT_MUGSHOT,
				{ citizenid: selectedProfile.citizenid },
				{ success: true, message: "Mugshot captured", imageUrl: "" },
			);
			if (result.success) {
				if (result.imageUrl) {
					citizenImageBroken = false;
					selectedProfile = { ...selectedProfile, image: result.imageUrl };
					citizens = citizens.map((c) =>
						c.cid === selectedProfile!.citizenid ? { ...c, image: result.imageUrl! } : c,
					);
				}
				globalNotifications.success(result.message || "Mugshot captured");
			} else {
				globalNotifications.error(result.message || "Failed to capture mugshot");
			}
		} catch {
			globalNotifications.error("Failed to capture mugshot");
		}
	}

	interface VehicleDetail {
		plate: string;
		vehicle: string;
		owner?: string;
		model?: string;
		label?: string;
		class?: string;
		type?: string;
		status?: string;
		reason?: string;
		registered?: boolean;
		registrationReason?: string;
		points?: number;
		information?: string;
		stolen?: boolean;
		boloactive?: boolean;
	}
	let vehicleDetail: VehicleDetail | null = $state(null);
	let vehicleDetailLoading = $state(false);
	let vehicleDetailFeatures = $state({ points: false, insurance: false, registration: false });

	// ── Property detail modal ──
	interface PropertyDetail {
		property_name: string;
		coords?: { x: number; y: number; z: number } | null;
		streetName?: string;
		owner?: string;
		ownerName?: string;
		keyholders?: Array<{ citizenid: string; name?: string }>;
	}
	let propertyDetail: PropertyDetail | null = $state(null);
	let propertyDetailLoading = $state(false);
	let waypointSet = $state(false);
	let waypointTimeout: ReturnType<typeof setTimeout> | null = null;

	function goToBolo(boloId: number) {
		openBoloDetail(boloId);
		tabService.setActiveTab("BOLOs");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) tabService.setInstanceTab(activeInstance.id, "BOLOs");
	}

	function goToWarrantReport(reportId: number | string) {
		openReportInEditor(String(reportId));
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) tabService.setInstanceTab(activeInstance.id, "Reports");
	}

	async function openVehicleFromProfile(plate: string) {
		if (!plate) return;
		vehicleDetailLoading = true;
		vehicleDetail = null;
		vehicleDetailFeatures = { points: false, insurance: false, registration: false };
		try {
			const response = await fetchNui<any>(NUI_EVENTS.VEHICLE.GET_VEHICLE, { plate });
			vehicleDetail = response?.vehicle || { plate, vehicle: "Unknown" };
			vehicleDetailFeatures = {
				points: !!response?.features?.points,
				insurance: !!response?.features?.insurance,
				registration: !!response?.features?.registration,
			};
		} catch {
			vehicleDetail = { plate, vehicle: "Unknown" };
			vehicleDetailFeatures = { points: false, insurance: false, registration: false };
		}
		vehicleDetailLoading = false;
	}

	function closeVehicleDetail() {
		vehicleDetail = null;
	}

	async function openPropertyFromProfile(propertyId: number, propertyName: string) {
		if (!propertyId) return;
		propertyDetailLoading = true;
		propertyDetail = null;
		waypointSet = false;

		if (isEnvBrowser()) {
			await new Promise((r) => setTimeout(r, 400));
			propertyDetail = {
				property_name: propertyName,
				coords: { x: -59.4, y: -616.29, z: 37.36 },
				owner: 'ABC12345',
				ownerName: 'Marcus Rodriguez',
				keyholders: [
					{ citizenid: 'DEF67890', name: 'Sarah Chen' },
					{ citizenid: 'GHI11223', name: 'James Wilson' },
				],
			};
			propertyDetailLoading = false;
			return;
		}

		try {
			const response = await fetchNui<any>('getProperty', { property_id: propertyId });
			if (response?.property) {
				propertyDetail = response.property;
			} else {
				propertyDetail = { property_name: propertyName };
			}
		} catch {
			propertyDetail = { property_name: propertyName };
		}
		propertyDetailLoading = false;
	}

	function closePropertyDetail() {
		propertyDetail = null;
		waypointSet = false;
		if (waypointTimeout) clearTimeout(waypointTimeout);
	}

	async function setPropertyWaypoint() {
		if (!propertyDetail?.coords) return;
		try {
			await fetchNui(NUI_EVENTS.CITIZEN.SET_WAYPOINT, { x: propertyDetail.coords.x, y: propertyDetail.coords.y });
			waypointSet = true;
			if (waypointTimeout) clearTimeout(waypointTimeout);
			waypointTimeout = setTimeout(() => { waypointSet = false; }, 2500);
		} catch {
			// silent — waypoint set is best-effort
		}
	}

	function formatCoords(coords: { x: number; y: number; z: number } | null | undefined): string {
		if (!coords) return 'Unknown';
		return `${coords.x.toFixed(1)}, ${coords.y.toFixed(1)}, ${coords.z.toFixed(1)}`;
	}

	async function toggleLicense(type: "driver" | "weapon", enabled: boolean) {
		if (!selectedProfile) return;
		const response = await fetchNui(NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_LICENSE, {
			citizenid: selectedProfile.citizenid,
			license: type,
			enabled,
		});
		if (response?.success) {
			selectedProfile = { ...selectedProfile, licenses: { ...selectedProfile.licenses, [type]: enabled } };
		}
	}

	async function toggleCustomLicense(licenseId: number, enabled: boolean) {
		if (!selectedProfile) return;
		if (isEnvBrowser()) {
			selectedProfile = { ...selectedProfile, customLicenses: (selectedProfile.customLicenses || []).map(l => l.id === licenseId ? { ...l, active: enabled } : l) };
			return;
		}
		const response = await fetchNui(NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_CUSTOM_LICENSE, {
			citizenid: selectedProfile.citizenid,
			licenseId,
			enabled,
		});
		if (response?.success) {
			selectedProfile = { ...selectedProfile, customLicenses: (selectedProfile.customLicenses || []).map(l => l.id === licenseId ? { ...l, active: enabled } : l) };
		}
	}

	// ── Active licenses ──
	interface LicenseEntry {
		key: string;
		name: string;
		type: "state" | "custom";
		active: boolean;
		customId?: number;
	}

	let activeLicenses = $derived.by((): LicenseEntry[] => {
		if (!selectedProfile) return [];
		const result: LicenseEntry[] = [];
		if (selectedProfile.licenses?.driver) result.push({ key: "driver", name: "Driver's License", type: "state", active: true });
		if (selectedProfile.licenses?.weapon) result.push({ key: "weapon", name: "Weapon License", type: "state", active: true });
		for (const cl of selectedProfile.customLicenses || []) {
			if (cl.active) result.push({ key: `custom-${cl.id}`, name: cl.name, type: "custom", active: true, customId: cl.id });
		}
		return result;
	});

	let showIssueLicenseModal = $state(false);

	interface IssuableLicense {
		key: string;
		name: string;
		type: "state" | "custom";
		active: boolean;
		customId?: number;
		description?: string;
	}

	let issuableLicenses = $derived.by((): IssuableLicense[] => {
		if (!selectedProfile) return [];
		const result: IssuableLicense[] = [];
		result.push({ key: "driver", name: "Driver's License", type: "state", description: "State-issued license for operating motor vehicles", active: selectedProfile.licenses?.driver || false });
		result.push({ key: "weapon", name: "Weapon License", type: "state", description: "State-issued license for carrying firearms", active: selectedProfile.licenses?.weapon || false });
		for (const cl of selectedProfile.customLicenses || []) {
			result.push({ key: `custom-${cl.id}`, name: cl.name, type: "custom", active: cl.active, customId: cl.id, description: cl.description });
		}
		return result;
	});

	async function toggleIssuableLicense(license: IssuableLicense) {
		const newState = !license.active;
		if (license.type === "state") {
			await toggleLicense(license.key as "driver" | "weapon", newState);
		} else if (license.customId) {
			await toggleCustomLicense(license.customId, newState);
		}
	}

	function showCopyNotice(label: string) {
		copyNotice = label;
		if (copyTimeout) clearTimeout(copyTimeout);
		copyTimeout = setTimeout(() => { copyNotice = ""; copyTimeout = null; }, 1400);
	}

	async function copyToClipboard(value: string, label: string) {
		if (!value) return;
		try {
			await fetchNui("copyToClipboard", { text: value });
			showCopyNotice(label);
			return;
		} catch {
			// NUI callback not available
		}
		try {
			if (navigator?.clipboard?.writeText) {
				await navigator.clipboard.writeText(value);
				showCopyNotice(label);
				return;
			}
		} catch {
			// silent
		}
		try {
			const textarea = document.createElement("textarea");
			textarea.value = value;
			textarea.style.position = "fixed";
			textarea.style.opacity = "0";
			document.body.appendChild(textarea);
			textarea.select();
			document.execCommand("copy");
			document.body.removeChild(textarea);
			showCopyNotice(label);
		} catch {
			// silent
		}
	}
</script>

<!-- ── Photo URL Modal ── -->
{#if photoModalOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" onclick={(e) => { if (e.target === e.currentTarget) closePhotoModal(); }}>
		<div class="modal-card photo-modal" role="dialog" aria-modal="true" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>Set Profile Photo</h3>
				<button class="modal-close" onclick={closePhotoModal}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body photo-modal-body">
				<div class="photo-form-group">
					<span class="photo-label">Image URL</span>
					<input
						class="photo-input"
						type="url"
						placeholder="https://example.com/photo.jpg"
						bind:value={photoUrlInput}
						onkeydown={(e) => { if (e.key === 'Enter') confirmPhotoUrl(); if (e.key === 'Escape') closePhotoModal(); }}
					/>

					<span class="url-hint">
						<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
						</svg>
						Use <a href="https://fivemanage.com" target="_blank" rel="noopener noreferrer">FiveManage</a> to make sure your links persist forever.
					</span>
				</div>
			</div>
			<div class="modal-footer-row">
				<button class="photo-cancel-btn" onclick={closePhotoModal} disabled={photoSaving}>Cancel</button>
				<button class="photo-confirm-btn" onclick={confirmPhotoUrl} disabled={photoSaving || !photoUrlInput.trim()}>
					{photoSaving ? "Saving…" : "Set Photo"}
				</button>
			</div>
		</div>
	</div>
{/if}

<div class="page">
	{#if selectedProfile}
		<!-- ===== PROFILE VIEW ===== -->
		<div class="profile-view">
			<div class="profile-topbar">
				<button class="back-btn" onclick={closeProfile}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
					Back
				</button>
				<div class="profile-identity">
					<span class="profile-name">{selectedProfile.firstName} {selectedProfile.lastName}</span>
					<span class="profile-cid">{selectedProfile.citizenid}</span>
				</div>
				{#if selectedProfile.flags && selectedProfile.flags.length > 0}
					<div class="profile-flags">
						{#each selectedProfile.flags.slice(0, 5) as flag}
							<span class="flag {getPillClass(flag)}">{flag}</span>
						{/each}
						{#if selectedProfile.flags.length > 5}
							<span class="flag flag-more">+{selectedProfile.flags.length - 5}</span>
						{/if}
					</div>
				{/if}
				{#if copyNotice}
					<div class="copy-toast">{copyNotice} copied</div>
				{/if}
			</div>

			<div class="pstats-row">
				<div class="pstat"><span class="pstat-val">{selectedProfile.properties}</span><span class="pstat-lbl">Properties</span></div>
				<div class="pstat"><span class="pstat-val">{selectedProfile.vehicles}</span><span class="pstat-lbl">Vehicles</span></div>
				<div class="pstat"><span class="pstat-val accent-red">{selectedProfile.arrests}</span><span class="pstat-lbl">Arrests</span></div>
				<div class="pstat"><span class="pstat-val">{selectedProfile.occupations.length}</span><span class="pstat-lbl">Jobs</span></div>
			</div>

			<div class="profile-body">
				<div class="profile-sidebar">
					<!-- Photo panel -->
					<div class="panel">
						<div class="profile-img">
							{#if selectedProfile.image && !citizenImageBroken}
								<!-- svelte-ignore a11y_click_events_have_key_events -->
								<!-- svelte-ignore a11y_no_static_element_interactions -->
								<img 
									src={selectedProfile.image} 
									alt="Profile" 
									onerror={handleImageError}
									onclick={() => openLightbox(selectedProfile!.image!)}
									style="cursor: zoom-in;"
								/>
							{:else}
								<div class="no-photo-placeholder">
									<svg width="40" height="40" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
									<span>No Photo</span>
								</div>
							{/if}
						</div>
						{#if !isEMS}
							<div class="profile-photo-actions">
								<button class="photo-action-btn" onclick={openPhotoModal} title="Set photo URL">
									<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71"/></svg>
									Set URL
								</button>
								<button class="photo-action-btn" onclick={openGallery} title="View all photos">
									<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/></svg>
									Gallery
								</button>
							</div>
						{/if}
					</div>

					<!-- Personal Details -->
					<div class="panel detail-panel">
						<div class="detail-row"><span class="dlabel">Gender</span><span class="dvalue">{selectedProfile.gender}</span></div>
						<div class="detail-row"><span class="dlabel">DOB</span><span class="dvalue">{selectedProfile.dob}</span></div>
						<div class="detail-row">
							<span class="dlabel">Phone</span>
							<span class="dvalue clickable" onclick={() => copyToClipboard(selectedProfile?.phone || '', 'Phone')}>
								<span class="material-icons copy-icon">content_copy</span>
								{selectedProfile.phone}
							</span>
						</div>
						<div class="detail-row">
							<span class="dlabel">Fingerprint</span>
							{#if editingFingerprint}
								<input class="dna-input" type="text" bind:value={fingerprintValue}
									onkeydown={(e) => { if (e.key === 'Enter') saveFingerprint(); if (e.key === 'Escape') { editingFingerprint = false; } }}
									onblur={saveFingerprint}
								/>
							{:else}
								<span class="dvalue clickable" onclick={() => startEditFingerprint()}>
									<span class="material-icons edit-icon">edit</span>
									{selectedProfile.fingerprint || 'N/A'}
								</span>
							{/if}
						</div>
						<div class="detail-row">
							<span class="dlabel">DNA</span>
							{#if editingDNA}
								<input class="dna-input" type="text" bind:value={dnaValue}
									onkeydown={(e) => { if (e.key === 'Enter') saveDNA(); if (e.key === 'Escape') { editingDNA = false; } }}
									onblur={saveDNA}
								/>
							{:else}
								<span class="dvalue clickable" onclick={() => startEditDNA()}>
									<span class="material-icons edit-icon">edit</span>
									{selectedProfile.dna || 'N/A'}
								</span>
							{/if}
						</div>
						<div class="detail-row"><span class="dlabel">Occupations</span><span class="dvalue">{formatOccupations(selectedProfile.occupations)}</span></div>
						<div class="detail-row">
							<span class="dlabel">Tags</span>
							<button class="issue-license-btn" onclick={() => (showTagModal = true)}>
								<span class="material-icons" style="font-size: 12px;">add</span> Manage Tags
							</button>
						</div>
						<div class="ptags-fullrow">
							{#each (selectedProfile.tags ?? []) as tag (tag)}
								<span class="flag tag-pill" style={tagPillStyle(citizenTagColor(tag))}>
									{tag}
									{#if canManageTag(tag)}
										<button class="ctag-remove" title="Remove tag" disabled={tagBusy} onclick={() => removeCitizenTag(tag)}>×</button>
									{/if}
								</span>
							{/each}
							{#if (selectedProfile.tags ?? []).length === 0}
								<span class="ptags-empty">No tags</span>
							{/if}
						</div>
					</div>
				</div>

				<!-- Main content -->
				<div class="profile-main">
					{#if selectedProfile.notes !== undefined}
						<div class="panel">
							<div class="panel-title">
								Notes
								{#if !editingNotes && !isEMS}
									<button class="issue-license-btn" onclick={startEditNotes}>
										<span class="material-icons" style="font-size: 12px;">edit</span> Edit
									</button>
								{/if}
							</div>
							{#if editingNotes}
								<textarea
									class="dna-input"
									style="width:100%;min-height:80px;resize:vertical;font-family:inherit;"
									bind:value={notesValue}
									placeholder="Enter notes..."
									maxlength={250}
									onkeydown={(e) => { if (e.key === 'Enter' && e.ctrlKey) saveNotes(); }}
								></textarea>
								<div style="display:flex;align-items:center;justify-content:space-between;margin-top:8px;">
									<div style="display:flex;gap:6px;">
										<button class="notes-save-btn" onclick={saveNotes} disabled={notesSaving}>{notesSaving ? 'Saving...' : 'Save'}</button>
										<button class="view-btn" onclick={() => { editingNotes = false; notesValue = selectedProfile?.notes || ''; }}>Cancel</button>
									</div>
									<span style="font-size:10px;color:{notesValue.length > 225 ? '#f87171' : 'rgba(255,255,255,0.2)'};">{notesValue.length}/250</span>
								</div>
							{:else}
								{#if selectedProfile.notes?.trim()}
									<div class="notes-text">{selectedProfile.notes}</div>
								{:else}
									<div class="empty-msg">No notes on file.</div>
								{/if}
							{/if}
						</div>
					{/if}

					<div class="sections-grid">
						<!-- Active Warrants -->
						<div class="panel" class:panel-danger={hasActiveWarrants}>
							<div class="panel-title">Active Warrants <span class="cnt" class:cnt-danger={hasActiveWarrants}>{selectedProfile.activeWarrants?.length || 0}</span></div>
							{#if hasActiveWarrants}<div class="panel-caution caution-danger">PROCEED WITH CAUTION</div>{/if}
							<div class="section-list">
								{#if selectedProfile.activeWarrants && selectedProfile.activeWarrants.length > 0}
									{#each selectedProfile.activeWarrants.slice(0, 3) as w}
										<div class="sitem sitem-danger">
											<div class="sitem-info"><span class="sitem-primary">Report #{w.reportid}</span><span class="sitem-secondary">Expires: {formatExpiryDate(w.expirydate)}</span></div>
											<button class="sitem-arrow" title="View Report" onclick={() => goToWarrantReport(w.reportid)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
									{#if selectedProfile.activeWarrants.length > 3}<div class="sitem-overflow">+{selectedProfile.activeWarrants.length - 3} more warrants</div>{/if}
								{:else}<div class="empty-msg">No active warrants</div>{/if}
							</div>
						</div>

						<!-- Active BOLOs -->
						<div class="panel" class:panel-warning={hasActiveBolos}>
							<div class="panel-title">Active BOLOs <span class="cnt" class:cnt-warning={hasActiveBolos}>{selectedProfile.activeBolos?.length || 0}</span></div>
							{#if hasActiveBolos}<div class="panel-caution caution-warning">PROCEED WITH CAUTION</div>{/if}
							<div class="section-list">
								{#if selectedProfile.activeBolos && selectedProfile.activeBolos.length > 0}
									{#each selectedProfile.activeBolos.slice(0, 3) as b}
										<div class="sitem sitem-warning">
											<div class="sitem-info"><span class="sitem-primary">{b.type} BOLO</span>{#if b.notes}<span class="sitem-secondary">{b.notes}</span>{/if}</div>
											<button class="sitem-arrow" title="View BOLO" onclick={() => goToBolo(b.id)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
									{#if selectedProfile.activeBolos.length > 3}<div class="sitem-overflow">+{selectedProfile.activeBolos.length - 3} more BOLOs</div>{/if}
								{:else}<div class="empty-msg">No active BOLOs</div>{/if}
							</div>
						</div>

						<!-- Vehicles -->
						<div class="panel">
							<div class="panel-title">Vehicles <span class="cnt">{selectedProfile.ownedVehicles?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.ownedVehicles && selectedProfile.ownedVehicles.length > 0}
									{#each sectionSlice(selectedProfile.ownedVehicles, vehiclesPage) as v}
										<div class="sitem">
											<div class="sitem-info"><span class="sitem-primary">{v.vehicle}</span><span class="sitem-secondary">{v.plate}</span></div>
											<button class="sitem-arrow" title="View Vehicle" onclick={() => openVehicleFromProfile(v.plate)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
								{:else}<div class="empty-msg">No vehicles</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.ownedVehicles) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={vehiclesPage <= 1} onclick={() => vehiclesPage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{vehiclesPage} / {sectionTotalPages(selectedProfile.ownedVehicles)}</span>
									<button class="spager-btn" disabled={vehiclesPage >= sectionTotalPages(selectedProfile.ownedVehicles)} onclick={() => vehiclesPage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Licenses -->
						<div class="panel">
							<div class="panel-title">
								Licenses <span class="cnt">{activeLicenses.length}</span>
								{#if canManageLicenses}
									<button class="issue-license-btn" onclick={() => (showIssueLicenseModal = true)}>
										<span class="material-icons" style="font-size: 12px;">add</span> Issue License
									</button>
								{/if}
							</div>
							<div class="section-list">
								{#if activeLicenses.length > 0}
									{#each sectionSlice(activeLicenses, licensesPage) as license (license.key)}
										<div class="sitem">
											<div class="sitem-info"><span class="sitem-primary">{license.name}</span><span class="sitem-secondary">{license.type === 'state' ? 'State License' : 'Custom License'}</span></div>
											<span class="license-status license-active">Active</span>
										</div>
									{/each}
								{:else}<div class="empty-msg">No licenses</div>{/if}
							</div>
							{#if sectionTotalPages(activeLicenses) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={licensesPage <= 1} onclick={() => licensesPage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{licensesPage} / {sectionTotalPages(activeLicenses)}</span>
									<button class="spager-btn" disabled={licensesPage >= sectionTotalPages(activeLicenses)} onclick={() => licensesPage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Properties -->
						<div class="panel">
							<div class="panel-title">Properties <span class="cnt">{selectedProfile.propertiesList?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.propertiesList && selectedProfile.propertiesList.length > 0}
									{#each sectionSlice(selectedProfile.propertiesList, propertiesPage) as p}
										<div class="sitem">
											<div class="sitem-info"><span class="sitem-primary">{p.property_name}</span></div>
											<button class="sitem-arrow" title="View Property" onclick={() => openPropertyFromProfile(p.id, p.property_name)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
								{:else}<div class="empty-msg">No properties</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.propertiesList) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={propertiesPage <= 1} onclick={() => propertiesPage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{propertiesPage} / {sectionTotalPages(selectedProfile.propertiesList)}</span>
									<button class="spager-btn" disabled={propertiesPage >= sectionTotalPages(selectedProfile.propertiesList)} onclick={() => propertiesPage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Weapons -->
						<div class="panel">
							<div class="panel-title">Weapons <span class="cnt">{selectedProfile.weapons?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.weapons && selectedProfile.weapons.length > 0}
									{#each sectionSlice(selectedProfile.weapons, weaponsPage) as w}
										<div class="sitem">
											<div class="sitem-info">
												<span class="sitem-primary">{w.weaponModel}</span>
												<span class="sitem-secondary">{w.serial}</span>
											</div>
											<div style="display:flex;align-items:center;gap:4px;flex-wrap:wrap;">
												{#if w.scratched}
													<span class="badge badge-red">Scratched</span>
												{:else}
													<span class="badge badge-green">Intact</span>
												{/if}
												{#each w.flags ?? [] as flag}
													<span class="badge {flag.type === 'Stolen' || flag.type === 'Wanted' ? 'badge-red' : ''}">{flag.type}</span>
												{/each}
											</div>
										</div>
									{/each}
								{:else}<div class="empty-msg">No weapons</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.weapons) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={weaponsPage <= 1} onclick={() => weaponsPage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{weaponsPage} / {sectionTotalPages(selectedProfile.weapons)}</span>
									<button class="spager-btn" disabled={weaponsPage >= sectionTotalPages(selectedProfile.weapons)} onclick={() => weaponsPage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Evidence -->
						<div class="panel">
							<div class="panel-title">Evidence <span class="cnt">{selectedProfile.evidence?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.evidence && selectedProfile.evidence.length > 0}
									{#each sectionSlice(selectedProfile.evidence, evidencePage) as e}
										<div class="sitem">
											<div class="sitem-info"><span class="sitem-primary">{e.title}</span><span class="sitem-secondary">{e.type}{#if e.notes} - {e.notes}{/if}</span></div>
										</div>
									{/each}
								{:else}<div class="empty-msg">No evidence</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.evidence) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={evidencePage <= 1} onclick={() => evidencePage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{evidencePage} / {sectionTotalPages(selectedProfile.evidence)}</span>
									<button class="spager-btn" disabled={evidencePage >= sectionTotalPages(selectedProfile.evidence)} onclick={() => evidencePage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Linked Reports -->
						<div class="panel">
							<div class="panel-title">Linked Reports <span class="cnt">{selectedProfile.linkedReports?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.linkedReports && selectedProfile.linkedReports.length > 0}
									{#each sectionSlice(selectedProfile.linkedReports, reportsPage) as r}
										<div class="sitem">
											<div class="sitem-info"><span class="sitem-primary">{r.title}</span><span class="sitem-secondary">{r.type}</span></div>
											{#if !isEMS}<button class="view-btn" onclick={() => goToWarrantReport(r.id)}>View</button>{/if}
										</div>
									{/each}
								{:else}<div class="empty-msg">No reports</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.linkedReports) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={reportsPage <= 1} onclick={() => reportsPage--}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg></button>
									<span class="spager-info">{reportsPage} / {sectionTotalPages(selectedProfile.linkedReports)}</span>
									<button class="spager-btn" disabled={reportsPage >= sectionTotalPages(selectedProfile.linkedReports)} onclick={() => reportsPage++}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg></button>
								</div>
							{/if}
						</div>

						<!-- Charges — fetched on demand, 20 at a time, from a dedicated
						     endpoint (NOT part of the profile payload), grouped by charge
						     type with a combined count across all of the citizen's reports.
						     See loadCitizenCharges() / getCitizenCharges (server). -->
						<div class="panel">
							<div class="panel-title">Charges <span class="cnt">{citizenCharges.length}{chargesHasMore ? "+" : ""}</span></div>
							<div class="section-list">
								{#if chargesLoading && citizenCharges.length === 0}
									<div class="empty-msg">Loading charges…</div>
								{:else if citizenCharges.length > 0}
									{#each citizenCharges as c (c.charge)}
										<div class="sitem" class:sitem-danger={c.charge_class === "felony"} class:sitem-warning={c.charge_class === "misdemeanor"}>
											<div class="sitem-info">
												<span class="sitem-primary">
													{c.total_count > 1 ? `${c.total_count}x ${c.charge}` : c.charge}
												</span>
												<span class="sitem-secondary">
													{#if c.report_count > 1}
														Across {c.report_count} reports
													{:else}
														Report #{c.report_id}
													{/if}
													{#if c.datecreated}· {new Date(c.datecreated).toLocaleDateString()}{/if}
													{#if c.total_fine}· ${c.total_fine.toLocaleString()}{/if}
													{#if c.total_time}· {c.total_time}mo{/if}
												</span>
											</div>
											{#if c.charge_class}
												<span class="badge" class:badge-red={c.charge_class === "felony"} class:badge-green={c.charge_class !== "felony"}>{capitalize(c.charge_class)}</span>
											{/if}
										</div>
									{/each}
								{:else}
									<div class="empty-msg">No charges</div>
								{/if}
							</div>
							{#if chargesHasMore}
								<div class="section-pager">
									<button class="load-more-btn" disabled={chargesLoading} onclick={loadMoreCharges}>
										{chargesLoading ? "Loading…" : "Load more charges"}
									</button>
								</div>
							{/if}
						</div>
					</div>
				</div>
			</div>
		</div>

		{#if galleryOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="modal-overlay" onclick={(e) => { if (e.target === e.currentTarget) galleryOpen = false; }}>
				<div class="modal-card gallery-card" onclick={(e) => e.stopPropagation()}>
					<div class="modal-header">
						<h3>Photo Gallery – {selectedProfile?.firstName} {selectedProfile?.lastName}</h3>
						<div style="display:flex;gap:6px;align-items:center;">
							<button class="gallery-add-btn" onclick={() => { galleryAddOpen = true; galleryAddUrl = ""; }}>
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
								Add
							</button>
							<button class="modal-close" onclick={() => galleryOpen = false}>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
							</button>
						</div>
					</div>
					<div class="gallery-body">
						<!-- Profilbild separat -->
						{#if selectedProfile?.image && !citizenImageBroken}
							<div class="gallery-section-label">Profile Photo</div>
							<div class="gallery-grid" style="margin-bottom: 12px;">
								<div class="gallery-item">
									<!-- svelte-ignore a11y_click_events_have_key_events -->
									<!-- svelte-ignore a11y_no_static_element_interactions -->
									<img src={selectedProfile.image} alt="Profile" class="gallery-thumb" onclick={() => { galleryOpen = false; openLightbox(selectedProfile!.image!); }} />
								</div>
							</div>
							<div class="gallery-section-label">Gallery</div>
						{/if}

						{#if galleryImages.length === 0}
							<div class="empty-msg" style="padding: 16px 0;">No gallery images</div>
						{:else}
							<div class="gallery-grid">
								{#each galleryImages as img}
									<div class="gallery-item">
										<!-- svelte-ignore a11y_click_events_have_key_events -->
										<!-- svelte-ignore a11y_no_static_element_interactions -->
										<img src={img} alt="Gallery photo" class="gallery-thumb" onclick={() => { galleryOpen = false; openLightbox(img); }} />
										<button
											class="gallery-delete-btn"
											onclick={(e) => { e.stopPropagation(); removeGalleryImage(img); }}
											aria-label="Remove image"
										>
											<svg width="8" height="8" viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
										</button>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			</div>
		{/if}

		<!-- Gallery Add Modal -->
		{#if galleryAddOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="modal-overlay" onclick={(e) => { if (e.target === e.currentTarget) galleryAddOpen = false; }}>
				<div class="modal-card photo-modal" onclick={(e) => e.stopPropagation()}>
					<div class="modal-header">
						<h3>Add Gallery Image</h3>
						<button class="modal-close" onclick={() => galleryAddOpen = false}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					</div>
					<div class="modal-body photo-modal-body">
						<div class="photo-form-group">
							<span class="photo-label">Image URL</span>
							<input
								class="photo-input"
								type="url"
								placeholder="https://example.com/photo.jpg"
								bind:value={galleryAddUrl}
								onkeydown={(e) => { if (e.key === 'Enter') addGalleryImage(); if (e.key === 'Escape') galleryAddOpen = false; }}
							/>
							<span class="url-hint">
								<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
								Use <a href="https://fivemanage.com" target="_blank" rel="noopener noreferrer">FiveManage</a> to make sure your links persist forever.
							</span>
						</div>
					</div>
					<div class="modal-footer-row">
						<button class="photo-cancel-btn" onclick={() => galleryAddOpen = false} disabled={galleryAdding}>Cancel</button>
						<button class="photo-confirm-btn" onclick={addGalleryImage} disabled={galleryAdding || !galleryAddUrl.trim()}>
							{galleryAdding ? "Adding…" : "Add Image"}
						</button>
					</div>
				</div>
			</div>
		{/if}

		<!-- Lightbox -->
		{#if lightboxOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="modal-overlay lightbox-overlay" onclick={() => lightboxOpen = false}>
				<div class="lightbox-card" onclick={(e) => e.stopPropagation()}>
					<button class="lightbox-close" onclick={() => lightboxOpen = false}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
					</button>
					<img
						src={lightboxUrl}
						alt="Full size"
						class="lightbox-img"
					/>
				</div>
			</div>
		{/if}

		<!-- Vehicle Detail Modal -->
		<!-- ── Vehicle Detail Modal ── -->
		{#if vehicleDetail || vehicleDetailLoading}
			<div class="modal-overlay" onclick={closeVehicleDetail}>
				<div class="modal-card" onclick={(e) => e.stopPropagation()}>
					{#if vehicleDetailLoading}
						<div class="center-msg"><div class="spinner"></div><span>Loading vehicle...</span></div>
					{:else if vehicleDetail}
						<div class="modal-header">
							<h3>Vehicle Details</h3>
							<button class="modal-close" onclick={closeVehicleDetail}>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
							</button>
						</div>
						<div class="modal-body">
							<div class="vd-row"><span class="vd-label">Plate</span><span class="vd-value mono">{vehicleDetail.plate}</span></div>
							<div class="vd-row"><span class="vd-label">Vehicle</span><span class="vd-value">{vehicleDetail.label || vehicleDetail.vehicle || vehicleDetail.model || 'Unknown'}</span></div>
							{#if vehicleDetail.owner}<div class="vd-row"><span class="vd-label">Owner</span><span class="vd-value">{vehicleDetail.owner}</span></div>{/if}
							{#if vehicleDetail.class}<div class="vd-row"><span class="vd-label">Class</span><span class="vd-value">{vehicleDetail.class}</span></div>{/if}
							{#if vehicleDetailFeatures.insurance}<div class="vd-row"><span class="vd-label">Insurance</span><span class="vd-value" style="color: {(vehicleDetail.status || 'valid').toLowerCase() === 'uninsured' ? '#f87171' : '#34d399'};">{(vehicleDetail.status || 'valid').toLowerCase() === 'uninsured' ? 'Uninsured' : 'Insured'}</span></div>{/if}
							{#if vehicleDetailFeatures.registration}<div class="vd-row"><span class="vd-label">Registration</span><span class="vd-value" style="color: {vehicleDetail.registered === false ? '#f87171' : '#34d399'};">{vehicleDetail.registered === false ? 'Unregistered' : 'Registered'}</span></div>{/if}
							{#if vehicleDetailFeatures.points && vehicleDetail.points !== undefined}<div class="vd-row"><span class="vd-label">Points</span><span class="vd-value" class:accent-red={vehicleDetail.points > 0}>{vehicleDetail.points}</span></div>{/if}
							{#if vehicleDetail.stolen}<div class="vd-row"><span class="vd-label">Stolen</span><span class="vd-value accent-red">Yes</span></div>{/if}
							{#if vehicleDetail.boloactive}<div class="vd-row"><span class="vd-label">BOLO</span><span class="vd-value" style="color: #fbbf24;">Active</span></div>{/if}
							{#if vehicleDetail.information}<div class="vd-row vd-notes"><span class="vd-label">Notes</span><span class="vd-value">{vehicleDetail.information}</span></div>{/if}
						</div>
					{/if}
				</div>
			</div>
		{/if}

		<!-- ── Property Detail Modal ── -->
		{#if propertyDetail || propertyDetailLoading}
			<div class="modal-overlay" onclick={closePropertyDetail}>
				<div class="modal-card modal-card-property" onclick={(e) => e.stopPropagation()}>
					{#if propertyDetailLoading}
						<div class="center-msg"><div class="spinner"></div><span>Loading property...</span></div>
					{:else if propertyDetail}
						<div class="modal-header">
							<div class="prop-modal-title-group">
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: rgba(96,165,250,0.6); flex-shrink:0; margin-top:1px"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
								<h3>{propertyDetail.property_name}</h3>
							</div>
							<button class="modal-close" onclick={closePropertyDetail}>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
							</button>
						</div>

						<!-- Location banner -->
						{#if propertyDetail.coords}
							<button
								class="prop-location-banner"
								class:waypoint-active={waypointSet}
								onclick={setPropertyWaypoint}
								title="Set GPS waypoint"
							>
								<div class="prop-location-left">
									<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></svg>
									<div class="prop-location-text">
										<span class="prop-location-label">Location</span>
										<span class="prop-location-coords">
											{propertyDetail.streetName || propertyDetail.property_name}
										</span>
									</div>
								</div>
								<div class="prop-waypoint-btn" class:waypoint-done={waypointSet}>
									{#if waypointSet}
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
										Waypoint Set
									{:else}
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
										Set Waypoint
									{/if}
								</div>
							</button>
						{/if}

						<div class="modal-body">
							<!-- Owner row -->
							<div class="prop-section-label">Owner</div>
							{#if propertyDetail.ownerName || propertyDetail.owner}
								<div class="prop-person-row prop-owner-row">
									<div class="prop-person-avatar prop-owner-avatar">
										<svg width="14" height="14" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
									</div>
									<div class="prop-person-info">
										<span class="prop-person-name">{propertyDetail.ownerName || 'Unknown'}</span>
										{#if propertyDetail.owner}
											<span class="prop-person-cid">{propertyDetail.owner}</span>
										{/if}
									</div>
									<span class="prop-role-badge prop-role-owner">Owner</span>
								</div>
							{:else}
								<div class="prop-empty-row">No owner on record</div>
							{/if}

							<!-- Keyholders -->
							<div class="prop-section-label prop-section-label-gap">
								Keyholders
								<span class="prop-kh-count">{propertyDetail.keyholders?.length || 0}</span>
							</div>
							{#if propertyDetail.keyholders && propertyDetail.keyholders.length > 0}
								<div class="prop-keyholders-list">
									{#each propertyDetail.keyholders as kh}
										<button class="prop-person-row prop-person-clickable" onclick={() => { closePropertyDetail(); viewProfile(kh.citizenid); }}>
											<div class="prop-person-avatar">
												<svg width="13" height="13" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
											</div>
											<div class="prop-person-info">
												<span class="prop-person-name">{kh.name || 'Unknown'}</span>
												<span class="prop-person-cid">{kh.citizenid}</span>
											</div>
											<span class="prop-role-badge prop-role-key">Key Access</span>
										</button>
									{/each}
								</div>
							{:else}
								<div class="prop-empty-row">No keyholders</div>
							{/if}
						</div>
					{/if}
				</div>
			</div>
		{/if}

		<!-- Issue License Modal -->
		{#if showIssueLicenseModal}
			<div class="modal-overlay" onclick={() => (showIssueLicenseModal = false)}>
				<div class="modal-card" onclick={(e) => e.stopPropagation()}>
					<div class="modal-header">
						<h3>Manage Licenses</h3>
						<button class="modal-close" onclick={() => (showIssueLicenseModal = false)}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					</div>
					<div class="modal-body license-modal-body">
						{#each issuableLicenses as license (license.key)}
							<div class="license-modal-row">
								<div class="license-modal-info">
									<div style="display: flex; flex-direction: column; gap: 2px; min-width: 0;">
										<div style="display: flex; align-items: center; gap: 6px;">
											<span class="license-modal-name">{license.name}</span>
											<span class="license-modal-type">{license.type === 'state' ? 'State' : 'Custom'}</span>
										</div>
										{#if license.description}
											<span class="license-modal-description">{license.description}</span>
										{/if}
									</div>
								</div>
								<label class="toggle"><input type="checkbox" checked={license.active} onchange={() => toggleIssuableLicense(license)} /><span class="toggle-track"></span></label>
							</div>
						{/each}
					</div>
				</div>
			</div>
		{/if}

		<!-- Manage Tags Modal -->
		{#if showTagModal}
			<div class="modal-overlay" onclick={() => (showTagModal = false)}>
				<div class="modal-card" onclick={(e) => e.stopPropagation()}>
					<div class="modal-header">
						<h3>Manage Tags</h3>
						<button class="modal-close" onclick={() => (showTagModal = false)}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					</div>
					<div class="modal-body license-modal-body">
						{#if manageableTags.length === 0}
							<div class="ptags-empty" style="padding: 8px;">No tags available</div>
						{:else}
							{#each manageableTags as t (t.name)}
								{@const active = (selectedProfile?.tags ?? []).includes(t.name)}
								<div class="license-modal-row">
									<div class="license-modal-info">
										<div style="display:flex; flex-direction:column; align-items:flex-start; gap:3px; min-width:0;">
											<span class="flag tag-pill" style={tagPillStyle(t.color)}>{t.name}</span>
											{#if t.description}<span class="license-modal-description">{t.description}</span>{/if}
										</div>
									</div>
									<label class="toggle"><input type="checkbox" checked={active} disabled={tagBusy} onchange={() => active ? removeCitizenTag(t.name) : addCitizenTag(t.name)} /><span class="toggle-track"></span></label>
								</div>
							{/each}
						{/if}
					</div>
				</div>
			</div>
		{/if}

	{:else}
		<!-- ===== LIST VIEW ===== -->
		<div class="list-view">
			<div class="list-topbar">
				<div class="search-box">
					<svg width="14" height="14" fill="rgba(255,255,255,0.35)" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
					<input bind:value={searchQuery} type="text" placeholder="Search by name, ID, phone, fingerprint or DNA..." />
				</div>
			</div>

			{#if loading}
				<div class="center-msg"><div class="spinner"></div><span>Loading citizens...</span></div>
			{:else if citizens.length === 0}
				<div class="center-msg"><span>No citizen records available.</span></div>
			{:else}
				<div class="citizens-header">
					<span></span><span>Name</span><span>Citizen ID</span><span>Phone</span><span>Gender</span><span>DOB</span><span>Stats</span><span>Tags</span><span>Flags</span>
				</div>
				<div class="citizens-table">
					{#each filteredCitizens as citizen (citizen.id)}
						<button class="citizen-row" onclick={() => viewProfile(citizen.cid)}>
							<div class="citizen-avatar">
								{#if citizen.image}
									<img src={citizen.image} alt="" />
								{:else}
									<svg width="20" height="20" fill="rgba(255,255,255,0.3)" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
								{/if}
							</div>
							<div class="citizen-name">{citizen.firstName} {citizen.lastName}</div>
							<div class="citizen-meta">{citizen.cid}</div>
							<div class="citizen-meta">{citizen.phone}</div>
							<div class="citizen-meta">{citizen.gender}</div>
							<div class="citizen-meta">{citizen.dob}</div>
							<div class="citizen-nums">
								<span>{citizen.properties} prop</span>
								<span>{citizen.vehicles} veh</span>
								<span class:accent-red={citizen.arrests > 0}>{citizen.arrests} arr</span>
							</div>
							<div class="citizen-tags-cell">
								{#each (citizen.tags ?? []).slice(0, 3) as tag}
									<span class="flag tag-pill" style={tagPillStyle(citizenTagColor(tag))}>{tag}</span>
								{/each}
								{#if (citizen.tags ?? []).length > 3}
									<span class="flag flag-more">+{(citizen.tags ?? []).length - 3}</span>
								{/if}
							</div>
							<div class="citizen-flags-cell">
								{#each citizen.flags.slice(0, 3) as flag}
									<span class="flag {getPillClass(flag)}">{flag}</span>
								{/each}
								{#if citizen.flags.length > 3}
									<span class="flag flag-more">+{citizen.flags.length - 3}</span>
								{/if}
							</div>
						</button>
					{/each}
				</div>
				{#if filteredCitizens.length === 0 && searchQuery}
					<div class="center-msg"><span>No citizens match your search.</span></div>
				{/if}
				<Pagination
					currentPage={citizenPage}
					totalItems={allFilteredCitizens.length}
					perPage={citizenPerPage}
					onPageChange={(p) => { citizenPage = p; }}
					onPerPageChange={(pp) => { citizenPerPage = pp; citizenPage = 1; }}
				/>
			{/if}
		</div>
	{/if}
</div>

<style>
	.page { height: 100%; display: flex; flex-direction: column; background: var(--card-dark-bg); overflow: hidden; }

	/* ── Photo URL Modal ── */
	.photo-modal { width: min(380px, 92vw); }
	.photo-modal-body { padding: 14px 16px; display: flex; flex-direction: column; gap: 4px; }
	.photo-form-group { display: flex; align-items: center; flex-direction: column; gap: 4px; }
	.photo-label { 
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		margin-top: 5px;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}
	.photo-input {
		display: flex;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		transition: border-color 0.1s;
		font-family: inherit;
		width: 90%;
	}
	.photo-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.photo-input::placeholder { color: rgba(255, 255, 255, 0.2); }
	.url-hint {
		display: flex;
		align-items: center;
		gap: 5px;
		margin-top: 5px;
		font-size: 10px;
		color: rgba(255,255,255,0.25);
		line-height: 1.4;
	}
	.url-hint svg { flex-shrink: 0; opacity: 0.45; }
	.url-hint a { color: rgba(var(--accent-text-rgb), 0.5); text-decoration: none; transition: color 0.1s; }
	.url-hint a:hover { color: rgba(var(--accent-text-rgb), 0.85); text-decoration: underline; }
	.modal-footer-row {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255,255,255,0.06);
	}
	.photo-cancel-btn {
		background: transparent;
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255,255,255,0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}
	.photo-cancel-btn:hover:not(:disabled) { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.1); }
	.photo-cancel-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.photo-confirm-btn {
		background: rgba(16,185,129,0.06);
		color: rgba(52,211,153,0.7);
		border: 1px solid rgba(16,185,129,0.1);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.photo-confirm-btn:hover:not(:disabled) { background: rgba(16,185,129,0.12); color: rgba(110,231,183,0.9); }
	.photo-confirm-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	/* ===== LIST VIEW ===== */
	.list-view { display: flex; flex-direction: column; height: 100%; }
	.list-topbar { display: flex; align-items: center; gap: 16px; padding: 0 20px; height: 48px; flex-shrink: 0; border-bottom: 1px solid rgba(255,255,255,0.06); }
	.search-box { flex: 1; max-width: 400px; display: flex; align-items: center; gap: 8px; background: transparent; border: none; padding: 0; }
	.search-box input { flex: 1; background: none; border: none; color: rgba(255,255,255,0.85); font-size: 12px; outline: none; }
	.search-box input::placeholder { color: rgba(255,255,255,0.25); }

	.citizens-header { display: grid; grid-template-columns: 36px 1.5fr 1fr 1fr 0.6fr 0.8fr 1.2fr 1.2fr 1.5fr; gap: 12px; padding: 8px 20px; border-bottom: 1px solid rgba(255,255,255,0.06); color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; flex-shrink: 0; }
	.citizens-table { flex: 1; overflow-y: auto; padding: 2px 10px; display: flex; flex-direction: column; gap: 0; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.08) transparent; min-height: 0; }
	.citizens-table::-webkit-scrollbar { width: 3px; }
	.citizens-table::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 2px; }

	.citizen-row { display: grid; grid-template-columns: 36px 1.5fr 1fr 1fr 0.6fr 0.8fr 1.2fr 1.2fr 1.5fr; align-items: center; gap: 12px; padding: 8px 10px; background: transparent; border: none; border-radius: 4px; cursor: pointer; transition: background 0.1s; text-align: left; font: inherit; color: inherit; width: 100%; }
	.citizen-row:hover { background: rgba(255,255,255,0.03); }

	.citizen-avatar { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0; }
	.citizen-avatar img { width: 100%; height: 100%; object-fit: cover; }
	.citizen-name { color: rgba(255,255,255,0.85); font-size: 12px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.citizen-meta { color: rgba(255,255,255,0.3); font-size: 11px; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.citizen-nums { display: flex; gap: 8px; font-size: 10px; color: rgba(255,255,255,0.35); }
	.citizen-flags-cell { display: flex; gap: 4px; flex-wrap: nowrap; align-items: center; overflow: hidden; }
	.citizen-tags-cell { display: flex; gap: 4px; flex-wrap: nowrap; align-items: center; overflow: hidden; }
	.ctag-mini {
		font-size: 9px; font-weight: 600; padding: 2px 6px; border-radius: 3px; white-space: nowrap;
		color: var(--ctag, #9ca3af);
		background: color-mix(in srgb, var(--ctag, #9ca3af) 14%, transparent);
		border: 1px solid color-mix(in srgb, var(--ctag, #9ca3af) 28%, transparent);
	}
	.ctag-mini.ctag-more { color: rgba(255,255,255,0.4); background: rgba(255,255,255,0.05); border-color: rgba(255,255,255,0.08); }

	.flag { padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 600; letter-spacing: 0.2px; background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.4); border: 1px solid transparent; }
	.flag-red { background: rgba(239,68,68,0.12); color: #f87171; border-color: rgba(239,68,68,0.15); }
	.flag-yellow { background: rgba(250,204,21,0.12); color: #facc15; border-color: rgba(250,204,21,0.15); }
	.flag-orange { background: rgba(245,158,11,0.12); color: #fbbf24; border-color: rgba(245,158,11,0.15); }
	.flag-amber { background: rgba(249,115,22,0.12); color: #fb923c; border-color: rgba(249,115,22,0.15); }
	.flag-more { background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.3); font-size: 9px; white-space: nowrap; flex-shrink: 0; }
	.accent-red { color: #f87171 !important; }

	.center-msg { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; color: rgba(255,255,255,0.2); font-size: 12px; }
	.spinner { width: 24px; height: 24px; border: 2px solid rgba(255,255,255,0.08); border-top-color: #60a5fa; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ===== PROFILE VIEW ===== */
	.profile-view { display: flex; flex-direction: column; height: 100%; overflow: hidden; }
	.panel-caution { font-size: 9px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 3px 8px; border-radius: 3px; margin-bottom: 8px; }
	.caution-danger { background: rgba(239,68,68,0.08); color: #f87171; }
	.caution-warning { background: rgba(245,158,11,0.08); color: #fbbf24; }
	.profile-view { display: flex; flex-direction: column; height: 100%; overflow: hidden;}

	.panel-caution { font-size: 9px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 3px 8px; border-radius: 3px; margin-bottom: 8px; }
	.caution-danger { background: rgba(239,68,68,0.08); color: #f87171; }
	.caution-warning { background: rgba(245,158,11,0.08); color: #fbbf24; }

	.panel-danger { border: 1px solid rgba(239,68,68,0.35) !important; }
	.panel-warning { border: 1px solid rgba(245,158,11,0.35) !important; }
	.cnt-danger { background: rgba(239,68,68,0.12) !important; color: #f87171 !important; }
	.cnt-warning { background: rgba(245,158,11,0.12) !important; color: #fbbf24 !important; }
	.sitem-danger .sitem-primary { color: #f87171 !important; }
	.sitem-warning .sitem-primary { color: #fbbf24 !important; }

	.profile-topbar { display: flex; align-items: center; gap: 14px; padding: 0 20px; height: 48px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
	.back-btn { display: flex; align-items: center; gap: 6px; background: none; border: none; color: rgba(255,255,255,0.4); padding: 6px 0; font-size: 11px; cursor: pointer; transition: color 0.12s; font-weight: 500; }
	.back-btn:hover { color: rgba(255,255,255,0.8); }
	.profile-identity { display: flex; align-items: baseline; gap: 10px; flex: 1; }
	.profile-name { color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 600; }
	.profile-cid { color: rgba(255,255,255,0.25); font-size: 11px; font-family: monospace; }
	.profile-flags { display: flex; gap: 4px; }
	.copy-toast { color: #34d399; font-size: 11px; font-weight: 500; animation: fadeToast 1.4s ease-in-out; }
	@keyframes fadeToast { 0%,100% { opacity: 0; } 30%,70% { opacity: 1; } }

	.pstats-row { display: flex; align-items: center; padding: 0 20px; height: 44px; flex-shrink: 0; border-bottom: 1px solid rgba(255,255,255,0.06); gap: 0; }
	.tags-detail-row { align-items: flex-start; }
	.tags-detail-row .dlabel { padding-top: 3px; }
	.ptags-list { display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end; gap: 6px; min-width: 0; }
	.ptags-empty { font-size: 11px; color: rgba(255,255,255,0.25); }
	.flag.tag-pill { display: inline-flex; align-items: center; gap: 3px; }
	.ptags-fullrow { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; padding: 8px 16px 12px; }
	.ctag {
		display: inline-flex; align-items: center; gap: 5px;
		font-size: 10px; font-weight: 600; padding: 2px 4px 2px 8px; border-radius: 4px;
		color: var(--ctag); background: color-mix(in srgb, var(--ctag) 14%, transparent);
		border: 1px solid color-mix(in srgb, var(--ctag) 30%, transparent);
	}
	.ctag-remove {
		display: inline-flex; align-items: center; justify-content: center;
		width: 14px; height: 14px; border: none; border-radius: 3px; background: transparent;
		color: var(--ctag); opacity: 0.6; cursor: pointer; font-size: 13px; line-height: 1; padding: 0;
	}
	.ctag-remove:hover:not(:disabled) { opacity: 1; background: color-mix(in srgb, var(--ctag) 20%, transparent); }
	.ctag-remove:disabled { opacity: 0.3; cursor: default; }
	.ctag-add-wrap { position: relative; }
	.ctag-add {
		font-size: 10px; font-weight: 600; padding: 3px 8px; border-radius: 4px; cursor: pointer;
		background: transparent; border: 1px dashed rgba(255,255,255,0.18); color: rgba(255,255,255,0.5); transition: all 0.1s;
	}
	.ctag-add:hover:not(:disabled) { border-color: rgba(var(--accent-rgb),0.5); color: rgba(var(--accent-text-rgb),0.9); }
	.ctag-add:disabled { opacity: 0.4; cursor: default; }
	.ctag-picker {
		position: absolute; top: calc(100% + 4px); left: 0; z-index: 30;
		min-width: 160px; max-height: 220px; overflow-y: auto;
		background: rgba(20,22,28,0.98); border: 1px solid rgba(255,255,255,0.1); border-radius: 6px;
		padding: 4px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);
	}
	.ctag-picker-empty { font-size: 10px; color: rgba(255,255,255,0.3); padding: 6px 8px; }
	.ctag-picker-item {
		display: flex; align-items: center; gap: 7px; width: 100%; text-align: left;
		background: transparent; border: none; border-radius: 4px; padding: 5px 8px;
		color: rgba(255,255,255,0.8); font-size: 11px; cursor: pointer;
	}
	.ctag-picker-item:hover { background: rgba(255,255,255,0.06); }
	.ctag-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
	.pstat { display: flex; align-items: center; gap: 8px; padding: 0 18px; border-right: 1px solid rgba(255,255,255,0.06); }
	.pstat:last-child { border-right: none; }
	.pstat-val { color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 700; line-height: 1; }
	.pstat-lbl { color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.5px; }

	.profile-body { display: grid; grid-template-columns: 240px 1fr; flex: 1; min-height: 0; overflow: hidden; }
	.profile-sidebar { display: flex; flex-direction: column; border-right: 1px solid rgba(255,255,255,0.06); overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent; }
	.profile-sidebar::-webkit-scrollbar { width: 3px; }
	.profile-sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.06); border-radius: 2px; }

	.panel { padding: 14px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); background: transparent; border-radius: 0; }
	.panel:last-child { border-bottom: none; }
	.panel-title { color: rgba(255,255,255,0.35); font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px; display: flex; align-items: center; gap: 6px; }
	.cnt { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 600; padding: 0 5px; border-radius: 4px; line-height: 16px; }

	.profile-img { display: flex; align-items: center; justify-content: center; min-height: 160px; color: rgba(255,255,255,0.15); background: rgba(255,255,255,0.02); border-radius: 6px; overflow: hidden; }
	.profile-img img { width: 100%; max-height: 200px; object-fit: cover; border-radius: 6px; }
	.no-photo-placeholder { display: flex; flex-direction: column; align-items: center; gap: 6px; color: rgba(255,255,255,0.15); }
	.no-photo-placeholder span { font-size: 10px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.5px; }

	.detail-panel { display: flex; flex-direction: column; gap: 0; padding: 0; }
	.detail-row { display: flex; justify-content: space-between; align-items: center; padding: 9px 16px; border-bottom: 1px solid rgba(255,255,255,0.04); }
	.detail-row:last-child { border-bottom: none; }
	.dlabel { color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
	.dvalue { color: rgba(255,255,255,0.75); font-size: 12px; }
	.dvalue.clickable { cursor: pointer; transition: color 0.12s; }
	.dvalue.clickable:hover { color: #60a5fa; }
	.dvalue .edit-icon { font-size: 11px; margin-left: 4px; opacity: 0; transition: opacity 0.12s; vertical-align: middle; }
	.dvalue .copy-icon { font-size: 11px; margin-left: 4px; opacity: 0.5; transition: opacity 0.12s; vertical-align: middle; }
	.dvalue.clickable:hover .edit-icon { opacity: 0.5; }
	.dna-input { background: rgba(255,255,255,0.06); border: 1px solid rgba(96,165,250,0.3); border-radius: 3px; color: rgba(255,255,255,0.9); font-size: 12px; padding: 2px 6px; outline: none; width: 120px; }
	.dna-input:focus { border-color: rgba(96,165,250,0.6); }

	.license-status { font-size: 11px; color: rgba(239,68,68,0.8); font-weight: 500; }
	.license-status.license-active { color: rgba(34,197,94,0.8); }
	.license-status { font-size: 11px; color: rgba(239, 68, 68, 0.8); font-weight: 500; }
	.license-status.license-active { color: rgba(34, 197, 94, 0.8); }

	.toggle { position: relative; display: inline-block; width: 32px; height: 16px; flex-shrink: 0; }
	.toggle input { opacity: 0; width: 0; height: 0; }
	.toggle-track { position: absolute; cursor: pointer; inset: 0; background: rgba(255,255,255,0.1); border-radius: 16px; transition: background 0.2s; }
	.toggle-track::before { content: ""; position: absolute; height: 12px; width: 12px; left: 2px; bottom: 2px; background: rgba(255,255,255,0.6); border-radius: 50%; transition: transform 0.2s; }
	.toggle input:checked + .toggle-track { background: rgba(16,185,129,0.45); }
	.toggle input:checked + .toggle-track::before { transform: translateX(16px); }

	.notes-text { color: rgba(255,255,255,0.55); font-size: 12px; line-height: 1.5; white-space: pre-wrap; word-wrap: break-word; }

	.profile-main { display: flex; flex-direction: column; overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent; }
	.profile-main::-webkit-scrollbar { width: 3px; }
	.profile-main::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.06); border-radius: 2px; }
	.sections-grid { display: grid; grid-template-columns: 1fr 1fr; }

	.sections-grid .panel { border-bottom: 1px solid rgba(255,255,255,0.06); border-right: 1px solid rgba(255,255,255,0.06); }
	.sections-grid .panel:nth-child(2n) { border-right: none; }
	.profile-main > .panel { border-bottom: 1px solid rgba(255,255,255,0.06); }

	.section-list { display: flex; flex-direction: column; gap: 2px; }
	.sitem { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 7px 8px; background: transparent; border: none; border-radius: 4px; transition: background 0.1s; }
	.sitem:hover { background: rgba(255,255,255,0.03); }
	.sitem-info { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
	.sitem-primary { color: rgba(255,255,255,0.8); font-size: 12px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.sitem-secondary { color: rgba(255,255,255,0.3); font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.sitem-overflow { text-align: center; font-size: 10px; color: rgba(255,255,255,0.25); padding: 4px 0 0; font-weight: 500; }
	.sitem-arrow { display: flex; align-items: center; justify-content: center; width: 22px; height: 22px; flex-shrink: 0; background: transparent; border: none; color: rgba(255,255,255,0.2); cursor: pointer; transition: color 0.12s; border-radius: 4px; }
	.sitem-arrow:hover { color: rgba(255,255,255,0.6); background: rgba(255,255,255,0.04); }

	.badge { padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 600; flex-shrink: 0; border: 1px solid transparent; text-transform: capitalize; }
	.badge-green { background: rgba(16,185,129,0.12); color: #34d399; border-color: rgba(16,185,129,0.15); }
	.badge-red { background: rgba(239,68,68,0.12); color: #f87171; border-color: rgba(239,68,68,0.15); }

	.view-btn { background: transparent; color: rgba(255,255,255,0.3); border: none; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 500; cursor: pointer; transition: all 0.12s; flex-shrink: 0; }
	.view-btn:hover { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.04); }

	.empty-msg { color: rgba(255,255,255,0.15); font-size: 11px; text-align: center; padding: 14px 0; }

	.section-pager { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 6px 0 0; margin-top: 2px; }
	.spager-btn { background: transparent; border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 2px 4px; color: rgba(255,255,255,0.3); cursor: pointer; display: flex; align-items: center; transition: all 0.12s ease; }
	.spager-btn:hover:not(:disabled) { background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.7); }
	.spager-btn:disabled { opacity: 0.2; cursor: not-allowed; }
	.spager-info { font-size: 10px; color: rgba(255,255,255,0.2); min-width: 28px; text-align: center; }

	.load-more-btn { width: 100%; background: transparent; border: 1px solid rgba(255,255,255,0.08); border-radius: 5px; padding: 6px 0; color: rgba(255,255,255,0.4); font-size: 11px; font-weight: 500; cursor: pointer; transition: all 0.12s ease; }
	.load-more-btn:hover:not(:disabled) { background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.75); border-color: rgba(255,255,255,0.14); }
	.load-more-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	.profile-photo-actions { display: flex; gap: 6px; justify-content: center; margin-top: 8px; }
	.photo-action-btn { display: flex; align-items: center; gap: 4px; background: transparent; border: 1px solid rgba(255,255,255,0.06); color: rgba(255,255,255,0.4); padding: 4px 8px; border-radius: 4px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.12s; }
	.photo-action-btn:hover:not(:disabled) { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.12); background: rgba(255,255,255,0.03); }
	.photo-action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	/* Modal shared */
	.modal-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.6); display: flex; align-items: center; justify-content: center; z-index: 100; backdrop-filter: blur(2px); }
	.modal-card { background: var(--dark-bg); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; width: 360px; max-height: 80%; overflow-y: auto; display: flex; flex-direction: column; }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
	.modal-header h3 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.85); }
	.modal-close { background: transparent; border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; color: rgba(255,255,255,0.3); cursor: pointer; padding: 4px; display: flex; align-items: center; justify-content: center; transition: all 0.1s; }
	.modal-close:hover { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.1); }
	.modal-body { padding: 0; }

	.upload-spinner { width: 10px; height: 10px; border: 2px solid rgba(255,255,255,0.15); border-left-color: var(--accent-60); border-radius: 50%; animation: spin 0.8s linear infinite; }

	/* ── Shared modals ── */
	.modal-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.6); display: flex; align-items: center; justify-content: center; z-index: 100; backdrop-filter: blur(2px); }
	.modal-card { background: var(--dark-bg); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; width: 360px; max-height: 80%; overflow-y: auto; }
	.modal-card-property { width: 400px; }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); }
	.modal-header h3 { margin: 0; font-size: 13px; font-weight: 600; color: rgba(255,255,255,0.85); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.modal-close { background: none; border: none; color: rgba(255,255,255,0.3); cursor: pointer; padding: 4px; border-radius: 4px; display: flex; flex-shrink: 0; }
	.modal-close:hover { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.04); }
	.modal-body { padding: 0; }

	/* ── Vehicle modal rows ── */
	.vd-row { display: flex; justify-content: space-between; align-items: center; padding: 9px 16px; border-bottom: 1px solid rgba(255,255,255,0.04); }
	.vd-row:last-child { border-bottom: none; }
	.vd-label { color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
	.vd-value { color: rgba(255,255,255,0.75); font-size: 12px; font-weight: 500; }
	.vd-value.mono { font-family: monospace; letter-spacing: 0.5px; }
	.vd-notes { flex-direction: column; align-items: flex-start; gap: 4px; }
	.vd-notes .vd-value { font-weight: 400; line-height: 1.4; }

	/* ── Property modal ── */
	.prop-modal-title-group { display: flex; align-items: flex-start; gap: 7px; flex: 1; min-width: 0; }
	.prop-modal-title-group h3 { white-space: normal; line-height: 1.3; }

	/* Location banner — clickable strip */
	.prop-location-banner { display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; background: rgba(96,165,250,0.04); border-bottom: 1px solid rgba(96,165,250,0.08); cursor: pointer; width: 100%; border: none; text-align: left; transition: background 0.12s; }
	.prop-location-banner:hover { background: rgba(96,165,250,0.08); }
	.prop-location-banner.waypoint-active { background: rgba(52,211,153,0.05); border-bottom-color: rgba(52,211,153,0.1); }
	.prop-location-left { display: flex; align-items: center; gap: 8px; min-width: 0; }
	.prop-location-left svg { color: rgba(96,165,250,0.5); flex-shrink: 0; }
	.prop-location-text { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
	.prop-location-label { font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: rgba(255,255,255,0.25); }
	.prop-location-coords { font-size: 11px; color: rgba(255,255,255,0.6); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.prop-person-clickable { cursor: pointer; background: transparent; border: none; width: 100%; text-align: left; font: inherit; color: inherit; }
	.prop-person-clickable:hover { background: rgba(255,255,255,0.03); }

	.prop-waypoint-btn { display: flex; align-items: center; gap: 4px; font-size: 10px; font-weight: 600; color: rgba(96,165,250,0.6); flex-shrink: 0; padding: 4px 8px; border-radius: 4px; border: 1px solid rgba(96,165,250,0.12); background: rgba(96,165,250,0.05); transition: all 0.12s; }
	.prop-location-banner:hover .prop-waypoint-btn { color: rgba(96,165,250,0.9); border-color: rgba(96,165,250,0.25); background: rgba(96,165,250,0.1); }
	.prop-waypoint-btn.waypoint-done { color: #34d399; border-color: rgba(52,211,153,0.2); background: rgba(52,211,153,0.06); }

	/* Property body sections */
	.prop-section-label { font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: rgba(255,255,255,0.25); padding: 12px 16px 6px; display: flex; align-items: center; gap: 6px; }
	.prop-section-label-gap { padding-top: 8px; border-top: 1px solid rgba(255,255,255,0.04); }
	.prop-kh-count { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.3); font-size: 9px; padding: 0 5px; border-radius: 3px; line-height: 15px; }

	.prop-person-row { display: flex; align-items: center; gap: 10px; padding: 8px 16px; transition: background 0.1s; }
	.prop-person-row:hover { background: rgba(255,255,255,0.02); }
	.prop-keyholders-list { display: flex; flex-direction: column; padding-bottom: 4px; }

	.prop-person-avatar { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; flex-shrink: 0; color: rgba(255,255,255,0.25); }
	.prop-owner-avatar { background: rgba(96,165,250,0.08); color: rgba(96,165,250,0.5); }

	.prop-person-info { display: flex; flex-direction: column; gap: 1px; flex: 1; min-width: 0; }
	.prop-person-name { font-size: 12px; font-weight: 500; color: rgba(255,255,255,0.8); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.prop-person-cid { font-size: 10px; color: rgba(255,255,255,0.25); font-family: monospace; }

	.prop-role-badge { font-size: 9px; font-weight: 700; letter-spacing: 0.3px; padding: 2px 7px; border-radius: 3px; flex-shrink: 0; border: 1px solid transparent; }
	.prop-role-owner { background: rgba(96,165,250,0.1); color: #93c5fd; border-color: rgba(96,165,250,0.15); }
	.prop-role-key { background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.35); border-color: rgba(255,255,255,0.06); }

	.prop-empty-row { padding: 10px 16px; font-size: 11px; color: rgba(255,255,255,0.2); }

	.prop-owner-row { border-bottom: none; }

	.prop-coords-row { display: flex; align-items: center; gap: 6px; padding: 8px 16px 12px; border-top: 1px solid rgba(255,255,255,0.04); color: rgba(255,255,255,0.2); font-size: 10px; font-family: monospace; }
	.prop-coords-row svg { color: rgba(255,255,255,0.15); flex-shrink: 0; }

	/* Issue License button */
	.issue-license-btn { display: flex; align-items: center; gap: 3px; margin-left: auto; background: rgba(59,130,246,0.06); border: 1px solid rgba(59,130,246,0.1); border-radius: 3px; padding: 2px 8px; color: rgba(147,197,253,0.7); font-size: 9px; font-weight: 600; cursor: pointer; transition: all 0.12s; text-transform: none; letter-spacing: 0; }
	.issue-license-btn:hover { background: rgba(59,130,246,0.12); color: rgba(147,197,253,0.9); }

	.license-modal-body { padding: 4px 0; }
	.license-modal-row { display: flex; align-items: center; justify-content: space-between; padding: 8px 16px; border-bottom: 1px solid rgba(255,255,255,0.03); }
	.license-modal-row:hover { background: rgba(255,255,255,0.02); }
	.license-modal-row:hover .license-modal-description { max-height: 50px; opacity: 1; }
	.license-modal-row:last-child { border-bottom: none; }
	.license-modal-info { display: flex; align-items: center; gap: 8px; }
	.license-modal-name { font-size: 12px; color: rgba(255,255,255,0.75); font-weight: 500; }
  .license-modal-type { font-size: 8px; font-weight: 700; letter-spacing: 0.5px; padding: 1px 5px; border-radius: 3px; text-transform: uppercase; background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.25); flex-shrink: 0; }
	.license-modal-description { font-size: 10px; color: rgba(255,255,255,0.35); line-height: 1.3; overflow: hidden; text-overflow: ellipsis; max-height: 0; opacity: 0; transition: max-height 0.8s ease, opacity 0.8s ease; }
  
	/* Notes */
	.notes-save-btn { background: rgba(16,185,129,0.08); border: 1px solid rgba(16,185,129,0.15); color: rgba(52,211,153,0.8); padding: 4px 12px; border-radius: 3px; font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.12s; }
	.notes-save-btn:hover:not(:disabled) { background: rgba(16,185,129,0.14); color: #34d399; }
	.notes-save-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	/* Gallery & Lightbox */
	.gallery-card { width: min(560px, 92vw); max-height: 80vh; display: flex; flex-direction: column; }
	.gallery-body { padding: 12px; overflow-y: auto; flex: 1; min-height: 0; }
	.gallery-section-label { font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.6px; color: rgba(255,255,255,0.25); margin-bottom: 6px; }
	.gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 8px; }
	.gallery-item { position: relative; aspect-ratio: 1; border-radius: 4px; overflow: hidden; border: 1px solid rgba(255,255,255,0.06); }
	.gallery-item:hover .gallery-thumb { transform: scale(1.04); }
	.gallery-thumb { width: 100%; height: 100%; object-fit: cover; display: block; transition: transform 0.2s ease; cursor: zoom-in; }
	.gallery-delete-btn { position: absolute; top: 2px; right: 2px; width: 16px; height: 16px; background: rgba(239,68,68,0.8); border: none; border-radius: 50%; color: #fff; cursor: pointer; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.15s; }
	.gallery-item:hover .gallery-delete-btn { opacity: 1; }
	.gallery-add-btn { display: flex; align-items: center; gap: 4px; background: rgba(16,185,129,0.06); border: 1px solid rgba(16,185,129,0.1); border-radius: 3px; padding: 3px 8px; color: rgba(52,211,153,0.7); font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.gallery-add-btn:hover { background: rgba(16,185,129,0.12); color: rgba(110,231,183,0.9); }

	.lightbox-overlay { background: rgba(0,0,0,0.85); }
	.lightbox-card { position: relative; max-width: 90vw; max-height: 90vh; display: flex; flex-direction: column; padding-top: 40px; }
	.lightbox-close { position: absolute; top: 0; right: 0; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.12); border-radius: 4px; color: rgba(255,255,255,0.6); cursor: pointer; padding: 4px; display: flex; align-items: center; justify-content: center; transition: all 0.1s; z-index: 10; }
	.lightbox-close:hover { background: rgba(255,255,255,0.2); color: #fff; }
	.lightbox-img { max-width: 90vw; max-height: calc(90vh - 40px); object-fit: contain; display: block; border-radius: 4px; }
</style>