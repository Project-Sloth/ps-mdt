import { writable } from "svelte/store";

const pendingReportId = writable<string | null>(null);

export function openReportInEditor(reportId: string | null): void {
	pendingReportId.set(reportId ?? "new");
}

export function clearPendingReport(): void {
	pendingReportId.set(null);
}

export { pendingReportId };
