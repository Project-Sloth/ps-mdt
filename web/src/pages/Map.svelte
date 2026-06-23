<script lang="ts">
    // Inline hover tooltip rendered into <body>, same pattern already used in
    // Roster.svelte / TagsManager.svelte — avoids CEF clipping issues when the
    // tooltip's parent scrolls/overflows (e.g. the officer list panel).
    function tip(node: HTMLElement, text: string | undefined) {
        let el: HTMLDivElement | null = null;
        let cur = text;
        function place(e: MouseEvent) {
            if (!el) return;
            const t = el.getBoundingClientRect();
            let x = e.clientX + 14;
            let y = e.clientY + 16;
            if (x + t.width > window.innerWidth - 4) x = e.clientX - t.width - 14;
            if (y + t.height > window.innerHeight - 4) y = e.clientY - t.height - 16;
            el.style.left = `${Math.max(4, x)}px`;
            el.style.top = `${Math.max(4, y)}px`;
        }
        function show(e: MouseEvent) {
            if (!cur || el) return;
            el = document.createElement("div");
            el.textContent = cur;
            el.style.cssText = "position:fixed;z-index:99999;background:#111113;color:rgba(255,255,255,0.92);padding:6px 9px;border-radius:5px;font-size:11px;font-weight:500;line-height:1.4;max-width:240px;white-space:normal;word-break:break-word;border:1px solid rgba(255,255,255,0.12);box-shadow:0 8px 24px rgba(0,0,0,0.6);pointer-events:none;";
            document.body.appendChild(el);
            place(e);
        }
        function move(e: MouseEvent) { if (el) place(e); }
        function hide() { if (el) { el.remove(); el = null; } }
        node.addEventListener("mouseenter", show);
        node.addEventListener("mousemove", move);
        node.addEventListener("mouseleave", hide);
        return {
            update(v: string | undefined) { cur = v; if (el && !v) hide(); },
            destroy() { hide(); node.removeEventListener("mouseenter", show); node.removeEventListener("mousemove", move); node.removeEventListener("mouseleave", hide); },
        };
    }

    import { onMount, onDestroy } from "svelte";
    import L, { CRS, Projection, LatLngBounds, Transformation, Map } from "leaflet";
    import "leaflet/dist/leaflet.css";
    import { fetchNui } from "../utils/fetchNui";
    import { isEnvBrowser } from "../utils/misc";
    import { NUI_EVENTS } from "../constants/nuiEvents";
    import { globalNotifications } from "../services/notificationService.svelte";
    import type { AuthService } from "../services/authService.svelte";

    interface Props {
        authService?: AuthService;
    }
    let { authService }: Props = $props();

    let canViewPatrols   = $derived(authService ? (authService.hasPermission("map_patrols_view")   ?? true) : true);
    let canManagePatrols = $derived(authService ? (authService.hasPermission("map_patrols_manage") ?? true) : true);
    let canEditPatrols   = $derived(authService ? (authService.hasPermission("map_patrols_edit")   ?? true) : true);
    // EMS see their own units/zones; the live-position layer isn't bodycam-based for them.
    let isEms            = $derived(authService?.jobType === "ems");

    let mapContainer: HTMLDivElement | null = null;
    let map: L.Map | null = null;
    let mapInitialized = false;
    let refreshTimer: ReturnType<typeof setInterval> | null = null;

    let tabVisible = $state(true);
    let showVehicles = $state(localStorage.getItem("mdt_map_vehicles") !== "false");
    let showBodycams = $state(localStorage.getItem("mdt_map_bodycams") !== "false");
    let showPatrols  = $state(localStorage.getItem("mdt_map_patrols_layer") !== "false");
    let showZones    = $state(localStorage.getItem("mdt_map_zones") !== "false");
    let iconStyle = $state<"dot" | "badge">(
        (localStorage.getItem("mdt_map_icon_style") as "dot" | "badge") ?? "dot"
    );

    let vehicleLayer = L.layerGroup();
    let bodycamLayer = L.layerGroup();
    let patrolLayer  = L.layerGroup();
    let zoneLayer    = L.layerGroup();

    let sidebarOpen  = $state(localStorage.getItem("mdt_map_sidebar")   !== "false");
    let officersOpen = $state(localStorage.getItem("mdt_map_officers")  !== "false");
    let patrolsOpen  = $state(localStorage.getItem("mdt_map_patrols")   !== "false");

    function toggleSidebar() {
        sidebarOpen = !sidebarOpen;
        localStorage.setItem("mdt_map_sidebar", String(sidebarOpen));
        fetchNui(NUI_EVENTS.MAP.SAVE_UI_STATE, { key: "sidebarOpen", value: sidebarOpen }, {}).catch(() => {});
    }
    function toggleOfficers() {
        officersOpen = !officersOpen;
        localStorage.setItem("mdt_map_officers", String(officersOpen));
        fetchNui(NUI_EVENTS.MAP.SAVE_UI_STATE, { key: "officersOpen", value: officersOpen }, {}).catch(() => {});
    }
    function togglePatrols() {
        patrolsOpen = !patrolsOpen;
        localStorage.setItem("mdt_map_patrols", String(patrolsOpen));
        fetchNui(NUI_EVENTS.MAP.SAVE_UI_STATE, { key: "patrolsOpen", value: patrolsOpen }, {}).catch(() => {});
    }

    let sidebarWidth = $derived(
        (officersOpen ? 260 : 36) + 1 + (patrolsOpen ? 260 : 36)
    );

    type GtaPoint = { x: number; y: number };

    type Bodycam = {
        citizenid: string;
        name: string;
        callsign?: string;
        rank?: string;
        coords: { x: number; y: number; z: number };
        heading?: number;
        inVehicle?: boolean;
        // Officer Status extension — populated server-side in tracking.lua by
        // folding GetOfficerStatusSnapshot() into each bodycam entry, and kept
        // current in real time via the syncOfficerStatus NUI message handled
        // below (no need to wait for the next 4.5s tracking poll).
        status?: string;
        statusNote?: string;
        statusUpdatedAt?: number; // ms epoch
    };

    type Patrol = {
        id: string;
        name: string;
        color: string;
        memberIds: string[];
        zonePoints?: GtaPoint[] | null;
    };

    let officers        = $state<Bodycam[]>([]);
    let patrols         = $state<Patrol[]>([]);
    let officerSearch   = $state("");

    // ─── Officer Status ────────────────────────────────────────────────────
    // Status definitions (id/label/color) come from the server so the UI never
    // hardcodes them — Config.OfficerStatus.list is the single source of truth
    // and can grow without touching this file. `Default` is what an officer
    // who never set a status is treated as.
    type StatusDef = { id: string; label: string; color: string; icon?: string };
    let statusDefs    = $state<StatusDef[]>([
        { id: "active", label: "Active", color: "#22C55E", icon: "●" },
        { id: "busy",   label: "Busy",   color: "#F59E0B", icon: "●" },
    ]);
    let defaultStatusId = $state("active");
    let statusById = $derived(new globalThis.Map(statusDefs.map(s => [s.id, s] as [string, StatusDef])));

    function statusDef(id?: string): StatusDef {
        const resolved = id ?? defaultStatusId;
        return statusById.get(resolved) ?? { id: resolved, label: resolved, color: "#6b7280" };
    }

    // Hex → rgba pill style, identical approach to Citizens.svelte's
    // tagPillStyle (CEF-safe: no color-mix(), just plain rgba()).
    function statusPillStyle(hex: string): string {
        const c = /^#[0-9a-fA-F]{6}$/.test(hex || "") ? hex : "#6b7280";
        const r = parseInt(c.slice(1, 3), 16);
        const g = parseInt(c.slice(3, 5), 16);
        const b = parseInt(c.slice(5, 7), 16);
        return `color:${c};border-color:rgba(${r},${g},${b},0.35);background:rgba(${r},${g},${b},0.15);`;
    }
    function statusChipStyle(hex: string): string {
        const c = /^#[0-9a-fA-F]{6}$/.test(hex || "") ? hex : "#6b7280";
        const r = parseInt(c.slice(1, 3), 16);
        const g = parseInt(c.slice(3, 5), 16);
        const b = parseInt(c.slice(5, 7), 16);
        return `--chip-color:${c};--chip-border:rgba(${r},${g},${b},0.45);--chip-bg:rgba(${r},${g},${b},0.18);`;
    }

    // The local player's own current status — drives the picker in the panel
    // header. Resolved from the officers list once it includes ownCitizenId.
    // Initialized with a plain literal (not defaultStatusId) to avoid a
    // state-reads-its-own-scope warning; loadStatusConfig()/refreshTracking()
    // overwrite it with the real value almost immediately after mount anyway.
    let myStatusId   = $state<string>("active");
    let myStatusNote = $state<string>("");
    let statusPickerOpen = $state(false);
    let statusNoteDraft  = $state("");
    let statusChangePending = $state(false);

    // Status filter for the officer list: empty set = show all.
    let statusFilter = $state<Set<string>>(new Set());

    function toggleStatusFilter(id: string) {
        const next = new Set(statusFilter);
        if (next.has(id)) next.delete(id); else next.add(id);
        statusFilter = next;
    }

    // "since" label, recomputed lazily where displayed (cheap string math).
    function timeSince(ts?: number): string {
        if (!ts) return "";
        const diffSec = Math.max(0, Math.floor((Date.now() - ts) / 1000));
        if (diffSec < 60) return "just now";
        const m = Math.floor(diffSec / 60);
        if (m < 60) return `${m}m ago`;
        const h = Math.floor(m / 60);
        if (h < 24) return `${h}h ago`;
        const d = Math.floor(h / 24);
        return `${d}d ago`;
    }

    async function loadStatusConfig() {
        if (isEnvBrowser()) return;
        try {
            const res = await fetchNui(
                NUI_EVENTS.MAP.GET_OFFICER_STATUS_CONFIG,
                {},
                { statuses: statusDefs, default: defaultStatusId },
            );
            const statuses = (res as any).statuses;
            if (Array.isArray(statuses) && statuses.length > 0) statusDefs = statuses;
            if (typeof (res as any).default === "string") defaultStatusId = (res as any).default;
        } catch { /* keep the built-in fallback defs above */ }
    }

    async function setMyStatus(id: string, note?: string) {
        if (statusChangePending) return;
        statusChangePending = true;
        try {
            await fetchNui(NUI_EVENTS.MAP.SET_OFFICER_STATUS, { status: id, note }, { success: true });
            // Optimistic local update — the server's syncOfficerStatus broadcast
            // (which includes our own change) will confirm this shortly after.
            myStatusId   = id;
            myStatusNote = note ?? "";
            if (ownCitizenId) applyStatusUpdate({ citizenid: ownCitizenId, status: id, note, updatedAt: Date.now() });
            statusPickerOpen = false;
        } catch {
            globalNotifications.error("Failed to update status.");
        } finally {
            // Small cooldown mirrors the server's anti-spam window so the
            // button can't be hammered while the request is in flight.
            setTimeout(() => { statusChangePending = false; }, 600);
        }
    }

    // Patches one officer's status in-place (used by both the optimistic local
    // update above and the real-time broadcast handler below) and restyles
    // their map marker immediately — no need to wait for the next poll. Also
    // refreshes patrol labels, since a member's status change can flip the
    // derived patrol-level status shown on the map (see getPatrolStatus).
    function applyStatusUpdate(payload: { citizenid: string; status: string; note?: string; updatedAt: number }) {
        officers = officers.map(o =>
            o.citizenid === payload.citizenid
                ? { ...o, status: payload.status, statusNote: payload.note, statusUpdatedAt: payload.updatedAt }
                : o
        );
        if (payload.citizenid === ownCitizenId) {
            myStatusId   = payload.status;
            myStatusNote = payload.note ?? "";
        }
        restyleOfficerMarker(payload.citizenid);
        refreshPatrolLabels();
    }

    // Search-filtered officer lists (recomputed when officers/patrols/search change)
    let unassignedFiltered   = $derived(filterOfficers(unassignedOfficers()));
    let totalVisibleOfficers = $derived(filterOfficers(officers).length);

    // One-time centering flag — pan to own position on first data load
    let centeredOnSelf = false;
    // Own citizenId sent from Lua on open
    let ownCitizenId: string | null = null;

    // Officer highlight state
    let selectedOfficerId = $state<string | null>(null);
    let highlightMarker: L.Marker | null = null;
    let highlightPopup:  L.Popup  | null = null;

    function selectOfficer(citizenid: string) {
        // Toggle off if already selected
        if (selectedOfficerId === citizenid) {
            clearOfficerHighlight();
            return;
        }
        selectedOfficerId = citizenid;
        highlightOfficerOnMap(citizenid);
    }

    function clearOfficerHighlight() {
        selectedOfficerId = null;
        highlightMarker?.remove(); highlightMarker = null;
        highlightPopup?.remove();  highlightPopup  = null;
    }

    // Build the full popup HTML for an officer
    function buildOfficerPopupHtml(officer: Bodycam): string {
        const patrol   = getOfficerPatrol(officer.citizenid);
        const color    = patrol?.color ?? "#38bdf8";

        // Heading → compass direction label
        const headingLabel = (h: number) => {
            const dirs = ["N","NE","E","SE","S","SW","W","NW","N"];
            return dirs[Math.round(((360 - h) % 360) / 45)];
        };
        const heading  = officer.heading != null
            ? `<span class="op-heading">
                   <svg width="10" height="10" viewBox="0 0 12 12" style="transform:rotate(${360 - officer.heading}deg);display:inline-block">
                       <polygon points="6,1 9,11 6,8 3,11" fill="currentColor"/>
                   </svg>
                   ${headingLabel(officer.heading)}
               </span>`
            : "";

        // Use server-provided flag — no coordinate guessing, no flicker
        const inVehicle = officer.inVehicle ?? false;
        const vehicleBadge = inVehicle
            ? `<span class="op-badge op-badge--vehicle">🚔 In Vehicle</span>`
            : `<span class="op-badge op-badge--foot">🦶 On Foot</span>`;

        const patrolHtml = patrol
            ? `<span class="op-patrol" style="color:${patrol.color}">● ${patrol.name}</span>`
            : `<span class="op-patrol op-patrol--none">● Unassigned</span>`;

        // Officer Status (Active/Busy/...) — separate from the existing
        // "Status" row above (which shows In Vehicle/On Foot), so it's
        // labelled "Availability" to avoid any ambiguity.
        const sDef = statusDef(officer.status);
        const sNote = officer.statusNote?.trim();
        const sSince = timeSince(officer.statusUpdatedAt);
        const availabilityHtml = `
            <span class="op-availability" style="color:${sDef.color}">● ${sNote || sDef.label}</span>
            ${sSince ? `<span class="op-availability-since">${sSince}</span>` : ""}
        `;

        return `
            <div class="op-wrap">
                <div class="op-header" style="--op-color:${color}">
                    <div class="op-name">${officer.name}</div>
                    ${officer.callsign ? `<div class="op-callsign-badge">${officer.callsign}</div>` : ""}
                </div>
                <div class="op-body">
                    ${officer.rank ? `<div class="op-row"><span class="op-label">Rank</span><span class="op-value">${officer.rank}</span></div>` : ""}
                    <div class="op-row"><span class="op-label">Availability</span>${availabilityHtml}</div>
                    <div class="op-row"><span class="op-label">Patrol</span>${patrolHtml}</div>
                    <div class="op-row"><span class="op-label">Status</span>${vehicleBadge}</div>
                    <div class="op-row op-row--coords">
                        <span class="op-label">Heading</span>
                        ${heading}
                    </div>
                </div>
            </div>
        `;
    }

    // Build the popup HTML for a vehicle marker. Live (non-cached) vehicles get
    // a "View Dashcam" button; parked/last-known ones don't (no live feed).
    function buildVehiclePopupHtml(vehicle: any, plate: string, cached: boolean): string {
        const coords = normalizeCoords(vehicle.coords) ?? { x: 0, y: 0 };
        const headingLabel = (h: number) => {
            const dirs = ["N","NE","E","SE","S","SW","W","NW","N"];
            return dirs[Math.round(((360 - h) % 360) / 45)];
        };
        const heading = vehicle.heading != null
            ? `<span class="op-heading">
                   <svg width="10" height="10" viewBox="0 0 12 12" style="transform:rotate(${360 - vehicle.heading}deg);display:inline-block">
                       <polygon points="6,1 9,11 6,8 3,11" fill="currentColor"/>
                   </svg>
                   ${headingLabel(vehicle.heading)}
               </span>`
            : "";

        const status = cached
            ? `<span class="op-badge op-badge--foot">🅿️ Parked</span>`
            : `<span class="op-badge op-badge--vehicle">🚔 Active</span>`;

        const action = (!cached && plate)
            ? `<button class="veh-dashcam-btn" data-plate="${plate}">
                   <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17 10.5V7a1 1 0 0 0-1-1H4a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-3.5l4 4v-11l-4 4z"/></svg>
                   View Dashcam
               </button>`
            : `<div class="veh-note">No live dashcam (last known position)</div>`;

        return `
            <div class="op-wrap veh-wrap">
                <div class="op-header" style="--op-color:#f97316">
                    <div class="op-name">${plate || "Unknown Vehicle"}</div>
                    <div class="op-callsign-badge">VEH</div>
                </div>
                <div class="op-body">
                    <div class="op-row"><span class="op-label">Status</span>${status}</div>
                    <div class="op-row op-row--coords">
                        <span class="op-label">Heading</span>
                        ${heading}
                    </div>
                    <div class="veh-actions">${action}</div>
                </div>
            </div>
        `;
    }

    // Open the dashcam for a vehicle by plate (dashcam ids are the plate). The
    // server validates permission / configured model and returns an error we
    // surface as a toast.
    async function viewVehicleDashcam(plate: string) {
        if (!plate) return;
        try {
            const res: any = await fetchNui(NUI_EVENTS.CAMERA.VIEW_CAMERA, plate);
            if (res && res.success === false) {
                globalNotifications.error(res.message || "No dashcam available for this vehicle");
            }
        } catch {
            globalNotifications.error("No dashcam available for this vehicle");
        }
    }

    // Leaflet stops click propagation inside popups, so wire the button up via
    // the popup's DOM once it's open (and after any content refresh).
    function attachDashcamHandler(marker: L.Marker, plate: string) {
        const el = marker.getPopup()?.getElement();
        const btn = el?.querySelector(".veh-dashcam-btn") as HTMLButtonElement | null;
        if (btn) {
            btn.onclick = (ev) => {
                ev.preventDefault();
                ev.stopPropagation();
                viewVehicleDashcam(plate);
                marker.closePopup();
            };
        }
    }

    function highlightOfficerOnMap(citizenid: string) {
        if (!map) return;
        const officer = officers.find(o => o.citizenid === citizenid);
        if (!officer) return;

        const patrol  = getOfficerPatrol(citizenid);
        const color   = patrol?.color ?? "#38bdf8";
        const latlng  = toMapLatLng(officer.coords) as L.LatLng;

        if (highlightMarker) {
            // Reposition existing marker
            highlightMarker.setLatLng(latlng);
        } else {
            // First time: create marker
            highlightMarker = L.marker(latlng, {
                icon: L.divIcon({
                    className: "",
                    html: `<div class="officer-highlight-ring" style="--ring-color:${color}"></div>`,
                    iconSize:   [40, 40],
                    iconAnchor: [20, 20],
                }),
                zIndexOffset: 500,
                interactive: false,
            }).addTo(map);

            // Create popup
            highlightPopup = L.popup({
                closeButton:  true,
                autoClose:    false,
                closeOnClick: false,
                className:    "officer-popup",
                offset:       [0, -8],
            })
            .setLatLng(latlng)
            .setContent(buildOfficerPopupHtml(officer))
            .addTo(map);

            highlightPopup.on("remove", () => { clearOfficerHighlight(); });

            // Pan only on first selection
            map.panTo(latlng, { animate: true, duration: 0.5 });
        }

        // Always update popup: position + full content (so all live data refreshes)
        if (highlightPopup) {
            highlightPopup.setLatLng(latlng);
            highlightPopup.setContent(buildOfficerPopupHtml(officer));
        }
    }

    let newPatrolName  = $state("");
    let newPatrolColor = $state("#38bdf8");
    let showCreateForm = $state(false);

    let editingPatrolId   = $state<string | null>(null);
    let editingPatrolName = $state("");

    const PATROL_COLORS = [
        "#38bdf8", "#f97316", "#a855f7", "#22c55e",
        "#ef4444", "#eab308", "#ec4899", "#14b8a6"
    ];

    // ── Zone drawing state ────────────────────────────────────────────────────
    let drawingPatrolId = $state<string | null>(null);
    let drawPoints      = $state<L.LatLng[]>([]);
    let drawPolyline:  L.Polyline    | null = null;
    let drawPolygon:   L.Polygon     | null = null;
    let drawMarkers:   L.CircleMarker[]     = [];
    // cursorMarker removed – using DOM dot instead (see createCursorDot)
    const zonePolygons = new globalThis.Map<string, { poly: L.Polygon; label: L.Marker }>();

    // Marker pools for recycling — keyed by citizenid / plate so existing markers
    // are moved (setLatLng/setIcon) instead of cleared and rebuilt every refresh.
    const bodycamMarkers = new globalThis.Map<string, L.Marker>();
    const vehicleMarkers = new globalThis.Map<string, L.Marker>();

    const offsetX = 40;
    const offsetY = 31;

    function toMapLatLng(coords: { x: number; y: number }) {
        return [coords.y - offsetY, coords.x + offsetX];
    }
    function toGtaCoords(latlng: L.LatLng): GtaPoint {
        return { x: latlng.lng - offsetX, y: latlng.lat + offsetY };
    }

    // ── Zone rendering ────────────────────────────────────────────────────────
    function renderAllZones() {
        if (!map) return;
        for (const { poly, label } of zonePolygons.values()) { poly.remove(); label.remove(); }
        zonePolygons.clear();
        zoneLayer.clearLayers();
        if (!showZones) return;
        for (const patrol of patrols) {
            if (patrol.zonePoints && patrol.zonePoints.length >= 3) renderZone(patrol);
        }
    }

    function renderZone(patrol: Patrol) {
        if (!map || !patrol.zonePoints || patrol.zonePoints.length < 3) return;
        const latlngs = patrol.zonePoints.map(pt => toMapLatLng(pt) as L.LatLng);
        const poly = L.polygon(latlngs, {
            color: patrol.color, weight: 2, opacity: 0.85,
            fillColor: patrol.color, fillOpacity: 0.12,
            dashArray: "6 4", className: "patrol-zone-poly",
        }).addTo(zoneLayer);
        const center = poly.getBounds().getCenter();
        const label = L.marker(center, {
            icon: L.divIcon({
                className: "",
                html: `<div class="zone-label" style="color:${patrol.color};border-color:${patrol.color}">${patrol.name}</div>`,
                iconSize: [null as any, null as any], iconAnchor: [0, 0],
            }),
            interactive: false, zIndexOffset: -200,
        }).addTo(zoneLayer);
        zonePolygons.set(patrol.id, { poly, label });
    }

    function removeZoneById(id: string) {
        const e = zonePolygons.get(id);
        if (e) { e.poly.remove(); e.label.remove(); zonePolygons.delete(id); }
    }

    function refreshZoneForPatrol(patrol: Patrol) {
        removeZoneById(patrol.id);
        if (showZones && patrol.zonePoints && patrol.zonePoints.length >= 3) renderZone(patrol);
    }

    // ── Zone drawing ──────────────────────────────────────────────────────────
    function getDrawColor() {
        return patrols.find(p => p.id === drawingPatrolId)?.color ?? "#38bdf8";
    }

    // ── DOM cursor dot (bypasses CSS zoom coordinate issues) ─────────────────
    let cursorDotEl: HTMLDivElement | null = null;

    function createCursorDot() {
        removeCursorDot();
        cursorDotEl = document.createElement("div");
        cursorDotEl.className = "draw-cursor-dot";
        cursorDotEl.style.setProperty("--dot-color", getDrawColor());
        document.body.appendChild(cursorDotEl);
    }

    function moveCursorDot(clientX: number, clientY: number) {
        if (!cursorDotEl) return;
        cursorDotEl.style.left = `${clientX}px`;
        cursorDotEl.style.top  = `${clientY}px`;
    }

    function removeCursorDot() {
        cursorDotEl?.remove();
        cursorDotEl = null;
    }

    function startDrawing(patrolId: string) {
        if (!map || !canEditPatrols) return;
        stopDrawing(false);
        drawingPatrolId = patrolId;
        drawPoints = [];
        // Hide native cursor, use our DOM dot instead (immune to CSS zoom offset)
        mapContainer?.classList.add("map-cursor-none");
        createCursorDot();
        map.on("mousemove", onDrawMouseMove);
        map.on("click", onDrawClick);
        globalNotifications.info("Click to place points • Enter to finish • Backspace to undo • Esc to cancel");
    }

    // The MDT is commonly scaled by CSS `zoom` (and sometimes `transform: scale()`)
    // on a parent for resolution-independent UI. We must undo that scale to map a
    // mouse position into Leaflet's own container-pixel space, otherwise placed
    // points drift by a constant on-screen offset. We read the declared zoom /
    // transform off the ancestor chain — that's reliable across Chromium versions,
    // unlike deriving it from offsetWidth (which itself becomes scaled under `zoom`).
    function getAncestorScale(): number {
        let el: HTMLElement | null = mapContainer;
        let s = 1;
        while (el) {
            const cs = getComputedStyle(el);
            const zoomStr = (cs as any).zoom as string | undefined;
            if (zoomStr && zoomStr !== "" && zoomStr !== "normal") {
                const zv = parseFloat(zoomStr);
                if (!isNaN(zv) && zv !== 1) s *= zv;
            }
            const t = cs.transform;
            if (t && t !== "none") {
                try {
                    const m = new DOMMatrixReadOnly(t);
                    if (m.a && !isNaN(m.a) && m.a !== 1) s *= m.a; // horizontal scale
                } catch { /* unparseable transform — ignore */ }
            }
            el = el.parentElement;
        }
        return s;
    }

    function mouseEventToLatLng(e: L.LeafletMouseEvent): L.LatLng {
        if (!map || !mapContainer) return e.latlng;
        const oe    = e.originalEvent as MouseEvent;
        const rect  = mapContainer.getBoundingClientRect();
        const scale = getAncestorScale();

        // Residual constant correction (in container px) for a getBoundingClientRect
        // quirk under CSS `zoom`: the measured rect origin is off by a fixed amount
        // for this layout. NOTE: these are NOT the GTA<->map offsetX/offsetY above —
        // they're a pixel fudge tied to the MDT's current zoom factor and the map's
        // placement in the layout. Re-tune if either of those changes.
        const clickFudgeX = 40;
        const clickFudgeY = 30;

        // rect + clientX/Y are on-screen (scaled) px; Leaflet's container point is
        // in unscaled layout px, so undo the scale on the offset from the edge.
        const x = ((oe.clientX - rect.left) / scale) - clickFudgeX;
        const y = ((oe.clientY - rect.top)  / scale) - clickFudgeY;
        return map.containerPointToLatLng(L.point(x, y));
    }

    function onDrawMouseMove(e: L.LeafletMouseEvent) {
        if (!map) return;
        const latlng = mouseEventToLatLng(e);
        // Position cursor dot directly using native mouse coords — no zoom distortion
        const oe = e.originalEvent as MouseEvent;
        moveCursorDot(oe.clientX, oe.clientY);
        if (drawPoints.length > 0) {
            const pts = [...drawPoints, latlng];
            if (!drawPolyline) {
                drawPolyline = L.polyline(pts, { color: getDrawColor(), weight: 2, opacity: 0.7, dashArray: "5 4", interactive: false }).addTo(map);
            } else { drawPolyline.setLatLngs(pts); }
            if (drawPoints.length >= 2) {
                const closed = [...drawPoints, latlng, drawPoints[0]];
                if (!drawPolygon) {
                    drawPolygon = L.polygon(closed, { color: getDrawColor(), weight: 1.5, opacity: 0.5, fillColor: getDrawColor(), fillOpacity: 0.08, interactive: false, dashArray: "5 4" }).addTo(map);
                } else { drawPolygon.setLatLngs(closed); }
            }
        }
    }

    function onDrawClick(e: L.LeafletMouseEvent) {
        if (!map) return;
        const latlng = mouseEventToLatLng(e);
        if (drawPoints.length >= 3) {
            const fp = map.latLngToContainerPoint(drawPoints[0]);
            const np = map.latLngToContainerPoint(latlng);
            if (Math.hypot(fp.x - np.x, fp.y - np.y) < 14) { finishDrawing(); return; }
        }
        drawPoints = [...drawPoints, latlng];
        drawMarkers.push(L.circleMarker(latlng, { radius: 4, color: getDrawColor(), fillColor: "#fff", fillOpacity: 1, weight: 2, interactive: false }).addTo(map));
    }

    async function finishDrawing() {
        if (drawPoints.length < 3) { globalNotifications.error("Need at least 3 points."); return; }
        const id = drawingPatrolId;
        if (!id) return;
        const gtaPoints = drawPoints.map(toGtaCoords);
        stopDrawing(false);
        patrols = patrols.map(p => p.id === id ? { ...p, zonePoints: gtaPoints } : p);
        const patrol = patrols.find(p => p.id === id);
        if (patrol) refreshZoneForPatrol(patrol);
        try { await fetchNui(NUI_EVENTS.MAP.SET_PATROL_ZONE, { id, points: gtaPoints }, { success: true }); }
        catch { globalNotifications.error("Failed to save zone."); }
    }

    async function clearZone(id: string) {
        patrols = patrols.map(p => p.id === id ? { ...p, zonePoints: null } : p);
        removeZoneById(id);
        try { await fetchNui(NUI_EVENTS.MAP.SET_PATROL_ZONE, { id, points: null }, { success: true }); }
        catch { globalNotifications.error("Failed to clear zone."); }
    }

    function stopDrawing(notify = true) {
        if (!map) return;
        map.off("mousemove", onDrawMouseMove);
        map.off("click", onDrawClick);
        drawPolyline?.remove(); drawPolyline = null;
        drawPolygon?.remove();  drawPolygon  = null;
        removeCursorDot();
        for (const m of drawMarkers) m.remove();
        drawMarkers = [];
        mapContainer?.classList.remove("map-cursor-none");
        drawingPatrolId = null;
        drawPoints = [];
        if (notify) globalNotifications.info("Zone drawing cancelled.");
    }

    function onKeyDown(e: KeyboardEvent) {
        if (!drawingPatrolId) return;
        if (e.key === "Enter")     { e.preventDefault(); finishDrawing(); }
        else if (e.key === "Escape")    { e.preventDefault(); stopDrawing(true); }
        else if (e.key === "Backspace" && drawPoints.length > 0) {
            e.preventDefault();
            drawMarkers[drawMarkers.length - 1]?.remove();
            drawMarkers.pop();
            drawPoints = drawPoints.slice(0, -1);
            // Update or remove preview lines after undo
            if (drawPoints.length === 0) {
                drawPolyline?.remove(); drawPolyline = null;
                drawPolygon?.remove();  drawPolygon  = null;
            } else if (drawPoints.length === 1) {
                drawPolygon?.remove();  drawPolygon  = null;
            }
            // Polyline will be redrawn on next mousemove automatically
        }
    }

    function getTrackConfig(kind: "vehicle" | "bodycam") {
        if (kind === "vehicle") return { color: "#f97316", fill: "#fb923c", label: "V" };
        return { color: "#a855f7", fill: "#c084fc", label: "B" };
    }

    // Builds just the divIcon for a tracker. Split out from createMarker so we can
    // reuse it on existing markers via setIcon() during recycling.
    function makeTrackIcon(
        kind: "vehicle" | "bodycam",
        heading?: number,
        patrolColor?: string,
        cached = false,
        statusColor?: string
    ): L.DivIcon {
        const config = getTrackConfig(kind);
        const dotColor = patrolColor ?? config.fill;
        const borderColor = patrolColor ? patrolColor : config.color;
        const rotation = heading != null ? 360 - heading : 0;
        const hasHeading = heading != null;
        const cachedClass = cached ? " tracking-cached" : "";
        // Small status dot pinned to the marker, counter-rotated so it never
        // tilts with heading. Only bodycams (officers) carry a status — vehicle
        // markers are untouched.
        const statusDot = (kind === "bodycam" && statusColor)
            ? `<div class="tracking-status-dot" style="background:${statusColor};transform:rotate(${-rotation}deg)"></div>`
            : "";

        if (iconStyle === "badge") {
            return L.divIcon({
                className: "",
                html: `
                    <div class="tracking-badge-wrap${cachedClass}" style="transform: rotate(${rotation}deg)">
                        <div class="tracking-icon tracking-${kind}" style="${patrolColor ? `background:${patrolColor}` : ""}">
                            <span style="transform: rotate(-${rotation}deg)">${config.label}</span>
                        </div>
                        ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}" style="${patrolColor ? `border-bottom-color:${patrolColor}` : ""}"></div>` : ""}
                        ${statusDot}
                    </div>
                `,
                iconSize: [28, 28],
                iconAnchor: [14, 14],
            });
        }

        return L.divIcon({
            className: "",
            html: `
                <div class="tracking-dot-wrap${cachedClass}" style="transform: rotate(${rotation}deg)">
                    <div class="tracking-dot" style="background:${dotColor}; border: 2px solid ${borderColor}"></div>
                    ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}" style="${patrolColor ? `border-bottom-color:${patrolColor}` : ""}"></div>` : ""}
                    ${statusDot}
                </div>
            `,
            iconSize: [20, 20],
            iconAnchor: [10, 10],
        });
    }

    function createMarker(
        kind: "vehicle" | "bodycam",
        coords: { x: number; y: number },
        label: string,
        heading?: number,
        patrolColor?: string,
        cached = false,
        statusColor?: string
    ) {
        const offset: [number, number] = iconStyle === "badge" ? [0, -14] : [0, -10];
        return L.marker(toMapLatLng(coords) as any, {
            icon: makeTrackIcon(kind, heading, patrolColor, cached, statusColor),
        }).bindTooltip(label, { direction: "top", offset });
    }

    // Restyles one officer's existing map marker in place (icon swap only, no
    // move) so a status change reflects on the map the instant the broadcast
    // arrives — no need to wait for the next refreshTracking poll.
    function restyleOfficerMarker(citizenid: string) {
        const marker = bodycamMarkers.get(citizenid);
        const officer = officers.find(o => o.citizenid === citizenid);
        if (!marker || !officer) return;
        const patrol = getOfficerPatrol(citizenid);
        const color = patrol?.color ?? "#6b7280";
        const sColor = statusDef(officer.status).color;
        marker.setIcon(makeTrackIcon("bodycam", officer.heading, color, false, sColor));
    }

    function normalizeCoords(raw: any) {
        if (!raw) return null;
        if (Array.isArray(raw) && raw.length >= 2) return { x: Number(raw[0]), y: Number(raw[1]) };
        if (typeof raw.x === "number" && typeof raw.y === "number") return { x: raw.x, y: raw.y };
        return null;
    }

    function getOfficerPatrol(citizenid: string): Patrol | undefined {
        return patrols.find(p => p.memberIds.includes(citizenid));
    }

    function unassignedOfficers() {
        return officers.filter(o => !patrols.some(p => p.memberIds.includes(o.citizenid)));
    }

    // ─── Patrol Status (derived, not stored) ──────────────────────────────
    // A patrol has no status of its own — it's purely derived from its
    // members' individual statuses, recomputed on every officers/patrols
    // change. Rules (as specified):
    //   • Empty patrol (no members currently online)   → no indicator at all
    //   • All members on the default status (Active)   → patrol shows that
    //   • Any member on a non-default status (Busy...) → patrol takes on
    //     that status; if members differ, the one that comes first in
    //     Config.OfficerStatus.list (after the default) wins — i.e. the
    //     "most attention-worthy" status, same idea as a traffic light.
    // Returns undefined for an empty patrol so callers can skip rendering.
    function getPatrolStatus(patrol: Patrol): StatusDef | undefined {
        const members = officers.filter(o => patrol.memberIds.includes(o.citizenid));
        if (members.length === 0) return undefined;

        const memberStatusIds = new Set(members.map(o => o.status ?? defaultStatusId));
        // Walk the configured list in order (skipping the default) so the
        // first non-default status present among members wins — deterministic
        // even with 3+ statuses and mixed members.
        for (const def of statusDefs) {
            if (def.id === defaultStatusId) continue;
            if (memberStatusIds.has(def.id)) return def;
        }
        // Nobody deviates — show the default status.
        return statusDef(defaultStatusId);
    }

    // Case-insensitive filter over name / callsign / rank for the sidebar search,
    // plus an optional status filter (empty set = no filtering by status).
    function filterOfficers(list: Bodycam[]): Bodycam[] {
        const q = officerSearch.trim().toLowerCase();
        let result = list;
        if (statusFilter.size > 0) {
            result = result.filter(o => statusFilter.has(o.status ?? defaultStatusId));
        }
        if (!q) return result;
        return result.filter(o =>
            [o.name, o.callsign, o.rank].some(v => String(v ?? "").toLowerCase().includes(q))
        );
    }

    function refreshPatrolLabels() {
        patrolLayer.clearLayers();
        if (!showPatrols) return;

        for (const patrol of patrols) {
            const members = officers.filter(o => patrol.memberIds.includes(o.citizenid));
            if (members.length === 0) continue;

            const centroid = members.reduce(
                (acc, o) => ({ x: acc.x + o.coords.x, y: acc.y + o.coords.y }),
                { x: 0, y: 0 }
            );
            centroid.x /= members.length;
            centroid.y /= members.length;

            const anchor = members.reduce((closest, o) => {
                const dx = o.coords.x - centroid.x;
                const dy = o.coords.y - centroid.y;
                const cdx = closest.coords.x - centroid.x;
                const cdy = closest.coords.y - centroid.y;
                return (dx*dx + dy*dy) < (cdx*cdx + cdy*cdy) ? o : closest;
            });

            const latLng = toMapLatLng(anchor.coords);
            const pStatus = getPatrolStatus(patrol);
            const statusDotHtml = pStatus
                ? `<span class="patrol-label-status-dot" style="background:${pStatus.color}"></span>`
                : "";
            L.marker(latLng as any, {
                icon: L.divIcon({
                    className: "",
                    html: `<div class="patrol-label" style="border-color:${patrol.color};color:${patrol.color}">${statusDotHtml}${patrol.name}</div>`,
                    iconSize: [null as any, null as any],
                    iconAnchor: [0, 24],
                }),
                interactive: false,
                zIndexOffset: -100,
            }).addTo(patrolLayer);
        }
    }

    async function refreshTracking() {
        if (!map || !tabVisible) return;
        if (isEnvBrowser()) return;

        try {
            const response = await fetchNui(
                NUI_EVENTS.MAP.GET_TRACKING,
                {},
                { data: { vehicles: [], bodycams: [] } },
                3000,
            );

            const success = (response as any).success;
            if (success === false) return;

            const data = (response as any).data ?? response;
            const bodycams = (data as any).bodycams;
            const vehicles = (data as any).vehicles;

            if (!Array.isArray(bodycams) && !Array.isArray(vehicles)) return;

            const freshOfficers: Bodycam[] = [];
            const seenBodycams = new Set<string>();

            for (const bodycam of bodycams || []) {
                const coords = normalizeCoords((bodycam as any).coords);
                if (!coords) continue;

                // A missing citizenid forces a random fallback id below, which makes
                // this officer's marker flicker between refreshes. Surface it for devs.
                if (!bodycam.citizenid) console.warn("[MDT] bodycam without citizenid; marker may flicker:", bodycam.name);

                const bc: Bodycam = {
                    citizenid: bodycam.citizenid ?? bodycam.name ?? String(Math.random()),
                    name: bodycam.name ?? "",
                    callsign: bodycam.callsign,
                    rank: bodycam.rank,
                    coords: { x: coords.x, y: coords.y, z: bodycam.coords?.z ?? 0 },
                    inVehicle: (bodycam as any).inVehicle ?? false,
                    heading: bodycam.heading,
                    status: (bodycam as any).status,
                    statusNote: (bodycam as any).statusNote,
                    statusUpdatedAt: (bodycam as any).statusUpdatedAt,
                };
                freshOfficers.push(bc);
                seenBodycams.add(bc.citizenid);

                const patrol = getOfficerPatrol(bc.citizenid);
                const label = `${[bc.rank, bc.callsign].filter(Boolean).join(" | ")}${bc.name ? " | " + bc.name : ""}`;
                const color = patrol?.color ?? "#6b7280";
                const sColor = statusDef(bc.status).color;
                const latLng = toMapLatLng(coords) as any;

                // Recycle existing markers (move + restyle) instead of clearing the
                // whole layer and rebuilding every divIcon each refresh.
                const existing = bodycamMarkers.get(bc.citizenid);
                if (existing) {
                    existing.setLatLng(latLng);
                    existing.setIcon(makeTrackIcon("bodycam", bodycam.heading, color, false, sColor));
                    existing.setTooltipContent(label);
                } else {
                    const m = createMarker("bodycam", coords, label, bodycam.heading, color, false, sColor);
                    const cid = bc.citizenid;
                    m.on("click", () => selectOfficer(cid));
                    m.addTo(bodycamLayer);
                    bodycamMarkers.set(bc.citizenid, m);
                }

                // Track our own current status so the panel-header picker stays
                // correct even before any local change is made.
                if (bc.citizenid === ownCitizenId) {
                    myStatusId   = bc.status ?? defaultStatusId;
                    myStatusNote = bc.statusNote ?? "";
                }
            }

            // Drop markers for officers no longer present
            for (const [id, m] of bodycamMarkers) {
                if (!seenBodycams.has(id)) {
                    bodycamLayer.removeLayer(m);
                    bodycamMarkers.delete(id);
                }
            }

            officers = freshOfficers;

            // Pan to own position once per MDT open
            if (!centeredOnSelf && map && ownCitizenId) {
                const self = freshOfficers.find(o => o.citizenid === ownCitizenId);
                if (self) {
                    centeredOnSelf = true;
                    map.setView(toMapLatLng(self.coords) as L.LatLngExpression, 5, { animate: false });
                }
            }

            // Keep highlight in sync as the officer moves; drop it if they go off-duty.
            if (selectedOfficerId) {
                if (officers.some(o => o.citizenid === selectedOfficerId)) {
                    highlightOfficerOnMap(selectedOfficerId);
                } else {
                    clearOfficerHighlight();
                }
            }

            // Vehicles — same recycling approach. `cached` (parked / last-known)
            // vehicles come from the server's vehicleCache and are rendered dimmed.
            const seenVehicles = new Set<string>();
            for (const vehicle of vehicles || []) {
                const coords = normalizeCoords((vehicle as any).coords);
                if (!coords) continue;
                const plate  = `${(vehicle as any).plate || ""}`.trim();
                const cached = (vehicle as any).cached === true;
                const label  = cached ? `${plate || "Vehicle"} (Parked)` : plate;
                const key    = plate || `v:${coords.x.toFixed(1)},${coords.y.toFixed(1)}`;
                seenVehicles.add(key);
                const latLng = toMapLatLng(coords) as any;

                const existing = vehicleMarkers.get(key);
                if (existing) {
                    existing.setLatLng(latLng);
                    existing.setIcon(makeTrackIcon("vehicle", (vehicle as any).heading, undefined, cached));
                    existing.setTooltipContent(label);
                    existing.setPopupContent(buildVehiclePopupHtml(vehicle, plate, cached));
                    if (existing.isPopupOpen()) attachDashcamHandler(existing, plate);
                } else {
                    const m = createMarker("vehicle", coords, label, (vehicle as any).heading, undefined, cached);
                    m.bindPopup(buildVehiclePopupHtml(vehicle, plate, cached), {
                        className: "officer-popup veh-popup",
                        closeButton: true,
                        autoClose: true,
                        closeOnClick: false,
                        offset: [0, -10],
                    });
                    const vplate = plate;
                    m.on("popupopen", () => attachDashcamHandler(m, vplate));
                    m.addTo(vehicleLayer);
                    vehicleMarkers.set(key, m);
                }
            }
            for (const [key, m] of vehicleMarkers) {
                if (!seenVehicles.has(key)) {
                    vehicleLayer.removeLayer(m);
                    vehicleMarkers.delete(key);
                }
            }

            refreshPatrolLabels();
        } catch {
            // keep existing
        }
    }

    type DragKind = "officer" | "patrol";
    type DragState = {
        kind: DragKind;
        id: string;
        label: string;
        x: number;
        y: number;
        active: boolean;
    };

    let drag = $state<DragState | null>(null);
    let dragOverPatrolId = $state<string | null>(null);
    let dragOverPatrolSortId = $state<string | null>(null);
    let isDragging = $state(false);

    let ghostEl: HTMLDivElement | null = null;

    function createGhost(label: string, kind: DragKind, x: number, y: number) {
        removeGhost();
        ghostEl = document.createElement("div");
        ghostEl.className = `drag-ghost drag-ghost--${kind}`;
        ghostEl.textContent = label;
        ghostEl.style.left = `${x + 12}px`;
        ghostEl.style.top  = `${y - 16}px`;
        document.body.appendChild(ghostEl);
    }

    function moveGhost(x: number, y: number) {
        if (!ghostEl) return;
        ghostEl.style.left = `${x + 12}px`;
        ghostEl.style.top  = `${y - 16}px`;
    }

    function removeGhost() {
        ghostEl?.remove();
        ghostEl = null;
    }

    function getPatrolIdFromPoint(x: number, y: number): string | null {
        const els = document.elementsFromPoint(x, y);
        for (const el of els) {
            const card = (el as HTMLElement).closest("[data-patrol-id]") as HTMLElement | null;
            if (card) return card.dataset.patrolId ?? null;
        }
        return null;
    }

    function onMouseDown(e: MouseEvent, kind: DragKind, id: string, label: string) {
        if (e.button !== 0) return;
        e.preventDefault();
        drag = { kind, id, label, x: e.clientX, y: e.clientY, active: false };
    }

    function onGlobalMouseMove(e: MouseEvent) {
        if (!drag) return;

        if (!drag.active) {
            const dx = e.clientX - drag.x;
            const dy = e.clientY - drag.y;
            if (Math.sqrt(dx*dx + dy*dy) < 5) return;
            drag.active = true;
            isDragging = true;
            createGhost(drag.label, drag.kind, e.clientX, e.clientY);
        }

        moveGhost(e.clientX, e.clientY);

        const pid = getPatrolIdFromPoint(e.clientX, e.clientY);
        if (drag.kind === "officer") {
            dragOverPatrolId = pid;
            dragOverPatrolSortId = null;
        } else {
            dragOverPatrolSortId = pid !== drag.id ? pid : null;
            dragOverPatrolId = null;
        }
    }

    function onGlobalMouseUp(e: MouseEvent) {
        if (!drag) return;

        if (drag.active) {
            const pid = getPatrolIdFromPoint(e.clientX, e.clientY);

            if (drag.kind === "officer") {
                if (pid) {
                    assignOfficer(drag.id, pid);
                } else {
                    const el = document.elementFromPoint(e.clientX, e.clientY);
                    if (el?.closest(".panel-officers")) {
                        removeFromPatrol(drag.id);
                    }
                }
            } else if (drag.kind === "patrol" && pid && pid !== drag.id) {
                const arr = [...patrols];
                const fromIdx = arr.findIndex(p => p.id === drag!.id);
                const toIdx   = arr.findIndex(p => p.id === pid);
                if (fromIdx >= 0 && toIdx >= 0) {
                    const [moved] = arr.splice(fromIdx, 1);
                    arr.splice(toIdx, 0, moved);
                    patrols = arr;
                    syncPatrolOrder(arr);
                }
            }
        }

        removeGhost();
        drag = null;
        isDragging = false;
        dragOverPatrolId = null;
        dragOverPatrolSortId = null;
    }

    function handleNuiMessage(event: MessageEvent) {
        const { type, data } = event.data ?? {};

        if (type === "setVisible") {
            if (data?.visible === true) {
                centeredOnSelf = false; // re-center each time MDT opens
                setTimeout(() => {
                    refreshTracking();
                    loadPatrols();
                }, 300);
            }
            return;
        }

        if (type === "setLocalCitizenId") {
            if (typeof data?.citizenid === "string") ownCitizenId = data.citizenid;
            return;
        }

        if (type === "mapUiState") {
            if (typeof data?.sidebarOpen  === "boolean") { sidebarOpen  = data.sidebarOpen;  localStorage.setItem("mdt_map_sidebar",  String(sidebarOpen)); }
            if (typeof data?.officersOpen === "boolean") { officersOpen = data.officersOpen; localStorage.setItem("mdt_map_officers", String(officersOpen)); }
            if (typeof data?.patrolsOpen  === "boolean") { patrolsOpen  = data.patrolsOpen;  localStorage.setItem("mdt_map_patrols",  String(patrolsOpen)); }
            return;
        }

        if (type === "syncPatrols") {
            patrols = Array.isArray(data) ? data as Patrol[] : Object.values(data as Record<string, Patrol>);
            refreshPatrolLabels();
            renderAllZones();
            const msg = event.data as any;
            if (msg.action === "assigned" && msg.citizenid) flashAssigned(msg.citizenid);
            if (msg.action === "removed"  && msg.citizenid) flashRemoved(msg.citizenid);
            return;
        }

        if (type === "syncOfficerStatus") {
            // Real-time push from server/backend/officer_status.lua — fires for
            // ANY officer in this player's domain (police vs ems), including our
            // own changes made from another client/instance. Patches the officer
            // list + map marker in place; no re-fetch of the whole tracking list.
            if (data && typeof data.citizenid === "string" && typeof data.status === "string") {
                applyStatusUpdate(data);
            }
            return;
        }


    }

    let recentlyAssigned = $state<Set<string>>(new Set());
    let recentlyRemoved  = $state<Set<string>>(new Set());

    function flashAssigned(citizenid: string) {
        recentlyAssigned = new Set([...recentlyAssigned, citizenid]);
        setTimeout(() => {
            recentlyAssigned = new Set([...recentlyAssigned].filter(id => id !== citizenid));
        }, 700);
    }

    function flashRemoved(citizenid: string) {
        recentlyRemoved = new Set([...recentlyRemoved, citizenid]);
        setTimeout(() => {
            recentlyRemoved = new Set([...recentlyRemoved].filter(id => id !== citizenid));
        }, 700);
    }

    async function loadPatrols() {
        if (isEnvBrowser()) return;
        try {
            const res = await fetchNui(NUI_EVENTS.MAP.GET_PATROLS, {}, { success: true, data: [] });
            const data = (res as any).data ?? res;
            patrols = Array.isArray(data) ? data as Patrol[] : Object.values(data as Record<string, Patrol>);
            refreshPatrolLabels();
            renderAllZones();
        } catch {
            globalNotifications.error("Failed to load patrols");
        }
    }

    function patrolNameExists(name: string, excludeId?: string) {
        return patrols.some(p => p.name.toLowerCase() === name.toLowerCase() && p.id !== excludeId);
    }

    async function createPatrol() {
        const name = newPatrolName.trim();
        if (!name) return;
        if (patrolNameExists(name)) {
            globalNotifications.error(`Patrol "${name}" already exists`);
            return;
        }
        const id = crypto.randomUUID();
        try {
            await fetchNui(NUI_EVENTS.MAP.CREATE_PATROL, { id, name, color: newPatrolColor }, { success: true });
        } catch { }
        newPatrolName = "";
        showCreateForm = false;
    }

    async function deletePatrol(id: string) {
        if (drawingPatrolId === id) stopDrawing(false);
        removeZoneById(id);
        try {
            await fetchNui(NUI_EVENTS.MAP.DELETE_PATROL, { id }, { success: true });
        } catch { }
    }

    async function renamePatrolOnServer(id: string, name: string) {
        if (patrolNameExists(name, id)) {
            globalNotifications.error(`Patrol "${name}" already exists`);
            return;
        }
        try {
            await fetchNui(NUI_EVENTS.MAP.RENAME_PATROL, { id, name }, { success: true });
        } catch { }
    }

    async function assignOfficer(officerId: string, patrolId: string) {
        try {
            await fetchNui(NUI_EVENTS.MAP.ASSIGN_OFFICER, { patrolId, citizenId: officerId }, { success: true });
        } catch { }
    }

    async function removeFromPatrol(officerId: string) {
        try {
            await fetchNui(NUI_EVENTS.MAP.REMOVE_FROM_PATROL, { citizenId: officerId }, { success: true });
        } catch { }
    }

    function movePatrol(id: string, dir: -1 | 1) {
        const idx = patrols.findIndex(p => p.id === id);
        if (idx < 0) return;
        const newIdx = idx + dir;
        if (newIdx < 0 || newIdx >= patrols.length) return;
        const arr = [...patrols];
        [arr[idx], arr[newIdx]] = [arr[newIdx], arr[idx]];
        patrols = arr;
        syncPatrolOrder(arr);
    }

    function syncPatrolOrder(arr: Patrol[]) {
        fetchNui(NUI_EVENTS.MAP.REORDER_PATROLS, { ids: arr.map(p => p.id) }, { success: true }).catch(() => {});
    }

    function handleVisibilityChange() {
        tabVisible = !document.hidden;
    }

    function syncLayerVisibility() {
        if (!map) return;
        const toggle = (layer: L.LayerGroup, show: boolean) => {
            if (show && !map!.hasLayer(layer)) layer.addTo(map!);
            else if (!show && map!.hasLayer(layer)) map!.removeLayer(layer);
        };
        toggle(vehicleLayer, showVehicles);
        toggle(bodycamLayer, showBodycams);
        toggle(patrolLayer, showPatrols);
        toggle(zoneLayer, showZones);
    }

    function getCustomCRS() {
        const zoomNumb = 0.6931471805599453;
        return L.extend({}, CRS.Simple, {
            projection: Projection.LonLat,
            scale: (zoom: number) => Math.pow(2, zoom),
            zoom: (sc: number) => Math.log(sc) / zoomNumb,
            distance: (pos1: { lng: number; lat: number }, pos2: { lng: number; lat: number }) => {
                const dx = pos2.lng - pos1.lng;
                const dy = pos2.lat - pos1.lat;
                return Math.sqrt(dx * dx + dy * dy);
            },
            transformation: new Transformation(0.02072, 117.3, -0.0205, 172.8),
            infinite: false,
        });
    }

    // IDENTICAL to original – no changes
    function initializeMap() {
        if (mapInitialized) return;
        mapInitialized = true;

        const CustomCRS = getCustomCRS();
        map = L.map(mapContainer as HTMLDivElement, {
            crs: CustomCRS,
            minZoom: 3,
            maxZoom: 10,
            zoom: 5,
            preferCanvas: true,
            center: [0, -1024],
            maxBoundsViscosity: 1.0,
            zoomControl: false,
        } as any);

        L.control.zoom({ position: "topright" }).addTo(map);

        const bounds = getMapBounds(map);
        map.setView([-300, -1500], 3);
        map.setMaxBounds(bounds);
        map.attributionControl.setPrefix(false);

        L.imageOverlay("./images/map.jpeg", bounds).addTo(map);

        map.on("dragend", () => {
            if (!bounds.contains(map!.getCenter())) {
                map!.panTo(bounds.getCenter(), { animate: false });
            }
        });

        vehicleLayer = L.layerGroup().addTo(map);
        bodycamLayer = L.layerGroup().addTo(map);
        patrolLayer  = L.layerGroup().addTo(map);
        zoneLayer    = L.layerGroup().addTo(map);

        syncLayerVisibility();
        refreshTracking();
        refreshTimer = setInterval(refreshTracking, 4500);
    }

    function getMapBounds(map: Map) {
        const sw = map.unproject([0, 1024], 2);
        const ne = map.unproject([1024, 0], 2);
        return new LatLngBounds(sw, ne);
    }

    // Closes the status picker popover when clicking anywhere outside it.
    function handleOutsideClick(e: MouseEvent) {
        if (!statusPickerOpen) return;
        const target = e.target as HTMLElement;
        if (!target.closest(".my-status")) statusPickerOpen = false;
    }

    // onMount: original tracking/patrol bootstrap, plus the Officer Status
    // additions (loadStatusConfig + the outside-click handler for its picker).
    onMount(() => {
        document.addEventListener("visibilitychange", handleVisibilityChange);
        window.addEventListener("message", handleNuiMessage);
        window.addEventListener("mousemove", onGlobalMouseMove);
        window.addEventListener("mouseup", onGlobalMouseUp);
        window.addEventListener("keydown", onKeyDown);
        window.addEventListener("click", handleOutsideClick);
        initializeMap();
        loadPatrols();
        loadStatusConfig();
    });

    onDestroy(() => {
        document.removeEventListener("visibilitychange", handleVisibilityChange);
        window.removeEventListener("message", handleNuiMessage);
        window.removeEventListener("mousemove", onGlobalMouseMove);
        window.removeEventListener("mouseup", onGlobalMouseUp);
        window.removeEventListener("keydown", onKeyDown);
        window.removeEventListener("click", handleOutsideClick);
        if (drawingPatrolId) stopDrawing(false);
        removeGhost();
        if (map) { map.remove(); map = null; mapInitialized = false; }
        if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
        bodycamMarkers.clear();
        vehicleMarkers.clear();
    });

    $effect(() => { syncLayerVisibility(); });
    $effect(() => { iconStyle; refreshTracking(); });
    $effect(() => { showPatrols; refreshPatrolLabels(); });
    $effect(() => { showZones; renderAllZones(); });
</script>
<div class="map-page">
    <div class="map-wrapper" style="--sidebar-width:{sidebarWidth}px">

        <div class="map-controls">
            <span class="controls-header">Tracking</span>
            <div class="controls-group">
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showVehicles} onchange={() => localStorage.setItem("mdt_map_vehicles", String(showVehicles))} />
                    <span class="toggle-label">Vehicles</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showBodycams} onchange={() => localStorage.setItem("mdt_map_bodycams", String(showBodycams))} />
                    <span class="toggle-label">{isEms ? "Live Units" : "Bodycams"}</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showPatrols} onchange={() => localStorage.setItem("mdt_map_patrols_layer", String(showPatrols))} />
                    <span class="toggle-label">Patrols</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showZones} onchange={() => localStorage.setItem("mdt_map_zones", String(showZones))} />
                    <span class="toggle-label">Zones</span>
                </label>
            </div>
            <div class="controls-divider"></div>
            <div class="controls-group">
                <span class="controls-label">Style</span>
                <div class="segment">
                    <button class:active={iconStyle === "dot"} onclick={() => { iconStyle = "dot"; localStorage.setItem("mdt_map_icon_style", "dot"); }} type="button">Dots</button>
                    <button class:active={iconStyle === "badge"} onclick={() => { iconStyle = "badge"; localStorage.setItem("mdt_map_icon_style", "badge"); }} type="button">Badges</button>
                </div>
            </div>
            <div class="controls-divider"></div>
            <div class="legend">
                <span class="legend-item vehicle">Vehicle</span>
                <span class="legend-item vehicle-parked">Parked</span>
                <span class="legend-item bodycam-unassigned">Unassigned</span>
                {#each patrols.filter(p => p.memberIds.length > 0) as patrol}
                    <span class="legend-item" style="--dot:{patrol.color}">{patrol.name}</span>
                {/each}
            </div>
        </div>

        {#if drawingPatrolId}
            {@const drawPatrol = patrols.find(p => p.id === drawingPatrolId)}
            <div class="drawing-hud" style="--zone-color:{drawPatrol?.color ?? '#38bdf8'}">
                <div class="drawing-hud-title">
                    <span class="drawing-dot"></span>
                    Drawing zone for <strong>{drawPatrol?.name}</strong>
                </div>
                <div class="drawing-hud-hints">
                    <kbd>Click</kbd> Place point &nbsp;·&nbsp;
                    <kbd>Enter</kbd> Finish &nbsp;·&nbsp;
                    <kbd>⌫</kbd> Undo &nbsp;·&nbsp;
                    <kbd>Esc</kbd> Cancel
                </div>
                <div class="drawing-hud-count">{drawPoints.length} point{drawPoints.length !== 1 ? "s" : ""}{drawPoints.length >= 3 ? " ✓" : ""}</div>
                <div class="drawing-hud-actions">
                    <button class="hud-btn hud-btn--finish" onclick={() => finishDrawing()} disabled={drawPoints.length < 3} type="button">Finish</button>
                    <button class="hud-btn hud-btn--cancel" onclick={() => stopDrawing(true)} type="button">Cancel</button>
                </div>
            </div>
        {/if}

        <div bind:this={mapContainer} class="map-container" class:map-no-pointer={isDragging}></div>

        {#if canViewPatrols}
        <button class="sidebar-toggle" class:open={sidebarOpen} onclick={() => toggleSidebar()} type="button" title={sidebarOpen ? "Close sidebar" : "Manage patrols"}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                {#if sidebarOpen}
                    <path d="M10 3L5 8L10 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                {:else}
                    <path d="M6 3L11 8L6 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                {/if}
            </svg>
            {#if !sidebarOpen}<span class="sidebar-toggle-label">Patrols</span>{/if}
        </button>

        <div class="sidebar" class:sidebar--open={sidebarOpen}>
            <div class="panel" class:panel--open={officersOpen} class:panel--closed={!officersOpen}>
                <div class="panel-header panel-header--clickable" onclick={toggleOfficers}>
                    {#if officersOpen}
                        <span class="panel-title">Officers</span>
                        <span class="tab-badge">{officers.length}</span>
                    {:else}
                        <span class="panel-title-vertical">Officers</span>
                    {/if}
                    <svg class="panel-chevron" class:rotated={!officersOpen} width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 4.5l4 4 4-4"/></svg>
                </div>
                {#if officersOpen}
                <!-- My Status — sets the local officer's own availability. Always
                     visible at the top of the panel regardless of search/filter,
                     since it acts on the player themselves, not the list below. -->
                <div class="my-status">
                    <button
                        class="my-status-trigger"
                        class:disabled={statusChangePending}
                        onclick={() => { statusPickerOpen = !statusPickerOpen; statusNoteDraft = myStatusNote; }}
                        title="Set your status"
                    >
                        <span class="my-status-dot" style="background:{statusDef(myStatusId).color}"></span>
                        <span class="my-status-label">{myStatusNote || statusDef(myStatusId).label}</span>
                        <svg class="my-status-chevron" class:rotated={statusPickerOpen} width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 4.5l4 4 4-4"/></svg>
                    </button>
                    {#if statusPickerOpen}
                        <div class="my-status-popover">
                            {#each statusDefs as s (s.id)}
                                <button
                                    class="my-status-option"
                                    class:active={myStatusId === s.id}
                                    onclick={() => setMyStatus(s.id, statusNoteDraft.trim() || undefined)}
                                >
                                    <span class="my-status-dot" style="background:{s.color}"></span>
                                    {s.label}
                                </button>
                            {/each}
                            <input
                                class="my-status-note-input"
                                placeholder="Optional note (e.g. Traffic Stop)…"
                                maxlength="60"
                                bind:value={statusNoteDraft}
                                onkeydown={(e) => { if (e.key === "Enter") setMyStatus(myStatusId, statusNoteDraft.trim() || undefined); }}
                            />
                        </div>
                    {/if}
                </div>
                <!-- Status filter chips — toggle to show only matching officers below.
                     Empty selection (default) shows everyone. -->
                <div class="status-filter-row">
                    {#each statusDefs as s (s.id)}
                        <button
                            class="status-chip"
                            class:active={statusFilter.has(s.id)}
                            style={statusChipStyle(s.color)}
                            onclick={() => toggleStatusFilter(s.id)}
                        >
                            <span class="status-chip-dot" style="background:{s.color}"></span>{s.label}
                        </button>
                    {/each}
                </div>
                <div class="panel-content panel-officers-content">
                    {#if officers.length === 0}
                        <div class="empty-hint">No officers on duty.</div>
                    {:else if totalVisibleOfficers === 0}
                        <div class="empty-hint">No officers match {statusFilter.size > 0 ? "the selected status" : `"${officerSearch}"`}.</div>
                    {/if}
                    {#if unassignedFiltered.length > 0}
                        <div class="section-label">Unassigned ({unassignedFiltered.length})</div>
                        {#each unassignedFiltered as officer (officer.citizenid)}
                            {@const sDef = statusDef(officer.status)}
                            <div class="officer-card" class:dragging={drag?.kind === "officer" && drag.id === officer.citizenid && drag.active} class:anim-removed={recentlyRemoved.has(officer.citizenid)} class:officer-selected={selectedOfficerId === officer.citizenid} onmousedown={(e) => canManagePatrols && onMouseDown(e, "officer", officer.citizenid, officer.name)} onclick={() => selectOfficer(officer.citizenid)} style={canManagePatrols ? "cursor:grab" : "cursor:pointer"}>
                                {#if canManagePatrols}<div class="officer-drag-handle">⠿</div>{/if}
                                <span class="officer-status-dot" style="background:{sDef.color}" use:tip={`${officer.statusNote || sDef.label}${officer.statusUpdatedAt ? " · " + timeSince(officer.statusUpdatedAt) : ""}`}></span>
                                <div class="officer-info">
                                    <span class="officer-name">{officer.name}</span>
                                    <span class="officer-meta">{[officer.rank, officer.callsign].filter(Boolean).join(" · ")}</span>
                                </div>
                                <span class="officer-status-badge" style={statusPillStyle(sDef.color)}>{officer.statusNote || sDef.label}</span>
                            </div>
                        {/each}
                    {/if}
                    {#each patrols as patrol}
                        {@const members = patrol.memberIds.map(id => officers.find(o => o.citizenid === id)).filter(Boolean) as Bodycam[]}
                        {@const visibleMembers = filterOfficers(members)}
                        {@const pStatus = getPatrolStatus(patrol)}
                        {#if visibleMembers.length > 0}
                            <div class="section-label" style="margin-top:8px">
                                <span class="section-dot" style="background:{patrol.color}"></span>
                                {patrol.name}
                                {#if pStatus}
                                    <span class="patrol-status-pill" style={statusPillStyle(pStatus.color)} use:tip={`Patrol status: ${pStatus.label}`}>{pStatus.label}</span>
                                {/if}
                            </div>
                            {#each visibleMembers as officer (officer!.citizenid)}
                                {@const sDef = statusDef(officer!.status)}
                                <div class="officer-card officer-card--assigned" class:dragging={drag?.kind === "officer" && drag.id === officer!.citizenid && drag.active} class:anim-assigned={recentlyAssigned.has(officer!.citizenid)} class:officer-selected={selectedOfficerId === officer!.citizenid} style="border-left: 2px solid {patrol.color};{canManagePatrols ? '' : 'cursor:pointer'}" onmousedown={(e) => canManagePatrols && onMouseDown(e, "officer", officer!.citizenid, officer!.name)} onclick={() => selectOfficer(officer!.citizenid)}>
                                    {#if canManagePatrols}<div class="officer-drag-handle">⠿</div>{/if}
                                    <span class="officer-status-dot" style="background:{sDef.color}" use:tip={`${officer!.statusNote || sDef.label}${officer!.statusUpdatedAt ? " · " + timeSince(officer!.statusUpdatedAt) : ""}`}></span>
                                    <div class="officer-info">
                                        <span class="officer-name">{officer!.name}</span>
                                        <span class="officer-meta">{[officer!.rank, officer!.callsign].filter(Boolean).join(" · ")}</span>
                                    </div>
                                    <span class="officer-status-badge" style={statusPillStyle(sDef.color)}>{officer!.statusNote || sDef.label}</span>
                                    {#if canManagePatrols}
                                        <button class="officer-kick" onmousedown={(e) => e.stopPropagation()} onclick={(e) => { e.stopPropagation(); removeFromPatrol(officer!.citizenid); }} title="Remove">×</button>
                                    {/if}
                                </div>
                            {/each}
                        {/if}
                    {/each}
                </div>
                <div class="officer-search">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
                    <input class="officer-search-input" placeholder="Search officers…" bind:value={officerSearch} />
                    {#if officerSearch}<button class="officer-search-clear" onclick={() => (officerSearch = "")} type="button" title="Clear">×</button>{/if}
                </div>
                {/if}
            </div>

            <div class="panel-divider"></div>

            <div class="panel" class:panel--open={patrolsOpen} class:panel--closed={!patrolsOpen}>
                <div class="panel-header panel-header--clickable" onclick={togglePatrols}>
                    {#if patrolsOpen}
                        <span class="panel-title">Patrols</span>
                        <span class="tab-badge">{patrols.length}</span>
                        {#if canEditPatrols}
                            <button class="btn-icon-add" onmousedown={(e) => e.stopPropagation()} onclick={(e) => { e.stopPropagation(); showCreateForm = !showCreateForm; }} type="button" title="New patrol">
                                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="1" x2="6" y2="11"/><line x1="1" y1="6" x2="11" y2="6"/></svg>
                            </button>
                        {/if}
                    {:else}
                        <span class="panel-title-vertical">Patrols</span>
                    {/if}
                    <svg class="panel-chevron" class:rotated={!patrolsOpen} width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 4.5l4 4 4-4"/></svg>
                </div>

                {#if patrolsOpen}
                {#if showCreateForm && canEditPatrols}
                    <div class="create-form">
                        <input class="create-input" placeholder="Patrol name…" bind:value={newPatrolName} onkeydown={(e) => e.key === "Enter" && createPatrol()} autofocus />
                        <div class="color-row">
                            {#each PATROL_COLORS as c}
                                <button class="color-swatch" class:selected={newPatrolColor === c} style="background:{c}" onclick={() => (newPatrolColor = c)} type="button"></button>
                            {/each}
                        </div>
                        <div class="create-actions">
                            <button class="btn-create" onclick={createPatrol} type="button">Create</button>
                            <button class="btn-cancel" onclick={() => (showCreateForm = false)} type="button">Cancel</button>
                        </div>
                    </div>
                {/if}

                <div class="panel-content">
                    {#if patrols.length === 0}<div class="empty-hint">No patrols yet.<br/>Press + above.</div>{/if}

                    {#each patrols as patrol, idx (patrol.id)}
                        {@const pStatus = getPatrolStatus(patrol)}
                        <div class="patrol-card" class:drag-over={dragOverPatrolId === patrol.id} class:sort-over={dragOverPatrolSortId === patrol.id} data-patrol-id={patrol.id}>
                            <div class="patrol-header">
                                {#if canEditPatrols}
                                    <div class="patrol-sort-handle" title="Drag to reorder" onmousedown={(e) => onMouseDown(e, "patrol", patrol.id, patrol.name)}>⠿</div>
                                {/if}
                                <div class="patrol-color-bar" style="background:{patrol.color}"></div>
                                {#if editingPatrolId === patrol.id && canEditPatrols}
                                    <input class="patrol-name-edit" bind:value={editingPatrolName}
                                        onblur={() => { const n = editingPatrolName.trim(); if (n) renamePatrolOnServer(patrol.id, n); editingPatrolId = null; }}
                                        onkeydown={(e) => { if (e.key === "Enter") { const n = editingPatrolName.trim(); if (n) renamePatrolOnServer(patrol.id, n); editingPatrolId = null; } if (e.key === "Escape") editingPatrolId = null; }}
                                        autofocus />
                                {:else}
                                    <span class="patrol-name" ondblclick={() => { if (canEditPatrols) { editingPatrolId = patrol.id; editingPatrolName = patrol.name; } }} title={canEditPatrols ? "Double-click to rename" : ""}>{patrol.name}</span>
                                {/if}
                                <span class="patrol-count">{patrol.memberIds.length}</span>
                                {#if pStatus}
                                    <span class="patrol-status-dot" style="background:{pStatus.color}" use:tip={`Patrol status: ${pStatus.label}`}></span>
                                {/if}
                                {#if canEditPatrols}
                                    <div class="patrol-sort-arrows">
                                        <button class="sort-arrow" onclick={() => movePatrol(patrol.id, -1)} disabled={idx === 0} type="button" title="Move up">▲</button>
                                        <button class="sort-arrow" onclick={() => movePatrol(patrol.id, 1)} disabled={idx === patrols.length - 1} type="button" title="Move down">▼</button>
                                    </div>
                                    <button class="patrol-delete" onclick={() => deletePatrol(patrol.id)} type="button" title="Delete">
                                        <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 2l8 8M10 2L2 10"/></svg>
                                    </button>
                                {/if}
                            </div>

                            {#if canEditPatrols}
                                <div class="zone-controls">
                                    {#if drawingPatrolId === patrol.id}
                                        <div class="zone-drawing-active">
                                            <span class="zone-pulse" style="background:{patrol.color}"></span>Drawing…
                                        </div>
                                    {:else if patrol.zonePoints && patrol.zonePoints.length >= 3}
                                        <div class="zone-info">
                                            <span class="zone-badge" style="background:{patrol.color}20;border-color:{patrol.color}40;color:{patrol.color}">
                                                <svg width="8" height="8" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 11 L3 5 L8 1 L11 4 L7 9 Z"/></svg>
                                                Zone · {patrol.zonePoints.length} pts
                                            </span>
                                            <button class="zone-btn zone-btn--edit" onclick={() => startDrawing(patrol.id)} title="Redraw zone" type="button">
                                                <svg width="9" height="9" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 1.5l2 2L4 10 1.5 10.5 2 8z"/><path d="M7 3l2 2"/></svg>
                                            </button>
                                            <button class="zone-btn zone-btn--clear" onclick={() => clearZone(patrol.id)} title="Clear zone" type="button">
                                                <svg width="9" height="9" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 2l8 8M10 2L2 10"/></svg>
                                            </button>
                                        </div>
                                    {:else}
                                        <button class="zone-btn zone-btn--draw" onclick={() => startDrawing(patrol.id)} type="button">
                                            <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 11 L3 5 L8 1 L11 4 L7 9 Z"/><path d="M3 5 L7 9"/></svg>
                                            Draw zone
                                        </button>
                                    {/if}
                                </div>
                            {:else if patrol.zonePoints && patrol.zonePoints.length >= 3}
                                <div class="zone-controls">
                                    <div class="zone-info">
                                        <span class="zone-indicator" style="background:{patrol.color}"></span>
                                        <span class="zone-pts">Zone active</span>
                                    </div>
                                </div>
                            {/if}

                            {#if patrol.memberIds.length === 0}
                                {#if canManagePatrols}<div class="drop-hint">Drag an officer here →</div>{/if}
                            {:else}
                                {#each patrol.memberIds as mid}
                                    {@const officer = officers.find(o => o.citizenid === mid)}
                                    {#if officer}
                                        <div class="patrol-member" class:anim-assigned={recentlyAssigned.has(mid)}>
                                            <span class="member-name">{officer.name}</span>
                                            <span class="member-meta">{officer.callsign ?? ""}</span>
                                        </div>
                                    {/if}
                                {/each}
                            {/if}
                        </div>
                    {/each}
                </div>
                {/if}
            </div>
        </div>
        {/if}
    </div>
</div>

<style>
    :global(.leaflet-popup-content-wrapper) { background: var(--dark-bg); color: rgba(255,255,255,0.8); border-radius: 8px; border: 1px solid rgba(255,255,255,0.06); box-shadow: none; }
    :global(.leaflet-popup-tip) { background: var(--dark-bg); }
    :global(.leaflet-tooltip) { background: var(--dark-bg); color: rgba(255,255,255,0.8); border: 1px solid rgba(255,255,255,0.06); border-radius: 6px; font-size: 11px; padding: 4px 8px; box-shadow: none; }
    :global(.leaflet-tooltip-top::before) { border-top-color: #111111; }
    :global(.leaflet-control-zoom) { border: 1px solid rgba(255,255,255,0.06) !important; border-radius: 8px !important; overflow: hidden; box-shadow: none !important; }
    :global(.leaflet-control-zoom a) { background: rgba(17,17,17,0.92) !important; color: rgba(255,255,255,0.6) !important; border-color: rgba(255,255,255,0.04) !important; width: 30px !important; height: 30px !important; line-height: 30px !important; font-size: 14px !important; }
    :global(.leaflet-control-zoom a:hover) { background: rgba(255,255,255,0.08) !important; color: rgba(255,255,255,0.9) !important; }
    :global(.patrol-label) { background: rgba(0,0,0,0.55); border: 1px solid; border-radius: 4px; padding: 2px 6px; font-size: 9px; font-weight: 600; letter-spacing: 0.4px; text-transform: uppercase; white-space: nowrap; pointer-events: none; opacity: 0.7; }
    :global(.patrol-label-status-dot) { display: inline-block; vertical-align: middle; width: 5px; height: 5px; border-radius: 50%; margin-right: 4px; margin-bottom: 1px; }
    :global(.patrol-zone-poly) { transition: fill-opacity 0.2s; }
    :global(.patrol-zone-poly:hover) { fill-opacity: 0.22 !important; }
    :global(.zone-label) { background: rgba(0,0,0,0.62); border: 1px solid; border-radius: 5px; padding: 3px 8px; font-size: 10px; font-weight: 700; letter-spacing: 0.6px; text-transform: uppercase; white-space: nowrap; pointer-events: none; opacity: 0.85; transform: translateX(-50%); display: inline-block; }
    :global(.tracking-icon) { width: 22px; height: 22px; border-radius: 5px; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; color: #0c0c0c; }
    :global(.tracking-vehicle) { background: #f97316; }
    :global(.tracking-bodycam) { background: #a855f7; }
    :global(.tracking-dot-wrap), :global(.tracking-badge-wrap) { position: relative; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; }
    :global(.tracking-dot) { width: 12px; height: 12px; border-radius: 50%; }
    :global(.tracking-arrow) { position: absolute; top: -7px; left: 50%; transform: translateX(-50%); width: 0; height: 0; border-left: 4px solid transparent; border-right: 4px solid transparent; }
    :global(.tracking-arrow-vehicle) { border-bottom: 8px solid #f97316; }
    :global(.tracking-arrow-bodycam) { border-bottom: 8px solid #a855f7; }
    /* Parked / last-known vehicles served from the server cache — dimmed + dashed */
    :global(.tracking-cached) { opacity: 0.5; }
    :global(.tracking-cached .tracking-dot) { border-style: dashed !important; }
    :global(.map-cursor-none) { cursor: none !important; }
    :global(.map-cursor-none .leaflet-interactive) { cursor: none !important; }
    :global(.map-cursor-none .leaflet-container) { cursor: none !important; }

    /* DOM-based drawing cursor dot – positioned in viewport coords, immune to CSS zoom */
    :global(.draw-cursor-dot) {
        position: fixed;
        z-index: 99999;
        pointer-events: none;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: var(--dot-color, #38bdf8);
        border: 2px solid rgba(255,255,255,0.9);
        box-shadow: 0 0 0 1px var(--dot-color, #38bdf8), 0 2px 6px rgba(0,0,0,0.4);
        transform: translate(-50%, -50%);
        transition: none;
    }
    /* Officer highlight ring */
    :global(.officer-highlight-ring) {
        width: 40px; height: 40px;
        border-radius: 50%;
        border: 2.5px solid var(--ring-color, #38bdf8);
        box-shadow: 0 0 0 4px color-mix(in srgb, var(--ring-color, #38bdf8) 20%, transparent);
        animation: ring-pulse 1.4s ease-in-out infinite;
        pointer-events: none;
    }
    @keyframes ring-pulse {
        0%, 100% { transform: scale(1);    opacity: 1;    box-shadow: 0 0 0 4px color-mix(in srgb, var(--ring-color,#38bdf8) 20%, transparent); }
        50%       { transform: scale(1.18); opacity: 0.75; box-shadow: 0 0 0 8px color-mix(in srgb, var(--ring-color,#38bdf8) 8%,  transparent); }
    }

    /* Officer popup */
    :global(.officer-popup .leaflet-popup-content-wrapper) {
        background: rgba(13,13,13,0.97) !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
        border-radius: 10px !important;
        padding: 0 !important;
        min-width: 190px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.5) !important;
    }
    :global(.officer-popup .leaflet-popup-content) { margin: 0 !important; }
    :global(.officer-popup .leaflet-popup-tip-container) { display: none; }
    :global(.officer-popup .leaflet-popup-close-button) {
        color: rgba(255,255,255,0.25) !important;
        font-size: 14px !important;
        top: 4px !important; right: 6px !important;
        width: 20px !important; height: 20px !important;
        line-height: 20px !important;
    }
    :global(.officer-popup .leaflet-popup-close-button:hover) { color: rgba(255,255,255,0.8) !important; }

    :global(.op-wrap)   { display: flex; flex-direction: column; overflow: hidden; border-radius: 10px; }
    :global(.op-header) {
        padding: 10px 30px 8px 12px; /* right padding makes room for the × button */
        background: linear-gradient(135deg, color-mix(in srgb, var(--op-color,#38bdf8) 15%, transparent), transparent);
        border-bottom: 1px solid rgba(255,255,255,0.06);
        display: flex; flex-direction: column; gap: 3px;
    }
    :global(.op-name)           { font-size: 12px; font-weight: 700; color: rgba(255,255,255,0.95); line-height: 1.2; }
    :global(.op-callsign-badge) {
        font-size: 9px; font-weight: 700; letter-spacing: 0.5px;
        background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.12);
        color: rgba(255,255,255,0.55); border-radius: 4px; padding: 1px 5px;
        white-space: nowrap; align-self: flex-start;
    }
    :global(.op-body)    { padding: 8px 12px; display: flex; flex-direction: column; gap: 5px; }
    :global(.op-row)     { display: flex; align-items: center; gap: 6px; font-size: 10px; }
    :global(.op-label)   { color: rgba(255,255,255,0.25); min-width: 48px; font-size: 9px; text-transform: uppercase; letter-spacing: 0.4px; }
    :global(.op-value)   { color: rgba(255,255,255,0.75); font-weight: 500; }
    :global(.op-patrol)  { font-weight: 600; font-size: 10px; }
    :global(.op-patrol--none) { color: rgba(255,255,255,0.3); font-weight: 500; }
    :global(.op-badge)   { font-size: 9px; font-weight: 600; padding: 1px 6px; border-radius: 4px; }
    :global(.op-badge--vehicle) { background: rgba(249,115,22,0.15); color: rgba(249,115,22,0.9); }
    :global(.op-badge--foot)    { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.4); }
    :global(.op-heading) { display: inline-flex; align-items: center; gap: 3px; color: rgba(255,255,255,0.4); font-size: 9px; margin-left: auto; }
    :global(.op-row--coords) {
        border-top: 1px solid rgba(255,255,255,0.05);
        padding-top: 5px; margin-top: 2px;
        font-variant-numeric: tabular-nums;
    }
    :global(.op-row--coords .op-value) { color: rgba(255,255,255,0.4); font-size: 9px; }

    /* Vehicle popup: dashcam button + note */
    :global(.veh-actions) { margin-top: 8px; }
    :global(.veh-dashcam-btn) {
        display: flex; align-items: center; justify-content: center; gap: 6px;
        width: 100%; padding: 6px 8px;
        background: rgba(249,115,22,0.15);
        color: rgba(249,180,120,0.95);
        border: 1px solid rgba(249,115,22,0.35);
        border-radius: 6px;
        font-size: 11px; font-weight: 600; cursor: pointer;
        transition: background 0.12s ease, border-color 0.12s ease;
    }
    :global(.veh-dashcam-btn:hover) {
        background: rgba(249,115,22,0.28);
        border-color: rgba(249,115,22,0.55);
        color: #fff;
    }
    :global(.veh-dashcam-btn svg) { flex-shrink: 0; }
    :global(.veh-note) {
        margin-top: 2px; padding-top: 6px;
        border-top: 1px solid rgba(255,255,255,0.05);
        font-size: 9px; color: rgba(255,255,255,0.35); text-align: center;
    }

    /* Selected officer card highlight */
    .officer-selected {
        border-color: rgba(56,189,248,0.35) !important;
        background: rgba(56,189,248,0.06) !important;
    }

    :global(.drag-ghost) { position: fixed; z-index: 9999; pointer-events: none; padding: 5px 10px; border-radius: 6px; font-size: 11px; font-weight: 600; white-space: nowrap; box-shadow: 0 4px 16px rgba(0,0,0,0.4); transform: rotate(2deg); transition: none; }
    :global(.drag-ghost--officer) { background: rgba(30,30,30,0.97); border: 1px solid rgba(255,255,255,0.15); color: rgba(255,255,255,0.9); }
    :global(.drag-ghost--patrol) { background: rgba(30,30,30,0.97); border: 1px solid rgba(255,255,255,0.12); color: rgba(255,255,255,0.7); }

    .map-page { height: 100%; padding: 10px 20px 20px; background: var(--card-dark-bg); }
    .map-wrapper { position: relative; width: 100%; height: 100%; border-radius: 10px; overflow: hidden; border: 1px solid rgba(255,255,255,0.06); display: flex; }
    .map-container { flex: 1; height: 100%; }
    .map-no-pointer { pointer-events: none !important; }
    .officer-card.dragging { opacity: 0.35; }

    .drawing-hud { position: absolute; z-index: 1010; top: 14px; left: 50%; transform: translateX(-50%); background: rgba(10,10,12,0.94); border: 1px solid var(--zone-color,#38bdf8); border-radius: 10px; padding: 10px 16px; display: flex; flex-direction: column; gap: 6px; min-width: 300px; box-shadow: 0 0 24px rgba(0,0,0,0.5); pointer-events: auto; }
    .drawing-hud-title { display: flex; align-items: center; gap: 8px; font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.9); }
    .drawing-hud-title strong { color: var(--zone-color,#38bdf8); }
    .drawing-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--zone-color,#38bdf8); box-shadow: 0 0 6px var(--zone-color,#38bdf8); animation: pulse-dot 1.2s ease-in-out infinite; }
    @keyframes pulse-dot { 0%,100% { opacity:1; transform:scale(1); } 50% { opacity:0.5; transform:scale(0.7); } }
    .drawing-hud-hints { font-size: 10px; color: rgba(255,255,255,0.35); line-height: 1.5; }
    .drawing-hud-hints kbd { display: inline-block; background: rgba(255,255,255,0.07); border: 1px solid rgba(255,255,255,0.12); border-radius: 3px; padding: 0 4px; font-size: 9px; font-family: inherit; color: rgba(255,255,255,0.55); }
    .drawing-hud-count { font-size: 11px; font-weight: 500; color: rgba(255,255,255,0.4); }
    .drawing-hud-actions { display: flex; gap: 5px; margin-top: 2px; }
    .hud-btn { flex: 1; padding: 5px 10px; border-radius: 6px; font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.12s; border: 1px solid; }
    .hud-btn--finish { background: rgba(56,189,248,0.15); border-color: var(--zone-color,#38bdf8); color: var(--zone-color,#38bdf8); }
    .hud-btn--finish:hover:not(:disabled) { background: rgba(56,189,248,0.28); }
    .hud-btn--finish:disabled { opacity: 0.3; cursor: default; }
    .hud-btn--cancel { background: rgba(255,255,255,0.04); border-color: rgba(255,255,255,0.1); color: rgba(255,255,255,0.4); }
    .hud-btn--cancel:hover { background: rgba(255,255,255,0.09); color: rgba(255,255,255,0.7); }

    .map-controls { position: absolute; z-index: 1001; top: 12px; left: 12px; background: rgba(17,17,17,0.92); border: 1px solid rgba(255,255,255,0.06); border-radius: 10px; padding: 12px 14px; min-width: 160px; color: rgba(255,255,255,0.9); font-size: 12px; }
    .controls-header { font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; font-size: 11px; color: rgba(255,255,255,0.5); margin-bottom: 10px; display: block; }
    .controls-group { display: flex; flex-direction: column; gap: 6px; }
    .controls-label { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.5); margin-bottom: 2px; }
    .controls-divider { height: 1px; background: rgba(255,255,255,0.04); margin: 10px 0; }
    .control-toggle { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 12px; color: rgba(255,255,255,0.7); }
    .control-toggle input[type="checkbox"] { width: 14px; height: 14px; accent-color: rgba(var(--accent-rgb),0.7); cursor: pointer; }
    .segment { display: grid; grid-template-columns: 1fr 1fr; gap: 4px; }
    .segment button { border-radius: 6px; border: 1px solid rgba(255,255,255,0.06); background: rgba(255,255,255,0.04); color: rgba(255,255,255,0.5); font-size: 11px; font-weight: 500; padding: 5px 8px; cursor: pointer; transition: all 0.1s ease; }
    .segment button:hover { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.7); }
    .segment button.active { background: rgba(255,255,255,0.08); border-color: rgba(255,255,255,0.12); color: rgba(255,255,255,0.9); }
    .legend { display: flex; flex-direction: column; gap: 5px; font-size: 11px; color: rgba(255,255,255,0.45); }
    .legend-item { display: flex; align-items: center; gap: 8px; }
    .legend-item::before { content:""; width:6px; height:6px; border-radius:50%; display:inline-block; flex-shrink:0; background:var(--dot,#888); }
    .legend-item.vehicle::before { background:#f97316; }
    .legend-item.vehicle-parked::before { background:#f97316; opacity:0.45; }
    .legend-item.bodycam-unassigned::before { background:#6b7280; }

    .sidebar-toggle { position: absolute; z-index: 1002; right: 0; top: 50%; transform: translateY(-50%); display: flex; align-items: center; gap: 6px; background: rgba(17,17,17,0.92); border: 1px solid rgba(255,255,255,0.08); border-right: none; border-radius: 8px 0 0 8px; padding: 10px 10px; color: rgba(255,255,255,0.6); font-size: 11px; font-weight: 600; letter-spacing: 0.4px; cursor: pointer; transition: right 0.25s cubic-bezier(0.4,0,0.2,1), background 0.15s; writing-mode: vertical-rl; text-orientation: mixed; }
    .sidebar-toggle:hover { background: rgba(30,30,30,0.95); color: rgba(255,255,255,0.9); }
    .sidebar-toggle.open { right: var(--sidebar-width,520px); }
    .sidebar-toggle-label { writing-mode: vertical-rl; text-orientation: mixed; }

    .sidebar { position: absolute; z-index: 1001; top: 0; right: 0; bottom: 0; width: var(--sidebar-width,520px); display: flex; flex-direction: row; background: rgba(13,13,13,0.96); border-left: 1px solid rgba(255,255,255,0.06); transform: translateX(100%); transition: transform 0.25s cubic-bezier(0.4,0,0.2,1), width 0.25s cubic-bezier(0.4,0,0.2,1); overflow: hidden; }
    .sidebar--open { transform: translateX(0); }
    .panel { display: flex; flex-direction: column; overflow: hidden; transition: width 0.25s cubic-bezier(0.4,0,0.2,1); }
    .panel--open { width: 260px; flex-shrink: 0; }
    .panel--closed { width: 36px; flex-shrink: 0; }
    .panel-divider { width: 1px; background: rgba(255,255,255,0.05); flex-shrink: 0; }
    .panel-header { display: flex; align-items: center; gap: 6px; padding: 11px 12px 10px; border-bottom: 1px solid rgba(255,255,255,0.05); flex-shrink: 0; min-height: 40px; }
    .panel--closed .panel-header { flex-direction: column; align-items: center; justify-content: flex-start; padding: 10px 0; gap: 4px; border-bottom: none; height: 100%; overflow: hidden; }
    .panel-title-vertical { writing-mode: vertical-rl; text-orientation: mixed; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.3); flex: 1; margin-top: 6px; }
    .panel--closed .panel-chevron { transform: rotate(-90deg); }
    .panel--closed .panel-chevron.rotated { transform: rotate(90deg); }
    .panel-header--clickable { cursor: pointer; user-select: none; transition: background 0.1s; }
    .panel-header--clickable:hover { background: rgba(255,255,255,0.03); }
    .panel-chevron { color: rgba(255,255,255,0.25); flex-shrink: 0; transition: transform 0.2s ease; }
    .panel-chevron.rotated { transform: rotate(-90deg); }
    .panel-title { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.5); flex: 1; }
    .tab-badge { background: rgba(255,255,255,0.07); border-radius: 10px; padding: 1px 6px; font-size: 10px; color: rgba(255,255,255,0.35); }
    .btn-icon-add { display: flex; align-items: center; justify-content: center; width: 22px; height: 22px; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); border-radius: 5px; color: rgba(255,255,255,0.5); cursor: pointer; transition: all 0.1s; flex-shrink: 0; }
    .btn-icon-add:hover { background: rgba(255,255,255,0.1); color: rgba(255,255,255,0.9); }
    .panel-content { flex: 1; overflow-y: auto; padding: 8px; display: flex; flex-direction: column; gap: 3px; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.07) transparent; min-height: 0; }
    .section-label { display: flex; align-items: center; gap: 5px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.25); padding: 5px 3px 2px; }
    /* Derived patrol status pill shown next to the patrol name in the Officer
       list (sidebar section-label) — see getPatrolStatus(). */
    .patrol-status-pill { margin-left: auto; font-size: 8px; font-weight: 700; letter-spacing: 0.3px; text-transform: uppercase; padding: 2px 6px; border-radius: 8px; border: 1px solid; }
    .section-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
    .empty-hint { text-align: center; font-size: 11px; color: rgba(255,255,255,0.18); padding: 20px 10px; line-height: 1.6; }
    .officer-card { display: flex; align-items: center; gap: 7px; padding: 7px 8px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 6px; cursor: grab; transition: background 0.1s, border-color 0.1s; user-select: none; flex-shrink: 0; }
    .officer-card:hover { background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.09); }
    .officer-card:active { cursor: grabbing; }
    .officer-card--assigned { opacity: 0.65; }
    .officer-drag-handle { flex-shrink: 0; font-size: 14px; line-height: 1; color: rgba(255,255,255,0.2); cursor: grab; }
    .officer-info { flex: 1; min-width: 0; }
    .officer-name { display: block; font-size: 11px; font-weight: 500; color: rgba(255,255,255,0.82); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .officer-meta { display: block; font-size: 10px; color: rgba(255,255,255,0.28); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .officer-kick { background: transparent; border: none; color: rgba(255,255,255,0.15); font-size: 15px; line-height: 1; cursor: pointer; padding: 0 2px; border-radius: 3px; transition: all 0.1s; flex-shrink: 0; }
    .officer-kick:hover { color: #ef4444; background: rgba(239,68,68,0.1); }
    .officer-search { display: flex; align-items: center; gap: 6px; padding: 7px 8px; border-top: 1px solid rgba(255,255,255,0.06); background: rgba(255,255,255,0.02); flex-shrink: 0; }
    .officer-search svg { flex-shrink: 0; color: rgba(255,255,255,0.25); }
    .officer-search-input { flex: 1; min-width: 0; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); border-radius: 5px; padding: 5px 8px; color: rgba(255,255,255,0.85); font-size: 11px; outline: none; }
    .officer-search-input:focus { border-color: rgba(255,255,255,0.2); }
    .officer-search-input::placeholder { color: rgba(255,255,255,0.25); }
    .officer-search-clear { background: transparent; border: none; color: rgba(255,255,255,0.3); font-size: 14px; line-height: 1; cursor: pointer; padding: 0 2px; flex-shrink: 0; }
    .officer-search-clear:hover { color: rgba(255,255,255,0.8); }

    /* ─── Officer Status ─────────────────────────────────────────────────── */
    /* "My Status" picker — sets the local officer's own availability */
    .my-status { position: relative; padding: 6px 8px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
    .my-status-trigger { display: flex; align-items: center; gap: 7px; width: 100%; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 6px; padding: 6px 8px; cursor: pointer; transition: background 0.1s, border-color 0.1s; box-sizing: border-box; }
    .my-status-trigger:hover { background: rgba(255,255,255,0.07); border-color: rgba(255,255,255,0.14); }
    .my-status-trigger.disabled { opacity: 0.5; pointer-events: none; }
    .my-status-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; box-shadow: 0 0 6px currentColor; }
    .my-status-label { flex: 1; min-width: 0; text-align: left; font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.85); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .my-status-chevron { color: rgba(255,255,255,0.3); flex-shrink: 0; transition: transform 0.15s ease; }
    .my-status-chevron.rotated { transform: rotate(180deg); }
    .my-status-popover { position: absolute; top: calc(100% + 4px); left: 8px; right: 8px; z-index: 50; background: #161618; border: 1px solid rgba(255,255,255,0.1); border-radius: 7px; padding: 5px; box-shadow: 0 10px 28px rgba(0,0,0,0.5); display: flex; flex-direction: column; gap: 2px; animation: status-popover-in 0.12s ease-out; }
    @keyframes status-popover-in { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
    .my-status-option { display: flex; align-items: center; gap: 7px; background: transparent; border: none; border-radius: 5px; padding: 6px 7px; font-size: 11px; font-weight: 500; color: rgba(255,255,255,0.75); cursor: pointer; text-align: left; transition: background 0.1s; }
    .my-status-option:hover { background: rgba(255,255,255,0.07); }
    .my-status-option.active { background: rgba(255,255,255,0.09); color: rgba(255,255,255,0.95); }
    .my-status-note-input { margin-top: 3px; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); border-radius: 5px; padding: 6px 8px; color: rgba(255,255,255,0.9); font-size: 11px; outline: none; box-sizing: border-box; }
    .my-status-note-input:focus { border-color: rgba(255,255,255,0.2); }
    .my-status-note-input::placeholder { color: rgba(255,255,255,0.25); }

    /* Status filter chips */
    .status-filter-row { display: flex; flex-wrap: wrap; gap: 4px; padding: 6px 8px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
    .status-chip { display: flex; align-items: center; gap: 4px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 3px 8px 3px 6px; font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.45); cursor: pointer; transition: all 0.12s; }
    .status-chip:hover { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.7); }
    /* CEF doesn't support color-mix(); active-state tint/border/text color are
       set inline per-chip from JS instead (see --chip-* custom props below). */
    .status-chip.active { background: var(--chip-bg); border-color: var(--chip-border); color: var(--chip-color); }
    .status-chip-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }

    /* Per-officer status dot + badge inside each officer-card */
    .officer-status-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; box-shadow: 0 0 5px currentColor; }
    .officer-status-badge { flex-shrink: 0; font-size: 9px; font-weight: 700; letter-spacing: 0.2px; padding: 2px 6px; border-radius: 9px; border: 1px solid; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 84px; }

    /* Officer popup "Availability" row (buildOfficerPopupHtml) */
    :global(.op-availability) { font-weight: 600; font-size: 10px; }
    :global(.op-availability-since) { color: rgba(255,255,255,0.25); font-size: 9px; margin-left: 5px; }

    /* Status dot pinned onto the bodycam map marker (tracking-dot / tracking-badge) */
    :global(.tracking-status-dot) { position: absolute; bottom: -2px; right: -2px; width: 7px; height: 7px; border-radius: 50%; border: 1.5px solid rgba(10,10,12,0.9); box-shadow: 0 0 4px rgba(0,0,0,0.6); }
    .create-form { display: flex; flex-direction: column; gap: 7px; padding: 8px; background: rgba(255,255,255,0.03); border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
    .create-input { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); border-radius: 5px; padding: 6px 9px; color: rgba(255,255,255,0.9); font-size: 12px; outline: none; width: 100%; box-sizing: border-box; }
    .create-input:focus { border-color: rgba(255,255,255,0.2); }
    .color-row { display: flex; gap: 5px; flex-wrap: wrap; }
    .color-swatch { width: 18px; height: 18px; border-radius: 50%; border: 2px solid transparent; cursor: pointer; transition: transform 0.1s; }
    .color-swatch:hover { transform: scale(1.15); }
    .color-swatch.selected { border-color: rgba(255,255,255,0.75); transform: scale(1.1); }
    .create-actions { display: flex; gap: 5px; }
    .btn-create { flex: 1; padding: 6px; background: rgba(var(--accent-rgb),0.14); border: 1px solid rgba(var(--accent-rgb),0.28); border-radius: 5px; color: rgba(255,255,255,0.8); font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
    .btn-create:hover { background: rgba(var(--accent-rgb),0.24); }
    .btn-cancel { padding: 6px 10px; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.06); border-radius: 5px; color: rgba(255,255,255,0.35); font-size: 11px; cursor: pointer; transition: all 0.1s; }
    .btn-cancel:hover { background: rgba(255,255,255,0.08); color: rgba(255,255,255,0.7); }
    .patrol-card { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 7px; overflow: hidden; transition: border-color 0.15s, background 0.15s; margin-bottom: 2px; min-height: 36px; flex-shrink: 0; }
    .patrol-card.drag-over { border-color: rgba(255,255,255,0.22); background: rgba(255,255,255,0.06); }
    .patrol-card.sort-over { border-color: rgba(var(--accent-rgb),0.5); background: rgba(var(--accent-rgb),0.06); }
    .patrol-header { display: flex; align-items: center; gap: 7px; padding: 7px 8px; }
    .patrol-color-bar { width: 3px; height: 20px; border-radius: 2px; flex-shrink: 0; }
    .patrol-name { flex: 1; font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.82); cursor: default; }
    .patrol-name-edit { flex: 1; background: rgba(255,255,255,0.07); border: 1px solid rgba(255,255,255,0.15); border-radius: 3px; padding: 1px 5px; font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.9); outline: none; }
    .patrol-count { font-size: 10px; font-weight: 700; color: rgba(255,255,255,0.22); background: rgba(255,255,255,0.05); border-radius: 10px; padding: 1px 6px; }
    /* Derived patrol status (Patrols panel) — see getPatrolStatus() */
    .patrol-status-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; box-shadow: 0 0 5px currentColor; }
    .patrol-delete { background: transparent; border: none; color: rgba(255,255,255,0.18); cursor: pointer; padding: 2px; display: flex; align-items: center; border-radius: 3px; transition: all 0.1s; }
    .patrol-delete:hover { color: #ef4444; background: rgba(239,68,68,0.1); }
    .patrol-sort-handle { font-size: 13px; line-height: 1; color: rgba(255,255,255,0.18); cursor: grab; flex-shrink: 0; padding: 0 2px; }
    .patrol-sort-handle:active { cursor: grabbing; }
    .patrol-sort-arrows { display: flex; flex-direction: column; gap: 1px; flex-shrink: 0; }
    .sort-arrow { background: transparent; border: none; color: rgba(255,255,255,0.2); font-size: 8px; line-height: 1; cursor: pointer; padding: 1px 2px; border-radius: 2px; transition: all 0.1s; }
    .sort-arrow:hover:not(:disabled) { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.08); }
    .sort-arrow:disabled { opacity: 0.2; cursor: default; }
    .drop-hint { font-size: 10px; color: rgba(255,255,255,0.15); text-align: center; padding: 7px; border-top: 1px dashed rgba(255,255,255,0.05); }
    .patrol-member { display: flex; align-items: center; gap: 5px; padding: 4px 8px 4px 18px; border-top: 1px solid rgba(255,255,255,0.04); }
    .member-name { font-size: 11px; color: rgba(255,255,255,0.65); flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .member-meta { font-size: 10px; color: rgba(255,255,255,0.22); white-space: nowrap; }

    .zone-controls { display: flex; align-items: center; padding: 4px 8px 6px; border-top: 1px solid rgba(255,255,255,0.04); }
    .zone-btn { display: inline-flex; align-items: center; gap: 4px; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.07); border-radius: 5px; padding: 3px 7px; font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.4); cursor: pointer; transition: all 0.12s; letter-spacing: 0.3px; }
    .zone-btn--draw:hover { background: rgba(56,189,248,0.1); border-color: rgba(56,189,248,0.3); color: rgba(56,189,248,0.9); }
    .zone-btn--edit { padding: 3px 5px; }
    .zone-btn--edit:hover { background: rgba(234,179,8,0.1); border-color: rgba(234,179,8,0.3); color: rgba(234,179,8,0.9); }
    .zone-btn--clear { margin-left: auto; background: transparent; border: none; color: rgba(255,255,255,0.2); padding: 2px 4px; }
    .zone-btn--clear:hover { color: #ef4444; background: rgba(239,68,68,0.1); }
    .zone-info { display: flex; align-items: center; gap: 4px; flex: 1; min-width: 0; }
    .zone-badge { display: inline-flex; align-items: center; gap: 4px; flex: 1; min-width: 0; padding: 2px 6px; border-radius: 4px; border: 1px solid; font-size: 10px; font-weight: 600; letter-spacing: 0.2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .zone-indicator { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
    .zone-pts { font-size: 10px; color: rgba(255,255,255,0.3); flex: 1; }
    .zone-drawing-active { display: flex; align-items: center; gap: 6px; font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.5); font-style: italic; }
    .zone-pulse { width: 6px; height: 6px; border-radius: 50%; animation: pulse-dot 1.2s ease-in-out infinite; }

    @keyframes anim-assign-in { 0% { background: rgba(34,197,94,0.18); box-shadow: 0 0 0 1px rgba(34,197,94,0.35); transform: scaleX(0.97); } 40% { background: rgba(34,197,94,0.10); box-shadow: 0 0 0 1px rgba(34,197,94,0.2); transform: scaleX(1.01); } 100% { background: transparent; box-shadow: none; transform: scaleX(1); } }
    @keyframes anim-remove-in { 0% { background: rgba(239,68,68,0.15); box-shadow: 0 0 0 1px rgba(239,68,68,0.3); opacity:1; transform: scaleX(1); } 60% { background: rgba(239,68,68,0.08); opacity:0.7; transform: scaleX(0.98); } 100% { background: transparent; box-shadow: none; opacity:1; transform: scaleX(1); } }
    @keyframes slide-down { 0% { opacity:0; transform:translateY(-6px); } 100% { opacity:1; transform:translateY(0); } }
    .anim-assigned { animation: anim-assign-in 0.65s cubic-bezier(0.22,1,0.36,1) forwards, slide-down 0.25s ease-out; }
    .anim-removed  { animation: anim-remove-in 0.65s cubic-bezier(0.22,1,0.36,1) forwards, slide-down 0.25s ease-out; }
</style>