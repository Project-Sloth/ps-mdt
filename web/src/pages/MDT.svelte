<script lang="ts">
    import {onMount} from "svelte";
    import {useNuiEvent} from "@/utils/useNuiEvent";
    import {setupDevelopmentMode} from "@/utils/developmentMode";
    import {createAuthService} from "../services/authService.svelte";
    import {createTabService} from "../services/tabService.svelte";
    import {settingsService} from "../services/settingsService.svelte";
    import {createInstanceStateService} from "../services/instanceStateService.svelte";
    import {NUI_EVENTS} from "@/constants/nuiEvents";
    import {getTabsForJob, type MDTTab} from "../constants";
    import {fetchNui} from "@/utils/fetchNui";
    import {readPrefs, applyGlobalPrefs, onPrefsReady, prefsReady} from "@/utils/preferences";
    import {globalNotifications} from "../services/notificationService.svelte";
    import TopBar from "../components/TopBar.svelte";
    import NavigationPills from "../components/NavigationPills.svelte";
    import InstanceTabs from "../components/InstanceTabs.svelte";
    import ContentArea from "../components/ContentArea.svelte";
    import RadioPTT from "../components/RadioPTT.svelte";
    import type {AuthUpdateData} from "@/interfaces/IUser";

    const authService = createAuthService();
    const tabService = createTabService();
    const instanceStateService = createInstanceStateService(tabService);

    let opacityStyle = $state("opacity: 1");

    function handleOpacityStyleChange(style: string): void {
        opacityStyle = style;
    }

    onMount(() => {
        authService.checkAuth();
        settingsService.loadColorConfig();
        setupInstanceCoordination();
        loadMissedHearings();
        applyGlobalPrefs();
        return onPrefsReady(applyGlobalPrefs);
    });

    // Reduced motion and window size must apply from the first frame, whether
    // or not the Settings page ever mounts. Settings re-applies them live on
    // save; onPrefsReady covers the case where the KVP pull lands after this.

    // Default tab (Settings > General): applied on every MDT open. "last"
    // (or unset) keeps the classic behavior of resuming wherever you were.
    // Anything the player can't open — wrong job, tab_hidden_* permission —
    // silently falls back to that same last-tab behavior.
    //
    // Why not listen for setVisible: VisibilityProvider unmounts this whole
    // component while the MDT is closed and remounts it on open — a setVisible
    // listener registered here would always arrive AFTER the event that
    // caused the mount. The remount itself is therefore the "MDT opened"
    // signal; we just wait for auth to finish so jobType and the tab_hidden_*
    // permissions are real values rather than their pre-auth defaults.
    let defaultTabApplied = false;
    $effect(() => {
        if (!authService.isAuthorized || defaultTabApplied) return;
        defaultTabApplied = true;
        // Wait for the KVP pull: auth can finish first, and reading the
        // preference too early lands on the fallback instead of the saved tab.
        prefsReady.then(applyDefaultTab);
    });

    function applyDefaultTab() {
        if (authService.jobType === "civilian") return; // civilians have no tab bar
        const pref = readPrefs().defaultTab;
        if (typeof pref !== "string" || pref === "last") return;
        const allowed = getTabsForJob(authService.jobType).some(t => t.name === pref);
        const hidden = authService.hasRawPermission(`tab_hidden_${pref.toLowerCase()}`);
        if (!allowed || hidden) return;
        const active = tabService.getActiveInstance();
        if (active) tabService.setInstanceTab(active.id, pref as MDTTab);
        else tabService.setActiveTab(pref as MDTTab);
    }

    // Global court reminder toast — shows on any tab, not just the calendar
    useNuiEvent<{ title?: string; scheduled_at?: string | number; location?: string }>(
        "courtReminder",
        (data) => {
            const raw = data?.scheduled_at;

            const num = Number(raw);

            const date = raw
                ? new Date(num < 1e12 ? num * 1000 : num)
                : null;

            const when =
                date && !isNaN(date.getTime())
                    ? ` (${date.toLocaleString("en-US", {
                        hour: "2-digit",
                        minute: "2-digit",
                    })})`
                    : "";

            const where = data?.location
                ? ` — ${data.location}`
                : "";

            globalNotifications.info(
                `Appointment: ${data?.title ?? "Hearing"}${when}${where}`
            );
        }
    );

    // On first MDT open, surface hearings whose reminder fired while offline
    async function loadMissedHearings(): Promise<void> {
        try {
            const missed = await fetchNui<Array<{ title: string; scheduled_at?: string }>>(
                NUI_EVENTS.COURT.GET_MISSED,
                {},
                [],
            );
            if (Array.isArray(missed) && missed.length > 0) {
                const titles = missed.slice(0, 3).map((m) => m.title).join(", ");
                const extra = missed.length > 3 ? ` +${missed.length - 3}` : "";
                globalNotifications.info(`Missed Appointment: ${titles}${extra}`);
            }
        } catch {
            /* ignore */
        }
    }

    function setupInstanceCoordination(): void {
        $effect(() => {
            const activeInstance = tabService.getActiveInstance();
            if (activeInstance) {
                instanceStateService.switchToInstance(
                    activeInstance.id,
                    activeInstance.currentTab,
                );
            }
        });
    }

    useNuiEvent<AuthUpdateData>(
        NUI_EVENTS.AUTH.UPDATE_AUTH,
        (data: AuthUpdateData) => {
            authService.updateAuthState(data);
        },
    );

    setupDevelopmentMode();

    if (typeof document !== 'undefined') {
        let lastFocusedInput: HTMLElement | null = null;
        let refocusPending = false;

        document.addEventListener('focusin', (e) => {
            const el = e.target as HTMLElement;
            if (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA' || el.isContentEditable) {
                lastFocusedInput = el;
                refocusPending = false;
            }
        });

        document.addEventListener('focusout', (e) => {
            const fe = e as FocusEvent;
            const el = e.target as HTMLElement;
            // Skip SELECT elements - their dropdown interaction triggers focusout with null relatedTarget
            if (el.tagName === 'SELECT') return;
            if (fe.relatedTarget === null && lastFocusedInput === el && !refocusPending) {
                refocusPending = true;
                requestAnimationFrame(() => {
                    if (lastFocusedInput && (!document.activeElement || document.activeElement === document.body)) {
                        lastFocusedInput.focus();
                    }
                    refocusPending = false;
                });
            }
        });

    }
