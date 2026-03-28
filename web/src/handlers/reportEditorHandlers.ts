import type { Report, SearchResult, ReportCharge, Officer, Suspect, Victim, Evidence } from "../interfaces/IReportEditor";
import type { ReportService } from "../services/reportService.svelte";
import type { TagService } from "../services/tagService.svelte";
import type { ReportEditorUIService } from "../services/reportEditorUIService.svelte";

export function createReportEditorHandlers(
	getReport: () => Report,
	setReport: (report: Report) => void,
	reportService: ReportService,
	tagService: TagService,
	reportEditorUI: ReportEditorUIService,
) {
	return {
		// Add handlers
		handleAddOfficer: () => reportEditorUI.openOfficerSearch(),
		handleAddSuspect: () => reportEditorUI.openSuspectSearch(),
		handleAddVictim: () => reportEditorUI.openVictimSearch(),
		handleAddEvidence: () => {
			setReport(reportService.addEvidence(getReport()));
		},
		handleAddTag: (tag: string) => {
			const currentReport = getReport();
			currentReport.tags = tagService.addTag(currentReport.tags, tag);
		},

		// Remove handlers
		handleRemoveOfficer: (id: string) => {
			setReport(reportService.removeOfficer(getReport(), id));
		},
		handleRemoveSuspect: (id: string) => {
			setReport(reportService.removeSuspect(getReport(), id));
		},
		handleRemoveVictim: (id: string) => {
			setReport(reportService.removeVictim(getReport(), id));
		},
		handleRemoveEvidence: (id: string) => {
			setReport(reportService.removeEvidence(getReport(), id));
		},
		handleAddCharge: (charge: ReportCharge) => {
			const r = getReport();
			r.charges = [...r.charges, charge];
			setReport({ ...r });
		},
		handleRemoveCharge: (id: string) => {
			const r = getReport();
			r.charges = r.charges.filter((c) => c.id !== id);
			setReport({ ...r });
		},
		handleUpdateCharge: (charge: ReportCharge) => {
			const r = getReport();
			r.charges = r.charges.map((c) => (c.id === charge.id ? charge : c));
			setReport({ ...r });
		},
		handleRemoveTag: (index: number) => {
			const currentReport = getReport();
			currentReport.tags = tagService.removeTag(
				currentReport.tags,
				index,
			);
		},

		// Update handlers
		handleUpdateOfficer: (officer: Officer) => {
			reportService.updateItemInArray(
				getReport().involved.officers,
				officer,
			);
		},
		handleUpdateSuspect: (suspect: Suspect) => {
			reportService.updateItemInArray(
				getReport().involved.suspects,
				suspect,
			);
		},
		handleUpdateVictim: (victim: Victim) => {
			reportService.updateItemInArray(
				getReport().involved.victims,
				victim,
			);
		},
		handleUpdateEvidence: (evidence: Evidence) => {
			reportService.updateItemInArray(getReport().evidence, evidence);
		},
		handleTitleChange: (title: string) => {
			getReport().title = title;
		},
		handleTypeChange: (type: string) => {
			getReport().type = type;
		},
		handleContentUpdate: (content: string) => {
			getReport().content = content;
		},

		// Selection handlers
		selectOfficer: (item: SearchResult) => {
			setReport(reportService.addOfficer(getReport(), item));
			reportEditorUI.closeOfficerSearch();
		},
		selectSuspect: (item: SearchResult) => {
			setReport(reportService.addSuspect(getReport(), item));
			reportEditorUI.closeSuspectSearch();
		},
		selectVictim: (item: SearchResult) => {
			setReport(reportService.addVictim(getReport(), item));
			reportEditorUI.closeVictimSearch();
		},
	};
}

export type ReportEditorHandlers = ReturnType<
	typeof createReportEditorHandlers
>;
