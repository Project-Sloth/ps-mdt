<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import L, { CRS, Projection, LatLngBounds, Transformation, Map } from "leaflet";
    import "leaflet/dist/leaflet.css";
    import { fetchNui } from "../utils/fetchNui";
    import { isEnvBrowser } from "../utils/misc";
    import { NUI_EVENTS } from "../constants/nuiEvents";
    import { globalNotifications } from "../services/notificationService.svelte";

    let mapContainer: HTMLDivElement | null = null;
    let map: L.Map | null = null;
    let mapInitialized = false;
    let refreshTimer: ReturnType<typeof setInterval> | null = null;

    let tabVisible = $state(true);

    let showVehicles = $state(true);
    let showBodycams = $state(true);
    let iconStyle = $state<"dot" | "badge">("dot");

    let vehicleLayer = L.layerGroup();
    let bodycamLayer = L.layerGroup();

    const offsetX = 13;
    const offsetY = 5;

    function toMapLatLng(coords: { x: number; y: number }) {
        return [coords.y - offsetY, coords.x + offsetX];
    }

    function getTrackConfig(kind: "vehicle" | "bodycam") {
        if (kind === "vehicle") return { color: "#f97316", fill: "#fb923c", label: "V" };
        if (kind === "bodycam") return { color: "#a855f7", fill: "#c084fc", label: "B" };
        return { color: "#38bdf8", fill: "#0ea5e9", label: "O" };
    }

    function createMarker(
        kind: "vehicle" | "bodycam",
        coords: { x: number; y: number },
        label: string,
        heading?: number
    ) {
        const config = getTrackConfig(kind);
        const latLng = toMapLatLng(coords);
        const rotation = heading != null ? 360 - heading : 0;
        const hasHeading = heading != null;

        if (iconStyle === "badge") {
            return L.marker(latLng as any, {
                icon: L.divIcon({
                    className: "",
                    html: `
                        <div class="tracking-badge-wrap" style="transform: rotate(${rotation}deg)">
                            <div class="tracking-icon tracking-${kind}">
                                <span style="transform: rotate(-${rotation}deg)">${config.label}</span>
                            </div>
                            ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}"></div>` : ""}
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
                        <div class="tracking-dot" style="background:${config.fill}; border: 2px solid ${config.color}"></div>
                        ${hasHeading ? `<div class="tracking-arrow tracking-arrow-${kind}"></div>` : ""}
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

    async function refreshTracking() {
        if (!map || !tabVisible) return;
        if (isEnvBrowser()) return;

        try {
            const response = await fetchNui(
                NUI_EVENTS.MAP.GET_TRACKING,
                {},
                { data: { vehicles: [], bodycams: [] } }
            );
            const data = (response as any).data ?? response;

            vehicleLayer.clearLayers();
            bodycamLayer.clearLayers();

            if (showVehicles) {
                for (const vehicle of (data as any).vehicles || []) {
                    const coords = normalizeCoords((vehicle as any).coords);
                    if (!coords) continue;
                    const label = `${(vehicle as any).plate || ""}`.trim();
                    createMarker("vehicle", coords, label, (vehicle as any).heading).addTo(vehicleLayer);
                }
            }

            if (showBodycams) {
                for (const bodycam of (data as any).bodycams || []) {
                    const coords = normalizeCoords((bodycam as any).coords);
                    if (!coords) continue;
                    const label = `${[(bodycam as any).rank, (bodycam as any).callsign].filter(Boolean).join(" | ")}${(bodycam as any).name ? " | " + (bodycam as any).name : ""}`;
                    createMarker("bodycam", coords, label, (bodycam as any).heading).addTo(bodycamLayer);
                }
            }
        } catch {
            globalNotifications.error("Failed to refresh tracking");
        }
    }

    function handleVisibilityChange() {
        tabVisible = !document.hidden;
    }

    function syncLayerVisibility() {
        if (!map) return;

        if (showVehicles) {
            if (!map.hasLayer(vehicleLayer)) vehicleLayer.addTo(map);
        } else if (map.hasLayer(vehicleLayer)) {
            map.removeLayer(vehicleLayer);
        }

        if (showBodycams) {
            if (!map.hasLayer(bodycamLayer)) bodycamLayer.addTo(map);
        } else if (map.hasLayer(bodycamLayer)) {
            map.removeLayer(bodycamLayer);
        }
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
        initializeMap();
    });

    onDestroy(() => {
        document.removeEventListener("visibilitychange", handleVisibilityChange);

        if (map) {
            map.remove();
            map = null;
            mapInitialized = false;
        }
        if (refreshTimer) {
            clearInterval(refreshTimer);
            refreshTimer = null;
        }
    });

    $effect(() => { syncLayerVisibility(); });
    $effect(() => { iconStyle; refreshTracking(); });
</script>

<div class="map-page">
    <div class="map-wrapper">
        <div class="map-controls">
            <span class="controls-header">Tracking</span>

            <div class="controls-group">
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showVehicles} />
                    <span class="toggle-label">Vehicles</span>
                </label>
                <label class="control-toggle">
                    <input type="checkbox" bind:checked={showBodycams} />
                    <span class="toggle-label">Bodycams</span>
                </label>
            </div>

            <div class="controls-divider"></div>

            <div class="controls-group">
                <span class="controls-label">Style</span>
                <div class="segment">
                    <button
                        class:active={iconStyle === "dot"}
                        onclick={() => (iconStyle = "dot")}
                        type="button"
                    >
                        Dots
                    </button>
                    <button
                        class:active={iconStyle === "badge"}
                        onclick={() => (iconStyle = "badge")}
                        type="button"
                    >
                        Badges
                    </button>
                </div>
            </div>

            <div class="controls-divider"></div>

            <div class="legend">
                <span class="legend-item vehicle">Vehicle</span>
                <span class="legend-item bodycam">Bodycam</span>
            </div>
        </div>
        <div bind:this={mapContainer} class="map-container"></div>
    </div>
</div>

<style>
    :global(.leaflet-popup-content-wrapper) {
        background: var(--dark-bg);
        color: rgba(255, 255, 255, 0.8);
        border-radius: 8px;
        border: 1px solid rgba(255, 255, 255, 0.06);
        box-shadow: none;
    }
    :global(.leaflet-popup-tip) {
        background: var(--dark-bg);
    }
    :global(.leaflet-tooltip) {
        background: var(--dark-bg);
        color: rgba(255, 255, 255, 0.8);
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 6px;
        font-size: 11px;
        padding: 4px 8px;
        box-shadow: none;
    }
    :global(.leaflet-tooltip-top::before) {
        border-top-color: #111111;
    }
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
        width: 30px !important;
        height: 30px !important;
        line-height: 30px !important;
        font-size: 14px !important;
    }
    :global(.leaflet-control-zoom a:hover) {
        background: rgba(255, 255, 255, 0.08) !important;
        color: rgba(255, 255, 255, 0.9) !important;
    }

    .map-page {
        height: 100%;
        padding: 10px 20px 20px;
        background: var(--card-dark-bg);
    }
    .map-wrapper {
        position: relative;
        width: 100%;
        height: 100%;
        border-radius: 10px;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.06);
    }
    .map-container {
        width: 100%;
        height: 100%;
    }
    .map-controls {
        position: absolute;
        z-index: 1001;
        top: 12px;
        left: 12px;
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
    }
    .controls-group {
        display: flex;
        flex-direction: column;
        gap: 6px;
    }
    .controls-label {
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: rgba(255, 255, 255, 0.5);
        margin-bottom: 2px;
    }
    .controls-divider {
        height: 1px;
        background: rgba(255, 255, 255, 0.04);
        margin: 10px 0;
    }
    .control-toggle {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        font-size: 12px;
        color: rgba(255, 255, 255, 0.7);
    }
    .control-toggle input[type="checkbox"] {
        width: 14px;
        height: 14px;
        accent-color: rgba(var(--accent-rgb), 0.7);
        cursor: pointer;
    }
    .segment {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 4px;
    }
    .segment button {
        border-radius: 6px;
        border: 1px solid rgba(255, 255, 255, 0.06);
        background: rgba(255, 255, 255, 0.04);
        color: rgba(255, 255, 255, 0.5);
        font-size: 11px;
        font-weight: 500;
        padding: 5px 8px;
        cursor: pointer;
        transition: all 0.1s ease;
    }
    .segment button:hover {
        background: rgba(255, 255, 255, 0.06);
        color: rgba(255, 255, 255, 0.7);
    }
    .segment button.active {
        background: rgba(255, 255, 255, 0.08);
        border-color: rgba(255, 255, 255, 0.12);
        color: rgba(255, 255, 255, 0.9);
    }
    .legend {
        display: flex;
        flex-direction: column;
        gap: 5px;
        font-size: 11px;
        color: rgba(255, 255, 255, 0.45);
    }
    .legend-item {
        display: flex;
        align-items: center;
        gap: 8px;
    }
    .legend-item::before {
        content: "";
        width: 6px;
        height: 6px;
        border-radius: 50%;
        display: inline-block;
        flex-shrink: 0;
    }
    .legend-item.vehicle::before { background: #f97316; }
    .legend-item.bodycam::before { background: #a855f7; }

    :global(.tracking-icon) {
        width: 22px;
        height: 22px;
        border-radius: 5px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 11px;
        font-weight: 700;
        color: #0c0c0c;
    }
    :global(.tracking-vehicle) { background: #f97316; }
    :global(.tracking-bodycam) { background: #a855f7; }

    :global(.tracking-dot-wrap),
    :global(.tracking-badge-wrap) {
        position: relative;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
    }
    :global(.tracking-dot) {
        width: 12px;
        height: 12px;
        border-radius: 50%;
    }
    :global(.tracking-arrow) {
        position: absolute;
        top: -7px;
        left: 50%;
        transform: translateX(-50%);
        width: 0;
        height: 0;
        border-left: 4px solid transparent;
        border-right: 4px solid transparent;
    }
    :global(.tracking-arrow-vehicle) { border-bottom: 8px solid #f97316; }
    :global(.tracking-arrow-bodycam) { border-bottom: 8px solid #a855f7; }
</style>