</script>

<main class="mdt-container" data-job-type={authService.jobType}>
    <RadioPTT />
    <div class="mdt-window" style={opacityStyle}>
        <div class="mdt-interface">
            <TopBar
                    {authService}
                    {tabService}
                    onOpacityStyleChange={handleOpacityStyleChange}
            />

            <div class="mdt-content">
                {#if !authService.isCivilian}
                    <div class="mdt-navigation">
                        {#if authService.isAuthorized}
                            <NavigationPills {tabService} jobType={authService.jobType} {authService}/>
                        {/if}
                    </div>
                {/if}
                <div class="mdt-main-content">
                    {#if !authService.isCivilian}
                        <InstanceTabs {tabService}/>
                    {/if}
                    <ContentArea
                            {authService}
                            {tabService}
                            {instanceStateService}
                    />
                </div>
            </div>
        </div>
    </div>
</main>

<style>
    .mdt-container {
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
    }

    .mdt-window {
        /* Driven by the Window Size preference. Custom properties rather than a
           transform: a transform would scale the frame but leave click targets
           and border edges where they were. */
        width: var(--mdt-window-w, 95vw);
        height: var(--mdt-window-h, 90vh);
        background: var(--dark-bg);
        border-radius: 12px;
        overflow: hidden;
        display: flex;
        flex-direction: column;
        box-shadow: 0 20px 40px rgba(23, 23, 23, 0.3);
        border: 1px solid transparent;
        position: relative;
        transition: opacity 0.2s ease-in-out;
        will-change: opacity;
    }

    :global([data-job-type="ems"]) .mdt-window {
        border-color: rgba(220, 50, 50, 0.15);
        box-shadow: 0 20px 40px rgba(20, 8, 8, 0.4), 0 0 60px rgba(220, 50, 50, 0.04);
    }

    :global([data-job-type="doj"]) .mdt-window {
        border-color: rgba(180, 150, 60, 0.15);
        box-shadow: 0 20px 40px rgba(8, 12, 20, 0.4), 0 0 60px rgba(30, 58, 138, 0.04);
    }

    .mdt-interface {
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: column;
    }

    .mdt-content {
        display: flex;
        height: calc(100% - 55px); /* Adjust for TopBar height */
    }

    .mdt-navigation {
        max-width: 250px;
        background: var(--card-dark-bg);
        display: flex;
    }

    .mdt-main-content {
        display: flex;
        flex-direction: column;
        flex: 1;
        min-width: 0;
        width: 100%;
    }
</style>