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
    import { permissionHint } from "../utils/permissionHint";

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
    let dirtyDebounce: ReturnType<typeof setTimeout> | null = null;

    let tabVisible = $state(true);
    let showVehicles = $state(localStorage.getItem("mdt_map_vehicles") !== "false");
    let showBodycams = $state(localStorage.getItem("mdt_map_bodycams") !== "false");
    let showPatrols  = $state(localStorage.getItem("mdt_map_patrols_layer") !== "false");
    let showZones    = $state(localStorage.getItem("mdt_map_zones") !== "false");

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

    /**
     * Whether the sidebar is genuinely on screen. `sidebarOpen` survives in
     * localStorage regardless of permission, so without this the zoom control
     * and the default view kept reserving room for a panel that was never
     * rendered — leaving the +/- floating over the middle of the map.
     */
    let sidebarVisible = $derived(canViewPatrols && sidebarOpen);

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
        // Bodycam feed reference, keyed the same way as the Bodycams tab (server id),
        // plus the live power state so the popup can offer or withhold the feed.
        bodycamId?: string;
        bodycamOnline?: boolean;
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

    // ─── Dispatch calls on the map ─────────────────────────────────────────
    type DispatchUnitLite = {
        citizenid: string;
        charinfo?: { firstname?: string; lastname?: string };
        metadata?: { callsign?: string };
    };
    type MapDispatch = {
        id: string | number;
        message?: string;
        code?: string;
        codename?: string;
        priority?: number;
        coords?: unknown;
        street?: string;
        time?: number;
        units?: DispatchUnitLite[];
        note?: { text: string; author?: string; updatedAt?: number } | null;
    };
    let dispatches         = $state<MapDispatch[]>([]);
    // Calls a dispatcher has dismissed locally (cleared from ticker + map).
    let dismissedCallIds   = $state<Set<string>>(new Set());
    let showCalls          = $state(localStorage.getItem("mdt_map_calls") !== "false");

    // Preferences saved by the Settings tab (same NUI document, so plain
    // localStorage reads are enough — no round-trip needed).
    function readPreferences(): Record<string, unknown> {
        try { return JSON.parse(localStorage.getItem("ps-mdt-preferences") ?? "{}"); } catch { return {}; }
    }

    // Shown when the view has drifted away from the island — one click glides back.
    let showBackToMap      = $state(false);
    let selectedDispatchId = $state<string | null>(null);
    let assignBusy         = $state(false);
    let visibleDispatches  = $derived(dispatches.filter(d => !dismissedCallIds.has(String(d.id))));
    let selectedDispatch   = $derived(visibleDispatches.find(d => String(d.id) === selectedDispatchId) ?? null);
    let canAssignUnits     = $derived(authService ? (authService.hasPermission("dispatch_assign") ?? false) : true);
    let canManageNotes     = $derived(authService ? (authService.hasPermission("dispatch_notes") ?? false) : true);
    // Note editor state for the selected call.
    let noteEditing        = $state(false);
    let noteDraft          = $state("");
    let noteBusy           = $state(false);
    const NOTE_MAX         = 300;
    const dispatchMarkers: globalThis.Map<string, L.Marker> = new globalThis.Map();

    function dispatchCoords(d: MapDispatch): GtaPoint | null {
        const c = d.coords as any;
        if (!c) return null;
        if (typeof c.x === "number" && typeof c.y === "number") return { x: c.x, y: c.y };
        if (Array.isArray(c) && c.length >= 2) {
            const x = Number(c[0]), y = Number(c[1]);
            if (!isNaN(x) && !isNaN(y)) return { x, y };
        }
        return null;
    }

    function priorityColor(p?: number): string {
        if (p === 1) return "#ef4444";
        if (p === 2) return "#f59e0b";
        return "#38bdf8";
    }

    // Small inline SVG paths (24x24 viewBox) per call type — self-contained so
    // they work inside Leaflet divIcons without any font dependency (CEF-safe).
    const CALL_ICON_SVGS: Record<string, string> = {
        gun:   '<path fill="currentColor" d="M2 6.5h20v4h-3.1l-.55 1.65A2 2 0 0 1 16.45 13.5H12.6l-1.5 5.4a1.5 1.5 0 0 1-1.45 1.1H6.2l1.8-6.5H5a3 3 0 0 1-3-3v-4zm16 1.5h-2v1h2v-1z"/>',
        car:   '<path fill="currentColor" d="M6 6h12a1 1 0 0 1 .95.68L20.5 11H21a1 1 0 0 1 1 1v4.5h-2.35a2.4 2.4 0 0 1-4.7 0h-5.9a2.4 2.4 0 0 1-4.7 0H2V12a1 1 0 0 1 1-1h.5L5.05 6.68A1 1 0 0 1 6 6zm.7 2-1 3h12.6l-1-3H6.7z"/>',
        fight: '<path fill="currentColor" d="M12 1.8l1.9 4.8 4.9-1.9-1.9 4.9 4.8 1.9-4.8 1.9 1.9 4.9-4.9-1.9-1.9 4.8-1.9-4.8-4.9 1.9 1.9-4.9-4.8-1.9 4.8-1.9-1.9-4.9 4.9 1.9L12 1.8z"/>',
        rob:   '<path fill="currentColor" d="M9.2 3h5.6a.8.8 0 0 1 .7 1.2L14 7h-4L8.5 4.2A.8.8 0 0 1 9.2 3zM10 8h4c3.9 1.4 6 5 6 8.4A4.6 4.6 0 0 1 15.4 21H8.6A4.6 4.6 0 0 1 4 16.4C4 13 6.1 9.4 10 8zm2.6 3.2h-1.8v.9c-.9.2-1.6.9-1.6 1.9 0 1.2.9 1.7 2.1 2 .9.3 1.2.5 1.2.9 0 .5-.5.7-1.1.7-.7 0-1.4-.3-1.9-.6l-.5 1.4c.5.3 1.1.5 1.8.6v.9h1.8v-1c1-.2 1.7-1 1.7-2 0-1.3-1-1.8-2.2-2.1-.8-.2-1.1-.4-1.1-.8s.4-.7 1-.7 1.2.2 1.6.4l.5-1.3a4 4 0 0 0-1.5-.4v-.8z"/>',
        fire:  '<path fill="currentColor" d="M12 2s6 4.8 6 10a6 6 0 0 1-12 0c0-2.2 1.1-4 2.4-5.7.4 1.2 1.2 2.2 2 2.4.4-2.3-.3-4.6 1.6-6.7zm0 16.5A2.5 2.5 0 0 0 14.5 16c0-1.7-1.3-2.6-2.5-4-1.2 1.4-2.5 2.3-2.5 4a2.5 2.5 0 0 0 2.5 2.5z"/>',
        drugs: '<path fill="currentColor" d="M9.8 3.6a5 5 0 0 1 7.1 7.1l-6.4 6.4a5 5 0 1 1-7.1-7.1l6.4-6.4zm-2 3.4L4.6 10.2a3 3 0 1 0 4.2 4.2l3.2-3.2-4.2-4.2z"/>',
        alarm: '<path fill="currentColor" d="M12 2.5a1.5 1.5 0 0 1 1.5 1.5v.6A6 6 0 0 1 18 10.5V14l2 3H4l2-3v-3.5a6 6 0 0 1 4.5-5.9V4A1.5 1.5 0 0 1 12 2.5zM9.8 18.5h4.4a2.2 2.2 0 0 1-4.4 0z"/>',
        shield:'<path fill="currentColor" d="M12 1.8l8.5 3.2v6.2c0 5.2-3.6 9.4-8.5 11.6C7.1 20.6 3.5 16.4 3.5 11.2V5L12 1.8zm-1.2 13.4 5.5-5.5-1.4-1.4-4.1 4.1-1.7-1.7-1.4 1.4 3.1 3.1z"/>',
        knife: '<path fill="currentColor" d="M21.4 2.6c1.1 1.9-.6 5.6-4.4 7.8l-1.3.7-2.8-2.8.7-1.3c2.2-3.8 5.9-5.5 7.8-4.4zM11.6 9.6l2.8 2.8-8.2 8.2a1 1 0 0 1-1.4 0l-1.4-1.4a1 1 0 0 1 0-1.4l8.2-8.2z"/>',
        warn:  '<path fill="currentColor" d="M12 2.2 23 21H1L12 2.2zM11 10v5h2v-5h-2zm0 6.5v2h2v-2h-2z"/>',
    };

    // Map a dispatch to its icon by scanning code/codename/message/icon text.
    function callIconSvg(d: MapDispatch): string {
        const hay = `${d.code || ""} ${d.codename || ""} ${d.message || ""} ${(d as any).icon || ""} ${(d as any).name || ""}`.toLowerCase();
        const pick = (k: string) => CALL_ICON_SVGS[k];
        if (/shoot|shots|gun|firearm|weapon|10-?71|armed/.test(hay)) return pick("gun");
        if (/stab|knife|melee/.test(hay)) return pick("knife");
        if (/vehicle|car ?jack|speed|racing|pursuit|traffic|driving|carjack|stolen/.test(hay)) return pick("car");
        if (/fight|assault|brawl|battery/.test(hay)) return pick("fight");
        if (/robbery|store|bank|heist|jewel|burglar|theft|fleeca|vangelico/.test(hay)) return pick("rob");
        if (/fire|explosion|arson/.test(hay)) return pick("fire");
        if (/drug|deal|substance|weed|coke|meth/.test(hay)) return pick("drugs");
        if (/alarm|panic|intrusion/.test(hay)) return pick("alarm");
        if (/officer|backup|10-?13|down|distress|emergency/.test(hay)) return pick("shield");
        return pick("warn");
    }

    function dispatchAge(t?: number): string {
        if (!t) return "";
        const mins = Math.max(0, Math.round((Date.now() - t) / 60000));
        if (mins < 1) return "now";
        if (mins < 60) return `${mins}m ago`;
        return `${Math.floor(mins / 60)}h ${mins % 60}m ago`;
    }

    function unitLabel(u: DispatchUnitLite): string {
        const cs = u.metadata?.callsign && u.metadata.callsign !== "NO CALLSIGN" ? u.metadata.callsign : null;
        const name = [u.charinfo?.firstname, u.charinfo?.lastname].filter(Boolean).join(" ");
        // Prefer a resolved officer name from the live roster if the call's own
        // charinfo is missing, and only ever fall back to "Unit" — never show a
        // raw citizenid to the dispatcher.
        const fromRoster = officers.find(o => o.citizenid === u.citizenid)?.name;
        const display = name || fromRoster || "Unit";
        return cs ? `${cs} · ${display}` : display;
    }

    async function loadDispatches() {
        try {
            const res = await fetchNui<MapDispatch[]>(NUI_EVENTS.DASHBOARD.GET_RECENT_DISPATCHES, {}, []);
            dispatches = Array.isArray(res) ? res : [];
            renderDispatchMarkers();
        } catch { /* keep last known list */ }
    }

    function esc(v: unknown): string {
        return String(v ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function dispatchTooltip(d: MapDispatch): string {
        const parts = [
            `<b>${esc(d.code || d.codename || "Call")}</b>`,
            d.message ? esc(d.message) : "",
            [d.street ? esc(d.street) : "", d.time ? esc(dispatchAge(d.time)) : ""].filter(Boolean).join(" · "),
            `${(d.units || []).length} unit${(d.units || []).length === 1 ? "" : "s"} attached`,
        ].filter(Boolean);
        return parts.join("<br>");
    }

    // Icon HTML separated from the divIcon so renderDispatchMarkers can
    // compare it against the marker's current HTML and skip setIcon() (full
    // DOM replacement) when nothing visual changed — before this, EVERY call
    // marker was rebuilt on every loadDispatches, which stutters badly while
    // a dispatcher is panning/zooming on a busy server.
    function dispatchIconHtml(d: MapDispatch, selected: boolean): string {
        const col = priorityColor(d.priority);
        const svg = callIconSvg(d);
        return `<div class="disp-marker${selected ? " sel" : ""}" style="--dc:${col}">`
            + `<div class="disp-ring"></div>`
            + `<div class="disp-badge"><svg viewBox="0 0 24 24">${svg}</svg></div>`
            + `</div>`;
    }

    function dispatchIcon(html: string) {
        return L.divIcon({
            className: "",
            html,
            iconSize: [38, 38],
            iconAnchor: [19, 19],
        });
    }

    function renderDispatchMarkers() {
        if (!map) return;
        const seen = new Set<string>();
        if (showCalls) {
            for (const d of visibleDispatches) {
                const gp = dispatchCoords(d);
                if (!gp) continue;
                const id = String(d.id);
                seen.add(id);
                const ll = toMapLatLng(gp) as L.LatLngExpression;
                const html = dispatchIconHtml(d, selectedDispatchId === id);
                let m = dispatchMarkers.get(id);
                if (m) {
                    m.setLatLng(ll);
                    if ((m as any).__iconHtml !== html) {
                        m.setIcon(dispatchIcon(html));
                        (m as any).__iconHtml = html;
                    }
                    m.setTooltipContent(dispatchTooltip(d));
                } else {
                    m = L.marker(ll, { icon: dispatchIcon(html), zIndexOffset: 800 });
                    (m as any).__iconHtml = html;
                    m.on("click", () => selectDispatch(id));
                    m.bindTooltip(dispatchTooltip(d), { direction: "top", offset: [0, -16], className: "disp-tt", opacity: 1 });
                    m.addTo(map);
                    dispatchMarkers.set(id, m);
                }
            }
        }
        for (const [id, m] of dispatchMarkers) {
            if (!seen.has(id)) { m.remove(); dispatchMarkers.delete(id); }
        }
    }

    function selectDispatch(id: string) {
        selectedDispatchId = selectedDispatchId === id ? null : id;
        renderDispatchMarkers();
        // Only one focus at a time: opening a call closes the officer popup.
        if (selectedDispatchId) clearOfficerHighlight();
        if (selectedDispatchId && map) {
            const d = visibleDispatches.find(x => String(x.id) === id);
            const gp = d ? dispatchCoords(d) : null;
            if (gp) {
                // Glide over to the call, kept centered in the visible area.
                flyToCentered(toMapLatLng(gp) as L.LatLngExpression, Math.max(map.getZoom(), 5), 1.1);
            }
        }
    }

    function attachedIds(d: MapDispatch): Set<string> {
        return new Set((d.units || []).map(u => u.citizenid));
    }

    // Nearest online units not yet on the call — the dispatcher's quick-assign list.
    let nearbyUnits = $derived.by(() => {
        const d = selectedDispatch;
        if (!d) return [] as { o: Bodycam; dist: number }[];
        const gp = dispatchCoords(d);
        if (!gp) return [];
        const attached = attachedIds(d);
        // Only truly free units: not on the call, not part of a patrol
        // (patrols are assigned as a whole below), not busy — and not the
        // dispatcher themselves ("Attach yourself" is the dedicated path
        // for that, with its own waypoint + notify handling).
        return officers
            .filter(o =>
                !attached.has(o.citizenid) &&
                o.citizenid !== ownCitizenId &&
                !getOfficerPatrol(o.citizenid) &&
                (o.status ?? defaultStatusId) !== "busy")
            .map(o => ({ o, dist: Math.hypot(o.coords.x - gp.x, o.coords.y - gp.y) }))
            .sort((a, b) => a.dist - b.dist)
            .slice(0, 6);
    });

    function fmtDist(m: number): string {
        return m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${Math.round(m)} m`;
    }

    async function assignUnits(citizenids: string[], action: "attach" | "detach") {
        const d = selectedDispatch;
        if (!d || assignBusy || citizenids.length === 0) return;
        assignBusy = true;
        try {
            const gp = dispatchCoords(d);
            const res = await fetchNui<{ success: boolean; assigned?: number; offline?: number; error?: string }>(
                NUI_EVENTS.DISPATCH.ASSIGN_TO_DISPATCH,
                { dispatch_id: d.id, citizenids, action, coords: gp ? { x: gp.x, y: gp.y } : undefined },
                { success: true, assigned: citizenids.length, offline: 0 },
            );
            if (res?.success) {
                const n = res.assigned ?? citizenids.length;
                globalNotifications.success(action === "attach"
                    ? `Assigned ${n} unit${n === 1 ? "" : "s"} to the call — waypoint set`
                    : "Unit removed from the call");
                if (res.offline) globalNotifications.error(`${res.offline} unit(s) offline — skipped`);
                setTimeout(loadDispatches, 400);
            } else {
                globalNotifications.error(res?.error || "Assignment failed");
            }
        } catch {
            globalNotifications.error("Assignment failed");
        } finally {
            assignBusy = false;
        }
    }

    // Patrols eligible for assignment: at least one member online ("staffed")
    // and the derived patrol status isn't busy — sorted by distance to the call
    // so a dispatcher on a big server sees the closest active patrol first.
    let nearbyPatrols = $derived.by(() => {
        const d = selectedDispatch;
        if (!d) return [] as { p: Patrol; dist: number; count: number; st: StatusDef }[];
        const gp = dispatchCoords(d);
        if (!gp) return [];
        const attached = attachedIds(d);
        const out: { p: Patrol; dist: number; count: number; st: StatusDef }[] = [];
        for (const p of patrols) {
            const members = officers.filter(o => p.memberIds.includes(o.citizenid));
            if (members.length === 0) continue; // not staffed
            const st = getPatrolStatus(p);
            if (!st || st.id === "busy") continue; // occupied
            const assignable = members.filter(o => !attached.has(o.citizenid));
            if (assignable.length === 0) continue; // everyone already on the call
            const dist = Math.min(...members.map(o => Math.hypot(o.coords.x - gp.x, o.coords.y - gp.y)));
            out.push({ p, dist, count: assignable.length, st });
        }
        return out.sort((a, b) => a.dist - b.dist).slice(0, 4);
    });

    function assignPatrolToCall(p: Patrol) {
        if (!selectedDispatch) return;
        const attached = attachedIds(selectedDispatch);
        const ids = p.memberIds.filter(cid => officers.some(o => o.citizenid === cid) && !attached.has(cid));
        if (ids.length === 0) { globalNotifications.error("No online members left to assign"); return; }
        assignUnits(ids, "attach");
    }

    // ═══ Create Call modal ═══
    type CallCode = { code: string; label: string };
    let showCreateCall  = $state(false);
    let callCodes       = $state<CallCode[]>([]);
    let ccCode          = $state("");
    let ccTitle         = $state("");
    let ccNote          = $state("");
    let ccPickedGta     = $state<GtaPoint | null>(null);
    let ccStreet        = $state("");
    let ccPicking       = $state(false);
    let ccPendingGta    = $state<GtaPoint | null>(null); // provisional pick, awaiting confirm
    let ccPickMarker: L.Marker | null = null;
    let ccSelectedPatrols = $state<Set<string>>(new Set());
    let ccBusy          = $state(false);
    const CC_NOTE_MAX   = 300;

    // Tidy up the picking state whenever the modal is closed.
    $effect(() => {
        if (!showCreateCall) {
            ccPicking = false;
            ccPendingGta = null;
            removePickMarker();
        }
    });

    let ccSelectedCode  = $derived(callCodes.find(c => c.code === ccCode) ?? null);

    async function openCreateCall() {
        // Load the configured 10-codes lazily on first open.
        if (callCodes.length === 0) {
            try { callCodes = await fetchNui<CallCode[]>(NUI_EVENTS.DISPATCH.GET_CALL_CODES, {}, []); }
            catch { callCodes = []; }
        }
        ccCode = ""; ccTitle = ""; ccNote = "";
        ccPickedGta = null; ccStreet = ""; ccPicking = false;
        ccPendingGta = null; removePickMarker();
        ccSelectedPatrols = new Set();
        showCreateCall = true;
    }

    // Available patrols near the PICKED location (staffed + not busy), mirroring
    // the call-card's "Nearest available patrols" list.
    let ccNearbyPatrols = $derived.by(() => {
        const gp = ccPickedGta;
        if (!gp) return [] as { p: Patrol; dist: number; count: number; st: StatusDef }[];
        const out: { p: Patrol; dist: number; count: number; st: StatusDef }[] = [];
        for (const p of patrols) {
            const members = officers.filter(o => p.memberIds.includes(o.citizenid));
            if (members.length === 0) continue; // not staffed
            const st = getPatrolStatus(p);
            if (!st || st.id === "busy") continue; // occupied
            const dist = Math.min(...members.map(o => Math.hypot(o.coords.x - gp.x, o.coords.y - gp.y)));
            out.push({ p, dist, count: members.length, st });
        }
        return out.sort((a, b) => a.dist - b.dist).slice(0, 6);
    });

    function ccTogglePatrol(id: string) {
        const next = new Set(ccSelectedPatrols);
        if (next.has(id)) next.delete(id); else next.add(id);
        ccSelectedPatrols = next;
    }

    function startLocationPick() {
        // Never pick a location and draw a zone at the same time.
        if (drawingPatrolId) stopDrawing(true);
        ccPendingGta = null;
        removePickMarker();
        ccPicking = true;
        mapContainer?.classList.add("map-cursor-cross");
    }

    function ccPickIcon() {
        return L.divIcon({
            className: "",
            html: `<div class="cc-pin"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg></div>`,
            iconSize: [30, 30],
            iconAnchor: [15, 28],
        });
    }

    function removePickMarker() {
        ccPickMarker?.remove();
        ccPickMarker = null;
        mapContainer?.classList.remove("map-cursor-cross");
    }

    // While picking, a click drops/moves a provisional pin — not yet confirmed.
    function onPickLocation(gp: GtaPoint) {
        ccPendingGta = gp;
        if (map) {
            const ll = toMapLatLng(gp) as L.LatLngExpression;
            if (ccPickMarker) ccPickMarker.setLatLng(ll);
            else { ccPickMarker = L.marker(ll, { icon: ccPickIcon(), zIndexOffset: 2000 }).addTo(map); }
        }
    }

    // Confirm the provisional pin: resolve its street and return to the modal.
    async function confirmPick() {
        if (!ccPendingGta) return;
        ccPickedGta = ccPendingGta;
        ccPicking = false;
        removePickMarker();
        ccStreet = "";
        try {
            const res = await fetchNui<{ street: string }>(
                NUI_EVENTS.DISPATCH.RESOLVE_STREET, { x: ccPickedGta.x, y: ccPickedGta.y, z: 0 }, { street: "" });
            ccStreet = res?.street ?? "";
        } catch { /* leave blank */ }
    }

    // Cancel picking and return to the modal with the previous location intact.
    function cancelPick() {
        ccPicking = false;
        ccPendingGta = null;
        removePickMarker();
    }

    async function submitCreateCall() {
        if (ccBusy) return;
        if (!ccCode) { globalNotifications.error("Pick a 10-code"); return; }
        if (!ccPickedGta) { globalNotifications.error("Pick a location on the map"); return; }
        ccBusy = true;
        try {
            const res = await fetchNui<{ success: boolean; id?: string; error?: string }>(
                NUI_EVENTS.DISPATCH.CREATE_MANUAL_DISPATCH,
                {
                    code: ccCode,
                    title: ccTitle.trim(),          // may be empty — server falls back to label
                    label: ccSelectedCode?.label,   // used as title when none is typed
                    coords: { x: ccPickedGta.x, y: ccPickedGta.y },
                    street: ccStreet || undefined,
                    note: ccNote.trim() || undefined,
                },
                { success: true, id: "preview" },
            );
            if (!res?.success || !res.id) {
                globalNotifications.error(res?.error || "Failed to create call");
                return;
            }
            // Attach every online member of the selected patrols.
            const ids = [...new Set(
                patrols
                    .filter(p => ccSelectedPatrols.has(p.id))
                    .flatMap(p => p.memberIds)
                    .filter(cid => officers.some(o => o.citizenid === cid)),
            )];
            if (ids.length > 0) {
                await fetchNui(NUI_EVENTS.DISPATCH.ASSIGN_TO_DISPATCH, {
                    dispatch_id: res.id, citizenids: ids, action: "attach",
                    coords: { x: ccPickedGta.x, y: ccPickedGta.y },
                }, { success: true });
            }
            globalNotifications.success(`Call created${ids.length ? ` — ${ids.length} unit${ids.length === 1 ? "" : "s"} assigned` : ""}`);
            showCreateCall = false;
            setTimeout(loadDispatches, 300);
        } catch {
            globalNotifications.error("Failed to create call");
        } finally {
            ccBusy = false;
        }
    }

    // MDT-created (manual) calls have ids like "mdt-…". They need the manual
    // flag so the client keeps the unit list server-side instead of asking the
    // dispatch provider (which doesn't know about them).
    function isManualCall(d: MapDispatch | null): boolean {
        return !!d && typeof d.id === "string" && d.id.startsWith("mdt-");
    }

    async function selfAttachToCall(attach: boolean) {
        const d = selectedDispatch;
        if (!d) return;
        const payload = isManualCall(d) ? { id: d.id, manual: true } : d.id;
        try {
            // The Lua callback returns the refreshed list (post attach/detach,
            // cache already invalidated) — apply it immediately so unit chips
            // update on the spot; the delayed reload stays as a safety net for
            // provider-side processing races.
            const res = await fetchNui<MapDispatch[]>(
                attach ? NUI_EVENTS.DISPATCH.ATTACH_TO_DISPATCH : NUI_EVENTS.DISPATCH.DETACH_FROM_DISPATCH,
                payload, [],
            );
            if (Array.isArray(res) && res.length) { dispatches = res; renderDispatchMarkers(); }
            setTimeout(loadDispatches, 300);
        } catch { /* ignore */ }
    }

    let switchConfirmFrom = $state<MapDispatch | null>(null);

    // "Attach yourself" goes through here: already on another call → ask
    // before switching instead of quietly stacking attachments.
    function requestSelfAttach() {
        const d = selectedDispatch;
        if (!d) return;
        const cur = myCurrentCall;
        if (cur && String(cur.id) !== String(d.id)) { switchConfirmFrom = cur; return; }
        selfAttachToCall(true);
    }

    async function confirmSwitchCall() {
        const from = switchConfirmFrom;
        switchConfirmFrom = null;
        if (!from) return;
        // Order matters for the automatic status: attaching FIRST moves the
        // engagement to the new call (En Route again), so the detach from the
        // old call below no longer matches it and can't revert the status.
        await selfAttachToCall(true);
        const payload = isManualCall(from) ? { id: from.id, manual: true } : from.id;
        try {
            // Apply the returned list right away so the OLD call's unit chips
            // drop this officer immediately instead of waiting for the poll.
            const res = await fetchNui<MapDispatch[]>(NUI_EVENTS.DISPATCH.DETACH_FROM_DISPATCH, payload, []);
            if (Array.isArray(res) && res.length) { dispatches = res; renderDispatchMarkers(); }
        } catch { /* ignore */ }
        setTimeout(loadDispatches, 300);
    }

    function removeUnitFromCall(cid: string) {
        if (ownCitizenId && cid === ownCitizenId) { selfAttachToCall(false); return; }
        assignUnits([cid], "detach");
    }

    // Ticker paging: browse ALL calls three at a time (newest first),
    // navigated with the on-screen arrows or the keyboard arrow keys.
    let tickerPage = $state(0);
    let tickerAll = $derived(visibleDispatches.slice().reverse());
    let tickerPages = $derived(Math.max(1, Math.ceil(tickerAll.length / 3)));
    let tickerCalls = $derived(tickerAll.slice(tickerPage * 3, tickerPage * 3 + 3));
    $effect(() => { if (tickerPage >= tickerPages) tickerPage = Math.max(0, tickerPages - 1); });

    function tickerNav(dir: number) {
        tickerPage = Math.min(tickerPages - 1, Math.max(0, tickerPage + dir));
    }

    function handleTickerKeys(e: KeyboardEvent) {
        if (e.key === "Escape" && ccPicking) { e.preventDefault(); cancelPick(); return; }
        const t = e.target as HTMLElement | null;
        if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
        if (e.key === "ArrowLeft") { e.preventDefault(); tickerNav(-1); }
        else if (e.key === "ArrowRight") { e.preventDefault(); tickerNav(1); }
    }

    // ─── Call notes ─────────────────────────────────────────────────────────
    function startNoteEdit() {
        noteDraft = selectedDispatch?.note?.text ?? "";
        noteEditing = true;
    }
    function cancelNoteEdit() {
        noteEditing = false;
        noteDraft = "";
    }
    async function saveNote() {
        const d = selectedDispatch;
        const text = noteDraft.trim();
        if (!d || noteBusy || !text) return;
        noteBusy = true;
        try {
            const res = await fetchNui<{ success: boolean; error?: string }>(
                NUI_EVENTS.DISPATCH.SET_DISPATCH_NOTE, { dispatch_id: d.id, text }, { success: true });
            if (res?.success) {
                globalNotifications.success("Note saved");
                noteEditing = false;
                setTimeout(loadDispatches, 300);
            } else {
                globalNotifications.error(res?.error || "Failed to save note");
            }
        } catch {
            globalNotifications.error("Failed to save note");
        } finally {
            noteBusy = false;
        }
    }
    async function deleteNote() {
        const d = selectedDispatch;
        if (!d || noteBusy) return;
        noteBusy = true;
        try {
            const res = await fetchNui<{ success: boolean; error?: string }>(
                NUI_EVENTS.DISPATCH.DELETE_DISPATCH_NOTE, { dispatch_id: d.id }, { success: true });
            if (res?.success) {
                globalNotifications.success("Note removed");
                noteEditing = false;
                setTimeout(loadDispatches, 300);
            } else {
                globalNotifications.error(res?.error || "Failed to remove note");
            }
        } catch {
            globalNotifications.error("Failed to remove note");
        } finally {
            noteBusy = false;
        }
    }

    // Reset the note editor and any pending switch confirm whenever the
    // selected call changes.
    $effect(() => {
        selectedDispatchId;
        noteEditing = false;
        noteDraft = "";
        switchConfirmFrom = null;
    });

    // Ask before dismissing so a call isn't removed for everyone by accident.
    let dismissConfirmId = $state<string | null>(null);

    function requestDismiss(id: string) {
        dismissConfirmId = id;
    }

    async function dismissCall(id: string) {
        dismissConfirmId = null;
        // Optimistic local hide, then the server removes it for EVERYONE —
        // the broadcast refresh keeps all open MDTs in sync.
        dismissedCallIds = new Set([...dismissedCallIds, id]);
        if (selectedDispatchId === id) selectedDispatchId = null;
        renderDispatchMarkers();
        try {
            const res = await fetchNui<{ success: boolean; error?: string }>(
                NUI_EVENTS.DISPATCH.DISMISS_DISPATCH, { dispatch_id: id }, { success: true });
            if (res?.success) {
                globalNotifications.success("Call dismissed for all units");
            } else {
                globalNotifications.error(res?.error || "Failed to dismiss call");
            }
        } catch {
            globalNotifications.error("Failed to dismiss call");
        }
    }

    // ─── Officer Status ────────────────────────────────────────────────────
    // Status definitions (id/label/color) come from the server so the UI never
    // hardcodes them — Config.OfficerStatus.list is the single source of truth
    // and can grow without touching this file. `Default` is what an officer
    // who never set a status is treated as.
    type StatusDef = { id: string; label: string; color: string; icon?: string };
    // Status ids missing from this list paint a grey "unknown" dot, so what it
    // holds before the server answers decides what the first frames look like.
    //
    // It is remembered from the LAST successful load rather than hardcoded:
    // a hardcoded list would be wrong the moment a server adds a status or
    // removes one, and would keep being wrong every time the tab opens. The
    // cache is written by loadStatusConfig() below, so it always describes
    // THIS server's Config.OfficerStatus.list, custom entries included.
    //
    // Very first open on a machine there is no cache — that case is covered by
    // awaiting the fetch before the first markers are drawn (see initializeMap).
    const STATUS_CACHE_KEY = "mdt_status_defs";

    function readStatusCache(): { statuses: StatusDef[]; default?: string } | null {
        try {
            const raw = localStorage.getItem(STATUS_CACHE_KEY);
            if (!raw) return null;
            const parsed = JSON.parse(raw);
            if (!Array.isArray(parsed?.statuses) || parsed.statuses.length === 0) return null;
            // Only keep entries that actually look like a status definition;
            // a half-written cache must not poison the map.
            const statuses = parsed.statuses.filter(
                (d: any) => d && typeof d.id === "string" && typeof d.color === "string",
            );
            return statuses.length > 0 ? { statuses, default: parsed.default } : null;
        } catch {
            return null;
        }
    }

    function writeStatusCache(statuses: StatusDef[], fallbackId: string) {
        try {
            localStorage.setItem(STATUS_CACHE_KEY, JSON.stringify({ statuses, default: fallbackId }));
        } catch { /* storage full or unavailable — the fetch still works */ }
    }

    const cachedStatus = readStatusCache();
    let statusDefs    = $state<StatusDef[]>(cachedStatus?.statuses ?? []);
    let defaultStatusId = $state(cachedStatus?.default ?? "active");
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

    // Awaited before the first marker paint so dots are never drawn with a
    // status list the server has not confirmed yet.
    let statusConfigReady: Promise<void> | null = null;

    async function loadStatusConfig() {
        if (isEnvBrowser()) {
            // Browser preview has no NUI to ask, and with no cache the list
            // would be empty and every dot grey. Sample data only — the game
            // never reaches this branch.
            if (statusDefs.length === 0) {
                statusDefs = [
                    { id: "active", label: "Available", color: "#22C55E", icon: "●" },
                    { id: "busy",   label: "Busy",      color: "#F59E0B", icon: "●" },
                ];
            }
            return;
        }
        try {
            const res = await fetchNui(
                NUI_EVENTS.MAP.GET_OFFICER_STATUS_CONFIG,
                {},
                { statuses: statusDefs, default: defaultStatusId },
            );
            const statuses = (res as any).statuses;
            let changed = false;
            if (Array.isArray(statuses) && statuses.length > 0) {
                changed = JSON.stringify(statuses) !== JSON.stringify(statusDefs);
                statusDefs = statuses;
            }
            if (typeof (res as any).default === "string") defaultStatusId = (res as any).default;

            // Remembered for the next open, so a server that customises its
            // status list gets correct colours from the very first frame
            // instead of a hardcoded guess.
            if (Array.isArray(statuses) && statuses.length > 0) {
                writeStatusCache(statuses, defaultStatusId);
            }

            // Leaflet markers are built imperatively, so an updated status list
            // does not repaint them on its own — without this they would keep
            // the seed colours until the next poll, up to 10 seconds later.
            // Only reached when markers were already drawn before the config
            // arrived (a push beat the fetch); the normal path awaits this
            // promise first and never needs the extra pass.
            if (changed && officers.length > 0) {
                refreshTracking();
            }
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
    let ownCitizenId = $state<string | null>(null);
    let isSelfAttached = $derived(
        !!(selectedDispatch && ownCitizenId && attachedIds(selectedDispatch).has(ownCitizenId))
    );

    // The call this officer is currently attached to (if any) — used to stop
    // silent double-attaches: being on two calls at once is almost never
    // what anyone intended. Lives below ownCitizenId's declaration on purpose
    // (TS use-before-declaration).
    let myCurrentCall = $derived(
        ownCitizenId
            ? visibleDispatches.find(d => (d.units || []).some(u => u.citizenid === ownCitizenId)) ?? null
            : null,
    );

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
        // Only one focus at a time: opening an officer closes the call card.
        if (selectedDispatchId) {
            selectedDispatchId = null;
            renderDispatchMarkers();
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

        // Bodycam feed, mirroring the vehicle popup's dashcam action. Three states rather
        // than two: a camera that is switched off is a different thing from an officer
        // who has no bodycam id at all, and saying so saves a pointless click.
        const bodycamId = officer.bodycamId;
        const bodycamOnline = officer.bodycamOnline !== false;
        const bodycamAction = !bodycamId
            ? `<div class="veh-note">No bodycam available</div>`
            : bodycamOnline
                ? `<button class="op-bodycam-btn" data-bodycam="${bodycamId}">
                       <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17 10.5V7a1 1 0 0 0-1-1H4a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-3.5l4 4v-11l-4 4z"/></svg>
                       View Bodycam
                   </button>`
                : `<div class="veh-note veh-note--off">
                       <span class="bc-dot"></span>Bodycam switched off — no feed
                   </div>`;

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
                    <div class="veh-actions">${bodycamAction}</div>
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

    // Open an officer's bodycam feed. Same callback the Bodycams tab uses; the server
    // re-checks permission and current power state, so a stale popup can't force a feed.
    async function viewOfficerBodycam(bodycamId: string) {
        if (!bodycamId) return;
        try {
            const res: any = await fetchNui(NUI_EVENTS.BODYCAM.VIEW_BODYCAM, bodycamId);
            if (res && res.success === false) {
                globalNotifications.error(res.message || "No bodycam feed available");
            }
        } catch {
            globalNotifications.error("No bodycam feed available");
        }
    }

    // The officer popup is a standalone L.popup rather than a marker popup, and its
    // content is replaced on every tracking refresh — so the button has to be re-wired
    // after each setContent, not once on open.
    function attachOfficerBodycamHandler(popup: L.Popup, bodycamId?: string) {
        if (!bodycamId) return;
        const btn = popup.getElement()?.querySelector(".op-bodycam-btn") as HTMLButtonElement | null;
        if (!btn) return;
        btn.onclick = (ev) => {
            ev.preventDefault();
            ev.stopPropagation();
            viewOfficerBodycam(bodycamId);
        };
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
        const latlng  = toMapLatLng(officer.coords);

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

            attachOfficerBodycamHandler(highlightPopup, officer.bodycamId);
            highlightPopup.on("remove", () => { clearOfficerHighlight(); });

            // Glide over on first selection, kept centered in the visible area.
            flyToCentered(latlng, Math.max(map.getZoom(), 5));
        }

        // Always update popup: position + full content (so all live data refreshes)
        if (highlightPopup) {
            highlightPopup.setLatLng(latlng);
            highlightPopup.setContent(buildOfficerPopupHtml(officer));
            attachOfficerBodycamHandler(highlightPopup, officer.bodycamId);
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

    // GTA→map linear calibration — measured in-game with reference points
    // (deep south + far north). sx/sy correct the slight scale drift of this
    // map render (positions used to slide off toward the south/north edges),
    // ox/oy shift the whole layer.
    const CALIB_SX = 0.995209;
    const CALIB_SY = 1.003941;
    const CALIB_OX = 2.47;
    const CALIB_OY = 7.61;

    // Returns a real LatLng rather than a [lat, lng] array: every caller had
    // to cast the array back to a Leaflet type, and casting number[] to
    // L.LatLng is not a conversion TypeScript can vouch for.
    function toMapLatLng(coords: { x: number; y: number }): L.LatLng {
        return L.latLng(CALIB_SY * coords.y + CALIB_OY, CALIB_SX * coords.x + CALIB_OX);
    }
    function toGtaCoords(latlng: L.LatLng): GtaPoint {
        return { x: (latlng.lng - CALIB_OX) / CALIB_SX, y: (latlng.lat - CALIB_OY) / CALIB_SY };
    }

    let mapImageBounds: L.LatLngBounds | null = null;
    let cayoImageBounds: L.LatLngBounds | null = null;

    // Cayo Perico overlay placement — tuned in-game. Anchored at the image's
    // bottom-center (southern road tip) and scaled upward/outward from there.
    const CAYO_ANCHOR_X = 4735;
    const CAYO_BOTTOM_Y = -6305;
    const CAYO_SCALE    = 1.225;

    function cayoBounds(): L.LatLngBounds {
        const w = 1900 * CAYO_SCALE;
        const h = 1900 * CAYO_SCALE;
        return new LatLngBounds(
            toMapLatLng({ x: CAYO_ANCHOR_X - w / 2, y: CAYO_BOTTOM_Y }) as L.LatLngExpression,
            toMapLatLng({ x: CAYO_ANCHOR_X + w / 2, y: CAYO_BOTTOM_Y + h }) as L.LatLngExpression,
        );
    }

    // Default view: the island centered in the VISIBLE area — when the
    // officers/patrols sidebar is open it covers the right side, so the
    // center point shifts right by half the covered strip to compensate.
    const DEFAULT_VIEW_ZOOM = 2.75;

    function defaultViewTarget(): L.LatLng {
        const island = mapImageBounds ? mapImageBounds.getCenter() : L.latLng(-300, -1500);
        if (!map) return island;
        const coveredPx = sidebarVisible ? sidebarWidth + 34 : 0;
        const p = map.project(island, DEFAULT_VIEW_ZOOM).add([coveredPx / 2, 0]);
        return map.unproject(p, DEFAULT_VIEW_ZOOM);
    }

    // Reduced motion (Settings > Appearance): fly animations become instant
    // jumps. flyTo animates zoom+pan in JS every frame, and each frame's
    // transform update would fight the global transition kill-switch — the
    // result is exactly the stutter reduced motion is meant to avoid.
    function motionReduced(): boolean {
        return document.documentElement.classList.contains("mdt-reduced-motion");
    }

    // Fly to a map point but keep it centered in the VISIBLE area: when the
    // sidebar is open it covers the right strip, so we nudge the target left by
    // half that strip (in pixels at the destination zoom) before flying.
    function flyToCentered(target: L.LatLngExpression, zoom: number, duration = 0.9) {
        if (!map) return;
        const ll = L.latLng(target as L.LatLngExpression);
        const coveredPx = sidebarVisible ? sidebarWidth + 34 : 0;
        const p = map.project(ll, zoom).add([coveredPx / 2, 0]);
        if (motionReduced()) {
            map.setView(map.unproject(p, zoom), zoom, { animate: false });
            return;
        }
        map.flyTo(map.unproject(p, zoom), zoom, { duration, easeLinearity: 0.25 });
    }

    function flyBackToMap() {
        if (!map) return;
        if (motionReduced()) {
            map.setView(defaultViewTarget(), DEFAULT_VIEW_ZOOM, { animate: false });
        } else {
            map.flyTo(defaultViewTarget(), DEFAULT_VIEW_ZOOM, { duration: 1.2, easeLinearity: 0.25 });
        }
        showBackToMap = false;
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
        const latlngs = patrol.zonePoints.map(pt => toMapLatLng(pt));
        const poly = L.polygon(latlngs, {
            color: patrol.color, weight: 2.5, opacity: 0.9,
            fillColor: patrol.color, fillOpacity: 0.1,
            lineJoin: "round", className: "patrol-zone-poly",
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

    // ── Snap-to-nearest-point ──────────────────────────────────────────────────
    // While drawing, the cursor snaps to nearby vertices: the points already
    // placed in THIS zone (so you can close cleanly or align edges) and the
    // vertices of OTHER patrols' zones (so adjacent zones share exact borders).
    // Distance is measured in on-screen container pixels so the snap radius feels
    // consistent regardless of map zoom.
    const SNAP_PX = 12;
    let snapMarker: L.CircleMarker | null = null;

    function getSnapCandidates(): L.LatLng[] {
        const out: L.LatLng[] = [];
        for (const p of drawPoints) out.push(p);
        for (const patrol of patrols) {
            if (patrol.id === drawingPatrolId || !patrol.zonePoints) continue;
            for (const pt of patrol.zonePoints) {
                out.push(toMapLatLng(pt));
            }
        }
        return out;
    }

    // Returns the nearest snap target within SNAP_PX, or null. firstPointOnly keeps
    // the close-the-loop behaviour intact even when general snapping is in play.
    function findSnap(latlng: L.LatLng): L.LatLng | null {
        if (!map) return null;
        const cp = map.latLngToContainerPoint(latlng);
        let best: L.LatLng | null = null;
        let bestD = SNAP_PX;
        for (const cand of getSnapCandidates()) {
            const pp = map.latLngToContainerPoint(cand);
            const d = Math.hypot(pp.x - cp.x, pp.y - cp.y);
            if (d < bestD) { bestD = d; best = cand; }
        }
        return best;
    }

    function showSnap(latlng: L.LatLng) {
        if (!map) return;
        if (!snapMarker) {
            snapMarker = L.circleMarker(latlng, {
                radius: 7, color: "#ffffff", weight: 2, opacity: 0.95,
                fill: false, interactive: false, className: "zone-snap-ring",
            }).addTo(map);
        } else {
            snapMarker.setLatLng(latlng);
        }
    }

    function hideSnap() {
        snapMarker?.remove();
        snapMarker = null;
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
        // Never draw a zone and pick a call location at the same time.
        if (ccPicking) cancelPick();
        stopDrawing(false);
        drawingPatrolId = patrolId;
        drawPoints = [];
        // Hide native cursor, use our DOM dot instead (immune to CSS zoom offset)
        mapContainer?.classList.add("map-cursor-none");
        createCursorDot();
        map.on("mousemove", onDrawMouseMove);
        map.on("click", onDrawClick);
        globalNotifications.info("Click to place points • snaps to nearby vertices • Enter to finish • Backspace to undo • Esc to cancel");
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
        const clickFudgeX = 46;
        const clickFudgeY = 32;

        // rect + clientX/Y are on-screen (scaled) px; Leaflet's container point is
        // in unscaled layout px, so undo the scale on the offset from the edge.
        const x = ((oe.clientX - rect.left) / scale) - clickFudgeX;
        const y = ((oe.clientY - rect.top)  / scale) - clickFudgeY;
        return map.containerPointToLatLng(L.point(x, y));
    }

    function onDrawMouseMove(e: L.LeafletMouseEvent) {
        if (!map) return;
        let latlng = mouseEventToLatLng(e);
        // Position cursor dot directly using native mouse coords — no zoom distortion
        const oe = e.originalEvent as MouseEvent;
        moveCursorDot(oe.clientX, oe.clientY);
        // Snap the preview vertex to a nearby existing point and flag it visually.
        const snap = findSnap(latlng);
        if (snap) { latlng = snap; showSnap(snap); } else { hideSnap(); }
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
        let latlng = mouseEventToLatLng(e);
        // Apply the same snap as the live preview so the stored vertex matches.
        const snap = findSnap(latlng);
        if (snap) latlng = snap;
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
        hideSnap();
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
        // tilts with heading (the counter-rotation lives in CSS via --rot).
        // Only bodycams (officers) carry a status — vehicle markers are untouched.
        const statusDot = (kind === "bodycam" && statusColor)
            ? `<div class="tracking-status-dot" style="background:${statusColor}"></div>`
            : "";

        // Rotation is applied through a CSS variable so per-tick heading
        // changes can be written onto the EXISTING element (one style property)
        // instead of rebuilding the whole divIcon DOM — see applyTrackIcon.
        return L.divIcon({
            className: "",
            html: `
                <div class="tracking-dot-wrap${cachedClass}" style="--rot:${rotation}deg">
                    <div class="tracking-dot" style="background:${dotColor}; border: 2px solid ${borderColor}"></div>
                    ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}" style="${patrolColor ? `border-bottom-color:${patrolColor}` : ""}"></div>` : ""}
                    ${statusDot}
                </div>
            `,
            iconSize: [20, 20],
            iconAnchor: [10, 10],
        });
    }

    // Structural identity of a tracker icon — everything EXCEPT heading. As
    // long as this key is unchanged, refresh ticks only rotate the existing
    // element; setIcon (full DOM replacement + repaint) is skipped entirely.
    function trackIconKey(
        kind: "vehicle" | "bodycam",
        heading?: number,
        patrolColor?: string,
        cached = false,
        statusColor?: string
    ): string {
        return `${kind}|${patrolColor ?? ""}|${cached ? 1 : 0}|${statusColor ?? ""}|${heading != null ? 1 : 0}`;
    }

    // Cheap per-tick marker update. Previously every refreshTracking tick
    // called setIcon() on every marker (heading changes each tick), replacing
    // its DOM node and forcing layout+paint for the entire fleet — a major
    // source of jank while the map is being zoomed/panned. Now setIcon only
    // fires when the icon's structure actually changed (patrol color, status,
    // cached state); pure heading updates are a single CSS-variable write.
    function applyTrackIcon(
        m: L.Marker,
        kind: "vehicle" | "bodycam",
        heading?: number,
        patrolColor?: string,
        cached = false,
        statusColor?: string
    ) {
        const key = trackIconKey(kind, heading, patrolColor, cached, statusColor);
        if ((m as any).__iconKey !== key) {
            m.setIcon(makeTrackIcon(kind, heading, patrolColor, cached, statusColor));
            (m as any).__iconKey = key;
        }
        const wrap = m.getElement()?.querySelector(".tracking-dot-wrap") as HTMLElement | null;
        if (wrap) wrap.style.setProperty("--rot", `${heading != null ? 360 - heading : 0}deg`);
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
        const offset: [number, number] = [0, -10];
        const m = L.marker(toMapLatLng(coords) as any, {
            icon: makeTrackIcon(kind, heading, patrolColor, cached, statusColor),
        }).bindTooltip(label, { direction: "top", offset });
        // Stamp the structural key so the first applyTrackIcon call after
        // creation doesn't redundantly rebuild the icon it was born with.
        (m as any).__iconKey = trackIconKey(kind, heading, patrolColor, cached, statusColor);
        return m;
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
        applyTrackIcon(marker, "bodycam", officer.heading, color, false, sColor);
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
                // Sentinel fallback: on a timeout/abort fetchNui returns THIS, and
                // the success===false guard below then keeps the current officers
                // and vehicles instead of clearing every marker. Without it a slow
                // GET_TRACKING (common right after opening the tab) returns empty
                // arrays and blanks all officers for a refresh cycle (~3s flicker).
                { success: false },
                8000,
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
                    // This object is rebuilt field by field, so anything omitted here is
                    // silently dropped from the payload — the popup's bodycam action
                    // depends on both of these surviving the copy.
                    bodycamId: (bodycam as any).bodycamId,
                    bodycamOnline: (bodycam as any).bodycamOnline,
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
                    applyTrackIcon(existing, "bodycam", bodycam.heading, color, false, sColor);
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

            // Pan to own position once per MDT open — user preference
            // (Settings > Map > "Center on my position", default on).
            // Uses the preferred default zoom so both settings play together.
            if (!centeredOnSelf && map && ownCitizenId && readPreferences().centerOnSelf !== false) {
                const self = freshOfficers.find(o => o.citizenid === ownCitizenId);
                if (self) {
                    centeredOnSelf = true;
                    const z = Number(readPreferences().defaultZoom);
                    map.setView(toMapLatLng(self.coords) as L.LatLngExpression,
                        Number.isFinite(z) && z >= 2 && z <= 8 ? z : 5, { animate: false });
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
                    applyTrackIcon(existing, "vehicle", (vehicle as any).heading, undefined, cached);
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

        if (type === "trackingDirty") {
            // Debounce: a burst of dirty signals collapses into one refetch.
            if (dirtyDebounce) clearTimeout(dirtyDebounce);
            dirtyDebounce = setTimeout(() => {
                dirtyDebounce = null;
                refreshTracking();
            }, 250);
            return;
        }

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

        if (type === "updateRecentDispatches") {
            if (Array.isArray(data)) {
                dispatches = data;
                renderDispatchMarkers();
            }
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

    function getMapBounds(map: Map) {
        const sw = map.unproject([0, 1024], 2);
        const ne = map.unproject([1024, 0], 2);
        return new LatLngBounds(sw, ne);
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
            // Zoom far enough out to see the entire map at once.
            minZoom: 2,
            maxZoom: 10,
            // Default zoom is a user preference (Settings > Map, 2–8);
            // falls back to the classic 5 when unset or out of range.
            zoom: (() => {
                const z = Number(readPreferences().defaultZoom);
                return Number.isFinite(z) && z >= 2 && z <= 8 ? z : 5;
            })(),
            preferCanvas: true,
            center: [0, -1024],
            zoomControl: false,
            // Arrow keys page the call ticker instead of panning the map.
            keyboard: false,
            // Smooth scroll-zoom: quarter-step snapping with a fast, light
            // wheel response (lower px/level = quicker, less "sticky").
            zoomSnap: 0.25,
            zoomDelta: 0.5,
            wheelPxPerZoomLevel: 70,
            wheelDebounceTime: 20,
            zoomAnimation: true,
            zoomAnimationThreshold: 8,
            bounceAtZoomLimits: false,
            // Drag momentum — a flick keeps gliding and eases out.
            inertia: true,
            inertiaDeceleration: 2600,
            inertiaMaxSpeed: 2000,
            easeLinearity: 0.22,
        } as any);

        L.control.zoom({ position: "topright" }).addTo(map);

        // While the user pans or zooms, tag the container with .map-busy so CSS
        // can pause the infinite pulse animations and drop the glow box-shadows
        // on call markers. Animated shadows/scales force a repaint every frame,
        // which compounds with the zoom transform — on a busy server with many
        // active calls this alone causes visible stutter. The short release
        // delay stops flicker between chained wheel-zoom steps.
        let busyRelease: ReturnType<typeof setTimeout> | null = null;
        const markBusy = () => {
            if (busyRelease) { clearTimeout(busyRelease); busyRelease = null; }
            mapContainer?.classList.add("map-busy");
        };
        const releaseBusy = () => {
            if (busyRelease) clearTimeout(busyRelease);
            busyRelease = setTimeout(() => { mapContainer?.classList.remove("map-busy"); }, 150);
        };
        map.on("zoomstart movestart", markBusy);
        map.on("zoomend moveend", releaseBusy);

        // Location picker for the Create Call modal (only active while picking).
        map.on("click", (e: L.LeafletMouseEvent) => {
            if (ccPicking && !drawingPatrolId) onPickLocation(toGtaCoords(mouseEventToLatLng(e)));
        });


        // Image placement bounds (world extent of the map render). Intentionally
        // NOT applied as maxBounds: units can roam far off the island (e.g.
        // Cayo Perico), so the view must be free to follow them without being
        // pulled back toward the mainland.
        const bounds = getMapBounds(map);
        mapImageBounds = bounds;
        map.setView(defaultViewTarget(), DEFAULT_VIEW_ZOOM, { animate: false });

        // Offer a way back once the island has left the viewport entirely.
        map.on("moveend", () => {
            if (!map) return;
            const view = map.getBounds();
            const onMain = mapImageBounds ? view.intersects(mapImageBounds) : true;
            const onCayo = cayoImageBounds ? view.intersects(cayoImageBounds) : false;
            showBackToMap = !onMain && !onCayo;
        });
        map.attributionControl.setPrefix(false);

        L.imageOverlay("./images/map.jpeg", bounds).addTo(map);

        // ── Cayo Perico overlay ─────────────────────────────────────────────
        // Placed in WORLD coordinates via toMapLatLng, so the calibrated unit
        // markers line up with the island graphic automatically.
        //
        // The image is anchored at its BOTTOM-CENTER (the southern road tip,
        // which is confirmed to line up) and grows upward/outward from there.
        // If a unit in the north (airport) sits beyond the graphic, the image
        // is too small → raise CAYO_SCALE in ~0.05 steps. If the airport spot
        // is drawn past the marker, lower it. Shift the whole island left or
        // right with CAYO_ANCHOR_X.
        cayoImageBounds = cayoBounds();
        L.imageOverlay("./images/cayo.jpeg", cayoImageBounds).addTo(map);


        vehicleLayer = L.layerGroup().addTo(map);
        bodycamLayer = L.layerGroup().addTo(map);
        patrolLayer  = L.layerGroup().addTo(map);
        zoneLayer    = L.layerGroup().addTo(map);

        syncLayerVisibility();

        // Staggered startup: the map frame (tiles + overlays + layers) is up now;
        // defer the data fetches and marker rendering to later frames so opening
        // the tab doesn't spike a single game tick. Each step yields first.
        const idle = (fn: () => void, delay: number) => setTimeout(fn, delay);
        idle(async () => {
            // Wait for the status list, otherwise officers on any status
            // beyond the seeded ones paint grey for the first frames.
            try { await statusConfigReady; } catch { /* seeded defs stand */ }
            refreshTracking();
        }, 0);                              // next frame: officers/vehicles/bodycams
        idle(() => loadDispatches(), 60);   // then: dispatch calls + markers

        window.addEventListener("keydown", handleTickerKeys);

        // One-time cleanup of leftover calibration/tuning storage. Guarded so it
        // only touches localStorage once ever, instead of on every tab open.
        if (localStorage.getItem("mdt_legacy_cleanup") !== "1") {
            for (const k of ["mdt_calib", "mdt_calib_pts", "mdt_calib_tool", "mdt_map_icon_style", "mdt_cayo_cal", "mdt_cayo_tool"]) {
                localStorage.removeItem(k);
            }
            localStorage.setItem("mdt_legacy_cleanup", "1");
        }

        // Pushes (trackingDirty) drive freshness now; this poll is only a
        // safety net in case an event is ever missed, so it can run slower.
        refreshTimer = setInterval(() => { refreshTracking(); loadDispatches(); }, 10000);
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
        // Pull our own citizenid as a fallback: the Lua push (setLocalCitizenId)
        // fires once per MDT open and is lost if this component wasn't mounted
        // yet — without it, the nearby-units self-filter and center-on-self
        // have no idea who "self" is.
        fetchNui<{ citizenid?: string }>(NUI_EVENTS.MAP.GET_LOCAL_CITIZEN_ID, {}, {})
            .then(r => { if (!ownCitizenId && typeof r?.citizenid === "string") ownCitizenId = r.citizenid; })
            .catch(() => { /* push path remains */ });
        // Status colours have to be known BEFORE the first markers are drawn,
        // so this one starts immediately rather than being deferred like the
        // genuinely secondary fetches below.
        statusConfigReady = loadStatusConfig();
        setTimeout(() => loadPatrols(), 180);
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
        if (dirtyDebounce) { clearTimeout(dirtyDebounce); dirtyDebounce = null; }
        bodycamMarkers.clear();
        vehicleMarkers.clear();
        dispatchMarkers.clear();
        window.removeEventListener("keydown", handleTickerKeys);
    });

    // These effects react to layer-toggle changes. On first mount the data
    // isn't loaded yet and initializeMap() already does the initial render, so
    // we skip the very first (synchronous) run of each to avoid doing the same
    // rendering work twice in the opening frame.
    let effectsArmed = $state(false);
    onMount(() => { effectsArmed = true; });

    $effect(() => { syncLayerVisibility(); });
    $effect(() => { showPatrols; if (effectsArmed) refreshPatrolLabels(); });
    $effect(() => { showZones; if (effectsArmed) renderAllZones(); });
    $effect(() => { showCalls; if (effectsArmed) renderDispatchMarkers(); });
</script>
<div class="map-page">
    <div class="map-wrapper" style="--sidebar-width:{sidebarWidth}px; --zoom-offset:{sidebarVisible ? sidebarWidth + 46 : 12}px">

        {#if showBackToMap}
            <button class="back-to-map" onclick={flyBackToMap}>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"/><line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/></svg>
                Back to map
            </button>
        {/if}

        <!-- ─── Dispatch call ticker (newest calls, click to focus) ─── -->
        {#if showCalls && tickerAll.length > 0}
            <div class="call-ticker">
                {#if tickerPages > 1}
                    <button class="ticker-nav" disabled={tickerPage === 0} title="Previous calls (←)" onclick={() => tickerNav(-1)}>‹</button>
                {/if}
                {#each tickerCalls as d (d.id)}
                    <div class="ticker-chip" class:active={String(d.id) === selectedDispatchId}>
                        <button class="ticker-main" onclick={() => selectDispatch(String(d.id))}>
                            <span class="ticker-dot" style="background:{priorityColor(d.priority)}"></span>
                            <span class="ticker-code">{d.code || d.codename || "CALL"}</span>
                            <span class="ticker-text">{d.message || d.street || ""}</span>
                            <span class="ticker-age">{dispatchAge(d.time)}</span>
                        </button>
                        {#if canAssignUnits}
                            <button class="ticker-x" title="Dismiss call for everyone" onclick={() => requestDismiss(String(d.id))}>✕</button>
                        {/if}
                    </div>
                {/each}
                {#if tickerPages > 1}
                    <span class="ticker-page">{tickerPage + 1}/{tickerPages}</span>
                    <button class="ticker-nav" disabled={tickerPage === tickerPages - 1} title="Next calls (→)" onclick={() => tickerNav(1)}>›</button>
                {/if}
            </div>
        {/if}



        <!-- ─── Selected call card ─── -->
        {#if selectedDispatch}
            <div class="call-card">
                <div class="call-card-header">
                    <span class="call-prio-dot" style="background:{priorityColor(selectedDispatch.priority)}"></span>
                    <span class="call-title">{selectedDispatch.code || selectedDispatch.codename || "Call"}{#if selectedDispatch.codename && selectedDispatch.code} · {selectedDispatch.codename}{/if}</span>
                    {#if canAssignUnits}
                        <button class="call-close call-dismiss" title="Dismiss call for everyone (removes it from all MDTs)" aria-label="Dismiss" onclick={() => requestDismiss(String(selectedDispatch!.id))}>
                            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                        </button>
                    {/if}
                    <button class="call-close" aria-label="Close" onclick={() => { selectedDispatchId = null; renderDispatchMarkers(); }}>
                        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                    </button>
                </div>
                <div class="call-card-body">
                    {#if selectedDispatch.message}
                        <div class="call-message">{selectedDispatch.message}</div>
                    {/if}
                    <div class="call-meta">
                        {#if selectedDispatch.street}<span>{selectedDispatch.street}</span>{/if}
                        {#if selectedDispatch.time}<span>{dispatchAge(selectedDispatch.time)}</span>{/if}
                    </div>

                    <!-- Dispatch note (one per call) -->
                    <div class="call-note-block">
                        <div class="call-note-head">
                            <span class="call-section-label">Dispatch note</span>
                            {#if canManageNotes && !noteEditing}
                                {#if selectedDispatch.note}
                                    <div class="call-note-actions">
                                        <button class="note-mini-btn" title="Edit note" disabled={noteBusy} onclick={startNoteEdit}>Edit</button>
                                        <button class="note-mini-btn danger" title="Remove note" disabled={noteBusy} onclick={deleteNote}>Remove</button>
                                    </div>
                                {:else}
                                    <button class="note-mini-btn" title="Add a note for units on this call" disabled={noteBusy} onclick={startNoteEdit}>+ Add</button>
                                {/if}
                            {/if}
                        </div>

                        {#if noteEditing}
                            <textarea
                                class="note-input"
                                bind:value={noteDraft}
                                maxlength={NOTE_MAX}
                                rows="3"
                                placeholder="Info for assigned units — e.g. suspect fled north, approach with caution…"
                            ></textarea>
                            <div class="note-edit-row">
                                <span class="note-count">{noteDraft.length}/{NOTE_MAX}</span>
                                <div class="note-edit-btns">
                                    <button class="call-btn call-btn-ghost" disabled={noteBusy} onclick={cancelNoteEdit}>Cancel</button>
                                    <button class="call-btn call-btn-accent" disabled={noteBusy || !noteDraft.trim()} onclick={saveNote}>Save note</button>
                                </div>
                            </div>
                        {:else if selectedDispatch.note}
                            <div class="call-note">
                                <div class="call-note-text">{selectedDispatch.note.text}</div>
                                {#if selectedDispatch.note.author}
                                    <div class="call-note-author">— {selectedDispatch.note.author}</div>
                                {/if}
                            </div>
                        {:else}
                            <div class="call-empty">{canManageNotes ? "No note yet — add one for assigned units." : "No note for this call."}</div>
                        {/if}
                    </div>

                    <!-- Attached units -->
                    <div class="call-section-label">Units on call ({(selectedDispatch.units || []).length})</div>
                    {#if (selectedDispatch.units || []).length > 0}
                        <div class="call-units">
                            {#each selectedDispatch.units || [] as u (u.citizenid)}
                                <span class="call-unit-chip">
                                    {unitLabel(u)}
                                    {#if canAssignUnits || (ownCitizenId && u.citizenid === ownCitizenId)}
                                        <button class="unit-remove" title="Remove from call" disabled={assignBusy} onclick={() => removeUnitFromCall(u.citizenid)}>✕</button>
                                    {/if}
                                </span>
                            {/each}
                        </div>
                    {:else}
                        <div class="call-empty">No units attached yet</div>
                    {/if}

                    <div class="call-self-row">
                        {#if isSelfAttached}
                            <button class="call-btn call-btn-ghost" disabled={assignBusy} onclick={() => selfAttachToCall(false)}>Detach yourself</button>
                        {:else}
                            <button class="call-btn call-btn-accent" disabled={assignBusy} onclick={requestSelfAttach}>Attach yourself</button>
                        {/if}
                    </div>

                    <!-- Dispatcher: quick-assign -->
                    {#if canAssignUnits}
                        {#if nearbyUnits.length > 0}
                            <div class="call-section-label">Assign nearby units</div>
                            <div class="call-nearby">
                                {#each nearbyUnits as { o, dist } (o.citizenid)}
                                    <div class="nearby-row">
                                        <span class="nearby-dot" style="background:{statusDef(o.status).color}"></span>
                                        <span class="nearby-name">{o.callsign ? `${o.callsign} · ` : ""}{o.name}</span>
                                        <span class="nearby-dist">{fmtDist(dist)}</span>
                                        <button class="nearby-add" title="Assign — sets their waypoint" disabled={assignBusy} onclick={() => assignUnits([o.citizenid], "attach")}>+</button>
                                    </div>
                                {/each}
                            </div>
                        {/if}
                        {#if nearbyPatrols.length > 0}
                            <div class="call-section-label">Nearest available patrols</div>
                            <div class="call-nearby">
                                {#each nearbyPatrols as { p, dist, count, st } (p.id)}
                                    <div class="nearby-row">
                                        <span class="nearby-dot" style="background:{p.color}"></span>
                                        <span class="nearby-name">{p.name}</span>
                                        <span class="patrol-status-mini" style="color:{st.color}">{st.label}</span>
                                        <span class="nearby-dist">{count} 👤 · {fmtDist(dist)}</span>
                                        <button class="nearby-add" title="Assign all online members — sets their waypoints" disabled={assignBusy} onclick={() => assignPatrolToCall(p)}>+</button>
                                    </div>
                                {/each}
                            </div>
                        {/if}
                    {/if}
                </div>
            </div>
        {/if}

        <!-- ═══ Dismiss confirmation ═══ -->
        {#if switchConfirmFrom}
            <!-- Already attached elsewhere: confirm before switching calls -->
            <div class="cc-backdrop" onclick={(e) => { if (e.target === e.currentTarget) switchConfirmFrom = null; }}>
                <div class="confirm-box" role="dialog" aria-modal="true">
                    <div class="confirm-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    </div>
                    <div class="confirm-title">Switch calls?</div>
                    <div class="confirm-text">You're already attached to <b>{switchConfirmFrom.code || switchConfirmFrom.codename || "another call"}</b>. Attaching here will detach you from it.</div>
                    <div class="confirm-btns">
                        <button class="call-btn call-btn-ghost" onclick={() => switchConfirmFrom = null}>Cancel</button>
                        <button class="call-btn call-btn-accent" onclick={confirmSwitchCall}>Yes, switch</button>
                    </div>
                </div>
            </div>
        {/if}

        {#if dismissConfirmId}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="cc-backdrop" onclick={(e) => { if (e.target === e.currentTarget) dismissConfirmId = null; }}>
                <div class="confirm-box" role="dialog" aria-modal="true">
                    <div class="confirm-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    </div>
                    <div class="confirm-title">Dismiss this call?</div>
                    <div class="confirm-text">It will be removed from the map and ticker for <b>every unit</b>. This can't be undone.</div>
                    <div class="confirm-btns">
                        <button class="call-btn call-btn-ghost" onclick={() => dismissConfirmId = null}>Cancel</button>
                        <button class="call-btn call-btn-danger" onclick={() => dismissCall(dismissConfirmId!)}>Dismiss call</button>
                    </div>
                </div>
            </div>
        {/if}

        <!-- ═══ Create Call modal ═══ -->
        {#if showCreateCall}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="cc-backdrop" class:picking={ccPicking} onclick={(e) => { if (e.target === e.currentTarget && !ccPicking) showCreateCall = false; }}>
                {#if ccPicking}
                    <div class="cc-pick-bar">
                        <div class="cc-pick-msg">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                            <span>{ccPendingGta ? "Location set — confirm or click again to move it" : "Click anywhere on the map to place the call"}</span>
                        </div>
                        <div class="cc-pick-actions">
                            <button class="call-btn call-btn-ghost" onclick={cancelPick}>Cancel</button>
                            <button class="call-btn call-btn-accent" disabled={!ccPendingGta} onclick={confirmPick}>Use this location</button>
                        </div>
                    </div>
                {:else}
                    <div class="cc-modal" role="dialog" aria-modal="true">
                        <div class="cc-head">
                            <span class="cc-title-txt">Create Call</span>
                            <button class="call-close" aria-label="Close" onclick={() => showCreateCall = false}>
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                            </button>
                        </div>
                        <div class="cc-body">
                            <div class="cc-field">
                                <span class="cc-label">10-Code</span>
                                <select class="cc-input cc-select" bind:value={ccCode}>
                                    <option value="">— Select a code —</option>
                                    {#each callCodes as c}
                                        <option value={c.code}>{c.code} · {c.label}</option>
                                    {/each}
                                </select>
                            </div>

                            <div class="cc-field">
                                <span class="cc-label">Title <span class="cc-optional">(optional — uses the code's label if empty)</span></span>
                                <input class="cc-input" bind:value={ccTitle} maxlength="80" placeholder={ccSelectedCode?.label ? `Default: ${ccSelectedCode.label}` : "Short summary…"} />
                            </div>

                            <div class="cc-field">
                                <span class="cc-label">Note <span class="cc-optional">(optional)</span></span>
                                <textarea class="cc-input cc-textarea" bind:value={ccNote} maxlength={CC_NOTE_MAX} rows="2" placeholder="Extra info for assigned units…"></textarea>
                            </div>

                            <div class="cc-field">
                                <span class="cc-label">Location</span>
                                {#if ccPickedGta}
                                    <div class="cc-location-set">
                                        <span class="cc-loc-street">{ccStreet || "Location set"}</span>
                                        <button class="cc-loc-repick" onclick={startLocationPick}>Re-pick</button>
                                    </div>
                                {:else}
                                    <button class="cc-pick-btn" onclick={startLocationPick}>
                                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                                        Pick location on map
                                    </button>
                                {/if}
                            </div>

                            <div class="cc-field">
                                <span class="cc-label">Assign patrols <span class="cc-optional">(available, nearest)</span></span>
                                {#if !ccPickedGta}
                                    <div class="cc-empty">Pick a location first to see nearby patrols.</div>
                                {:else if ccNearbyPatrols.length === 0}
                                    <div class="cc-empty">No available patrols near this location.</div>
                                {:else}
                                    <div class="cc-units">
                                        {#each ccNearbyPatrols as { p, dist, count, st } (p.id)}
                                            <button class="cc-unit-row" class:sel={ccSelectedPatrols.has(p.id)} onclick={() => ccTogglePatrol(p.id)}>
                                                <span class="cc-unit-check">{ccSelectedPatrols.has(p.id) ? "✓" : ""}</span>
                                                <span class="cc-unit-dot" style="background:{p.color}"></span>
                                                <span class="cc-unit-name">{p.name}</span>
                                                <span class="cc-patrol-meta" style="color:{st.color}">{st.label}</span>
                                                <span class="cc-unit-dist">{count} 👤 · {fmtDist(dist)}</span>
                                            </button>
                                        {/each}
                                    </div>
                                {/if}
                            </div>
                        </div>
                        <div class="cc-footer">
                            <span class="cc-footer-hint">{ccSelectedPatrols.size} patrol{ccSelectedPatrols.size === 1 ? "" : "s"} selected</span>
                            <div class="cc-footer-btns">
                                <button class="call-btn call-btn-ghost" disabled={ccBusy} onclick={() => showCreateCall = false}>Cancel</button>
                                <button class="call-btn call-btn-accent" disabled={ccBusy || !ccCode || !ccPickedGta} onclick={submitCreateCall}>Create call</button>
                            </div>
                        </div>
                    </div>
                {/if}
            </div>
        {/if}

        <div class="map-controls">
            <span class="controls-header">Tracking</span>
            <div class="controls-group">
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showVehicles} onchange={() => localStorage.setItem("mdt_map_vehicles", String(showVehicles))} />
                    <span class="toggle-label">Vehicles</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showCalls} onchange={() => localStorage.setItem("mdt_map_calls", String(showCalls))} />
                    <span class="toggle-label">Calls</span>
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
            <button class="create-call-btn" use:permissionHint={canAssignUnits ? null : "dispatch_assign"} onclick={openCreateCall}>
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                Create Call
            </button>
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
                        onclick={() => { statusPickerOpen = !statusPickerOpen; statusNoteDraft = ""; }}
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
        {:else}
            <button class="sidebar-toggle" type="button"
                use:permissionHint={"map_patrols_view"}
                aria-label="Patrols sidebar">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                    <path d="M6 3L11 8L6 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span class="sidebar-toggle-label">Patrols</span>
            </button>
        {/if}
    </div>
</div>

<style>
    /* ═══ Dispatch calls ═══ */
    :global(.disp-marker) {
        position: relative;
        width: 38px;
        height: 38px;
        cursor: pointer;
    }
    :global(.disp-marker .disp-badge) {
        position: absolute;
        top: 50%; left: 50%;
        width: 26px; height: 26px;
        transform: translate(-50%, -50%);
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--dc, #38bdf8);
        border: 2px solid rgba(0, 0, 0, 0.6);
        border-radius: 50%;
        color: #0c0c0c;
        box-shadow: 0 0 10px var(--dc, #38bdf8), 0 2px 6px rgba(0, 0, 0, 0.5);
    }
    :global(.disp-marker .disp-badge svg) {
        width: 15px;
        height: 15px;
    }
    :global(.disp-marker .disp-ring) {
        position: absolute;
        top: 50%; left: 50%;
        width: 34px; height: 34px;
        transform: translate(-50%, -50%);
        border: 3px solid var(--dc, #38bdf8);
        border-radius: 50%;
        opacity: 0.7;
        animation: dispPulse 1.5s ease-out infinite;
        /* Promote to its own compositor layer: transform+opacity animate on
           the GPU instead of repainting the marker every frame. */
        will-change: transform, opacity;
    }
    /* While the map is panning/zooming (.map-busy is set from zoomstart /
       movestart): freeze the pulse rings and drop the glow shadows so the
       compositor only has to MOVE the marker layers, not repaint them each
       frame. Restored ~150ms after the gesture settles. */
    :global(.map-busy .disp-ring) { animation-play-state: paused; opacity: 0.35; }
    :global(.map-busy .disp-badge) { box-shadow: none !important; }
    :global(.map-busy .officer-highlight-ring) { animation-play-state: paused; }
    :global(.disp-marker.sel .disp-badge) {
        transform: translate(-50%, -50%) scale(1.18);
        border-color: rgba(255, 255, 255, 0.85);
    }
    :global(.disp-marker.sel .disp-ring) { animation-duration: 0.85s; opacity: 1; }
    @keyframes dispPulse {
        0%   { transform: translate(-50%, -50%) scale(0.5); opacity: 0.9; }
        100% { transform: translate(-50%, -50%) scale(1.45); opacity: 0; }
    }

    .back-to-map {
        position: absolute;
        top: 92px;
        right: var(--zoom-offset, 12px);
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 6px 14px;
        background: rgba(17, 17, 17, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 3px;
        color: rgba(255, 255, 255, 0.85);
        font-size: 11px;
        font-weight: 600;
        cursor: pointer;
        z-index: 1000;
        box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
        transition: color 0.12s, background 0.12s, border-color 0.12s, right 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        animation: fadeInBtn 0.2s ease-out;
    }
    .back-to-map:hover {
        border-color: rgba(255, 255, 255, 0.3);
        color: #fff;
        background: rgba(28, 28, 28, 0.96);
    }
    @keyframes fadeInBtn { 0% { opacity: 0; transform: translateY(-6px); } 100% { opacity: 1; transform: translateY(0); } }

    .call-ticker {
        position: absolute;
        bottom: 12px;
        left: 12px;
        display: flex;
        gap: 6px;
        z-index: 1000;
        max-width: min(720px, calc(100% - 120px));
    }
    .ticker-chip {
        position: relative;
        display: inline-flex;
        align-items: center;
        background: rgba(17, 17, 17, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 3px;
        min-width: 0;
        transition: border-color 0.1s, background 0.1s;
        box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
    }
    .ticker-chip:hover { border-color: rgba(255, 255, 255, 0.2); }
    .ticker-chip.active { border-color: rgba(56, 189, 248, 0.5); background: rgba(56, 189, 248, 0.1); }
    .ticker-main {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 5px 10px;
        background: transparent;
        border: none;
        color: rgba(255, 255, 255, 0.75);
        font-size: 10px;
        cursor: pointer;
        min-width: 0;
    }
    .ticker-x {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 0;
        padding: 0;
        overflow: hidden;
        opacity: 0;
        background: transparent;
        border: none;
        color: rgba(255, 255, 255, 0.35);
        font-size: 10px;
        cursor: pointer;
        transition: all 0.12s;
    }
    .ticker-chip:hover .ticker-x { width: 20px; opacity: 1; }
    .ticker-x:hover { color: rgba(248, 113, 113, 1); }
    .ticker-nav {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 22px;
        align-self: stretch;
        background: rgba(17, 17, 17, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 3px;
        color: rgba(255, 255, 255, 0.6);
        font-size: 14px;
        font-weight: 700;
        cursor: pointer;
        transition: all 0.1s;
        box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
    }
    .ticker-nav:hover:not(:disabled) { color: #fff; border-color: rgba(255, 255, 255, 0.2); }
    .ticker-nav:disabled { opacity: 0.3; cursor: default; }
    .ticker-page {
        display: flex;
        align-items: center;
        font-size: 9px;
        font-weight: 700;
        color: rgba(255, 255, 255, 0.45);
        padding: 0 3px;
        font-variant-numeric: tabular-nums;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.8);
    }


    .ticker-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
    .ticker-code { font-weight: 700; flex-shrink: 0; }
    .ticker-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 160px; color: rgba(255, 255, 255, 0.55); }
    .ticker-age { flex-shrink: 0; color: rgba(255, 255, 255, 0.35); font-size: 9px; }

    .call-card {
        position: absolute;
        bottom: 46px;
        left: 12px;
        width: 280px;
        max-height: min(430px, calc(100% - 90px));
        display: flex;
        flex-direction: column;
        background: rgba(17, 17, 17, 0.96);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 6px;
        z-index: 1001;
        overflow: hidden;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    }
    .call-card-header {
        display: flex;
        align-items: center;
        gap: 7px;
        padding: 8px 10px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        flex-shrink: 0;
    }
    .call-prio-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
    .call-title { flex: 1; font-size: 11px; font-weight: 700; color: rgba(255, 255, 255, 0.9); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .call-close {
        display: flex; align-items: center; justify-content: center;
        background: transparent;
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 3px;
        padding: 3px;
        color: rgba(255, 255, 255, 0.35);
        cursor: pointer;
        transition: all 0.1s;
    }
    .call-close:hover { color: rgba(255, 255, 255, 0.8); border-color: rgba(255, 255, 255, 0.14); }
    .call-dismiss:hover { color: rgba(248, 113, 113, 0.95); border-color: rgba(239, 68, 68, 0.35); }
    .call-card-body { padding: 9px 10px; overflow-y: auto; display: flex; flex-direction: column; gap: 7px; }
    .call-card-body::-webkit-scrollbar { width: 4px; }
    .call-card-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }
    .call-message { font-size: 11px; color: rgba(255, 255, 255, 0.85); line-height: 1.4; }
    .call-meta { display: flex; gap: 10px; font-size: 9px; color: rgba(255, 255, 255, 0.4); }
    .call-section-label {
        font-size: 8px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.35);
        margin-top: 2px;
    }
    .call-units { display: flex; flex-wrap: wrap; gap: 4px; }
    .call-unit-chip {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        padding: 2px 6px;
        font-size: 9px;
        color: rgba(255, 255, 255, 0.75);
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.07);
        border-radius: 3px;
    }
    .unit-remove {
        background: none;
        border: none;
        color: rgba(255, 255, 255, 0.3);
        font-size: 9px;
        cursor: pointer;
        padding: 0 1px;
        transition: color 0.1s;
    }
    .unit-remove:hover:not(:disabled) { color: rgba(248, 113, 113, 0.9); }
    .call-empty { font-size: 10px; color: rgba(255, 255, 255, 0.3); font-style: italic; }

    /* Dispatch note */
    .call-note-block { display: flex; flex-direction: column; gap: 5px; }
    .call-note-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
    .call-note-actions { display: flex; gap: 4px; }
    .note-mini-btn {
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 3px;
        color: rgba(255, 255, 255, 0.6);
        font-size: 9px;
        font-weight: 600;
        padding: 2px 7px;
        cursor: pointer;
        transition: all 0.1s;
    }
    .note-mini-btn:hover:not(:disabled) { color: rgba(255, 255, 255, 0.9); border-color: rgba(255, 255, 255, 0.18); }
    .note-mini-btn.danger:hover:not(:disabled) { color: rgba(248, 113, 113, 0.95); border-color: rgba(239, 68, 68, 0.35); }
    .note-mini-btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .call-note {
        background: rgba(234, 179, 8, 0.06);
        border: 1px solid rgba(234, 179, 8, 0.22);
        border-left-width: 3px;
        border-radius: 4px;
        padding: 6px 9px;
    }
    .call-note-text { font-size: 11px; color: rgba(255, 255, 255, 0.85); line-height: 1.45; white-space: pre-wrap; word-break: break-word; }
    .call-note-author { font-size: 9px; color: rgba(255, 255, 255, 0.4); margin-top: 3px; text-align: right; }
    .note-input {
        width: 100%;
        box-sizing: border-box;
        resize: vertical;
        min-height: 52px;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 4px;
        color: rgba(255, 255, 255, 0.85);
        font-size: 11px;
        font-family: inherit;
        line-height: 1.45;
        padding: 6px 8px;
        outline: none;
        transition: border-color 0.1s;
    }
    .note-input:focus { border-color: rgba(234, 179, 8, 0.4); }
    .note-input::placeholder { color: rgba(255, 255, 255, 0.28); }
    .note-edit-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
    .note-count { font-size: 9px; color: rgba(255, 255, 255, 0.35); font-variant-numeric: tabular-nums; }
    .note-edit-btns { display: flex; gap: 5px; }

    /* Create Call button + modal */
    .create-call-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        width: 100%;
        padding: 6px 10px;
        background: rgba(56, 189, 248, 0.1);
        border: 1px solid rgba(56, 189, 248, 0.25);
        border-radius: 3px;
        color: rgba(125, 211, 252, 0.95);
        font-size: 10px;
        font-weight: 700;
        cursor: pointer;
        transition: all 0.1s;
    }
    .create-call-btn:hover { background: rgba(56, 189, 248, 0.18); border-color: rgba(56, 189, 248, 0.4); }

    .cc-backdrop {
        position: absolute;
        inset: 0;
        z-index: 1500;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(0, 0, 0, 0.55);
    }
    /* While picking, let clicks pass through to the map (except the bar). */
    .cc-backdrop.picking { background: transparent; pointer-events: none; }
    .cc-pick-bar {
        position: absolute;
        top: 14px;
        left: 50%;
        transform: translateX(-50%);
        display: flex;
        align-items: center;
        gap: 16px;
        max-width: calc(100% - 40px);
        padding: 10px 14px;
        background: rgba(20, 20, 22, 0.98);
        border: 1px solid rgba(56, 189, 248, 0.5);
        border-radius: 6px;
        pointer-events: auto;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.55), 0 0 0 3px rgba(56, 189, 248, 0.08);
    }
    .cc-pick-msg {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 12px;
        font-weight: 600;
        color: rgba(186, 230, 253, 0.95);
    }
    .cc-pick-msg svg { color: rgba(125, 211, 252, 0.9); flex-shrink: 0; }
    .cc-pick-actions { display: flex; gap: 6px; flex-shrink: 0; }
    :global(.cc-pin) {
        color: rgba(56, 189, 248, 1);
        filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.6));
        animation: ccPinDrop 0.25s ease-out;
    }
    :global(.cc-pin svg) { width: 30px; height: 30px; }
    @keyframes ccPinDrop {
        0% { transform: translateY(-8px); opacity: 0; }
        100% { transform: translateY(0); opacity: 1; }
    }
    .cc-modal {
        width: 340px;
        max-height: calc(100% - 40px);
        display: flex;
        flex-direction: column;
        background: rgba(20, 20, 22, 0.98);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    }
    .cc-head {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 11px 14px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.07);
        flex-shrink: 0;
    }
    .cc-title-txt { font-size: 13px; font-weight: 700; color: rgba(255, 255, 255, 0.92); }
    .cc-body { padding: 12px 14px; overflow-y: auto; display: flex; flex-direction: column; gap: 11px; }
    .cc-body::-webkit-scrollbar { width: 4px; }
    .cc-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }
    .cc-field { display: flex; flex-direction: column; gap: 4px; }
    .cc-label { font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255, 255, 255, 0.45); }
    .cc-optional { color: rgba(255, 255, 255, 0.25); font-weight: 500; text-transform: none; letter-spacing: 0; }
    .cc-input {
        width: 100%;
        box-sizing: border-box;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 4px;
        color: rgba(255, 255, 255, 0.88);
        font-size: 11px;
        font-family: inherit;
        padding: 6px 9px;
        outline: none;
        transition: border-color 0.1s;
    }
    .cc-input:focus { border-color: rgba(56, 189, 248, 0.45); }
    .cc-input::placeholder { color: rgba(255, 255, 255, 0.28); }
    .cc-select { cursor: pointer; }
    .cc-select option { background: #1a1d23; color: rgba(255, 255, 255, 0.85); }
    .cc-textarea { resize: vertical; min-height: 40px; line-height: 1.45; }
    .cc-pick-btn {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 7px 10px;
        background: rgba(56, 189, 248, 0.08);
        border: 1px dashed rgba(56, 189, 248, 0.35);
        border-radius: 4px;
        color: rgba(125, 211, 252, 0.9);
        font-size: 11px;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.1s;
    }
    .cc-pick-btn:hover { background: rgba(56, 189, 248, 0.14); }
    .cc-location-set {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 9px;
        background: rgba(34, 197, 94, 0.06);
        border: 1px solid rgba(34, 197, 94, 0.22);
        border-radius: 4px;
    }
    .cc-loc-street { flex: 1; font-size: 11px; color: rgba(255, 255, 255, 0.82); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .cc-loc-repick { background: none; border: none; color: rgba(125, 211, 252, 0.85); font-size: 9px; font-weight: 700; cursor: pointer; }
    .cc-loc-repick:hover { color: rgba(186, 230, 253, 1); }
    .cc-empty { font-size: 10px; color: rgba(255, 255, 255, 0.3); font-style: italic; padding: 4px 0; }
    .cc-units { display: flex; flex-direction: column; gap: 3px; max-height: 150px; overflow-y: auto; }
    .cc-units::-webkit-scrollbar { width: 4px; }
    .cc-units::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }
    .cc-unit-row {
        display: flex;
        align-items: center;
        gap: 7px;
        padding: 5px 7px;
        background: rgba(255, 255, 255, 0.025);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 3px;
        cursor: pointer;
        transition: all 0.1s;
        text-align: left;
    }
    .cc-unit-row:hover { border-color: rgba(255, 255, 255, 0.15); }
    .cc-unit-row.sel { background: rgba(56, 189, 248, 0.1); border-color: rgba(56, 189, 248, 0.4); }
    .cc-unit-check { width: 12px; font-size: 10px; font-weight: 800; color: rgba(125, 211, 252, 1); flex-shrink: 0; }
    .cc-unit-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
    .cc-unit-name { flex: 1; font-size: 10px; color: rgba(255, 255, 255, 0.78); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .cc-unit-dist { font-size: 9px; color: rgba(255, 255, 255, 0.35); flex-shrink: 0; font-variant-numeric: tabular-nums; }
    .cc-patrol-meta { font-size: 8px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; flex-shrink: 0; }
    .cc-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 10px;
        padding: 10px 14px;
        border-top: 1px solid rgba(255, 255, 255, 0.07);
        flex-shrink: 0;
    }
    .cc-footer-hint { font-size: 10px; color: rgba(255, 255, 255, 0.4); }
    .cc-footer-btns { display: flex; gap: 6px; }

    /* Dismiss confirmation */
    .confirm-box {
        width: 300px;
        background: rgba(20, 20, 22, 0.98);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 8px;
        padding: 20px;
        text-align: center;
        box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    }
    .confirm-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 44px;
        height: 44px;
        margin: 0 auto 12px;
        border-radius: 50%;
        background: rgba(239, 68, 68, 0.12);
        color: rgba(248, 113, 113, 0.95);
    }
    .confirm-title { font-size: 14px; font-weight: 700; color: rgba(255, 255, 255, 0.92); margin-bottom: 6px; }
    .confirm-text { font-size: 11px; line-height: 1.5; color: rgba(255, 255, 255, 0.55); margin-bottom: 16px; }
    .confirm-text b { color: rgba(255, 255, 255, 0.8); }
    .confirm-btns { display: flex; gap: 8px; justify-content: center; }
    .call-btn-danger {
        background: rgba(239, 68, 68, 0.14);
        border: 1px solid rgba(239, 68, 68, 0.4);
        color: rgba(248, 113, 113, 0.95);
    }
    .call-btn-danger:hover:not(:disabled) { background: rgba(239, 68, 68, 0.22); border-color: rgba(239, 68, 68, 0.55); }
    .call-self-row { display: flex; }
    .call-btn {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        padding: 4px 10px;
        border-radius: 3px;
        font-size: 10px;
        font-weight: 600;
        cursor: pointer;
        border: 1px solid transparent;
        transition: all 0.1s;
    }
    .call-btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .call-btn-accent {
        background: rgba(56, 189, 248, 0.1);
        border-color: rgba(56, 189, 248, 0.2);
        color: rgba(125, 211, 252, 0.9);
    }
    .call-btn-accent:hover:not(:disabled) { background: rgba(56, 189, 248, 0.18); }
    .call-btn-ghost {
        background: rgba(255, 255, 255, 0.03);
        border-color: rgba(255, 255, 255, 0.08);
        color: rgba(255, 255, 255, 0.55);
    }
    .call-btn-ghost:hover:not(:disabled) { color: rgba(255, 255, 255, 0.85); }
    .call-nearby { display: flex; flex-direction: column; gap: 3px; }
    .nearby-row {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 4px 6px;
        background: rgba(255, 255, 255, 0.025);
        border: 1px solid rgba(255, 255, 255, 0.04);
        border-radius: 3px;
    }
    .nearby-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
    .nearby-name { flex: 1; font-size: 10px; color: rgba(255, 255, 255, 0.75); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .nearby-dist { font-size: 9px; color: rgba(255, 255, 255, 0.35); flex-shrink: 0; font-variant-numeric: tabular-nums; }
    .nearby-add {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 18px; height: 18px;
        flex-shrink: 0;
        background: rgba(56, 189, 248, 0.1);
        border: 1px solid rgba(56, 189, 248, 0.25);
        border-radius: 3px;
        color: rgba(125, 211, 252, 0.9);
        font-size: 12px;
        font-weight: 700;
        line-height: 1;
        cursor: pointer;
        transition: all 0.1s;
    }
    .nearby-add:hover:not(:disabled) { background: rgba(56, 189, 248, 0.2); }
    .nearby-add:disabled { opacity: 0.4; cursor: not-allowed; }
    .patrol-status-mini { font-size: 8px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; flex-shrink: 0; }

    /* Marker hover tooltip */
    :global(.disp-tt) {
        background: rgba(17, 17, 17, 0.96) !important;
        border: 1px solid rgba(255, 255, 255, 0.12) !important;
        border-radius: 4px !important;
        color: rgba(255, 255, 255, 0.85) !important;
        font-size: 10px !important;
        line-height: 1.45 !important;
        padding: 6px 9px !important;
        box-shadow: 0 6px 18px rgba(0, 0, 0, 0.5) !important;
        white-space: nowrap;
    }
    :global(.disp-tt::before) { border-top-color: rgba(255, 255, 255, 0.12) !important; }

    :global(.leaflet-popup-content-wrapper) { background: var(--dark-bg); color: rgba(255,255,255,0.8); border-radius: 8px; border: 1px solid rgba(255,255,255,0.06); box-shadow: none; }
    :global(.leaflet-popup-tip) { background: var(--dark-bg); }
    :global(.leaflet-tooltip) { background: var(--dark-bg); color: rgba(255,255,255,0.8); border: 1px solid rgba(255,255,255,0.06); border-radius: 6px; font-size: 11px; padding: 4px 8px; box-shadow: none; }
    :global(.leaflet-tooltip-top::before) { border-top-color: #111111; }
    /* Zoom control: shifts left out from under the patrols/officers panel when
       it's open, and animates smoothly with the panel. */
    :global(.leaflet-top.leaflet-right) { right: var(--zoom-offset, 12px) !important; transition: right 0.25s cubic-bezier(0.4,0,0.2,1); }
    :global(.leaflet-control-zoom) { border: 1px solid rgba(255,255,255,0.08) !important; border-radius: 10px !important; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.45) !important; margin-top: 12px !important; }
    :global(.leaflet-control-zoom a) { background: rgba(17,17,17,0.94) !important; color: rgba(255,255,255,0.7) !important; border-color: rgba(255,255,255,0.06) !important; width: 32px !important; height: 32px !important; line-height: 32px !important; font-size: 16px !important; font-weight: 600 !important; transition: background 0.12s, color 0.12s; }
    :global(.leaflet-control-zoom a:hover) { background: rgba(56,189,248,0.18) !important; color: #fff !important; }
    :global(.leaflet-control-zoom a:active) { background: rgba(56,189,248,0.3) !important; }
    :global(.patrol-label) { background: rgba(0,0,0,0.55); border: 1px solid; border-radius: 4px; padding: 2px 6px; font-size: 9px; font-weight: 600; letter-spacing: 0.4px; text-transform: uppercase; white-space: nowrap; pointer-events: none; opacity: 0.7; }
    :global(.patrol-label-status-dot) { display: inline-block; vertical-align: middle; width: 5px; height: 5px; border-radius: 50%; margin-right: 4px; margin-bottom: 1px; }
    :global(.patrol-zone-poly) {
        transition: fill-opacity 0.25s ease, stroke-opacity 0.25s ease, stroke-width 0.15s ease;
        filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.55));
        animation: zone-fade-in 0.35s ease-out;
    }
    :global(.patrol-zone-poly:hover) { fill-opacity: 0.2 !important; stroke-width: 3.5 !important; }
    @keyframes zone-fade-in { from { opacity: 0; } to { opacity: 1; } }
    :global(.zone-snap-ring) {
        filter: drop-shadow(0 0 3px rgba(255, 255, 255, 0.85));
        animation: zone-snap-pulse 0.9s ease-in-out infinite;
    }
    @keyframes zone-snap-pulse { 0%, 100% { stroke-opacity: 0.95; } 50% { stroke-opacity: 0.35; } }
    :global(.zone-label) { background: rgba(0,0,0,0.62); border: 1px solid; border-radius: 5px; padding: 3px 8px; font-size: 10px; font-weight: 700; letter-spacing: 0.6px; text-transform: uppercase; white-space: nowrap; pointer-events: none; opacity: 0.85; transform: translateX(-50%); display: inline-block; }
    :global(.tracking-dot-wrap) { position: relative; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; transform: rotate(var(--rot, 0deg)); }
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
    :global(.map-cursor-cross) { cursor: crosshair !important; }
    :global(.map-cursor-cross .leaflet-interactive) { cursor: crosshair !important; }
    :global(.map-cursor-cross .leaflet-container) { cursor: crosshair !important; }

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

    /* Officer bodycam action. Same shape as the vehicle dashcam button but in the
       officer-blue accent, so the two read as siblings rather than the same thing. */
    :global(.op-bodycam-btn) {
        display: flex; align-items: center; justify-content: center; gap: 6px;
        width: 100%; padding: 6px 8px;
        background: rgba(56,189,248,0.14);
        color: rgba(147,197,253,0.95);
        border: 1px solid rgba(56,189,248,0.32);
        border-radius: 6px;
        font-size: 11px; font-weight: 600; cursor: pointer;
        transition: background 0.12s ease, border-color 0.12s ease;
    }
    :global(.op-bodycam-btn:hover) {
        background: rgba(56,189,248,0.26);
        border-color: rgba(56,189,248,0.5);
        color: #fff;
    }
    :global(.op-bodycam-btn svg) { flex-shrink: 0; }

    /* A switched-off bodycam gets a red note rather than a disabled button: there is
       nothing to click, and the reason is worth stating. */
    :global(.veh-note--off) {
        display: flex; align-items: center; justify-content: center; gap: 5px;
        color: rgba(248,113,113,0.8);
    }
    :global(.bc-dot) {
        width: 5px; height: 5px; border-radius: 50%;
        background: rgba(248,113,113,0.9); flex-shrink: 0;
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
    .map-container { flex: 1; height: 100%; background: #10a9d3; }
    /* Ocean-blue backdrop around the map image instead of bare white. */
    :global(.map-container .leaflet-container) { background: #10a9d3 !important; }
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
    .controls-divider { height: 1px; background: rgba(255,255,255,0.04); margin: 10px 0; }
    .control-toggle { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 12px; color: rgba(255,255,255,0.7); }
    .control-toggle input[type="checkbox"] { width: 14px; height: 14px; accent-color: rgba(var(--accent-rgb),0.7); cursor: pointer; }
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

    /* Status dot pinned onto the bodycam map marker */
    :global(.tracking-status-dot) { position: absolute; bottom: -2px; right: -2px; width: 7px; height: 7px; border-radius: 50%; border: 1.5px solid rgba(10,10,12,0.9); box-shadow: 0 0 4px rgba(0,0,0,0.6); transform: rotate(calc(-1 * var(--rot, 0deg))); }
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