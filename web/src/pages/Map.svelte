<script lang="ts">
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

    // Default true = everyone can use it unless authService explicitly denies
    let canViewPatrols   = $derived(authService ? (authService.hasPermission("map_patrols_view")   ?? true) : true);
    let canManagePatrols = $derived(authService ? (authService.hasPermission("map_patrols_manage") ?? true) : true);
    let canEditPatrols   = $derived(authService ? (authService.hasPermission("map_patrols_edit")   ?? true) : true);

    // ─── Map state ───────────────────────────────────────────────────────────
    let mapContainer: HTMLDivElement | null = null;
    let map: L.Map | null = null;
    let mapInitialized = false;
    let refreshTimer: ReturnType<typeof setInterval> | null = null;

    let tabVisible = $state(true);
    let showVehicles = $state(localStorage.getItem("mdt_map_vehicles") !== "false");
    let showBodycams = $state(localStorage.getItem("mdt_map_bodycams") !== "false");
    let showPatrols  = $state(localStorage.getItem("mdt_map_patrols_layer") !== "false");
    let iconStyle = $state<"dot" | "badge">(
        (localStorage.getItem("mdt_map_icon_style") as "dot" | "badge") ?? "dot"
    );

    let vehicleLayer = L.layerGroup();
    let bodycamLayer = L.layerGroup();
    let patrolLayer = L.layerGroup();

    // ─── Sidebar state ────────────────────────────────────────────────────────
    // localStorage as default – overridden by Lua client on open
    let sidebarOpen  = $state(localStorage.getItem("mdt_map_sidebar")   !== "false");
    let officersOpen = $state(localStorage.getItem("mdt_map_officers")  !== "false");
    let patrolsOpen  = $state(localStorage.getItem("mdt_map_patrols")   !== "false");

    function toggleSidebar() {
        sidebarOpen = !sidebarOpen;
        localStorage.setItem("mdt_map_sidebar", String(sidebarOpen));
        // Also save in Lua client (survives resource restart)
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

    // Sidebar-Breite: 260px pro offenem Panel + 36px pro zugeklapptem + 1px Divider
    let sidebarWidth = $derived(
        (officersOpen ? 260 : 36) + 1 + (patrolsOpen ? 260 : 36)
    );

    // ─── Patrol types ─────────────────────────────────────────────────────────
    type Bodycam = {
        citizenid: string;
        name: string;
        callsign?: string;
        rank?: string;
        coords: { x: number; y: number; z: number };
        heading?: number;
    };

    type Patrol = {
        id: string;
        name: string;
        color: string;
        memberIds: string[];
    };

    // ─── Officers & Patrols ───────────────────────────────────────────────────
    let officers = $state<Bodycam[]>([]);
    let patrols = $state<Patrol[]>([]);

    // New patrol form
    let newPatrolName = $state("");
    let newPatrolColor = $state("#38bdf8");
    let showCreateForm = $state(false);

    // Edit patrol name
    let editingPatrolId = $state<string | null>(null);
    let editingPatrolName = $state("");

    const PATROL_COLORS = [
        "#38bdf8", "#f97316", "#a855f7", "#22c55e",
        "#ef4444", "#eab308", "#ec4899", "#14b8a6"
    ];

    // ─── Helpers ──────────────────────────────────────────────────────────────
    const offsetX = 13;
    const offsetY = 5;

    function toMapLatLng(coords: { x: number; y: number }) {
        return [coords.y - offsetY, coords.x + offsetX];
    }

    function getTrackConfig(kind: "vehicle" | "bodycam") {
        if (kind === "vehicle") return { color: "#f97316", fill: "#fb923c", label: "V" };
        return { color: "#a855f7", fill: "#c084fc", label: "B" };
    }

    function createMarker(
        kind: "vehicle" | "bodycam",
        coords: { x: number; y: number },
        label: string,
        heading?: number,
        patrolColor?: string
    ) {
        const config = getTrackConfig(kind);
        const dotColor = patrolColor ?? config.fill;
        const borderColor = patrolColor ? patrolColor : config.color;
        const latLng = toMapLatLng(coords);
        const rotation = heading != null ? 360 - heading : 0;
        const hasHeading = heading != null;

        if (iconStyle === "badge") {
            return L.marker(latLng as any, {
                icon: L.divIcon({
                    className: "",
                    html: `
                        <div class="tracking-badge-wrap" style="transform: rotate(${rotation}deg)">
                            <div class="tracking-icon tracking-${kind}" style="${patrolColor ? `background:${patrolColor}` : ""}">
                                <span style="transform: rotate(-${rotation}deg)">${config.label}</span>
                            </div>
                            ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}" style="${patrolColor ? `border-bottom-color:${patrolColor}` : ""}"></div>` : ""}
                        </div>
                    `,
                    iconSize: [28, 28],
                    iconAnchor: [14, 14],
                }),
            }).bindTooltip(label, { direction: "top", offset: [0, -14] });
        }

        return L.marker(latLng as any, {
            icon: L.divIcon({
                className: "",
                html: `
                    <div class="tracking-dot-wrap" style="transform: rotate(${rotation}deg)">
                        <div class="tracking-dot" style="background:${dotColor}; border: 2px solid ${borderColor}"></div>
                        ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}" style="${patrolColor ? `border-bottom-color:${patrolColor}` : ""}"></div>` : ""}
                    </div>
                `,
                iconSize: [20, 20],
                iconAnchor: [10, 10],
            }),
        }).bindTooltip(label, { direction: "top", offset: [0, -10] });
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

    // ─── Patrol map labels ────────────────────────────────────────────────────
    function refreshPatrolLabels() {
        patrolLayer.clearLayers();
        if (!showPatrols) return;

        for (const patrol of patrols) {
            const members = officers.filter(o => patrol.memberIds.includes(o.citizenid));
            if (members.length === 0) continue;

            // Centroid berechnen
            const centroid = members.reduce(
                (acc, o) => ({ x: acc.x + o.coords.x, y: acc.y + o.coords.y }),
                { x: 0, y: 0 }
            );
            centroid.x /= members.length;
            centroid.y /= members.length;

            // Place label at the member closest to the centroid
            
            const anchor = members.reduce((closest, o) => {
                const dx = o.coords.x - centroid.x;
                const dy = o.coords.y - centroid.y;
                const cdx = closest.coords.x - centroid.x;
                const cdy = closest.coords.y - centroid.y;
                return (dx*dx + dy*dy) < (cdx*cdx + cdy*cdy) ? o : closest;
            });

            const latLng = toMapLatLng(anchor.coords);

            L.marker(latLng as any, {
                icon: L.divIcon({
                    className: "",
                    html: `<div class="patrol-label" style="border-color:${patrol.color};color:${patrol.color}">${patrol.name}</div>`,
                    iconSize: [null as any, null as any],
                    iconAnchor: [0, 24], // offset upward above the marker
                }),
                interactive: false,
                zIndexOffset: -100,
            }).addTo(patrolLayer);
        }
    }

    // ─── Refresh tracking ─────────────────────────────────────────────────────
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

            // Bei Fehler oder leerem Response bestehende Daten behalten
            const success = (response as any).success;
            if (success === false) return;

            const data = (response as any).data ?? response;
            const bodycams = (data as any).bodycams;
            const vehicles = (data as any).vehicles;

            // Nur updaten wenn der Server wirklich Daten geliefert hat
            if (!Array.isArray(bodycams) && !Array.isArray(vehicles)) return;

            vehicleLayer.clearLayers();
            bodycamLayer.clearLayers();

            const freshOfficers: Bodycam[] = [];

            for (const bodycam of bodycams || []) {
                const coords = normalizeCoords((bodycam as any).coords);
                if (!coords) continue;

                const bc: Bodycam = {
                    citizenid: bodycam.citizenid ?? bodycam.name ?? String(Math.random()),
                    name: bodycam.name ?? "",
                    callsign: bodycam.callsign,
                    rank: bodycam.rank,
                    coords: { x: coords.x, y: coords.y, z: bodycam.coords?.z ?? 0 },
                    heading: bodycam.heading,
                };
                freshOfficers.push(bc);

                if (showBodycams) {
                    const patrol = getOfficerPatrol(bc.citizenid);
                    const label = `${[bc.rank, bc.callsign].filter(Boolean).join(" | ")}${bc.name ? " | " + bc.name : ""}`;
                    const color = patrol?.color ?? "#6b7280";
                    createMarker("bodycam", coords, label, bodycam.heading, color).addTo(bodycamLayer);
                }
            }

            officers = freshOfficers;

            if (showVehicles) {
                for (const vehicle of vehicles || []) {
                    const coords = normalizeCoords((vehicle as any).coords);
                    if (!coords) continue;
                    const label = `${(vehicle as any).plate || ""}`.trim();
                    createMarker("vehicle", coords, label, (vehicle as any).heading).addTo(vehicleLayer);
                }
            }

            refreshPatrolLabels();
        } catch {
            // Timeout oder Netzwerkfehler – bestehende Officer/Marker behalten
        }
    }

    // ─── Mouse-based Drag System (kein HTML5 draggable – CEF-kompatibel) ──────
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

    // Ghost element for visual drag feedback
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

    // Patrol-Card-Elemente per data-patrol-id finden
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
            // Only count as drag after 5px movement
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
                    // Auf Officers-Panel losgelassen → aus Streife entfernen
                    const el = document.elementFromPoint(e.clientX, e.clientY);
                    if (el?.closest(".panel-officers")) {
                        removeFromPatrol(drag.id);
                    }
                }
            } else if (drag.kind === "patrol" && pid && pid !== drag.id) {
                // Streifen sortieren
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
                // Short delay to ensure MDTOpen is set in Lua client
                setTimeout(() => {
                    refreshTracking();
                    loadPatrols();
                }, 300);
            }
            return;
        }

        if (type === "mapUiState") {
            // Lua client state overrides localStorage (authoritative after resource restart)
            if (typeof data?.sidebarOpen  === "boolean") { sidebarOpen  = data.sidebarOpen;  localStorage.setItem("mdt_map_sidebar",  String(sidebarOpen)); }
            if (typeof data?.officersOpen === "boolean") { officersOpen = data.officersOpen; localStorage.setItem("mdt_map_officers", String(officersOpen)); }
            if (typeof data?.patrolsOpen  === "boolean") { patrolsOpen  = data.patrolsOpen;  localStorage.setItem("mdt_map_patrols",  String(patrolsOpen)); }
            return;
        }

        if (type === "syncPatrols") {
            // Server sends sorted array
            patrols = Array.isArray(data) ? data as Patrol[] : Object.values(data as Record<string, Patrol>);
            refreshPatrolLabels();
            // Trigger animation for all clients based on server hint
            const msg = event.data as any;
            if (msg.action === "assigned" && msg.citizenid) flashAssigned(msg.citizenid);
            if (msg.action === "removed"  && msg.citizenid) flashRemoved(msg.citizenid);
        }
    }

    // ─── Assignment animation state ───────────────────────────────────────────
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
        } catch {
            globalNotifications.error("Failed to load patrols");
        }
    }

    // Doppelter Name?
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
        } catch { /* Server broadcasts syncPatrols */ }
        newPatrolName = "";
        showCreateForm = false;
    }

    async function deletePatrol(id: string) {
        try {
            await fetchNui(NUI_EVENTS.MAP.DELETE_PATROL, { id }, { success: true });
        } catch { /* Server broadcastet syncPatrols */ }
    }

    async function renamePatrolOnServer(id: string, name: string) {
        if (patrolNameExists(name, id)) {
            globalNotifications.error(`Patrol "${name}" already exists`);
            return;
        }
        try {
            await fetchNui(NUI_EVENTS.MAP.RENAME_PATROL, { id, name }, { success: true });
        } catch { /* Server broadcastet syncPatrols */ }
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

    // Move patrol up/down in the list
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

    // ─── NUI Message Listener (Server → Client → NUI sync) ───────────────────
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
        map.setView([-300, -1500], 4);
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
        patrolLayer = L.layerGroup().addTo(map);

        syncLayerVisibility();
        refreshTracking();
        refreshTimer = setInterval(refreshTracking, 4500);
    }

    function getMapBounds(map: Map) {
        const sw = map.unproject([0, 1024], 2);
        const ne = map.unproject([1024, 0], 2);
        return new LatLngBounds(sw, ne);
    }

    onMount(() => {
        document.addEventListener("visibilitychange", handleVisibilityChange);
        window.addEventListener("message", handleNuiMessage);
        window.addEventListener("mousemove", onGlobalMouseMove);
        window.addEventListener("mouseup", onGlobalMouseUp);
        initializeMap();
        loadPatrols();
    });

    onDestroy(() => {
        document.removeEventListener("visibilitychange", handleVisibilityChange);
        window.removeEventListener("message", handleNuiMessage);
        window.removeEventListener("mousemove", onGlobalMouseMove);
        window.removeEventListener("mouseup", onGlobalMouseUp);
        removeGhost();
        if (map) { map.remove(); map = null; mapInitialized = false; }
        if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
    });

    $effect(() => { syncLayerVisibility(); });
    $effect(() => { iconStyle; refreshTracking(); });
    $effect(() => { showPatrols; refreshPatrolLabels(); });
</script>

<div class="map-page">
    <div class="map-wrapper" style="--sidebar-width:{sidebarWidth}px">

        <!-- ── Left Controls ────────────────────────────────────── -->
        <div class="map-controls">
            <span class="controls-header">Tracking</span>

            <div class="controls-group">
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showVehicles} onchange={() => localStorage.setItem("mdt_map_vehicles", String(showVehicles))} />
                    <span class="toggle-label">Vehicles</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showBodycams} onchange={() => localStorage.setItem("mdt_map_bodycams", String(showBodycams))} />
                    <span class="toggle-label">Bodycams</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showPatrols} onchange={() => localStorage.setItem("mdt_map_patrols_layer", String(showPatrols))} />
                    <span class="toggle-label">Patrols</span>
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
                <span class="legend-item bodycam-unassigned">Unassigned</span>
                {#each patrols.filter(p => p.memberIds.length > 0) as patrol}
                    <span class="legend-item" style="--dot:{patrol.color}">{patrol.name}</span>
                {/each}
            </div>
        </div>

        <!-- ── Map ────────────────────────────────────────────────── -->
        <div bind:this={mapContainer} class="map-container" class:map-no-pointer={isDragging}></div>

        <!-- ── Sidebar Toggle Button ──────────────────────────────── -->
        {#if canViewPatrols}
        <button
            class="sidebar-toggle"
            class:open={sidebarOpen}
            onclick={() => toggleSidebar()}
            type="button"
            title={sidebarOpen ? "Close sidebar" : "Manage patrols"}
        >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                {#if sidebarOpen}
                    <path d="M10 3L5 8L10 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                {:else}
                    <path d="M6 3L11 8L6 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                {/if}
            </svg>
            {#if !sidebarOpen}
                <span class="sidebar-toggle-label">Patrols</span>
            {/if}
        </button>

        <!-- ── Right Sidebar ──────────────────────────────────────── -->
        <div class="sidebar" class:sidebar--open={sidebarOpen}>

            <!-- ── Officers Panel ────────────────────────────────── -->
            <div class="panel" class:panel--open={officersOpen} class:panel--closed={!officersOpen}>
                <div class="panel-header panel-header--clickable" onclick={toggleOfficers}>
                    {#if officersOpen}
                        <span class="panel-title">Officers</span>
                        <span class="tab-badge">{officers.length}</span>
                    {:else}
                        <span class="panel-title-vertical">Officers</span>
                    {/if}
                    <svg class="panel-chevron" class:rotated={!officersOpen} width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                        <path d="M2 4.5l4 4 4-4"/>
                    </svg>
                </div>
                {#if officersOpen}
                <div class="panel-content panel-officers-content">

                    {#if officers.length === 0}
                        <div class="empty-hint">No officers on duty.</div>
                    {/if}

                    <!-- Nicht zugeteilt -->
                    {#if unassignedOfficers().length > 0}
                        <div class="section-label">Unassigned ({unassignedOfficers().length})</div>
                        {#each unassignedOfficers() as officer (officer.citizenid)}
                            <div
                                class="officer-card"
                                class:dragging={drag?.kind === "officer" && drag.id === officer.citizenid && drag.active}
                                class:anim-removed={recentlyRemoved.has(officer.citizenid)}
                                onmousedown={(e) => canManagePatrols && onMouseDown(e, "officer", officer.citizenid, officer.name)}
                                style={canManagePatrols ? "cursor:grab" : "cursor:default"}
                            >
                                {#if canManagePatrols}<div class="officer-drag-handle">⠿</div>{/if}
                                <div class="officer-info">
                                    <span class="officer-name">{officer.name}</span>
                                    <span class="officer-meta">{[officer.rank, officer.callsign].filter(Boolean).join(" · ")}</span>
                                </div>
                            </div>
                        {/each}
                    {/if}

                    <!-- In Streifen -->
                    {#each patrols as patrol}
                        {@const members = patrol.memberIds.map(id => officers.find(o => o.citizenid === id)).filter(Boolean)}
                        {#if members.length > 0}
                            <div class="section-label" style="margin-top:8px">
                                <span class="section-dot" style="background:{patrol.color}"></span>
                                {patrol.name}
                            </div>
                            {#each members as officer (officer!.citizenid)}
                                <div
                                    class="officer-card officer-card--assigned"
                                    class:dragging={drag?.kind === "officer" && drag.id === officer!.citizenid && drag.active}
                                    class:anim-assigned={recentlyAssigned.has(officer!.citizenid)}
                                    style="border-left: 2px solid {patrol.color};{canManagePatrols ? '' : 'cursor:default'}"
                                    onmousedown={(e) => canManagePatrols && onMouseDown(e, "officer", officer!.citizenid, officer!.name)}
                                >
                                    {#if canManagePatrols}<div class="officer-drag-handle">⠿</div>{/if}
                                    <div class="officer-info">
                                        <span class="officer-name">{officer!.name}</span>
                                        <span class="officer-meta">{[officer!.rank, officer!.callsign].filter(Boolean).join(" · ")}</span>
                                    </div>
                                    {#if canManagePatrols}
                                        <button class="officer-kick" onmousedown={(e) => e.stopPropagation()} onclick={() => removeFromPatrol(officer!.citizenid)} title="Remove">×</button>
                                    {/if}
                                </div>
                            {/each}
                        {/if}
                    {/each}

                </div>
                {/if}
            </div>

            <!-- ── Divider ────────────────────────────────────────── -->
            <div class="panel-divider"></div>

            <!-- ── Patrols Panel ─────────────────────────────────── -->
            <div class="panel" class:panel--open={patrolsOpen} class:panel--closed={!patrolsOpen}>
                <div class="panel-header panel-header--clickable" onclick={togglePatrols}>
                    {#if patrolsOpen}
                        <span class="panel-title">Patrols</span>
                        <span class="tab-badge">{patrols.length}</span>
                        {#if canEditPatrols}
                            <button class="btn-icon-add" onmousedown={(e) => e.stopPropagation()} onclick={(e) => { e.stopPropagation(); showCreateForm = !showCreateForm; }} type="button" title="New patrol">
                                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                                    <line x1="6" y1="1" x2="6" y2="11"/>
                                    <line x1="1" y1="6" x2="11" y2="6"/>
                                </svg>
                            </button>
                        {/if}
                    {:else}
                        <span class="panel-title-vertical">Patrols</span>
                    {/if}
                    <svg class="panel-chevron" class:rotated={!patrolsOpen} width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                        <path d="M2 4.5l4 4 4-4"/>
                    </svg>
                </div>

                {#if patrolsOpen}
                {#if showCreateForm && canEditPatrols}
                    <div class="create-form">
                        <input
                            class="create-input"
                            placeholder="Patrol name…"
                            bind:value={newPatrolName}
                            onkeydown={(e) => e.key === "Enter" && createPatrol()}
                            autofocus
                        />
                        <div class="color-row">
                            {#each PATROL_COLORS as c}
                                <button
                                    class="color-swatch"
                                    class:selected={newPatrolColor === c}
                                    style="background:{c}"
                                    onclick={() => (newPatrolColor = c)}
                                    type="button"
                                ></button>
                            {/each}
                        </div>
                        <div class="create-actions">
                            <button class="btn-create" onclick={createPatrol} type="button">Create</button>
                            <button class="btn-cancel" onclick={() => (showCreateForm = false)} type="button">Cancel</button>
                        </div>
                    </div>
                {/if}

                <div class="panel-content">
                    {#if patrols.length === 0}
                        <div class="empty-hint">No patrols yet.<br/>Press + above.</div>
                    {/if}

                    {#each patrols as patrol, idx (patrol.id)}
                        <div
                            class="patrol-card"
                            class:drag-over={dragOverPatrolId === patrol.id}
                            class:sort-over={dragOverPatrolSortId === patrol.id}
                            data-patrol-id={patrol.id}
                        >
                            <div class="patrol-header">
                                {#if canEditPatrols}
                                    <div
                                        class="patrol-sort-handle"
                                        title="Drag to reorder"
                                        onmousedown={(e) => onMouseDown(e, "patrol", patrol.id, patrol.name)}
                                    >⠿</div>
                                {/if}
                                <div class="patrol-color-bar" style="background:{patrol.color}"></div>
                                {#if editingPatrolId === patrol.id && canEditPatrols}
                                    <input
                                        class="patrol-name-edit"
                                        bind:value={editingPatrolName}
                                        onblur={() => { const n = editingPatrolName.trim(); if (n) renamePatrolOnServer(patrol.id, n); editingPatrolId = null; }}
                                        onkeydown={(e) => { if (e.key === "Enter") { const n = editingPatrolName.trim(); if (n) renamePatrolOnServer(patrol.id, n); editingPatrolId = null; } if (e.key === "Escape") editingPatrolId = null; }}
                                        autofocus
                                    />
                                {:else}
                                    <span
                                        class="patrol-name"
                                        ondblclick={() => { if (canEditPatrols) { editingPatrolId = patrol.id; editingPatrolName = patrol.name; } }}
                                        title={canEditPatrols ? "Double-click to rename" : ""}
                                    >{patrol.name}</span>
                                {/if}
                                <span class="patrol-count">{patrol.memberIds.length}</span>
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

                            {#if patrol.memberIds.length === 0}
                                {#if canManagePatrols}
                                    <div class="drop-hint">Drag an officer here →</div>
                                {/if}
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
    /* ── Leaflet global overrides ───────────────────────────────── */
    :global(.leaflet-popup-content-wrapper) {
        background: var(--dark-bg);
        color: rgba(255, 255, 255, 0.8);
        border-radius: 8px;
        border: 1px solid rgba(255, 255, 255, 0.06);
        box-shadow: none;
    }
    :global(.leaflet-popup-tip) { background: var(--dark-bg); }
    :global(.leaflet-tooltip) {
        background: var(--dark-bg);
        color: rgba(255, 255, 255, 0.8);
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 6px;
        font-size: 11px;
        padding: 4px 8px;
        box-shadow: none;
    }
    :global(.leaflet-tooltip-top::before) { border-top-color: #111111; }
    :global(.leaflet-control-zoom) {
        border: 1px solid rgba(255, 255, 255, 0.06) !important;
        border-radius: 8px !important;
        overflow: hidden;
        box-shadow: none !important;
    }
    :global(.leaflet-control-zoom a) {
        background: rgba(17, 17, 17, 0.92) !important;
        color: rgba(255, 255, 255, 0.6) !important;
        border-color: rgba(255, 255, 255, 0.04) !important;
        width: 30px !important; height: 30px !important;
        line-height: 30px !important; font-size: 14px !important;
    }
    :global(.leaflet-control-zoom a:hover) {
        background: rgba(255, 255, 255, 0.08) !important;
        color: rgba(255, 255, 255, 0.9) !important;
    }

    /* ── Patrol label (on map) ─────────────────────────────────── */
    :global(.patrol-label) {
        background: rgba(0, 0, 0, 0.55);
        border: 1px solid;
        border-radius: 4px;
        padding: 2px 6px;
        font-size: 9px;
        font-weight: 600;
        letter-spacing: 0.4px;
        text-transform: uppercase;
        white-space: nowrap;
        pointer-events: none;
        opacity: 0.7;
    }

    /* ── Marker globals ────────────────────────────────────────── */
    :global(.tracking-icon) {
        width: 22px; height: 22px;
        border-radius: 5px;
        display: flex; align-items: center; justify-content: center;
        font-size: 11px; font-weight: 700; color: #0c0c0c;
    }
    :global(.tracking-vehicle) { background: #f97316; }
    :global(.tracking-bodycam) { background: #a855f7; }
    :global(.tracking-dot-wrap), :global(.tracking-badge-wrap) {
        position: relative;
        display: flex; align-items: center; justify-content: center;
        width: 100%; height: 100%;
    }
    :global(.tracking-dot) { width: 12px; height: 12px; border-radius: 50%; }
    :global(.tracking-arrow) {
        position: absolute; top: -7px; left: 50%;
        transform: translateX(-50%);
        width: 0; height: 0;
        border-left: 4px solid transparent;
        border-right: 4px solid transparent;
    }
    :global(.tracking-arrow-vehicle) { border-bottom: 8px solid #f97316; }
    :global(.tracking-arrow-bodycam) { border-bottom: 8px solid #a855f7; }

    /* ── Page layout ──────────────────────────────────────────── */
    .map-page {
        height: 100%;
        padding: 10px 20px 20px;
        background: var(--card-dark-bg);
    }
    .map-wrapper {
        position: relative;
        width: 100%; height: 100%;
        border-radius: 10px;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.06);
        display: flex;
    }
    .map-container { flex: 1; height: 100%; }
    .map-no-pointer { pointer-events: none !important; }

    /* ── Drag Ghost (global, fixed) ───────────────────────────── */
    :global(.drag-ghost) {
        position: fixed;
        z-index: 9999;
        pointer-events: none;
        padding: 5px 10px;
        border-radius: 6px;
        font-size: 11px;
        font-weight: 600;
        white-space: nowrap;
        box-shadow: 0 4px 16px rgba(0,0,0,0.4);
        transform: rotate(2deg);
        transition: none;
    }
    :global(.drag-ghost--officer) {
        background: rgba(30,30,30,0.97);
        border: 1px solid rgba(255,255,255,0.15);
        color: rgba(255,255,255,0.9);
    }
    :global(.drag-ghost--patrol) {
        background: rgba(30,30,30,0.97);
        border: 1px solid rgba(255,255,255,0.12);
        color: rgba(255,255,255,0.7);
    }
    .officer-card.dragging { opacity: 0.35; }

    /* ── Left Controls ────────────────────────────────────────── */
    .map-controls {
        position: absolute;
        z-index: 1001;
        top: 12px; left: 12px;
        background: rgba(17, 17, 17, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 10px;
        padding: 12px 14px;
        min-width: 160px;
        color: rgba(255, 255, 255, 0.9);
        font-size: 12px;
    }
    .controls-header {
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        font-size: 11px;
        color: rgba(255, 255, 255, 0.5);
        margin-bottom: 10px;
        display: block;
    }
    .controls-group { display: flex; flex-direction: column; gap: 6px; }
    .controls-label {
        font-size: 11px; font-weight: 600;
        text-transform: uppercase; letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.5); margin-bottom: 2px;
    }
    .controls-divider {
        height: 1px;
        background: rgba(255, 255, 255, 0.04);
        margin: 10px 0;
    }
    .control-toggle {
        display: flex; align-items: center; gap: 8px;
        cursor: pointer; font-size: 12px;
        color: rgba(255, 255, 255, 0.7);
    }
    .control-toggle input[type="checkbox"] {
        width: 14px; height: 14px;
        accent-color: rgba(var(--accent-rgb), 0.7);
        cursor: pointer;
    }
    .segment { display: grid; grid-template-columns: 1fr 1fr; gap: 4px; }
    .segment button {
        border-radius: 6px;
        border: 1px solid rgba(255, 255, 255, 0.06);
        background: rgba(255, 255, 255, 0.04);
        color: rgba(255, 255, 255, 0.5);
        font-size: 11px; font-weight: 500;
        padding: 5px 8px; cursor: pointer;
        transition: all 0.1s ease;
    }
    .segment button:hover { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.7); }
    .segment button.active {
        background: rgba(255,255,255,0.08);
        border-color: rgba(255,255,255,0.12);
        color: rgba(255,255,255,0.9);
    }
    .legend { display: flex; flex-direction: column; gap: 5px; font-size: 11px; color: rgba(255,255,255,0.45); }
    .legend-item { display: flex; align-items: center; gap: 8px; }
    .legend-item::before {
        content: ""; width: 6px; height: 6px;
        border-radius: 50%; display: inline-block; flex-shrink: 0;
        background: var(--dot, #888);
    }
    .legend-item.vehicle::before { background: #f97316; }
    .legend-item.bodycam-unassigned::before { background: #6b7280; }

    /* ── Sidebar Toggle Button ────────────────────────────────── */
    .sidebar-toggle {
        position: absolute;
        z-index: 1002;
        right: 0; top: 50%;
        transform: translateY(-50%);
        display: flex; align-items: center; gap: 6px;
        background: rgba(17, 17, 17, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-right: none;
        border-radius: 8px 0 0 8px;
        padding: 10px 10px;
        color: rgba(255, 255, 255, 0.6);
        font-size: 11px; font-weight: 600;
        letter-spacing: 0.4px;
        cursor: pointer;
        transition: right 0.25s cubic-bezier(0.4, 0, 0.2, 1), background 0.15s;
        writing-mode: vertical-rl;
        text-orientation: mixed;
    }
    .sidebar-toggle:hover { background: rgba(30,30,30,0.95); color: rgba(255,255,255,0.9); }
    .sidebar-toggle.open { right: var(--sidebar-width, 520px); }
    .sidebar-toggle-label { writing-mode: vertical-rl; text-orientation: mixed; }

    /* ── Right Sidebar (split) ────────────────────────────────── */
    .sidebar {
        position: absolute;
        z-index: 1001;
        top: 0; right: 0; bottom: 0;
        width: var(--sidebar-width, 520px);
        display: flex; flex-direction: row;
        background: rgba(13, 13, 13, 0.96);
        border-left: 1px solid rgba(255, 255, 255, 0.06);
        transform: translateX(100%);
        transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1),
                    width 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        overflow: hidden;
    }
    .sidebar--open { transform: translateX(0); }

    /* ── Panels ───────────────────────────────────────────────── */
    .panel {
        display: flex; flex-direction: column;
        overflow: hidden;
        transition: width 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .panel--open { width: 260px; flex-shrink: 0; }
    .panel--closed { width: 36px; flex-shrink: 0; }

    .panel-divider {
        width: 1px;
        background: rgba(255, 255, 255, 0.05);
        flex-shrink: 0;
    }
    .panel-header {
        display: flex; align-items: center; gap: 6px;
        padding: 11px 12px 10px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        flex-shrink: 0;
        min-height: 40px;
    }
    .panel--closed .panel-header {
        flex-direction: column;
        align-items: center;
        justify-content: flex-start;
        padding: 10px 0;
        gap: 4px;
        border-bottom: none;
        height: 100%;
        overflow: hidden;
    }
    .panel-title-vertical {
        writing-mode: vertical-rl;
        text-orientation: mixed;
        font-size: 10px; font-weight: 700;
        text-transform: uppercase; letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.3);
        flex: 1;
        margin-top: 6px;
    }
    .panel--closed .panel-chevron { transform: rotate(-90deg); }
    .panel--closed .panel-chevron.rotated { transform: rotate(90deg); }
    .panel-header--clickable {
        cursor: pointer;
        user-select: none;
        transition: background 0.1s;
    }
    .panel-header--clickable:hover { background: rgba(255,255,255,0.03); }
    .panel-chevron {
        color: rgba(255,255,255,0.25);
        flex-shrink: 0;
        transition: transform 0.2s ease;
    }
    .panel-chevron.rotated { transform: rotate(-90deg); }
    .panel-title {
        font-size: 11px; font-weight: 700;
        text-transform: uppercase; letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.5);
        flex: 1;
    }
    .tab-badge {
        background: rgba(255, 255, 255, 0.07);
        border-radius: 10px;
        padding: 1px 6px;
        font-size: 10px;
        color: rgba(255, 255, 255, 0.35);
    }
    .btn-icon-add {
        display: flex; align-items: center; justify-content: center;
        width: 22px; height: 22px;
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 5px;
        color: rgba(255,255,255,0.5);
        cursor: pointer;
        transition: all 0.1s;
        flex-shrink: 0;
    }
    .btn-icon-add:hover { background: rgba(255,255,255,0.1); color: rgba(255,255,255,0.9); }

    .panel-content {
        flex: 1;
        overflow-y: auto;
        padding: 8px;
        display: flex; flex-direction: column; gap: 3px;
        scrollbar-width: thin;
        scrollbar-color: rgba(255,255,255,0.07) transparent;
        min-height: 0;
    }

    .section-label {
        display: flex; align-items: center; gap: 5px;
        font-size: 10px; font-weight: 700;
        text-transform: uppercase; letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.25);
        padding: 5px 3px 2px;
    }
    .section-dot {
        width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0;
    }

    .empty-hint {
        text-align: center; font-size: 11px;
        color: rgba(255, 255, 255, 0.18);
        padding: 20px 10px; line-height: 1.6;
    }

    /* ── Officer Cards ────────────────────────────────────────── */
    .officer-card {
        display: flex; align-items: center; gap: 7px;
        padding: 7px 8px;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 6px;
        cursor: grab;
        transition: background 0.1s, border-color 0.1s;
        user-select: none;
        flex-shrink: 0;
    }
    .officer-card:hover { background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.09); }
    .officer-card:active { cursor: grabbing; }
    .officer-card--assigned { opacity: 0.65; }
    .officer-drag-handle {
        flex-shrink: 0; font-size: 14px; line-height: 1;
        color: rgba(255,255,255,0.2); cursor: grab;
    }
    .officer-info { flex: 1; min-width: 0; }
    .officer-name {
        display: block; font-size: 11px; font-weight: 500;
        color: rgba(255,255,255,0.82);
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .officer-meta {
        display: block; font-size: 10px;
        color: rgba(255,255,255,0.28);
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .officer-kick {
        background: transparent; border: none;
        color: rgba(255,255,255,0.15); font-size: 15px; line-height: 1;
        cursor: pointer; padding: 0 2px; border-radius: 3px;
        transition: all 0.1s; flex-shrink: 0;
    }
    .officer-kick:hover { color: #ef4444; background: rgba(239,68,68,0.1); }

    /* ── Create Form ──────────────────────────────────────────── */
    .create-form {
        display: flex; flex-direction: column; gap: 7px;
        padding: 8px;
        background: rgba(255,255,255,0.03);
        border-bottom: 1px solid rgba(255,255,255,0.06);
        flex-shrink: 0;
    }
    .create-input {
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 5px;
        padding: 6px 9px;
        color: rgba(255,255,255,0.9);
        font-size: 12px; outline: none; width: 100%;
        box-sizing: border-box;
    }
    .create-input:focus { border-color: rgba(255,255,255,0.2); }
    .color-row { display: flex; gap: 5px; flex-wrap: wrap; }
    .color-swatch {
        width: 18px; height: 18px; border-radius: 50%;
        border: 2px solid transparent;
        cursor: pointer; transition: transform 0.1s;
    }
    .color-swatch:hover { transform: scale(1.15); }
    .color-swatch.selected { border-color: rgba(255,255,255,0.75); transform: scale(1.1); }
    .create-actions { display: flex; gap: 5px; }
    .btn-create {
        flex: 1; padding: 6px;
        background: rgba(var(--accent-rgb), 0.14);
        border: 1px solid rgba(var(--accent-rgb), 0.28);
        border-radius: 5px;
        color: rgba(255,255,255,0.8);
        font-size: 11px; font-weight: 600;
        cursor: pointer; transition: all 0.1s;
    }
    .btn-create:hover { background: rgba(var(--accent-rgb), 0.24); }
    .btn-cancel {
        padding: 6px 10px;
        background: rgba(255,255,255,0.04);
        border: 1px solid rgba(255,255,255,0.06);
        border-radius: 5px;
        color: rgba(255,255,255,0.35);
        font-size: 11px; cursor: pointer; transition: all 0.1s;
    }
    .btn-cancel:hover { background: rgba(255,255,255,0.08); color: rgba(255,255,255,0.7); }

    /* ── Patrol Cards ─────────────────────────────────────────── */
    .patrol-card {
        background: rgba(255,255,255,0.03);
        border: 1px solid rgba(255,255,255,0.05);
        border-radius: 7px;
        overflow: hidden;
        transition: border-color 0.15s, background 0.15s;
        margin-bottom: 2px;
        min-height: 36px;
        flex-shrink: 0;
    }
    .patrol-card.drag-over {
        border-color: rgba(255,255,255,0.22);
        background: rgba(255,255,255,0.06);
    }
    .patrol-card.sort-over {
        border-color: rgba(var(--accent-rgb), 0.5);
        background: rgba(var(--accent-rgb), 0.06);
    }
    .patrol-header {
        display: flex; align-items: center; gap: 7px;
        padding: 7px 8px;
    }
    .patrol-color-bar { width: 3px; height: 20px; border-radius: 2px; flex-shrink: 0; }
    .patrol-name {
        flex: 1; font-size: 11px; font-weight: 600;
        color: rgba(255,255,255,0.82); cursor: default;
    }
    .patrol-name-edit {
        flex: 1;
        background: rgba(255,255,255,0.07);
        border: 1px solid rgba(255,255,255,0.15);
        border-radius: 3px; padding: 1px 5px;
        font-size: 11px; font-weight: 600;
        color: rgba(255,255,255,0.9); outline: none;
    }
    .patrol-count {
        font-size: 10px; font-weight: 700;
        color: rgba(255,255,255,0.22);
        background: rgba(255,255,255,0.05);
        border-radius: 10px; padding: 1px 6px;
    }
    .patrol-delete {
        background: transparent; border: none;
        color: rgba(255,255,255,0.18);
        cursor: pointer; padding: 2px;
        display: flex; align-items: center; border-radius: 3px;
        transition: all 0.1s;
    }
    .patrol-delete:hover { color: #ef4444; background: rgba(239,68,68,0.1); }

    .patrol-sort-handle {
        font-size: 13px; line-height: 1;
        color: rgba(255,255,255,0.18);
        cursor: grab; flex-shrink: 0;
        padding: 0 2px;
    }
    .patrol-sort-handle:active { cursor: grabbing; }

    .patrol-sort-arrows {
        display: flex; flex-direction: column; gap: 1px; flex-shrink: 0;
    }
    .sort-arrow {
        background: transparent; border: none;
        color: rgba(255,255,255,0.2);
        font-size: 8px; line-height: 1;
        cursor: pointer; padding: 1px 2px;
        border-radius: 2px; transition: all 0.1s;
    }
    .sort-arrow:hover:not(:disabled) { color: rgba(255,255,255,0.7); background: rgba(255,255,255,0.08); }
    .sort-arrow:disabled { opacity: 0.2; cursor: default; }

    .drop-hint {
        font-size: 10px; color: rgba(255,255,255,0.15);
        text-align: center; padding: 7px;
        border-top: 1px dashed rgba(255,255,255,0.05);
    }
    .patrol-member {
        display: flex; align-items: center; gap: 5px;
        padding: 4px 8px 4px 18px;
        border-top: 1px solid rgba(255,255,255,0.04);
    }
    .member-name {
        font-size: 11px; color: rgba(255,255,255,0.65);
        flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .member-meta { font-size: 10px; color: rgba(255,255,255,0.22); white-space: nowrap; }

    /* ── Assignment animations ────────────────────────────────── */
    @keyframes anim-assign-in {
        0%   { background: rgba(34, 197, 94, 0.18); box-shadow: 0 0 0 1px rgba(34,197,94,0.35); transform: scaleX(0.97); }
        40%  { background: rgba(34, 197, 94, 0.10); box-shadow: 0 0 0 1px rgba(34,197,94,0.2); transform: scaleX(1.01); }
        100% { background: transparent; box-shadow: none; transform: scaleX(1); }
    }
    @keyframes anim-remove-in {
        0%   { background: rgba(239, 68, 68, 0.15); box-shadow: 0 0 0 1px rgba(239,68,68,0.3); opacity: 1; transform: scaleX(1); }
        60%  { background: rgba(239, 68, 68, 0.08); opacity: 0.7; transform: scaleX(0.98); }
        100% { background: transparent; box-shadow: none; opacity: 1; transform: scaleX(1); }
    }
    @keyframes slide-down {
        0%   { opacity: 0; transform: translateY(-6px); }
        100% { opacity: 1; transform: translateY(0); }
    }

    .anim-assigned {
        animation: anim-assign-in 0.65s cubic-bezier(0.22, 1, 0.36, 1) forwards,
                   slide-down 0.25s ease-out;
    }
    .anim-removed {
        animation: anim-remove-in 0.65s cubic-bezier(0.22, 1, 0.36, 1) forwards,
                   slide-down 0.25s ease-out;
    }
</style>