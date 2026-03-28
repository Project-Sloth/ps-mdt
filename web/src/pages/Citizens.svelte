<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { compressImage } from "../services/uploadService";
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
		image?: string;
		occupations: string[];
		properties: number;
		vehicles: number;
		arrests: number;
		flags: string[];
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
			house: string;
		}>;
	}

	import type { JobType } from "../interfaces/IUser";
	import type { AuthService } from "../services/authService.svelte";

	let { tabService, jobType = 'leo', authService }: { tabService: ReturnType<typeof createTabService>; jobType?: JobType; authService?: AuthService } =
		$props();

	let canManageLicenses = $derived(authService?.hasPermission('citizens_edit_licenses') ?? !isEMS);

	const isEMS = $derived(jobType === 'ems');
	let searchQuery = $state("");
	let citizens: Citizen[] = $state([]);
	let loading = $state(true);
	let selectedProfile: CitizenProfile | null = $state(null);
	let copyNotice = $state("");
	let copyTimeout: ReturnType<typeof setTimeout> | null = null;

	let citizenPage = $state(1);
	let citizenPerPage = $state(25);

	let allFilteredCitizens = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		if (!query) return citizens;
		return citizens.filter(({ firstName, lastName, cid, phone }) =>
			[firstName, lastName, cid, phone].some((val) =>
				val?.toLowerCase().includes(query),
			),
		);
	});

	let citizenTotalPages = $derived(Math.max(1, Math.ceil(allFilteredCitizens.length / citizenPerPage)));

	let filteredCitizens = $derived.by(() => {
		const start = (citizenPage - 1) * citizenPerPage;
		return allFilteredCitizens.slice(start, start + citizenPerPage);
	});

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
				{ id: 1, cid: 'ABC12345', firstName: 'Marcus', lastName: 'Rodriguez', gender: 'Male', dob: '1990-05-15', phone: '555-0142', image: '', occupations: ['Mechanic', 'Taxi Driver'], properties: 2, vehicles: 3, arrests: 1, flags: ['Active Warrant', 'Violent'] },
				{ id: 2, cid: 'DEF67890', firstName: 'Sarah', lastName: 'Chen', gender: 'Female', dob: '1995-11-22', phone: '555-0299', image: '', occupations: ['Doctor'], properties: 1, vehicles: 1, arrests: 0, flags: [] },
				{ id: 3, cid: 'GHI11223', firstName: 'James', lastName: 'Wilson', gender: 'Male', dob: '1988-03-08', phone: '555-0377', image: '', occupations: ['Unemployed'], properties: 0, vehicles: 2, arrests: 5, flags: ['Flight Risk'] },
			];
			return;
		}
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

	function formatOccupations(list: string[] = []) {
		const cleaned = list.filter((item) => item && item.trim());
		return cleaned.length ? cleaned.join(", ") : "None";
	}

	function formatExpiryDate(raw: string | number): string {
		if (!raw) return "Unknown";
		const num = typeof raw === "string" ? Number(raw) : raw;
		if (!isNaN(num) && num > 1000000000) {
			// Unix timestamp - if > 10 digits it's milliseconds
			const ms = num > 9999999999 ? num : num * 1000;
			const d = new Date(ms);
			return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
		}
		return String(raw);
	}

	let hasActiveWarrants = $derived(
		(selectedProfile?.activeWarrants?.length ?? 0) > 0,
	);
	let hasActiveBolos = $derived(
		(selectedProfile?.activeBolos?.length ?? 0) > 0,
	);

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
		} catch {
			// silent fail
		}
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
		} catch {
			// silent fail
		}
	}

	async function viewProfile(citizenId: string) {
		if (isEnvBrowser()) {
			const mockProfiles: Record<string, CitizenProfile> = {
				'ABC12345': { citizenid: 'ABC12345', firstName: 'Marcus', lastName: 'Rodriguez', gender: 'Male', dob: '1990-05-15', phone: '555-0142', fingerprint: 'FP-8291-AXKF', image: '', occupations: ['Mechanic', 'Taxi Driver'], properties: 2, vehicles: 3, arrests: 1, flags: ['Active Warrant', 'Violent'], notes: 'Known associate of local gangs. Exercise caution during traffic stops.', licenses: { driver: true, weapon: false }, customLicenses: [{ id: 1, name: 'Hunting License', active: true }, { id: 2, name: 'Boating License', active: false }, { id: 3, name: 'Pilot License', active: false }], ownedVehicles: [{ plate: '03ROY490', vehicle: 'Exemplar' }, { plate: 'FAST001', vehicle: 'Sultan' }, { plate: 'LOW99X', vehicle: 'Bati 801' }], propertiesList: [{ house: '4 Integrity Way, Apt 30' }, { house: '1561 San Vitas Street' }], weapons: [{ id: 1, serial: 'WPN-4821', scratched: 0, weaponModel: 'weapon_pistol' }, { id: 2, serial: 'WPN-9012', scratched: 1, weaponModel: 'weapon_smg' }], evidence: [{ id: 1, title: 'Shell Casings', type: 'Physical', report_id: 42, notes: 'Found at scene near Vespucci' }, { id: 2, title: 'CCTV Footage', type: 'Digital', case_id: 7 }], linkedReports: [{ id: 42, title: 'Armed Robbery - Fleeca Bank', type: 'Incident' }, { id: 55, title: 'Traffic Violation - Speeding', type: 'Citation' }], activeBolos: [{ id: 1, type: 'Person', reportId: '42', notes: 'Armed and dangerous, last seen near Legion Square' }] },
				'DEF67890': { citizenid: 'DEF67890', firstName: 'Sarah', lastName: 'Chen', gender: 'Female', dob: '1995-11-22', phone: '555-0299', fingerprint: 'FP-1122-BXYZ', image: '', occupations: ['Doctor'], properties: 1, vehicles: 1, arrests: 0, flags: [], licenses: { driver: true, weapon: true }, customLicenses: [{ id: 1, name: 'Hunting License', active: false }, { id: 2, name: 'Boating License', active: true }, { id: 3, name: 'Pilot License', active: true }], ownedVehicles: [{ plate: 'MED001', vehicle: 'Schafter' }], propertiesList: [{ house: 'Eclipse Towers, Apt 5' }], weapons: [], evidence: [], linkedReports: [], activeBolos: [] },
				'GHI11223': { citizenid: 'GHI11223', firstName: 'James', lastName: 'Wilson', gender: 'Male', dob: '1988-03-08', phone: '555-0377', fingerprint: 'FP-3344-CDEF', image: '', occupations: [], properties: 0, vehicles: 2, arrests: 5, flags: ['Flight Risk'], licenses: { driver: false, weapon: false }, customLicenses: [{ id: 1, name: 'Hunting License', active: false }, { id: 2, name: 'Boating License', active: false }, { id: 3, name: 'Pilot License', active: false }], ownedVehicles: [{ plate: 'RUN4IT', vehicle: 'Comet' }, { plate: 'GHOST7', vehicle: 'Elegy' }], propertiesList: [], weapons: [{ id: 3, serial: 'WPN-5577', scratched: 0, weaponModel: 'weapon_assaultrifle' }], evidence: [], linkedReports: [{ id: 12, title: 'Evading Police', type: 'Incident' }], activeBolos: [] },
			};
			selectedProfile = mockProfiles[citizenId] || null;
			return;
		}
		try {
			const response = await fetchNui(NUI_EVENTS.CITIZEN.GET_CITIZEN, {
				citizenid: citizenId,
			});
			if (response?.profile) {
				selectedProfile = response.profile;
				citizens = citizens.map((citizen) =>
					citizen.cid === response.profile.citizenid
						? {
								...citizen,
								firstName: response.profile.firstName,
								lastName: response.profile.lastName,
								gender: response.profile.gender,
								dob: response.profile.dob,
								phone: response.profile.phone,
								image: response.profile.image,
								occupations: response.profile.occupations || citizen.occupations,
								properties: response.profile.properties,
								vehicles: response.profile.vehicles,
								arrests: response.profile.arrests,
								flags: response.profile.flags || citizen.flags,
						}
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

	// ── Profile section pagination ──
	const SECTION_PAGE_SIZE = 3;
	let vehiclesPage = $state(1);
	let propertiesPage = $state(1);
	let weaponsPage = $state(1);
	let evidencePage = $state(1);
	let reportsPage = $state(1);
	let licensesPage = $state(1);

	// Reset pages when profile changes
	$effect(() => {
		if (selectedProfile) {
			vehiclesPage = 1;
			propertiesPage = 1;
			weaponsPage = 1;
			evidencePage = 1;
			reportsPage = 1;
			licensesPage = 1;
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

	// Track broken profile images
	let citizenImageBroken = $state(false);
	function handleImageError() { citizenImageBroken = true; }

	// Reset broken state when profile changes
	$effect(() => {
		if (selectedProfile) citizenImageBroken = false;
	});

	// Photo upload/mugshot for citizen profile
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

	// Vehicle detail modal
	interface VehicleDetail {
		plate: string;
		vehicle: string;
		owner?: string;
		model?: string;
		label?: string;
		class?: string;
		type?: string;
		status?: string;
		points?: number;
		information?: string;
		stolen?: boolean;
		boloactive?: boolean;
	}
	let vehicleDetail: VehicleDetail | null = $state(null);
	let vehicleDetailLoading = $state(false);

	function goToBolo(boloId: number) {
		openBoloDetail(boloId);
		tabService.setActiveTab("BOLOs");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "BOLOs");
		}
	}

	function goToWarrantReport(reportId: number | string) {
		openReportInEditor(String(reportId));
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	async function openVehicleFromProfile(plate: string) {
		if (!plate) return;
		vehicleDetailLoading = true;
		vehicleDetail = null;
		try {
			const response = await fetchNui<any>(NUI_EVENTS.VEHICLE.GET_VEHICLE, { plate });
			if (response?.vehicle) {
				vehicleDetail = response.vehicle;
			} else {
				vehicleDetail = { plate, vehicle: "Unknown" };
			}
		} catch {
			vehicleDetail = { plate, vehicle: "Unknown" };
		}
		vehicleDetailLoading = false;
	}

	function closeVehicleDetail() {
		vehicleDetail = null;
	}

	async function toggleLicense(type: "driver" | "weapon", enabled: boolean) {
		if (!selectedProfile) return;
		const response = await fetchNui(NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_LICENSE, {
			citizenid: selectedProfile.citizenid,
			license: type,
			enabled,
		});
		if (response?.success) {
			selectedProfile = {
				...selectedProfile,
				licenses: {
					...selectedProfile.licenses,
					[type]: enabled,
				},
			};
		}
	}

	async function toggleCustomLicense(licenseId: number, enabled: boolean) {
		if (!selectedProfile) return;
		if (isEnvBrowser()) {
			selectedProfile = {
				...selectedProfile,
				customLicenses: (selectedProfile.customLicenses || []).map(l =>
					l.id === licenseId ? { ...l, active: enabled } : l
				),
			};
			return;
		}
		const response = await fetchNui(NUI_EVENTS.CITIZEN.UPDATE_CITIZEN_CUSTOM_LICENSE, {
			citizenid: selectedProfile.citizenid,
			licenseId,
			enabled,
		});
		if (response?.success) {
			selectedProfile = {
				...selectedProfile,
				customLicenses: (selectedProfile.customLicenses || []).map(l =>
					l.id === licenseId ? { ...l, active: enabled } : l
				),
			};
		}
	}

	// ── Active licenses (only ones the citizen holds) ──
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
		if (selectedProfile.licenses?.driver) {
			result.push({ key: "driver", name: "Driver's License", type: "state", active: true });
		}
		if (selectedProfile.licenses?.weapon) {
			result.push({ key: "weapon", name: "Weapon License", type: "state", active: true });
		}
		for (const cl of selectedProfile.customLicenses || []) {
			if (cl.active) {
				result.push({ key: `custom-${cl.id}`, name: cl.name, type: "custom", active: true, customId: cl.id });
			}
		}
		return result;
	});

	// ── Issue License modal ──
	let showIssueLicenseModal = $state(false);

	interface IssuableLicense {
		key: string;
		name: string;
		type: "state" | "custom";
		active: boolean;
		customId?: number;
	}

	let issuableLicenses = $derived.by((): IssuableLicense[] => {
		if (!selectedProfile) return [];
		const result: IssuableLicense[] = [];
		result.push({ key: "driver", name: "Driver's License", type: "state", active: selectedProfile.licenses?.driver || false });
		result.push({ key: "weapon", name: "Weapon License", type: "state", active: selectedProfile.licenses?.weapon || false });
		for (const cl of selectedProfile.customLicenses || []) {
			result.push({ key: `custom-${cl.id}`, name: cl.name, type: "custom", active: cl.active, customId: cl.id });
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
		if (copyTimeout) {
			clearTimeout(copyTimeout);
		}
		copyTimeout = setTimeout(() => {
			copyNotice = "";
			copyTimeout = null;
		}, 1400);
	}

	async function copyToClipboard(value: string, label: string) {
		if (!value) return;

		// In FiveM NUI, the Clipboard API is blocked by permissions policy.
		// Use NUI callback to copy via Lua's lib.setClipboard instead.
		try {
			await fetchNui("copyToClipboard", { text: value });
			showCopyNotice(label);
			return;
		} catch {
			// NUI callback not available (dev mode) - try browser API
		}

		try {
			if (navigator?.clipboard?.writeText) {
				await navigator.clipboard.writeText(value);
				showCopyNotice(label);
				return;
			}
		} catch {
			// Clipboard API blocked - silent
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
			// Fallback also failed - silent
		}
	}

</script>

<div class="page">
	{#if selectedProfile}
		<!-- ===== PROFILE VIEW ===== -->
		<div class="profile-view">
			<!-- Top bar -->
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

			<!-- Stats row -->
			<div class="pstats-row">
				<div class="pstat"><span class="pstat-val">{selectedProfile.properties}</span><span class="pstat-lbl">Properties</span></div>
				<div class="pstat"><span class="pstat-val">{selectedProfile.vehicles}</span><span class="pstat-lbl">Vehicles</span></div>
				<div class="pstat"><span class="pstat-val accent-red">{selectedProfile.arrests}</span><span class="pstat-lbl">Arrests</span></div>
				<div class="pstat"><span class="pstat-val">{selectedProfile.occupations.length}</span><span class="pstat-lbl">Jobs</span></div>
			</div>

			<!-- Body -->
			<div class="profile-body">
				<!-- Sidebar -->
				<div class="profile-sidebar">
					<!-- Photo panel -->
					<div class="panel">
						<div class="profile-img">
							{#if selectedProfile.image && !citizenImageBroken}
								<img src={selectedProfile.image} alt="Profile" onerror={handleImageError} />
							{:else}
								<div class="no-photo-placeholder">
									<svg width="40" height="40" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
									<span>No Photo</span>
								</div>
							{/if}
						</div>
						{#if !isEMS}
						<div class="profile-photo-actions">
							<button class="photo-action-btn" onclick={openCitizenPhotoUpload} title="Upload photo" disabled={uploading}>
								{#if uploading}
									<div class="upload-spinner"></div>
									Uploading...
								{:else}
									<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
									Upload
								{/if}
							</button>
							<button class="photo-action-btn" onclick={triggerCitizenMugshot} title="Take mugshot">
								<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
								Take Mugshot
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
							<span class="dvalue clickable" onclick={() => copyToClipboard(selectedProfile?.phone || '', 'Phone')}>{selectedProfile.phone}</span>
						</div>
						<div class="detail-row">
							<span class="dlabel">Fingerprint</span>
							{#if editingFingerprint}
								<input
									class="dna-input"
									type="text"
									bind:value={fingerprintValue}
									onkeydown={(e) => { if (e.key === 'Enter') saveFingerprint(); if (e.key === 'Escape') { editingFingerprint = false; } }}
									onblur={saveFingerprint}
								/>
							{:else}
								<span class="dvalue clickable" onclick={() => startEditFingerprint()}>
									{selectedProfile.fingerprint || 'N/A'}
									<span class="material-icons edit-icon">edit</span>
								</span>
							{/if}
						</div>
						<div class="detail-row">
							<span class="dlabel">DNA</span>
							{#if editingDNA}
								<input
									class="dna-input"
									type="text"
									bind:value={dnaValue}
									onkeydown={(e) => { if (e.key === 'Enter') saveDNA(); if (e.key === 'Escape') { editingDNA = false; } }}
									onblur={saveDNA}
								/>
							{:else}
								<span class="dvalue clickable" onclick={() => startEditDNA()}>
									{selectedProfile.dna || 'N/A'}
									<span class="material-icons edit-icon">edit</span>
								</span>
							{/if}
						</div>
						<div class="detail-row"><span class="dlabel">Occupations</span><span class="dvalue">{formatOccupations(selectedProfile.occupations)}</span></div>
					</div>

				</div>

				<!-- Main content -->
				<div class="profile-main">
					{#if selectedProfile.notes}
						<div class="panel">
							<div class="panel-title">Notes</div>
							<div class="notes-text">{selectedProfile.notes}</div>
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
											<div class="sitem-info">
												<span class="sitem-primary">Report #{w.reportid}</span>
												<span class="sitem-secondary">Expires: {formatExpiryDate(w.expirydate)}</span>
											</div>
											<button class="sitem-arrow" title="View Report" onclick={() => goToWarrantReport(w.reportid)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
									{#if selectedProfile.activeWarrants.length > 3}
										<div class="sitem-overflow">+{selectedProfile.activeWarrants.length - 3} more warrants</div>
									{/if}
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
											<div class="sitem-info">
												<span class="sitem-primary">{b.type} BOLO</span>
												{#if b.notes}<span class="sitem-secondary">{b.notes}</span>{/if}
											</div>
											<button class="sitem-arrow" title="View BOLO" onclick={() => goToBolo(b.id)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
									{#if selectedProfile.activeBolos.length > 3}
										<div class="sitem-overflow">+{selectedProfile.activeBolos.length - 3} more BOLOs</div>
									{/if}
								{:else}<div class="empty-msg">No active BOLOs</div>{/if}
							</div>
						</div>

						<div class="panel">
							<div class="panel-title">Vehicles <span class="cnt">{selectedProfile.ownedVehicles?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.ownedVehicles && selectedProfile.ownedVehicles.length > 0}
									{#each sectionSlice(selectedProfile.ownedVehicles, vehiclesPage) as v}
										<div class="sitem">
											<div class="sitem-info">
												<span class="sitem-primary">{v.vehicle}</span>
												<span class="sitem-secondary">{v.plate}</span>
											</div>
											<button class="sitem-arrow" title="View Vehicle" onclick={() => openVehicleFromProfile(v.plate)}>
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
											</button>
										</div>
									{/each}
								{:else}<div class="empty-msg">No vehicles</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.ownedVehicles) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={vehiclesPage <= 1} onclick={() => vehiclesPage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{vehiclesPage} / {sectionTotalPages(selectedProfile.ownedVehicles)}</span>
									<button class="spager-btn" disabled={vehiclesPage >= sectionTotalPages(selectedProfile.ownedVehicles)} onclick={() => vehiclesPage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
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
											<div class="sitem-info">
												<span class="sitem-primary">{license.name}</span>
												<span class="sitem-secondary">{license.type === 'state' ? 'State License' : 'Custom License'}</span>
											</div>
											<span class="license-status license-active">Active</span>
										</div>
									{/each}
								{:else}<div class="empty-msg">No licenses</div>{/if}
							</div>
							{#if sectionTotalPages(activeLicenses) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={licensesPage <= 1} onclick={() => licensesPage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{licensesPage} / {sectionTotalPages(activeLicenses)}</span>
									<button class="spager-btn" disabled={licensesPage >= sectionTotalPages(activeLicenses)} onclick={() => licensesPage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
								</div>
							{/if}
						</div>

						<div class="panel">
							<div class="panel-title">Properties <span class="cnt">{selectedProfile.propertiesList?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.propertiesList && selectedProfile.propertiesList.length > 0}
									{#each sectionSlice(selectedProfile.propertiesList, propertiesPage) as p}
										<div class="sitem"><div class="sitem-info"><span class="sitem-primary">{p.house}</span></div></div>
									{/each}
								{:else}<div class="empty-msg">No properties</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.propertiesList) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={propertiesPage <= 1} onclick={() => propertiesPage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{propertiesPage} / {sectionTotalPages(selectedProfile.propertiesList)}</span>
									<button class="spager-btn" disabled={propertiesPage >= sectionTotalPages(selectedProfile.propertiesList)} onclick={() => propertiesPage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
								</div>
							{/if}
						</div>
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
											{#if w.scratched}<span class="badge badge-red">Scratched</span>{:else}<span class="badge badge-green">Intact</span>{/if}
										</div>
									{/each}
								{:else}<div class="empty-msg">No weapons</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.weapons) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={weaponsPage <= 1} onclick={() => weaponsPage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{weaponsPage} / {sectionTotalPages(selectedProfile.weapons)}</span>
									<button class="spager-btn" disabled={weaponsPage >= sectionTotalPages(selectedProfile.weapons)} onclick={() => weaponsPage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
								</div>
							{/if}
						</div>
						<div class="panel">
							<div class="panel-title">Evidence <span class="cnt">{selectedProfile.evidence?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.evidence && selectedProfile.evidence.length > 0}
									{#each sectionSlice(selectedProfile.evidence, evidencePage) as e}
										<div class="sitem">
											<div class="sitem-info">
												<span class="sitem-primary">{e.title}</span>
												<span class="sitem-secondary">{e.type}{#if e.notes} - {e.notes}{/if}</span>
											</div>
										</div>
									{/each}
								{:else}<div class="empty-msg">No evidence</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.evidence) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={evidencePage <= 1} onclick={() => evidencePage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{evidencePage} / {sectionTotalPages(selectedProfile.evidence)}</span>
									<button class="spager-btn" disabled={evidencePage >= sectionTotalPages(selectedProfile.evidence)} onclick={() => evidencePage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
								</div>
							{/if}
						</div>
						<div class="panel">
							<div class="panel-title">Linked Reports <span class="cnt">{selectedProfile.linkedReports?.length || 0}</span></div>
							<div class="section-list">
								{#if selectedProfile.linkedReports && selectedProfile.linkedReports.length > 0}
									{#each sectionSlice(selectedProfile.linkedReports, reportsPage) as r}
										<div class="sitem">
											<div class="sitem-info">
												<span class="sitem-primary">{r.title}</span>
												<span class="sitem-secondary">{r.type}</span>
											</div>
											{#if !isEMS}<button class="view-btn" onclick={() => goToWarrantReport(r.id)}>View</button>{/if}
										</div>
									{/each}
								{:else}<div class="empty-msg">No reports</div>{/if}
							</div>
							{#if sectionTotalPages(selectedProfile.linkedReports) > 1}
								<div class="section-pager">
									<button class="spager-btn" disabled={reportsPage <= 1} onclick={() => reportsPage--}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
									</button>
									<span class="spager-info">{reportsPage} / {sectionTotalPages(selectedProfile.linkedReports)}</span>
									<button class="spager-btn" disabled={reportsPage >= sectionTotalPages(selectedProfile.linkedReports)} onclick={() => reportsPage++}>
										<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
									</button>
								</div>
							{/if}
						</div>
					</div>
				</div>
			</div>
		</div>
		<!-- Vehicle Detail Modal -->
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
							{#if vehicleDetail.status}<div class="vd-row"><span class="vd-label">Status</span><span class="vd-value vd-status-{vehicleDetail.status}">{vehicleDetail.status}</span></div>{/if}
							{#if vehicleDetail.points !== undefined}<div class="vd-row"><span class="vd-label">Points</span><span class="vd-value" class:accent-red={vehicleDetail.points > 0}>{vehicleDetail.points}</span></div>{/if}
							{#if vehicleDetail.stolen}<div class="vd-row"><span class="vd-label">Stolen</span><span class="vd-value accent-red">Yes</span></div>{/if}
							{#if vehicleDetail.boloactive}<div class="vd-row"><span class="vd-label">BOLO</span><span class="vd-value" style="color: #fbbf24;">Active</span></div>{/if}
							{#if vehicleDetail.information}<div class="vd-row vd-notes"><span class="vd-label">Notes</span><span class="vd-value">{vehicleDetail.information}</span></div>{/if}
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
									<span class="license-modal-name">{license.name}</span>
									<span class="license-modal-type">{license.type === 'state' ? 'State' : 'Custom'}</span>
								</div>
								<label class="toggle"><input type="checkbox" checked={license.active} onchange={() => toggleIssuableLicense(license)} /><span class="toggle-track"></span></label>
							</div>
						{/each}
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
					<input bind:value={searchQuery} type="text" placeholder="Search by name, ID, or phone..." />
				</div>
			</div>

			{#if loading}
				<div class="center-msg"><div class="spinner"></div><span>Loading citizens...</span></div>
			{:else if citizens.length === 0}
				<div class="center-msg"><span>No citizen records available.</span></div>
			{:else}
				<div class="citizens-header">
					<span></span>
					<span>Name</span>
					<span>Citizen ID</span>
					<span>Phone</span>
					<span>Gender</span>
					<span>DOB</span>
					<span>Stats</span>
					<span>Flags</span>
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

<input type="file" accept="image/*" bind:this={citizenPhotoInput} onchange={handleCitizenPhotoUpload} style="display:none" />

<style>
	.page { height: 100%; display: flex; flex-direction: column; background: var(--card-dark-bg); overflow: hidden; }

	/* ===== LIST VIEW ===== */
	.list-view { display: flex; flex-direction: column; height: 100%; }
	.list-topbar { display: flex; align-items: center; gap: 16px; padding: 0 20px; height: 48px; flex-shrink: 0; border-bottom: 1px solid rgba(255,255,255,0.06); }
	.search-box { flex: 1; max-width: 400px; display: flex; align-items: center; gap: 8px; background: transparent; border: none; padding: 0; }
	.search-box input { flex: 1; background: none; border: none; color: rgba(255,255,255,0.85); font-size: 12px; outline: none; }
	.search-box input::placeholder { color: rgba(255,255,255,0.25); }

	.citizens-header { display: grid; grid-template-columns: 36px 1.5fr 1fr 1fr 0.6fr 0.8fr 1.2fr 1.5fr; gap: 12px; padding: 8px 20px; border-bottom: 1px solid rgba(255,255,255,0.06); color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; flex-shrink: 0; }
	.citizens-table { flex: 1; overflow-y: auto; padding: 2px 10px; display: flex; flex-direction: column; gap: 0; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.08) transparent; min-height: 0; }
	.citizens-table::-webkit-scrollbar { width: 3px; }
	.citizens-table::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 2px; }

	.citizen-row { display: grid; grid-template-columns: 36px 1.5fr 1fr 1fr 0.6fr 0.8fr 1.2fr 1.5fr; align-items: center; gap: 12px; padding: 8px 10px; background: transparent; border: none; border-radius: 4px; cursor: pointer; transition: background 0.1s; text-align: left; font: inherit; color: inherit; width: 100%; }
	.citizen-row:hover { background: rgba(255,255,255,0.03); }

	.citizen-avatar { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0; }
	.citizen-avatar img { width: 100%; height: 100%; object-fit: cover; }

	.citizen-name { color: rgba(255,255,255,0.85); font-size: 12px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.citizen-meta { color: rgba(255,255,255,0.3); font-size: 11px; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.citizen-nums { display: flex; gap: 8px; font-size: 10px; color: rgba(255,255,255,0.35); }
	.citizen-flags-cell { display: flex; gap: 4px; flex-wrap: nowrap; align-items: center; overflow: hidden; }

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

	/* Panel caution inline */
	.panel-caution { font-size: 9px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 3px 8px; border-radius: 3px; margin-bottom: 8px; }
	.caution-danger { background: rgba(239,68,68,0.08); color: #f87171; }
	.caution-warning { background: rgba(245,158,11,0.08); color: #fbbf24; }

	/* Danger/warning panel variants */
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

	/* Stats strip - inline like dashboard */
	.pstats-row { display: flex; align-items: center; padding: 0 20px; height: 44px; flex-shrink: 0; border-bottom: 1px solid rgba(255,255,255,0.06); gap: 0; }
	.pstat { display: flex; align-items: center; gap: 8px; padding: 0 18px; border-right: 1px solid rgba(255,255,255,0.06); }
	.pstat:last-child { border-right: none; }
	.pstat-val { color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 700; line-height: 1; }
	.pstat-lbl { color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.5px; }

	/* Body */
	.profile-body { display: grid; grid-template-columns: 240px 1fr; flex: 1; min-height: 0; overflow: hidden; }

	.profile-sidebar { display: flex; flex-direction: column; border-right: 1px solid rgba(255,255,255,0.06); overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent; }
	.profile-sidebar::-webkit-scrollbar { width: 3px; }
	.profile-sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.06); border-radius: 2px; }

	.panel { padding: 14px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); background: transparent; border-radius: 0; border: none; border-bottom: 1px solid rgba(255,255,255,0.06); }
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
	.dvalue.clickable:hover .edit-icon { opacity: 0.5; }
	.dna-input {
		background: rgba(255,255,255,0.06);
		border: 1px solid rgba(96,165,250,0.3);
		border-radius: 3px;
		color: rgba(255,255,255,0.9);
		font-size: 12px;
		padding: 2px 6px;
		outline: none;
		width: 120px;
	}
	.dna-input:focus { border-color: rgba(96,165,250,0.6); }

	.license-row { display: flex; justify-content: space-between; align-items: center; padding: 5px 0; font-size: 12px; color: rgba(255,255,255,0.6); }
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

	/* Sections grid panels - use borders, no gaps */
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

	.badge { padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 600; flex-shrink: 0; border: 1px solid transparent; }
	.badge-green { background: rgba(16,185,129,0.12); color: #34d399; border-color: rgba(16,185,129,0.15); }
	.badge-red { background: rgba(239,68,68,0.12); color: #f87171; border-color: rgba(239,68,68,0.15); }

	.view-btn { background: transparent; color: rgba(255,255,255,0.3); border: none; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 500; cursor: pointer; transition: all 0.12s; flex-shrink: 0; }
	.view-btn:hover { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.04); }

	.empty-msg { color: rgba(255,255,255,0.15); font-size: 11px; text-align: center; padding: 14px 0; }

	/* ── Section mini-pager ── */
	.section-pager { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 6px 0 0; margin-top: 2px; }
	.spager-btn { background: transparent; border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 2px 4px; color: rgba(255,255,255,0.3); cursor: pointer; display: flex; align-items: center; transition: all 0.12s ease; }
	.spager-btn:hover:not(:disabled) { background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.7); }
	.spager-btn:disabled { opacity: 0.2; cursor: not-allowed; }
	.spager-info { font-size: 10px; color: rgba(255,255,255,0.2); min-width: 28px; text-align: center; }

	.profile-photo-actions { display: flex; gap: 6px; justify-content: center; margin-top: 8px; }
	.photo-action-btn { display: flex; align-items: center; gap: 4px; background: transparent; border: 1px solid rgba(255,255,255,0.06); color: rgba(255,255,255,0.4); padding: 4px 8px; border-radius: 4px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.12s; }
	.photo-action-btn:hover:not(:disabled) { color: rgba(255,255,255,0.7); border-color: rgba(255,255,255,0.12); background: rgba(255,255,255,0.03); }
	.photo-action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.upload-spinner { width: 10px; height: 10px; border: 2px solid rgba(255,255,255,0.15); border-left-color: var(--accent-60); border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

	/* Vehicle detail modal */
	.modal-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.6); display: flex; align-items: center; justify-content: center; z-index: 100; backdrop-filter: blur(2px); }
	.modal-card { background: var(--dark-bg); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; width: 360px; max-height: 80%; overflow-y: auto; }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); }
	.modal-header h3 { margin: 0; font-size: 13px; font-weight: 600; color: rgba(255,255,255,0.85); }
	.modal-close { background: none; border: none; color: rgba(255,255,255,0.3); cursor: pointer; padding: 4px; border-radius: 4px; display: flex; }
	.modal-close:hover { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.04); }
	.modal-body { padding: 0; }
	.vd-row { display: flex; justify-content: space-between; align-items: center; padding: 9px 16px; border-bottom: 1px solid rgba(255,255,255,0.04); }
	.vd-row:last-child { border-bottom: none; }
	.vd-label { color: rgba(255,255,255,0.3); font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
	.vd-value { color: rgba(255,255,255,0.75); font-size: 12px; font-weight: 500; }
	.vd-value.mono { font-family: monospace; letter-spacing: 0.5px; }
	.vd-notes { flex-direction: column; align-items: flex-start; gap: 4px; }
	.vd-notes .vd-value { font-weight: 400; line-height: 1.4; }
	.vd-status-stolen { color: #f87171 !important; }
	.vd-status-impounded { color: #fb923c !important; }
	.vd-status-bolo { color: #fbbf24 !important; }
	.vd-status-valid { color: #34d399 !important; }

	/* Issue License button */
	.issue-license-btn { display: flex; align-items: center; gap: 3px; margin-left: auto; background: rgba(59,130,246,0.06); border: 1px solid rgba(59,130,246,0.1); border-radius: 3px; padding: 2px 8px; color: rgba(147,197,253,0.7); font-size: 9px; font-weight: 600; cursor: pointer; transition: all 0.12s; text-transform: none; letter-spacing: 0; }
	.issue-license-btn:hover { background: rgba(59,130,246,0.12); color: rgba(147,197,253,0.9); }

	/* License modal */
	.license-modal-body { padding: 4px 0; }
	.license-modal-row { display: flex; align-items: center; justify-content: space-between; padding: 8px 16px; border-bottom: 1px solid rgba(255,255,255,0.03); }
	.license-modal-row:last-child { border-bottom: none; }
	.license-modal-info { display: flex; align-items: center; gap: 8px; }
	.license-modal-name { font-size: 12px; color: rgba(255,255,255,0.75); font-weight: 500; }
	.license-modal-type { font-size: 8px; font-weight: 700; letter-spacing: 0.5px; padding: 1px 5px; border-radius: 3px; text-transform: uppercase; background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.25); }
</style>
