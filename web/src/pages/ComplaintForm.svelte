<script lang="ts">
    import { GetParentResourceName } from "../utils/fivem";

    let { show = false, onClose = () => {} }: { show: boolean; onClose: () => void } = $props();

    // Form fields
    let officerName = $state("");
    let officerBadge = $state("");
    let category = $state("other");
    let description = $state("");
    let incidentDate = $state("");
    let incidentLocation = $state("");
    let witnesses = $state("");
    let evidenceUrl = $state("");
    let evidenceList: { url: string; label: string }[] = $state([]);

    // Submission state
    let submitting = $state(false);
    let submitted = $state(false);
    let complaintNumber = $state("");
    let errorMessage = $state("");

    const categories = [
        { value: "misconduct", label: "Misconduct" },
        { value: "excessive_force", label: "Excessive Force" },
        { value: "corruption", label: "Corruption" },
        { value: "negligence", label: "Negligence" },
        { value: "discrimination", label: "Discrimination" },
        { value: "other", label: "Other" },
    ];

    let isFormValid = $derived(
        officerName.trim() !== "" && category !== "" && description.trim() !== ""
    );

    function addEvidence() {
        if (evidenceUrl.trim() === "") return;
        const url = evidenceUrl.trim();
        const label = url.length > 50 ? url.substring(0, 50) + "..." : url;
        evidenceList = [...evidenceList, { url, label }];
        evidenceUrl = "";
    }

    function removeEvidence(index: number) {
        evidenceList = evidenceList.filter((_, i) => i !== index);
    }

    function resetForm() {
        officerName = "";
        officerBadge = "";
        category = "other";
        description = "";
        incidentDate = "";
        incidentLocation = "";
        witnesses = "";
        evidenceUrl = "";
        evidenceList = [];
        submitting = false;
        submitted = false;
        complaintNumber = "";
        errorMessage = "";
    }

    function handleCancel() {
        resetForm();
        // Fire NUI callback to let the game know the form was closed
        fetch(`https://${GetParentResourceName()}/closeComplaint`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify({}),
        }).catch(() => {});
        onClose();
    }

    async function handleSubmit() {
        if (!isFormValid || submitting) return;

        submitting = true;
        errorMessage = "";

        const data = {
            officerName: officerName.trim(),
            officerBadge: officerBadge.trim(),
            category,
            description: description.trim(),
            incidentDate,
            incidentLocation: incidentLocation.trim(),
            witnesses: witnesses.trim(),
            evidence: evidenceList,
        };

        try {
            const resourceName = GetParentResourceName();
            const resp = await fetch(`https://${resourceName}/submitComplaint`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(data),
            });

            if (!resp.ok) {
                throw new Error(`Request failed with status ${resp.status}`);
            }

            const result = await resp.json();
            complaintNumber = result?.complaintNumber || "IA-2026-UNKNOWN";
            submitted = true;

            // Auto-close after 3 seconds
            setTimeout(() => {
                resetForm();
                onClose();
            }, 3000);
        } catch (err) {
            errorMessage = "Failed to submit complaint. Please try again.";
            console.error("[ComplaintForm] Submit error:", err);
        } finally {
            submitting = false;
        }
    }
</script>

