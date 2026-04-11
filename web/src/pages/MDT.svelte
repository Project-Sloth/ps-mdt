<script lang="ts">
    import {onMount} from "svelte";
    import {useNuiEvent} from "@/utils/useNuiEvent";
    import {setupDevelopmentMode} from "@/utils/developmentMode";
    import {createAuthService} from "../services/authService.svelte";
    import {createTabService} from "../services/tabService.svelte";
    import {settingsService} from "../services/settingsService.svelte";
    import {createInstanceStateService} from "../services/instanceStateService.svelte";
    import {NUI_EVENTS} from "@/constants/nuiEvents";
    import TopBar from "../components/TopBar.svelte";
    import NavigationPills from "../components/NavigationPills.svelte";
    import InstanceTabs from "../components/InstanceTabs.svelte";
    import ContentArea from "../components/ContentArea.svelte";
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
    });

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
    <div class="mdt-window" style={opacityStyle}>
        <div class="mdt-interface">
            <TopBar
                    {authService}
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
        width: 95vw;
        height: 90vh;
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