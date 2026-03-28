import type { ComponentId } from "../constants";
import type {
	ReportPageData,
	CitizensPageData,
	ChargesPageData,
	VehiclesPageData,
	WeaponsPageData,
	RosterPageData,
	DashboardPageData,
	CasesPageData,
} from "../schemas/persistenceSchema";

export interface InstancePersistenceData {
	"report-page"?: ReportPageData;
	"citizens-page"?: CitizensPageData;
	"charges-page"?: ChargesPageData;
	"vehicles-page"?: VehiclesPageData;
	"weapons-page"?: WeaponsPageData;
	"roster-page"?: RosterPageData;
	"dashboard-page"?: DashboardPageData;
	"cases-page"?: CasesPageData;
}

export interface TabInstance {
	id: ComponentId;
	instanceName: string;
	currentTab: MDTTab; // Each instance maintains its own current tab
	isActive: boolean;
	data?: InstancePersistenceData; // Typed persistence data for this instance
}
