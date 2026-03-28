<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { createTabService } from "../services/tabService.svelte";
	import type { JobType } from "../interfaces/IUser";

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		jobType?: JobType;
	}

	let { tabService, jobType = 'leo' }: Props = $props();

	type View = "stats" | "leaderboard";

	let view = $state<View>("stats");

	interface OfficerStats {
		name: string;
		callsign: string;
		rank: string;
		reports: number;
		arrests: number;
		cases: number;
		evidence: number;
		bolos: number;
		warrants: number;
		totalFined: number;
		totalMonths: number;
		citations: number;
	}

	interface Award {
		id: number;
		name: string;
		description: string;
		icon: string;
		category: string;
		goalType: string;
		goalAmount: number;
		progress: number;
		earned: boolean;
		earnedDate?: string;
	}

	interface LeaderboardEntry {
		rank: number;
		name: string;
		callsign: string;
		department: string;
		reports: number;
		arrests: number;
		cases: number;
		warrants: number;
		totalFined: number;
		totalMonths: number;
		score: number;
		isCurrentUser: boolean;
	}

	let myStats: OfficerStats = $state({
		name: "", callsign: "", rank: "",
		reports: 0, arrests: 0, cases: 0, evidence: 0,
		bolos: 0, warrants: 0, totalFined: 0, totalMonths: 0, citations: 0,
	});

	let awards: Award[] = $state([]);
	let leaderboard: LeaderboardEntry[] = $state([]);
	let isLoading = $state(true);
	let leaderboardSort = $state<"score" | "reports" | "arrests" | "warrants" | "totalFined" | "totalMonths">("score");

	let sortedLeaderboard = $derived(
		[...leaderboard].sort((a, b) => (b as any)[leaderboardSort] - (a as any)[leaderboardSort])
	);

	let earnedAwards = $derived(awards.filter(a => a.earned));
	let inProgressAwards = $derived(awards.filter(a => !a.earned));

	function formatMoney(amount: number): string {
		return "$" + amount.toLocaleString();
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			loadMockData();
			isLoading = false;
			return;
		}
		try {
			const data = await fetchNui<{
				stats: OfficerStats;
				awards: Award[];
				leaderboard: LeaderboardEntry[];
			}>(NUI_EVENTS.AWARDS.GET_AWARDS_DATA, { jobType }, null);
			if (data) {
				myStats = data.stats || myStats;
				awards = data.awards || [];
				leaderboard = data.leaderboard || [];
			}
		} catch (e) {
			loadMockData();
		} finally {
			isLoading = false;
		}
	});

	function loadMockData() {
		myStats = {
			name: "John Smith", callsign: "1-A-12", rank: "Sergeant",
			reports: 147, arrests: 89, cases: 23, evidence: 56,
			bolos: 34, warrants: 18, totalFined: 285000, totalMonths: 342, citations: 67,
		};
		awards = [
			{ id: 1, name: "First Report", description: "File your first incident report", icon: "description", category: "Reports", goalType: "reports", goalAmount: 1, progress: 1, earned: true, earnedDate: "2024-01-15" },
			{ id: 2, name: "50 Reports Filed", description: "File 50 incident reports", icon: "description", category: "Reports", goalType: "reports", goalAmount: 50, progress: 50, earned: true, earnedDate: "2024-06-20" },
			{ id: 3, name: "100 Reports Filed", description: "File 100 incident reports", icon: "description", category: "Reports", goalType: "reports", goalAmount: 100, progress: 100, earned: true, earnedDate: "2024-11-10" },
			{ id: 4, name: "500 Reports Filed", description: "File 500 incident reports", icon: "description", category: "Reports", goalType: "reports", goalAmount: 500, progress: 147, earned: false },
			{ id: 5, name: "First Arrest", description: "File your first arrest report", icon: "local_police", category: "Arrests", goalType: "arrests", goalAmount: 1, progress: 1, earned: true, earnedDate: "2024-01-20" },
			{ id: 6, name: "50 Arrests", description: "File 50 arrest reports", icon: "local_police", category: "Arrests", goalType: "arrests", goalAmount: 50, progress: 50, earned: true, earnedDate: "2024-08-15" },
			{ id: 7, name: "200 Arrests", description: "File 200 arrest reports", icon: "local_police", category: "Arrests", goalType: "arrests", goalAmount: 200, progress: 89, earned: false },
			{ id: 8, name: "Case Worker", description: "Work on 25 cases", icon: "folder", category: "Cases", goalType: "cases", goalAmount: 25, progress: 23, earned: false },
			{ id: 9, name: "50 Evidence Logged", description: "Log 50 pieces of evidence", icon: "inventory_2", category: "Evidence", goalType: "evidence", goalAmount: 50, progress: 50, earned: true, earnedDate: "2024-09-05" },
			{ id: 10, name: "25 BOLOs Issued", description: "Issue 25 BOLOs", icon: "notification_important", category: "BOLOs", goalType: "bolos", goalAmount: 25, progress: 25, earned: true, earnedDate: "2024-07-01" },
			{ id: 11, name: "10 Warrants Issued", description: "Issue 10 warrants", icon: "gavel", category: "Warrants", goalType: "warrants", goalAmount: 10, progress: 10, earned: true, earnedDate: "2024-10-12" },
			{ id: 12, name: "$100K Fined", description: "Fine citizens a total of $100,000", icon: "payments", category: "Fines", goalType: "totalFined", goalAmount: 100000, progress: 100000, earned: true, earnedDate: "2024-05-22" },
			{ id: 13, name: "$500K Fined", description: "Fine citizens a total of $500,000", icon: "payments", category: "Fines", goalType: "totalFined", goalAmount: 500000, progress: 285000, earned: false },
			{ id: 14, name: "500 Months Sentenced", description: "Sentence a total of 500 months", icon: "schedule", category: "Sentencing", goalType: "totalMonths", goalAmount: 500, progress: 342, earned: false },
		];
		leaderboard = [
			{ rank: 1, name: "Mike Torres", callsign: "1-L-1", department: "LSPD", reports: 312, arrests: 198, cases: 45, warrants: 38, totalFined: 620000, totalMonths: 890, score: 2450, isCurrentUser: false },
			{ rank: 2, name: "Sarah Chen", callsign: "1-A-5", department: "LSPD", reports: 278, arrests: 156, cases: 52, warrants: 29, totalFined: 445000, totalMonths: 678, score: 2180, isCurrentUser: false },
			{ rank: 3, name: "James Rodriguez", callsign: "2-A-1", department: "BCSO", reports: 245, arrests: 134, cases: 38, warrants: 35, totalFined: 390000, totalMonths: 545, score: 1920, isCurrentUser: false },
			{ rank: 4, name: "Emily Davis", callsign: "1-B-3", department: "LSPD", reports: 201, arrests: 112, cases: 31, warrants: 22, totalFined: 356000, totalMonths: 412, score: 1650, isCurrentUser: false },
			{ rank: 5, name: "John Smith", callsign: "1-A-12", department: "LSPD", reports: 147, arrests: 89, cases: 23, warrants: 18, totalFined: 285000, totalMonths: 342, score: 1280, isCurrentUser: true },
			{ rank: 6, name: "Alex Johnson", callsign: "2-B-7", department: "BCSO", reports: 134, arrests: 78, cases: 19, warrants: 15, totalFined: 210000, totalMonths: 298, score: 1120, isCurrentUser: false },
			{ rank: 7, name: "Lisa Park", callsign: "1-C-2", department: "LSPD", reports: 118, arrests: 67, cases: 15, warrants: 12, totalFined: 178000, totalMonths: 234, score: 980, isCurrentUser: false },
			{ rank: 8, name: "David Brown", callsign: "2-A-9", department: "BCSO", reports: 95, arrests: 54, cases: 12, warrants: 9, totalFined: 145000, totalMonths: 189, score: 810, isCurrentUser: false },
			{ rank: 9, name: "Rachel Kim", callsign: "1-D-1", department: "LSPD", reports: 82, arrests: 43, cases: 8, warrants: 7, totalFined: 112000, totalMonths: 156, score: 690, isCurrentUser: false },
			{ rank: 10, name: "Chris Wilson", callsign: "2-C-4", department: "BCSO", reports: 67, arrests: 35, cases: 6, warrants: 5, totalFined: 89000, totalMonths: 120, score: 540, isCurrentUser: false },
		];
	}
