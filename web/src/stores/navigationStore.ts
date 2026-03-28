import { writable } from "svelte/store";

// Pending BOLO ID to open on the BOLOs page
const pendingBoloId = writable<number | null>(null);

// Pending warrant report ID to highlight on the Warrants page
const pendingWarrantReportId = writable<number | string | null>(null);

export function openBoloDetail(boloId: number): void {
	pendingBoloId.set(boloId);
}

export function clearPendingBolo(): void {
	pendingBoloId.set(null);
}

export function openWarrantDetail(reportId: number | string): void {
	pendingWarrantReportId.set(reportId);
}

export function clearPendingWarrant(): void {
	pendingWarrantReportId.set(null);
}

export { pendingBoloId, pendingWarrantReportId };
