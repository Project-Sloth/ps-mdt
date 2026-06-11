<script lang="ts">
	import { onMount } from "svelte";
	import { useNuiEvent } from "../../utils/useNuiEvent";
	import { fetchNui } from "../../utils/fetchNui";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import { globalNotifications } from "../../services/notificationService.svelte";
	import { createCourtService, toMysqlDateTime } from "../../services/courtService.svelte";
	import type { createTabService } from "../../services/tabService.svelte";
	import type { AuthService } from "../../services/authService.svelte";
	import type { SearchResult } from "../../interfaces/IReportEditor";
	import type {
		CourtHearing,
		CourtAttendee,
		HearingType,
		HearingStatus,
		AttendeeRole,
		EventCategory,
	} from "../../interfaces/ICourt";
	import PersonSearchModal from "../../components/report-editor/PersonSearchModal.svelte";

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		authService: AuthService;
	}
	let { authService }: Props = $props();

	const court = createCourtService();

	// Court events are gated by court_*; training/meeting/other by training_*.
	function permPrefix(cat: EventCategory): "court" | "training" {
		return cat === "court" ? "court" : "training";
	}
	function canCreateCat(cat: EventCategory): boolean {
		return authService.hasAnyPermission(`${permPrefix(cat)}_create`);
	}
	function canEditCat(cat: EventCategory): boolean {
		return authService.hasAnyPermission(`${permPrefix(cat)}_edit`);
	}
	function canDeleteCat(cat: EventCategory): boolean {
		return authService.hasAnyPermission(`${permPrefix(cat)}_delete`);
	}

	const ALL_CATEGORIES: EventCategory[] = ["court", "training", "meeting", "other"];
	const creatableCategories = $derived(ALL_CATEGORIES.filter(canCreateCat));
	const canCreateAny = $derived(creatableCategories.length > 0);

	// When viewing an existing event the officer can't edit, the modal is read-only.
	let formReadOnly = $state(false);

	const CATEGORY_LABELS: Record<EventCategory, string> = {
		court: "Gericht",
		training: "Ausbildung",
		meeting: "Meeting",
		other: "Sonstiges",
	};
	const CATEGORY_ICONS: Record<EventCategory, string> = {
		court: "gavel",
		training: "school",
		meeting: "groups",
		other: "event",
	};

	const WEEKDAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
	const HOURS = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, "0"));
	const MINUTES = Array.from({ length: 60 }, (_, i) => String(i).padStart(2, "0"));
	function timeHour() { return (form.time || "12:00").split(":")[0] ?? "12"; }
	function timeMin() { return (form.time || "12:00").split(":")[1] ?? "00"; }
	function setHour(h: string) { form.time = `${h}:${timeMin()}`; }
	function setMin(m: string) { form.time = `${timeHour()}:${m}`; }
	const MONTHS = [
		"Januar", "Februar", "März", "April", "Mai", "Juni",
		"Juli", "August", "September", "Oktober", "November", "Dezember",
	];
	const TYPE_LABELS: Record<HearingType, string> = {
		arraignment: "Anklageverlesung",
		trial: "Verhandlung",
		sentencing: "Urteilsverkündung",
		appeal: "Berufung",
		motion: "Antrag",
		hearing: "Anhörung",
		other: "Sonstiges",
	};
	const STATUS_LABELS: Record<HearingStatus, string> = {
		scheduled: "Geplant",
		in_session: "Läuft",
		completed: "Abgeschlossen",
		adjourned: "Vertagt",
		cancelled: "Abgesagt",
	};
	const ROLE_LABELS: Record<AttendeeRole, string> = {
		prosecutor: "Anklage",
		defense: "Verteidigung",
		officer: "Officer",
		witness: "Zeuge",
		judge: "Richter",
		trainee: "Teilnehmer",
		instructor: "Ausbilder",
		attendee: "Gast",
	};

	// Which categories are currently shown (filter chips)
	let activeCategories = $state<EventCategory[]>([...ALL_CATEGORIES]);
	function toggleCategory(cat: EventCategory) {
		activeCategories = activeCategories.includes(cat)
			? activeCategories.filter((c) => c !== cat)
			: [...activeCategories, cat];
		loadVisibleMonth();
	}

	// ── Calendar state ──────────────────────────────────────────────────────
	let viewDate = $state(new Date());

	function pad(n: number) { return n < 10 ? `0${n}` : `${n}`; }
	function dayKey(d: Date) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; }

	// 6-week (42 cell) grid starting Monday
	function gridStart(base: Date): Date {
		const first = new Date(base.getFullYear(), base.getMonth(), 1);
		const offset = (first.getDay() + 6) % 7; // 0 = Monday
		const start = new Date(first);
		start.setDate(first.getDate() - offset);
		start.setHours(0, 0, 0, 0);
		return start;
	}

	const gridDays = $derived.by(() => {
		const start = gridStart(viewDate);
		const days: Date[] = [];
		for (let i = 0; i < 42; i++) {
			const d = new Date(start);
			d.setDate(start.getDate() + i);
			days.push(d);
		}
		return days;
	});

	const hearingsByDay = $derived.by(() => {
		const map: Record<string, CourtHearing[]> = {};
		for (const h of court.state.hearings) {
			const key = (h.scheduled_at || "").slice(0, 10); // YYYY-MM-DD
			(map[key] ||= []).push(h);
		}
		return map;
	});

	async function loadVisibleMonth() {
		const start = gridStart(viewDate);
		const end = new Date(start);
		end.setDate(start.getDate() + 41);
		end.setHours(23, 59, 59, 0);
		const cats = activeCategories.length === ALL_CATEGORIES.length ? null : activeCategories;
		await court.loadRange(toMysqlDateTime(start), toMysqlDateTime(end), cats);
	}

	function prevMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1); }
	function nextMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1); }
	function goToday() { viewDate = new Date(); }

	// reload whenever the visible month changes
	let loadedKey = $state("");
	$effect(() => {
		const key = `${viewDate.getFullYear()}-${viewDate.getMonth()}`;
		if (key !== loadedKey) {
			loadedKey = key;
			loadVisibleMonth();
		}
	});

	onMount(() => {
		// Global toast/sound is handled in MDT.svelte; here we just refresh the view.
		useNuiEvent<{ title?: string }>("courtReminder", () => {
			court.refresh();
		});
	});

	// ── Selected day ────────────────────────────────────────────────────────
	let selectedDayKey = $state<string | null>(null);
	const selectedDayHearings = $derived(
		selectedDayKey ? (hearingsByDay[selectedDayKey] || []) : [],
	);

	function selectDay(d: Date) { selectedDayKey = dayKey(d); }

	function timeLabel(scheduledAt: string): string {
		return (scheduledAt || "").slice(11, 16) || "--:--";
	}

	// ── Create / edit modal ─────────────────────────────────────────────────
	type FormState = {
		id: number | null;
		title: string;
		category: EventCategory;
		hearing_type: HearingType;
		date: string;
		time: string;
		duration_minutes: number;
		location: string;
		judge_name: string;
		case_id: string;
		defendant_cid: string;
		defendant_name: string;
		status: HearingStatus;
		notes: string;
	};

	function emptyForm(prefillDate?: string): FormState {
		return {
			id: null,
			title: "",
			category: creatableCategories[0] ?? "court",
			hearing_type: "trial",
			date: prefillDate || dayKey(new Date()),
			time: "12:00",
			duration_minutes: 30,
			location: "",
			judge_name: "",
			case_id: "",
			defendant_cid: "",
			defendant_name: "",
			status: "scheduled",
			notes: "",
		};
	}

	let showModal = $state(false);
	let saving = $state(false);
	let form = $state<FormState>(emptyForm());
	let modalAttendees = $state<CourtAttendee[]>([]);

	function openCreate(forDayKey?: string) {
		form = emptyForm(forDayKey || selectedDayKey || undefined);
		modalAttendees = [];
		formReadOnly = false;
		showModal = true;
	}

	async function openEdit(hearing: CourtHearing) {
		const detail = await court.getHearing(hearing.id);
		const h = detail?.hearing ?? hearing;
		form = {
			id: h.id,
			title: h.title,
			category: h.category ?? "court",
			hearing_type: h.hearing_type,
			date: (h.scheduled_at || "").slice(0, 10),
			time: (h.scheduled_at || "").slice(11, 16),
			duration_minutes: h.duration_minutes ?? 30,
			location: h.location ?? "",
			judge_name: h.judge_name ?? "",
			case_id: h.case_id != null ? String(h.case_id) : "",
			defendant_cid: h.defendant_cid ?? "",
			defendant_name: h.defendant_name ?? "",
			status: h.status,
			notes: h.notes ?? "",
		};
		modalAttendees = detail?.attendees ?? [];
		formReadOnly = !canEditCat(h.category ?? "court");
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		saving = false;
	}

	function buildScheduledAt(): string {
		return `${form.date} ${form.time}:00`;
	}

	async function saveHearing() {
		if (!form.title.trim()) { globalNotifications.error("Titel ist erforderlich"); return; }
		if (!form.date || !form.time) { globalNotifications.error("Datum/Uhrzeit erforderlich"); return; }
		saving = true;

		const base = {
			title: form.title.trim(),
			category: form.category,
			hearing_type: form.hearing_type,
			scheduled_at: buildScheduledAt(),
			duration_minutes: Number(form.duration_minutes) || 30,
			location: form.location || null,
			judge_name: form.judge_name || null,
			case_id: form.case_id ? Number(form.case_id) : null,
			defendant_cid: form.defendant_cid || null,
			defendant_name: form.defendant_name || null,
			status: form.status,
			notes: form.notes || null,
		};

		try {
			if (form.id == null) {
				const res = await court.createHearing({
					...base,
					attendees: modalAttendees.map((a) => ({
						citizenid: a.citizenid,
						display_name: a.display_name ?? undefined,
						role: a.role,
					})),
				});
				if (res.success) {
					globalNotifications.success("Termin angelegt");
					closeModal();
				} else {
					globalNotifications.error(court.state.lastError || "Anlegen fehlgeschlagen");
				}
			} else {
				const res = await court.updateHearing(form.id, base);
				if (res.success) {
					globalNotifications.success("Termin aktualisiert");
					closeModal();
				} else {
					globalNotifications.error("Aktualisieren fehlgeschlagen");
				}
			}
		} finally {
			saving = false;
		}
	}

	let confirmDeleteId = $state<number | null>(null);
	async function confirmDelete() {
		if (confirmDeleteId == null) return;
		const ok = await court.deleteHearing(confirmDeleteId);
		if (ok) {
			globalNotifications.success("Termin gelöscht");
			if (showModal) closeModal();
		} else {
			globalNotifications.error("Löschen fehlgeschlagen");
		}
		confirmDeleteId = null;
	}

	// ── Attendee / defendant person search ──────────────────────────────────
	let showDefendantSearch = $state(false);
	let showAttendeeSearch = $state(false);
	let searchResults = $state<SearchResult[]>([]);
	let attendeeRole = $state<AttendeeRole>("officer");

	async function runSearch(query: string) {
		if (query.length < 2) { searchResults = []; return; }
		const results = await fetchNui<any[]>(NUI_EVENTS.CITIZEN.SEARCH_CITIZENS, { query }, []);
		searchResults = (Array.isArray(results) ? results : []).map((c: any) => ({
			id: c.citizenid || c.id,
			fullName: c.fullName || `${c.firstname ?? ""} ${c.lastname ?? ""}`.trim(),
			citizenid: c.citizenid || c.id,
			image: c.profileImage || c.image,
		}));
	}

	function selectDefendant(p: SearchResult) {
		form.defendant_cid = p.citizenid || p.id;
		form.defendant_name = p.fullName;
		showDefendantSearch = false;
		searchResults = [];
	}

	async function selectAttendee(p: SearchResult) {
		const cid = p.citizenid || p.id;
		if (modalAttendees.some((a) => a.citizenid === cid)) {
			showAttendeeSearch = false; searchResults = []; return;
		}
		// If editing an existing hearing, persist immediately; otherwise stage locally.
		if (form.id != null) {
			const res = await court.addAttendee(form.id, cid, p.fullName, attendeeRole);
			if (res.success) {
				modalAttendees = [...modalAttendees, { id: res.id ?? Date.now(), citizenid: cid, display_name: p.fullName, role: attendeeRole }];
			}
		} else {
			modalAttendees = [...modalAttendees, { id: Date.now(), citizenid: cid, display_name: p.fullName, role: attendeeRole }];
		}
		showAttendeeSearch = false;
		searchResults = [];
	}

	async function removeAttendee(a: CourtAttendee) {
		if (form.id != null && a.id > 0) {
			await court.removeAttendee(a.id);
		}
		modalAttendees = modalAttendees.filter((x) => x.citizenid !== a.citizenid);
	}

	const isToday = (d: Date) => dayKey(d) === dayKey(new Date());
	const inViewMonth = (d: Date) => d.getMonth() === viewDate.getMonth();