{#if show}
<div class="complaint-overlay">
    <div class="complaint-card">
        {#if submitted}
            <!-- Success State -->
            <button class="close-btn" onclick={() => handleCancel()} aria-label="Close">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
            <div class="success-container">
                <div class="success-icon">&#x2714;</div>
                <h2 class="success-title">Complaint Filed Successfully</h2>
                <p class="success-number">Your complaint number: <strong>{complaintNumber}</strong></p>
                <p class="success-note">You will be contacted if further information is needed.</p>
            </div>
        {:else}
            <!-- Form State -->
            <div class="card-header">
                <span class="header-icon">&#x1F6E1;</span>
                <h2 class="header-title">Internal Affairs Complaint</h2>
            </div>

            {#if errorMessage}
                <div class="error-banner">{errorMessage}</div>
            {/if}

            <form class="complaint-form" onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
                <!-- Officer Name -->
                <div class="form-group">
                    <label class="form-label" for="officerName">Officer Name <span class="required">*</span></label>
                    <input
                        id="officerName"
                        type="text"
                        class="form-input"
                        placeholder="Officer name or badge number"
                        bind:value={officerName}
                        required
                    />
                </div>

                <!-- Officer Badge -->
                <div class="form-group">
                    <label class="form-label" for="officerBadge">Officer Badge</label>
                    <input
                        id="officerBadge"
                        type="text"
                        class="form-input"
                        placeholder="Badge #"
                        bind:value={officerBadge}
                    />
                </div>

                <!-- Category -->
                <div class="form-group">
                    <label class="form-label" for="category">Category <span class="required">*</span></label>
                    <select id="category" class="form-input form-select" bind:value={category} required>
                        {#each categories as cat}
                            <option value={cat.value}>{cat.label}</option>
                        {/each}
                    </select>
                </div>

                <!-- Incident Date -->
                <div class="form-group">
                    <label class="form-label" for="incidentDate">Incident Date</label>
                    <input
                        id="incidentDate"
                        type="date"
                        class="form-input"
                        bind:value={incidentDate}
                    />
                </div>

                <!-- Location -->
                <div class="form-group">
                    <label class="form-label" for="incidentLocation">Location</label>
                    <input
                        id="incidentLocation"
                        type="text"
                        class="form-input"
                        placeholder="Where did this occur?"
                        bind:value={incidentLocation}
                    />
                </div>

                <!-- Description -->
                <div class="form-group">
                    <label class="form-label" for="description">Description <span class="required">*</span></label>
                    <textarea
                        id="description"
                        class="form-input form-textarea"
                        rows="5"
                        placeholder="Describe the incident in detail..."
                        bind:value={description}
                        required
                    ></textarea>
                </div>

                <!-- Witnesses -->
                <div class="form-group">
                    <label class="form-label" for="witnesses">Witnesses</label>
                    <textarea
                        id="witnesses"
                        class="form-input form-textarea"
                        rows="2"
                        placeholder="Names/descriptions of witnesses"
                        bind:value={witnesses}
                    ></textarea>
                </div>

                <!-- Evidence -->
                <div class="form-group">
                    <label class="form-label">Evidence</label>
                    <div class="evidence-input-row">
                        <input
                            type="url"
                            class="form-input evidence-url-input"
                            placeholder="Paste evidence URL..."
                            bind:value={evidenceUrl}
                            onkeydown={(e) => { if (e.key === "Enter") { e.preventDefault(); addEvidence(); } }}
                        />
                        <button type="button" class="btn-add-evidence" onclick={addEvidence}>Add</button>
                    </div>
                    {#if evidenceList.length > 0}
                        <ul class="evidence-list">
                            {#each evidenceList as item, i}
                                <li class="evidence-item">
                                    <span class="evidence-label" title={item.url}>{item.label}</span>
                                    <button type="button" class="btn-remove-evidence" onclick={() => removeEvidence(i)}>&times;</button>
                                </li>
                            {/each}
                        </ul>
                    {/if}
                </div>

                <!-- Buttons -->
                <div class="form-actions">
                    <button
                        type="submit"
                        class="btn-submit"
                        disabled={!isFormValid || submitting}
                    >
                        {submitting ? "Submitting..." : "Submit Complaint"}
                    </button>
                    <button type="button" class="btn-cancel" onclick={handleCancel}>
                        Cancel
                    </button>
                </div>
            </form>
        {/if}
    </div>
</div>
{/if}

<style>
    .complaint-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.85);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 3000;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }

    .complaint-card {
        background: rgb(18, 18, 22);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        max-width: 550px;
        width: 100%;
        max-height: 85vh;
        overflow-y: auto;
        padding: 28px 32px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
        position: relative;
    }

    .close-btn {
        position: absolute;
        top: 12px;
        right: 12px;
        background: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.6);
        cursor: pointer;
        padding: 6px;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.15s;
    }
    .close-btn:hover {
        background: rgba(255, 255, 255, 0.12);
        color: rgba(255, 255, 255, 0.9);
    }

    .card-header {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-bottom: 24px;
        padding-bottom: 16px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    }

    .header-icon {
        font-size: 22px;
        line-height: 1;
    }

    .header-title {
        font-size: 18px;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.87);
        margin: 0;
    }

    .error-banner {
        background: rgba(239, 68, 68, 0.15);
        border: 1px solid rgba(239, 68, 68, 0.3);
        color: rgb(252, 165, 165);
        padding: 10px 14px;
        border-radius: 6px;
        font-size: 13px;
        margin-bottom: 16px;
    }

    .complaint-form {
        display: flex;
        flex-direction: column;
        gap: 16px;
    }

    .form-group {
        display: flex;
        flex-direction: column;
        gap: 6px;
    }

    .form-label {
        font-size: 13px;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.7);
    }

    .required {
        color: rgb(239, 68, 68);
    }

    .form-input {
        background: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 6px;
        padding: 10px 12px;
        color: rgba(255, 255, 255, 0.87);
        font-size: 14px;
        font-family: inherit;
        outline: none;
        transition: border-color 0.15s ease;
    }

    .form-input::placeholder {
        color: rgba(255, 255, 255, 0.35);
    }

    .form-input:focus {
        border-color: rgba(100, 140, 255, 0.5);
    }

    .form-select {
        appearance: none;
        cursor: pointer;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23ffffff80' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right 12px center;
        padding-right: 32px;
    }

    .form-select option {
        background: rgb(18, 18, 22);
        color: rgba(255, 255, 255, 0.87);
    }

    .form-textarea {
        resize: vertical;
        min-height: 40px;
    }

    .evidence-input-row {
        display: flex;
        gap: 8px;
    }

    .evidence-url-input {
        flex: 1;
    }

    .btn-add-evidence {
        background: rgba(255, 255, 255, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.87);
        padding: 10px 16px;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: background 0.15s ease;
        white-space: nowrap;
    }

    .btn-add-evidence:hover {
        background: rgba(255, 255, 255, 0.15);
    }

    .evidence-list {
        list-style: none;
        margin: 8px 0 0;
        padding: 0;
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .evidence-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 4px;
        padding: 6px 10px;
    }

    .evidence-label {
        font-size: 12px;
        color: rgba(255, 255, 255, 0.6);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        flex: 1;
        margin-right: 8px;
    }

    .btn-remove-evidence {
        background: none;
        border: none;
        color: rgba(239, 68, 68, 0.7);
        font-size: 16px;
        cursor: pointer;
        padding: 0 4px;
        line-height: 1;
        transition: color 0.15s ease;
    }

    .btn-remove-evidence:hover {
        color: rgb(239, 68, 68);
    }

    .form-actions {
        display: flex;
        gap: 10px;
        margin-top: 8px;
        padding-top: 16px;
        border-top: 1px solid rgba(255, 255, 255, 0.08);
    }

    .btn-submit {
        flex: 1;
        background: rgb(59, 130, 246);
        border: none;
        border-radius: 6px;
        color: #fff;
        padding: 12px 20px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        transition: background 0.15s ease, opacity 0.15s ease;
    }

    .btn-submit:hover:not(:disabled) {
        background: rgb(37, 99, 235);
    }

    .btn-submit:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .btn-cancel {
        background: rgba(255, 255, 255, 0.1);
        border: none;
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.7);
        padding: 12px 20px;
        font-size: 14px;
        font-weight: 500;
        cursor: pointer;
        transition: background 0.15s ease;
    }

    .btn-cancel:hover {
        background: rgba(255, 255, 255, 0.15);
    }

    /* Success State */
    .success-container {
        display: flex;
        flex-direction: column;
        align-items: center;
        text-align: center;
        padding: 40px 20px;
        gap: 12px;
    }

    .success-icon {
        font-size: 48px;
        color: rgb(34, 197, 94);
        line-height: 1;
        margin-bottom: 8px;
    }

    .success-title {
        font-size: 20px;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.87);
        margin: 0;
    }

    .success-number {
        font-size: 15px;
        color: rgba(255, 255, 255, 0.6);
        margin: 0;
    }

    .success-number strong {
        color: rgba(255, 255, 255, 0.87);
    }

    .success-note {
        font-size: 13px;
        color: rgba(255, 255, 255, 0.5);
        margin: 4px 0 0;
    }

    /* Scrollbar styling */
    .complaint-card::-webkit-scrollbar {
        width: 6px;
    }

    .complaint-card::-webkit-scrollbar-track {
        background: transparent;
    }

    .complaint-card::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.12);
        border-radius: 3px;
    }

    .complaint-card::-webkit-scrollbar-thumb:hover {
        background: rgba(255, 255, 255, 0.2);
    }
</style>