</script>

<div class="awards-page">
	<div class="awards-topbar">
		<div class="tab-buttons">
			<button class="tab-btn" class:active={view === "stats"} onclick={() => (view = "stats")}>
				My Stats & Awards
			</button>
			<button class="tab-btn" class:active={view === "leaderboard"} onclick={() => (view = "leaderboard")}>
				Leaderboard
			</button>
		</div>
	</div>

	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading...</p>
		</div>
	{:else if view === "stats"}
		<div class="stats-view">
			<div class="stats-grid">
				<div class="stat-card">
					<span class="material-icons stat-icon si-blue">description</span>
					<span class="stat-value">{myStats.reports}</span>
					<span class="stat-label">Reports</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-red">local_police</span>
					<span class="stat-value">{myStats.arrests}</span>
					<span class="stat-label">Arrests</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-purple">folder</span>
					<span class="stat-value">{myStats.cases}</span>
					<span class="stat-label">Cases</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-cyan">inventory_2</span>
					<span class="stat-value">{myStats.evidence}</span>
					<span class="stat-label">Evidence</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-orange">notification_important</span>
					<span class="stat-value">{myStats.bolos}</span>
					<span class="stat-label">BOLOs</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-amber">gavel</span>
					<span class="stat-value">{myStats.warrants}</span>
					<span class="stat-label">Warrants</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-green">payments</span>
					<span class="stat-value">{formatMoney(myStats.totalFined)}</span>
					<span class="stat-label">Fined</span>
				</div>
				<div class="stat-card">
					<span class="material-icons stat-icon si-pink">schedule</span>
					<span class="stat-value">{myStats.totalMonths.toLocaleString()}</span>
					<span class="stat-label">Months Sentenced</span>
				</div>
			</div>

			{#if earnedAwards.length > 0}
				<div class="awards-section">
					<div class="section-header">
						<span class="section-title">Earned ({earnedAwards.length})</span>
					</div>
					<div class="awards-list">
						{#each earnedAwards as award (award.id)}
							<div class="award-row earned">
								<span class="material-icons award-icon">{award.icon}</span>
								<div class="award-info">
									<span class="award-name">{award.name}</span>
									<span class="award-desc">{award.description}</span>
								</div>
								<span class="award-category">{award.category}</span>
								{#if award.earnedDate}
									<span class="award-date">{new Date(award.earnedDate).toLocaleDateString()}</span>
								{/if}
								<span class="award-check material-icons">check_circle</span>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			{#if inProgressAwards.length > 0}
				<div class="awards-section">
					<div class="section-header">
						<span class="section-title">In Progress ({inProgressAwards.length})</span>
					</div>
					<div class="awards-list">
						{#each inProgressAwards as award (award.id)}
							<div class="award-row">
								<span class="material-icons award-icon">{award.icon}</span>
								<div class="award-info">
									<span class="award-name">{award.name}</span>
									<span class="award-desc">{award.description}</span>
								</div>
								<span class="award-category">{award.category}</span>
								<div class="award-progress">
									<div class="progress-bar">
										<div class="progress-fill" style="width: {Math.min(100, (award.progress / award.goalAmount) * 100)}%"></div>
									</div>
									<span class="progress-text">{award.progress}/{award.goalAmount}</span>
								</div>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			{#if awards.length === 0}
				<div class="empty-state">No awards configured. Ask an admin to set some up in Settings.</div>
			{/if}
		</div>

	{:else if view === "leaderboard"}
		<div class="leaderboard-view">
			<div class="leaderboard-controls">
				<span class="sort-label">Sort by</span>
				<select class="sort-select" bind:value={leaderboardSort}>
					<option value="score">Overall</option>
					<option value="reports">Reports</option>
					<option value="arrests">Arrests</option>
					<option value="warrants">Warrants</option>
					<option value="totalFined">Fined</option>
					<option value="totalMonths">Months</option>
				</select>
			</div>

			<div class="leaderboard-table">
				<div class="table-header">
					<span class="col-rank">#</span>
					<span class="col-name">Officer</span>
					<span class="col-dept">Dept</span>
					<span class="col-stat">Reports</span>
					<span class="col-stat">Arrests</span>
					<span class="col-stat">Cases</span>
					<span class="col-stat">Warrants</span>
					<span class="col-stat">Fined</span>
					<span class="col-stat">Months</span>
					<span class="col-score">Score</span>
				</div>
				{#each sortedLeaderboard as entry, i (entry.name)}
					<div class="table-row" class:current-user={entry.isCurrentUser}>
						<span class="col-rank">{i + 1}</span>
						<span class="col-name">
							<span class="officer-callsign">{entry.callsign}</span>
							<span class="officer-name">{entry.name}</span>
						</span>
						<span class="col-dept">{entry.department}</span>
						<span class="col-stat">{entry.reports}</span>
						<span class="col-stat">{entry.arrests}</span>
						<span class="col-stat">{entry.cases}</span>
						<span class="col-stat">{entry.warrants}</span>
						<span class="col-stat">{formatMoney(entry.totalFined)}</span>
						<span class="col-stat">{entry.totalMonths}</span>
						<span class="col-score">{entry.score.toLocaleString()}</span>
					</div>
				{:else}
					<div class="empty-state">No leaderboard data.</div>
				{/each}
			</div>
		</div>
	{/if}
</div>

<style>
	.awards-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		overflow: hidden;
	}

	.awards-topbar { flex-shrink: 0; }

	.tab-buttons {
		display: flex;
		padding: 0 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.tab-btn {
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		padding: 0 14px;
		height: 42px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		margin-bottom: -1px;
		text-transform: uppercase;
		letter-spacing: 0.4px;
	}

	.tab-btn:hover { color: rgba(255, 255, 255, 0.6); }
	.tab-btn.active { color: rgba(255, 255, 255, 0.85); border-bottom-color: rgba(255, 255, 255, 0.4); }

	/* Stats View */
	.stats-view {
		flex: 1;
		overflow-y: auto;
		padding: 14px 16px;
	}

	.stats-view::-webkit-scrollbar { width: 4px; }
	.stats-view::-webkit-scrollbar-track { background: transparent; }
	.stats-view::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 6px;
		margin-bottom: 18px;
	}

	.stat-card {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 12px;
		border-radius: 4px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.04);
	}

	.stat-icon { font-size: 18px; opacity: 0.45; }
	.si-blue { color: #3b82f6; }
	.si-red { color: #ef4444; }
	.si-purple { color: #8b5cf6; }
	.si-cyan { color: #06b6d4; }
	.si-orange { color: #f97316; }
	.si-amber { color: #f59e0b; }
	.si-green { color: #10b981; }
	.si-pink { color: #ec4899; }

	.stat-value {
		font-size: 14px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.85);
	}

	.stat-label {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.25);
		text-transform: uppercase;
		letter-spacing: 0.4px;
		font-weight: 600;
	}

	/* Awards Sections */
	.awards-section { margin-bottom: 16px; }

	.section-header {
		margin-bottom: 6px;
		padding: 0 2px;
	}

	.section-title {
		font-size: 11px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.5);
		text-transform: uppercase;
		letter-spacing: 0.4px;
	}

	.awards-list {
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 4px;
		overflow: hidden;
	}

	.award-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}

	.award-row:last-child { border-bottom: none; }
	.award-row:hover { background: rgba(255, 255, 255, 0.015); }

	.award-row.earned { background: rgba(255, 255, 255, 0.01); }

	.award-icon {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.25);
		flex-shrink: 0;
	}

	.award-row.earned .award-icon { color: rgba(255, 255, 255, 0.45); }

	.award-info {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.award-name {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.75);
	}

	.award-desc {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
	}

	.award-category {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.2);
		text-transform: uppercase;
		letter-spacing: 0.3px;
		padding: 2px 6px;
		background: rgba(255, 255, 255, 0.03);
		border-radius: 3px;
		flex-shrink: 0;
	}

	.award-date {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.2);
		flex-shrink: 0;
	}

	.award-check {
		font-size: 16px;
		color: rgba(16, 185, 129, 0.6);
		flex-shrink: 0;
	}

	.award-progress {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-shrink: 0;
		width: 140px;
	}

	.progress-bar {
		flex: 1;
		height: 3px;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: rgba(var(--accent-rgb), 0.4);
		border-radius: 2px;
	}

	.progress-text {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.2);
		white-space: nowrap;
		min-width: 45px;
		text-align: right;
	}

	/* Leaderboard */
	.leaderboard-view {
		flex: 1;
		overflow-y: auto;
		padding: 14px 16px;
	}

	.leaderboard-view::-webkit-scrollbar { width: 4px; }
	.leaderboard-view::-webkit-scrollbar-track { background: transparent; }
	.leaderboard-view::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.leaderboard-controls {
		display: flex;
		align-items: center;
		gap: 6px;
		margin-bottom: 10px;
		justify-content: flex-end;
	}

	.sort-label {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
	}

	.sort-select {
		padding: 4px 22px 4px 8px;
		font-size: 10px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.6);
		outline: none;
	}

	.leaderboard-table {
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 4px;
		overflow: hidden;
	}

	.table-header {
		display: flex;
		align-items: center;
		padding: 7px 12px;
		background: rgba(255, 255, 255, 0.02);
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
		font-size: 9px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: rgba(255, 255, 255, 0.25);
	}

	.table-row {
		display: flex;
		align-items: center;
		padding: 7px 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.025);
		font-size: 11px;
		transition: background 0.1s;
	}

	.table-row:last-child { border-bottom: none; }
	.table-row:hover { background: rgba(255, 255, 255, 0.015); }

	.table-row.current-user {
		background: rgba(var(--accent-rgb), 0.04);
		border-left: 2px solid rgba(var(--accent-rgb), 0.35);
	}

	.col-rank {
		width: 30px;
		flex-shrink: 0;
		text-align: center;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.35);
	}

	.col-name {
		flex: 1.5;
		min-width: 0;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.col-dept {
		width: 45px;
		flex-shrink: 0;
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.25);
		text-align: center;
	}

	.col-stat {
		flex: 1;
		text-align: center;
		color: rgba(255, 255, 255, 0.45);
		font-size: 10px;
	}

	.col-score {
		width: 60px;
		flex-shrink: 0;
		text-align: right;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
	}

	.officer-callsign {
		font-size: 9px;
		font-weight: 700;
		color: rgba(var(--accent-rgb), 0.5);
		background: rgba(var(--accent-rgb), 0.05);
		padding: 1px 5px;
		border-radius: 3px;
		white-space: nowrap;
	}

	.officer-name {
		color: rgba(255, 255, 255, 0.65);
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.loading-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 200px;
		color: rgba(255, 255, 255, 0.25);
		font-size: 11px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.4);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 8px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