</script>

<div class="page">
	<div class="header">
		<div class="title-row">
			<span class="material-icons">calendar_month</span>
			<h1>Kalender</h1>
		</div>
		<div class="controls">
			<button class="nav-btn" onclick={prevMonth} aria-label="Vorheriger Monat">
				<span class="material-icons">chevron_left</span>
			</button>
			<button class="today-btn" onclick={goToday}>Heute</button>
			<span class="month-label">{MONTHS[viewDate.getMonth()]} {viewDate.getFullYear()}</span>
			<button class="nav-btn" onclick={nextMonth} aria-label="Nächster Monat">
				<span class="material-icons">chevron_right</span>
			</button>
			{#if canCreateAny}
				<button class="primary-btn" onclick={() => openCreate()}>
					<span class="material-icons">add</span> Termin
				</button>
			{/if}
		</div>
	</div>

	<div class="filter-row">
		{#each ALL_CATEGORIES as cat}
			<button
				class="cat-filter cat-{cat}"
				class:active={activeCategories.includes(cat)}
				onclick={() => toggleCategory(cat)}
			>
				<span class="material-icons">{CATEGORY_ICONS[cat]}</span>
				{CATEGORY_LABELS[cat]}
			</button>
		{/each}
	</div>

	<div class="body">
		<div class="calendar">
			<div class="weekday-row">
				{#each WEEKDAYS as wd}<div class="weekday">{wd}</div>{/each}
			</div>
			<div class="grid">
				{#each gridDays as d}
					{@const key = dayKey(d)}
					{@const dayHearings = hearingsByDay[key] || []}
					<button
						class="cell"
						class:dim={!inViewMonth(d)}
						class:today={isToday(d)}
						class:selected={selectedDayKey === key}
						onclick={() => selectDay(d)}
					>
						<span class="cell-date">{d.getDate()}</span>
						<div class="chips">
							{#each dayHearings.slice(0, 3) as h}
								<span class="chip cat-{h.category} status-{h.status}" title={h.title}>
									<span class="chip-time">{timeLabel(h.scheduled_at)}</span>
									<span class="chip-title">{h.title}</span>
								</span>
							{/each}
							{#if dayHearings.length > 3}
								<span class="chip more">+{dayHearings.length - 3} weitere</span>
							{/if}
						</div>
					</button>
				{/each}
			</div>
		</div>

		<aside class="side">
			{#if court.state.isLoading}
				<div class="side-empty">Lade Termine…</div>
			{:else if !selectedDayKey}
				<div class="side-empty">
					<span class="material-icons">event</span>
					<p>Wähle einen Tag, um Termine zu sehen.</p>
				</div>
			{:else}
				<div class="side-head">
					<h2>{selectedDayKey.split("-").reverse().join(".")}</h2>
					{#if canCreateAny}
						<button class="ghost-btn" onclick={() => openCreate(selectedDayKey!)}>
							<span class="material-icons">add</span>
						</button>
					{/if}
				</div>
				{#if selectedDayHearings.length === 0}
					<div class="side-empty"><p>Keine Termine an diesem Tag.</p></div>
				{:else}
					<div class="day-list">
						{#each selectedDayHearings as h}
							<button class="day-item cat-{h.category} status-{h.status}" onclick={() => openEdit(h)}>
								<div class="day-item-top">
									<span class="day-item-time">{timeLabel(h.scheduled_at)}</span>
									<span class="day-item-status">{STATUS_LABELS[h.status]}</span>
								</div>
								<div class="day-item-title">{h.title}</div>
								<div class="day-item-meta">
									<span class="cat-badge cat-{h.category}">
										<span class="material-icons">{CATEGORY_ICONS[h.category]}</span>
										{CATEGORY_LABELS[h.category]}
									</span>
									{#if h.category === "court"}<span>· {TYPE_LABELS[h.hearing_type]}</span>{/if}
									{#if h.case_number}<span>· {h.case_number}</span>{/if}
									{#if h.defendant_name}<span>· {h.defendant_name}</span>{/if}
								</div>
							</button>
						{/each}
					</div>
				{/if}
			{/if}
		</aside>
	</div>
</div>

{#if showModal}
	<div class="overlay" onclick={closeModal} role="presentation">
		<div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" tabindex="-1">
			<div class="modal-head">
				<h2>{form.id == null ? "Neuer Termin" : (formReadOnly ? "Termin ansehen" : "Termin bearbeiten")}</h2>
				<button class="icon-btn" onclick={closeModal}><span class="material-icons">close</span></button>
			</div>

			<div class="modal-body">
				<label class="field">
					<span>Titel *</span>
					<input type="text" bind:value={form.title} placeholder="z.B. Schießtraining / Anhörung Schmidt" readonly={formReadOnly} />
				</label>

				<div class="field-row">
					<label class="field">
						<span>Kategorie</span>
						<select bind:value={form.category} disabled={formReadOnly}>
							{#each ALL_CATEGORIES as c}
								{#if canCreateCat(c) || c === form.category}
									<option value={c}>{CATEGORY_LABELS[c]}</option>
								{/if}
							{/each}
						</select>
					</label>
					{#if form.category === "court"}
						<label class="field">
							<span>Typ</span>
							<select bind:value={form.hearing_type} disabled={formReadOnly}>
								{#each Object.keys(TYPE_LABELS) as t}
									<option value={t}>{TYPE_LABELS[t as HearingType]}</option>
								{/each}
							</select>
						</label>
					{/if}
					<label class="field">
						<span>Status</span>
						<select bind:value={form.status} disabled={formReadOnly}>
							{#each Object.keys(STATUS_LABELS) as s}
								<option value={s}>{STATUS_LABELS[s as HearingStatus]}</option>
							{/each}
						</select>
					</label>
				</div>

				<div class="field-row">
					<label class="field">
						<span>Datum *</span>
						<input type="date" bind:value={form.date} readonly={formReadOnly} />
					</label>
					<label class="field">
						<span>Uhrzeit *</span>
						<div class="time-pick">
							<select value={timeHour()} onchange={(e) => setHour(e.currentTarget.value)} disabled={formReadOnly}>
								{#each HOURS as h}<option value={h}>{h}</option>{/each}
							</select>
							<span class="time-colon">:</span>
							<select value={timeMin()} onchange={(e) => setMin(e.currentTarget.value)} disabled={formReadOnly}>
								{#each MINUTES as m}<option value={m}>{m}</option>{/each}
							</select>
						</div>
					</label>
					<label class="field">
						<span>Dauer (Min)</span>
						<input type="number" min="5" step="5" bind:value={form.duration_minutes} readonly={formReadOnly} />
					</label>
				</div>

				<div class="field-row">
					<label class="field">
						<span>Ort</span>
						<input type="text" bind:value={form.location} placeholder="z.B. Saal 1 / Range" readonly={formReadOnly} />
					</label>
					{#if form.category === "court"}
						<label class="field">
							<span>Richter</span>
							<input type="text" bind:value={form.judge_name} placeholder="Name" readonly={formReadOnly} />
						</label>
						<label class="field">
							<span>Case-ID</span>
							<input type="number" bind:value={form.case_id} placeholder="optional" readonly={formReadOnly} />
						</label>
					{:else}
						<label class="field">
							<span>Leitung</span>
							<input type="text" bind:value={form.judge_name} placeholder="Ausbilder / Organisator" readonly={formReadOnly} />
						</label>
					{/if}
				</div>

				{#if form.category === "court"}
					<div class="field">
						<span>Angeklagte/r</span>
						<div class="person-pick">
							<input type="text" readonly value={form.defendant_name} placeholder="Keine Person gewählt" />
							{#if !formReadOnly}
								<button class="ghost-btn" onclick={() => { searchResults = []; showDefendantSearch = true; }}>
									<span class="material-icons">person_search</span>
								</button>
								{#if form.defendant_cid}
									<button class="ghost-btn" onclick={() => { form.defendant_cid = ""; form.defendant_name = ""; }}>
										<span class="material-icons">clear</span>
									</button>
								{/if}
							{/if}
						</div>
					</div>
				{/if}

				<div class="field">
					<span>{form.category === "court" ? "Geladene Personen" : "Teilnehmer"}</span>
					<div class="attendees">
						{#each modalAttendees as a}
							<span class="attendee-chip role-{a.role}">
								{a.display_name || a.citizenid}
								<small>{ROLE_LABELS[a.role]}</small>
								{#if !formReadOnly}
									<button class="chip-x" onclick={() => removeAttendee(a)} aria-label="Entfernen">
										<span class="material-icons">close</span>
									</button>
								{/if}
							</span>
						{/each}
						{#if !formReadOnly}
							<div class="attendee-add">
								<select bind:value={attendeeRole}>
									{#each Object.keys(ROLE_LABELS) as r}
										<option value={r}>{ROLE_LABELS[r as AttendeeRole]}</option>
									{/each}
								</select>
								<button class="ghost-btn" onclick={() => { searchResults = []; showAttendeeSearch = true; }}>
									<span class="material-icons">group_add</span> Hinzufügen
								</button>
							</div>
						{:else if modalAttendees.length === 0}
							<span class="empty-hint">Keine Teilnehmer</span>
						{/if}
					</div>
				</div>

				<label class="field">
					<span>Notizen</span>
					<textarea rows="3" bind:value={form.notes} placeholder="Optionale Notizen…" readonly={formReadOnly}></textarea>
				</label>
			</div>

			<div class="modal-foot">
				{#if form.id != null && canDeleteCat(form.category)}
					<button class="danger-btn" onclick={() => (confirmDeleteId = form.id)}>
						<span class="material-icons">delete</span> Löschen
					</button>
				{/if}
				<div class="spacer"></div>
				<button class="ghost-btn" onclick={closeModal}>{formReadOnly ? "Schließen" : "Abbrechen"}</button>
				{#if (form.id == null && canCreateCat(form.category)) || (form.id != null && canEditCat(form.category))}
					<button class="primary-btn" onclick={saveHearing} disabled={saving}>
						{saving ? "Speichern…" : "Speichern"}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

{#if confirmDeleteId != null}
	<div class="overlay" onclick={() => (confirmDeleteId = null)} role="presentation">
		<div class="confirm" onclick={(e) => e.stopPropagation()} role="dialog" tabindex="-1">
			<span class="material-icons warn">warning</span>
			<p>Diesen Termin wirklich löschen?</p>
			<div class="confirm-actions">
				<button class="ghost-btn" onclick={() => (confirmDeleteId = null)}>Abbrechen</button>
				<button class="danger-btn" onclick={confirmDelete}>Löschen</button>
			</div>
		</div>
	</div>
{/if}

<PersonSearchModal
	show={showDefendantSearch}
	title="Angeklagte/n suchen"
	searchResults={searchResults}
	onClose={() => { showDefendantSearch = false; searchResults = []; }}
	onSearch={runSearch}
	onSelect={selectDefendant}
/>

<PersonSearchModal
	show={showAttendeeSearch}
	title="Person laden"
	searchResults={searchResults}
	onClose={() => { showAttendeeSearch = false; searchResults = []; }}
	onSearch={runSearch}
	onSelect={selectAttendee}
/>

<style>
	/* ===== Page (Weapons-consistent) ===== */
	.page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	/* ===== Topbar / header ===== */
	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.title-row { display: flex; align-items: center; gap: 8px; }
	.title-row h1 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.9); }
	.title-row .material-icons { font-size: 16px; color: rgba(255, 255, 255, 0.35); }
	.controls { display: flex; align-items: center; gap: 6px; }
	.month-label { min-width: 140px; text-align: center; font-size: 11px; font-weight: 600; color: rgba(255, 255, 255, 0.7); }

	/* ===== Buttons (Weapons-consistent) ===== */
	.nav-btn, .today-btn, .ghost-btn, .icon-btn, .cancel-btn {
		display: flex;
		align-items: center;
		gap: 5px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		font-family: inherit;
	}
	.nav-btn:hover, .today-btn:hover, .ghost-btn:hover, .icon-btn:hover, .cancel-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}
	.nav-btn { padding: 4px 6px; }
	.icon-btn { padding: 4px; }
	.primary-btn {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		display: inline-flex;
		align-items: center;
		gap: 5px;
		font-family: inherit;
	}
	.primary-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }
	.primary-btn:disabled { opacity: 0.5; cursor: default; }
	.danger-btn {
		background: rgba(239, 68, 68, 0.06);
		color: rgba(248, 113, 113, 0.7);
		border: 1px solid rgba(239, 68, 68, 0.12);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		display: inline-flex;
		align-items: center;
		gap: 5px;
		font-family: inherit;
	}
	.danger-btn:hover { background: rgba(239, 68, 68, 0.12); color: rgba(252, 165, 165, 0.9); }

	/* ===== Category filter row ===== */
	.filter-row { display: flex; gap: 6px; padding: 8px 16px 0; flex-wrap: wrap; }
	.cat-filter {
		display: inline-flex; align-items: center; gap: 5px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		border-radius: 3px; padding: 3px 10px; font-size: 10px; font-weight: 500;
		cursor: pointer; transition: all 0.1s; font-family: inherit;
	}
	.cat-filter .material-icons { font-size: 13px; }
	.cat-filter:hover { color: rgba(255, 255, 255, 0.6); }
	.cat-filter.active.cat-court    { color: rgba(96, 165, 250, 0.9); border-color: rgba(96, 165, 250, 0.25); }
	.cat-filter.active.cat-training { color: rgba(52, 211, 153, 0.9); border-color: rgba(16, 185, 129, 0.25); }
	.cat-filter.active.cat-meeting  { color: rgba(251, 191, 36, 0.9); border-color: rgba(245, 158, 11, 0.25); }
	.cat-filter.active.cat-other    { color: rgba(255, 255, 255, 0.75); border-color: rgba(255, 255, 255, 0.18); }

	/* ===== Body / calendar grid ===== */
	.body { flex: 1; display: flex; min-height: 0; }
	.calendar { flex: 1; display: flex; flex-direction: column; padding: 12px 16px; min-width: 0; }
	.weekday-row, .grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; }
	.weekday { text-align: center; font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; color: rgba(255, 255, 255, 0.3); padding: 4px 0; }
	.grid { flex: 1; grid-auto-rows: 1fr; }
	.cell {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		padding: 5px;
		text-align: left;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		gap: 3px;
		overflow: hidden;
		min-height: 72px;
		transition: all 0.1s;
		font-family: inherit;
	}
	.cell:hover { border-color: rgba(255, 255, 255, 0.12); }
	.cell.dim { opacity: 0.35; }
	.cell.today .cell-date { color: var(--accent); }
	.cell.selected { background: var(--accent-10); border-color: var(--accent-30); }
	.cell-date { font-size: 11px; font-weight: 600; color: rgba(255, 255, 255, 0.6); }
	.chips { display: flex; flex-direction: column; gap: 2px; overflow: hidden; }
	.chip {
		font-size: 9px;
		border-radius: 2px;
		padding: 1px 4px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		display: flex;
		gap: 4px;
		background: rgba(255, 255, 255, 0.04);
		border-left: 2px solid rgba(255, 255, 255, 0.2);
		color: rgba(255, 255, 255, 0.75);
	}
	.chip-time { font-weight: 700; opacity: 0.85; }
	.chip-title { overflow: hidden; text-overflow: ellipsis; }
	.chip.more { background: transparent; border-left: none; color: rgba(255, 255, 255, 0.3); }
	.chip.cat-court    { border-left-color: rgba(96, 165, 250, 0.8); }
	.chip.cat-training { border-left-color: rgba(52, 211, 153, 0.8); }
	.chip.cat-meeting  { border-left-color: rgba(251, 191, 36, 0.8); }
	.chip.cat-other    { border-left-color: rgba(255, 255, 255, 0.35); }
	.chip.status-cancelled { opacity: 0.5; text-decoration: line-through; }
	.chip.status-completed { opacity: 0.7; }

	/* ===== Side panel ===== */
	.side {
		width: 300px;
		border-left: 1px solid rgba(255, 255, 255, 0.06);
		padding: 12px 14px;
		display: flex;
		flex-direction: column;
		overflow-y: auto;
		flex-shrink: 0;
	}
	.side-empty {
		flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
		color: rgba(255, 255, 255, 0.25); gap: 8px; text-align: center; font-size: 11px;
	}
	.side-empty .material-icons { font-size: 30px; opacity: 0.5; }
	.side-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
	.side-head h2 { font-size: 12px; font-weight: 600; margin: 0; color: rgba(255, 255, 255, 0.85); }
	.day-list { display: flex; flex-direction: column; gap: 6px; }
	.day-item {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-left: 2px solid rgba(255, 255, 255, 0.2);
		border-radius: 3px;
		padding: 8px 10px;
		text-align: left;
		cursor: pointer;
		color: rgba(255, 255, 255, 0.9);
		transition: all 0.1s;
		font-family: inherit;
	}
	.day-item:hover { border-color: rgba(255, 255, 255, 0.12); }
	.day-item.cat-court    { border-left-color: rgba(96, 165, 250, 0.8); }
	.day-item.cat-training { border-left-color: rgba(52, 211, 153, 0.8); }
	.day-item.cat-meeting  { border-left-color: rgba(251, 191, 36, 0.8); }
	.day-item.cat-other    { border-left-color: rgba(255, 255, 255, 0.35); }
	.day-item.status-cancelled { opacity: 0.55; text-decoration: line-through; }
	.day-item-top { display: flex; justify-content: space-between; font-size: 9px; color: rgba(255, 255, 255, 0.35); text-transform: uppercase; letter-spacing: 0.4px; }
	.day-item-time { font-weight: 700; color: rgba(255, 255, 255, 0.7); }
	.day-item-title { font-weight: 600; font-size: 12px; margin: 3px 0; }
	.day-item-meta { font-size: 10px; color: rgba(255, 255, 255, 0.35); display: flex; gap: 4px; flex-wrap: wrap; align-items: center; }
	.cat-badge {
		display: inline-flex; align-items: center; gap: 3px;
		padding: 1px 5px; border-radius: 2px; font-size: 9px; font-weight: 600;
		background: rgba(255, 255, 255, 0.05);
	}
	.cat-badge .material-icons { font-size: 11px; }
	.cat-badge.cat-court    { color: rgba(96, 165, 250, 0.9); }
	.cat-badge.cat-training { color: rgba(52, 211, 153, 0.9); }
	.cat-badge.cat-meeting  { color: rgba(251, 191, 36, 0.9); }
	.cat-badge.cat-other    { color: rgba(255, 255, 255, 0.5); }

	/* ===== Modal (Weapons-consistent) ===== */
	.overlay {
		position: fixed; inset: 0; background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		display: flex; align-items: center; justify-content: center; z-index: 999; padding: 20px;
	}
	.modal {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		width: min(540px, 92vw); max-height: 85vh;
		overflow: hidden;
		display: flex; flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}
	.modal-head {
		display: flex; align-items: center; justify-content: space-between;
		padding: 10px 16px; border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.modal-head h2 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.85); }
	.modal-body { padding: 14px 16px; overflow-y: auto; display: flex; flex-direction: column; gap: 12px; }
	.modal-foot {
		display: flex; align-items: center; gap: 6px;
		padding: 10px 16px; border-top: 1px solid rgba(255, 255, 255, 0.06);
	}
	.spacer { flex: 1; }

	/* ===== Form fields (Weapons-consistent) ===== */
	.field { display: flex; flex-direction: column; gap: 3px; flex: 1; }
	.field > span { color: rgba(255, 255, 255, 0.35); font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; }
	.field-row { display: flex; gap: 10px; }
	input, select, textarea {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		width: 100%;
		box-sizing: border-box;
		transition: border-color 0.1s;
		font-family: inherit;
	}
	input:focus, select:focus, textarea:focus { outline: none; border-color: var(--accent-35); }
	input::placeholder, textarea::placeholder { color: rgba(255, 255, 255, 0.2); }
	input[readonly] { opacity: 0.7; }
	textarea { resize: vertical; min-height: 60px; }
	.person-pick { display: flex; gap: 6px; align-items: center; }
	.attendees { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
	.attendee-chip {
		display: inline-flex; align-items: center; gap: 5px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px; padding: 3px 8px; font-size: 10px; color: rgba(255, 255, 255, 0.8);
	}
	.attendee-chip small { color: rgba(255, 255, 255, 0.35); }
	.chip-x { background: transparent; border: none; color: rgba(255, 255, 255, 0.3); cursor: pointer; display: inline-flex; padding: 0; }
	.chip-x:hover { color: rgba(255, 255, 255, 0.7); }
	.chip-x .material-icons { font-size: 13px; }
	.attendee-add { display: flex; gap: 6px; align-items: center; }
	.attendee-add select { width: auto; }
	.empty-hint { font-size: 10px; color: rgba(255, 255, 255, 0.3); }
	.time-pick { display: flex; align-items: center; gap: 4px; }
	.time-pick select { width: auto; }
	.time-colon { color: rgba(255, 255, 255, 0.4); }

	/* ===== Confirm dialog ===== */
	.confirm {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px; padding: 20px; width: 300px; text-align: center;
		display: flex; flex-direction: column; align-items: center; gap: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}
	.confirm p { margin: 0; font-size: 12px; color: rgba(255, 255, 255, 0.8); }
	.confirm .warn { color: rgba(251, 191, 36, 0.9); font-size: 32px; }
	.confirm-actions { display: flex; gap: 8px; }

	.material-icons { font-size: 16px; line-height: 1; }
</style>