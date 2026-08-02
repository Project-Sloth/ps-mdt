# ps-mdt v3

Police MDT (Mobile Data Terminal) for FiveM. Built with Svelte 5 and Lua. Works on QBCore and QBX through the ps_lib abstraction layer.

## What is this

A full in-game law enforcement computer. Officers press F11 or type `/mdt` to open it. From there they can look up citizens, write reports, manage cases, track evidence, issue warrants, run BOLOs, look up vehicles and weapons, view security cameras and bodycam feeds, handle dispatch, and manage their department. Everything is permission-based so you control exactly what each rank has access to.

## Dependencies

These need to be running on your server:

| Resource | Why |
|----------|-----|
| [ps_lib](https://github.com/Project-Sloth/ps_lib) | Framework abstraction layer |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [ox_lib](https://github.com/overextended/ox_lib) | Utility library |


Optional but HIGHLY RECOMMENDED:

| Resource | Why |
|----------|-----|
| [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch) | Dispatch integration |
| [lsn-radar](https://github.com/LeSiiN/lsn-radar) | Very Good Radar with all features needed|
| [ps-multijob](https://github.com/Project-Sloth/ps-multijob) | Officers Bodycam ( Optional, works anyways )|

## Installation
No backwards compatibility with ps-mdtv1.

### 1. Add DOJ jobs to QBCore

First, remove the default `judge` and `lawyer` entries from `qb-core/shared/jobs.lua`:

```lua
-- REMOVE THESE
judge = { label = 'Honorary', defaultDuty = true, offDutyPay = false, grades = { ['0'] = { name = 'Judge', payment = 100 } } },
lawyer = { label = 'Law Firm', defaultDuty = true, offDutyPay = false, grades = { ['0'] = { name = 'Associate', payment = 50 } } },
```

Then add the DOJ versions in their place:

```lua
judge = {
    label = 'Department of Justice',
    type = 'doj',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Clerk', payment = 75 },
        ['1'] = { name = 'Magistrate', payment = 100 },
        ['2'] = { name = 'Judge', isboss = true, payment = 150 },
    },
},
lawyer = {
    label = 'Law Firm',
    type = 'doj',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Paralegal', payment = 50 },
        ['1'] = { name = 'Associate', payment = 75 },
        ['2'] = { name = 'Partner', isboss = true, payment = 125 },
    },
},
```

### 2. Import the database

Run `sql/qbcore.sql` or `sql/qbx.sql` against your FiveM database. This creates all the tables the MDT needs. Use phpMyAdmin, HeidiSQL, or whatever database tool you prefer.

### 3. Set your FiveManage API keys

Image uploads (mugshots, evidence photos, suspect photos) and activity log forwarding go through [FiveManage](https://www.fivemanage.com/). You need API keys from their site.

Add these lines to your `server.cfg`:

```
set ps_mdt_fivemanage_key_images "YOUR_IMAGES_API_KEY_HERE"
set ps_mdt_fivemanage_key_logs   "YOUR_LOGS_API_KEY_HERE"
```

| Convar | What it does |
|--------|-------------|
| `ps_mdt_fivemanage_key_images` | Used for uploading mugshots, evidence photos, and suspect photos |
| `ps_mdt_fivemanage_key_logs` | Used for forwarding audit trail activity to FiveManage Logs |

Both are optional. Without the images key you won't be able to upload any images. Without the logs key the audit trail still works locally in the database, it just won't forward to FiveManage.

### 4. Build the frontend

If you grabbed a release with `web/dist` already in it, skip this step.

Otherwise:

```
cd resources/[qb]/ps-mdt/web
npm install
npm run build
```

### 5. Add to server.cfg

```
ensure ps_lib
ensure oxmysql
ensure ox_lib
ensure ps-mdt
```

ps-mdt has to start after its dependencies.

## Configuration

All config lives in `config.lua`.

### Jobs

Which jobs can access the MDT:

```lua
Config.PoliceJobType = "leo"
Config.PoliceJobs = { 'lspd', 'bcso', 'sahp', 'fib', 'gov' }

Config.DojJobType = "doj"
Config.DojJobs = { 'lawyer', 'judge' }

Config.MedicalJobType = "ems"
Config.MedicalJobs = { 'ambulance' }
```

DOJ access works two ways. Either the job name is in `Config.DojJobs`, or the job has `type = 'doj'` matching `Config.DojJobType`. You can use one or both.

### Keybind and command

```lua
Config.OnlyShowOnDuty = true   -- false = can open off duty

Config.Keys = {
    OpenMDT = {
        enabled = true,
        key = 'F11',
    },
}

Config.Commands = {
    Open = { enabled = true, command = 'mdt' },
    MessageOfTheDay = { enabled = true, command = 'motd' },
}
```

Commands the resource registers:

| Command | What it does |
|---------|-------------|
| `/mdt` | Opens the MDT |
| `/motd` | Message of the day |
| `/mdtimpound` | Impounds the vehicle you're in or standing next to (name set by `Config.Impound.OnSite.Command`) |
| `/complaint` | Opens the standalone IA complaint form. Works for civilians, no MDT needed |
| `/cameraplacer` | Places security cameras around the map |

### Date and time format

How every date and time in the MDT is rendered:

```lua
Config.DateTime = {
    TimeFormat = '24',           -- '24' or '12'
    DateFormat = 'DD-MM-YYYY',   -- 'MM-DD-YYYY', 'DD-MM-YYYY', or 'YYYY-MM-DD'
}
```

This applies everywhere: reports, warrants, the court calendar, audit logs, and the timestamp burned into camera, bodycam, and dashcam footage.

### Data sharing between departments

```lua
Config.Sharing = {
    -- All these departments see each other's data
    Mutual = {
        types = { 'reports', 'bodycams', 'evidence', 'bolos', 'warrants' },
        departments = { 'lspd', 'bcso', 'sahp' }
    },

    -- FIB/GOV can see patrol data but patrol can't see theirs
    OneWay = {
        {
            viewers = { 'fib', 'gov' },
            targets = { 'lspd', 'bcso', 'sahp' },
            types = { 'reports', 'bodycams', 'evidence', 'bolos', 'warrants' }
        },
    },
}
```

### Impound

Lots, reasons, fees, and the on-site impound flow all live under `Config.Impound`:

```lua
Config.Impound = {
    Lots = {
        { id = 'lspd',   label = 'LSPD Impound' },
        { id = 'paleto', label = 'Paleto Impound' },
    },

    -- Each reason carries a default fee. The officer can still edit it.
    Reasons = {
        { label = 'Evidence / Investigation', fee = 0 },
        { label = 'DUI',                      fee = 1500 },
        { label = 'Illegal Modifications',    fee = 1000 },
        -- ...
    },

    DefaultFee     = 500,
    MaxFee         = 50000,
    FeeAccount     = 'bank',   -- 'bank' or 'cash'
    RequireFeePaid = true,     -- fee must be collected before release

    -- Storage grows for every day the vehicle sits in the lot, then stops.
    Storage = {
        PerDay  = 500,
        MaxDays = 7,
    },

    OnSite = {
        Command     = 'mdtimpound',
        MaxDistance = 6.0,

        -- The officer writes the vehicle up, then radios it in. Both steps are
        -- cancellable: walk away and nothing is written.
        Sequence = { NotepadMs = 4500, RadioMs = 6000 },
        FadeMs   = 1500,

        -- Payout for clearing an unowned vehicle off the street.
        Cleanup = {
            RewardMin = 100, RewardMax = 200, Account = 'cash',
            Cooldown  = 120, MaxPerShift = 20,
        },
    },
}
```

Storage fees are worked out from the impound date rather than counted up by a timer, so they survive restarts and can't drift.

**Hold periods.** How long the vehicle stays put, regardless of the fee — paying up doesn't shorten a hold, and a hold expiring doesn't waive the fee:

```lua
Config.Impound.Durations = {
    { id = 'immediate', label = 'Releasable immediately', days = 0 },
    { id = '1d',        label = '1 day',                  days = 1 },
    { id = '3d',        label = '3 days',                 days = 3 },
    { id = '7d',        label = '7 days',                 days = 7 },
    { id = 'hold',      label = 'Until an officer releases it' },  -- no `days`
}
Config.Impound.DefaultDuration = 'immediate'
```

Each entry in `Config.Impound.Reasons` can carry a `hold` naming one of these ids. Picking that reason pre-selects it — a recommendation, not a rule, so the officer can still change it.

Cutting a hold short needs the separate `vehicle_impound_override` permission and a written reason, and is logged under its own audit category.

### Callsigns

Callsigns are picked from a grid rather than typed, so you can see what's taken, reserved and free.

Ranges are defined per job type, and optionally per job. There is **no global fallback**: a job with no range configured is a configuration mistake, and the MDT says so rather than quietly handing out numbers from a range nobody chose.

```lua
Config.Callsigns = {
    JobTypes = {
        leo = {
            Min = 1,          -- required
            Max = 100,        -- required
            Pad = 2,          -- 2 → 01..99, 3 → 001..999, 0 or omitted → no padding
            Prefix = '',      -- 'L-' gives L-01
            PageSize = 20,    -- boxes shown before "Load more"

            -- Restricted: only somebody with roster_callsign_reserved may hand these out.
            Reserved = {
                { n = 1, why = 'Chief of Police' },
                { from = 2, to = 5, why = 'Command staff' },   -- ranges work too
            },

            -- Forbidden outright. No permission unlocks a blocked callsign.
            Blocked = {
                { n = 99, why = 'Dispatch uses this on the radio' },
                { from = 90, to = 98, why = 'Held back for future units' },
            },
        },
        ems = { Min = 1, Max = 60, Pad = 2, Prefix = 'M-', Reserved = { { n = 1, why = 'Chief of Medicine' } }, Blocked = {} },
        doj = { Min = 1, Max = 30, Pad = 2, Prefix = 'DOJ-', Reserved = {}, Blocked = {} },
    },

    -- Optional. A job entry replaces the job type entry completely — it isn't merged
    -- into it — so spell the block out in full.
    Jobs = {
        -- bcso = {
        --     Min = 200, Max = 299, Pad = 3, Prefix = 'S-',
        --     Reserved = { [200] = 'Sheriff' },
        -- },
    },
}
```

An officer's range is looked up by job name first, then by job type. Assigning is done from Roster → the officer → Callsign, and needs `roster_manage_officers`. The same panel can hand a callsign back, so a number isn't stuck with someone who changed department or went on leave — firing an officer frees theirs automatically.

There are two ways to hold a number back, and the difference matters:

| | Who can assign it |
|---|---|
| **Reserved** | Anyone with the `roster_callsign_reserved` permission. That's the split between an FTO who can give a recruit a spare number and a supervisor who can hand out the Chief's. Assigning one is logged as a reserved assignment, not an ordinary one |
| **Blocked** | **Nobody.** No permission unlocks it. The config is saying the number doesn't exist — use it for numbers the radio needs, or ones you're holding back |

Blocking a number doesn't take it away from an officer who already has it. When that happens the picker says so, so it doesn't sit there unnoticed.

Write every entry as `{ n = 1, why = '…' }` or `{ from = 2, to = 5, why = '…' }`. The bracket form (`[1] = '…'`) is rejected: in Lua a keyless range entry *is* index 1, so putting the two next to each other makes the range overwrite the single number as the file is parsed — the value is gone before any code can notice. The resource refuses the shape rather than letting it fail silently.

Both lists are checked on resource start: a bad range, a number listed as both Reserved and Blocked, or one sitting outside `Min`–`Max` gets a warning in the console rather than surfacing the day somebody opens the picker.

The range, both lists, the reserved permission and uniqueness are all enforced server-side, not just hidden in the UI.

### Impound fees

Collecting a fee takes money out of a citizen's account, so it happens face to face:

```lua
Config.Impound.CollectRange = 6.0  -- owner must be within this many metres; 0 disables
```

An officer pressing Collect from across the map to debit somebody's bank account is a strange kind of power, and no tow yard works that way. With `CollectRange` set, the owner has to be standing there — and anyone who isn't can settle the bill themselves:

```lua
Config.CivilianAccess.payImpounds = true
```

Citizens then see their impounded vehicles in the civilian MDT with the fee itemised (impound fee + accrued storage), any hold that's in force, and a button to pay. Paying does **not** release the vehicle — an officer still does that.

### Bodycams

Officers control their own bodycam with `/bodycam`, or the toggle in the Bodycams tab. **Switching it off is deliberately not blocked — it is recorded.** Every state change lands in the audit log with who, when and why, and shows up on the officer's activity timeline in the Roster — no separate history view needed.

```lua
Config.Bodycam = {
    Command = 'bodycam',
    AutoDutyDefault = true,       -- default for the Settings preference
    NotifyOfficer = true,
}
```

An officer can only ever change their own camera: the server keys the state to the caller's citizenid and accepts no target, so there is no path to switching off someone else's.

Settings has a **Bodycam Follows Duty** preference: on by default, it switches the camera on at duty start and off at duty end, logged as `duty_on` / `duty_off` rather than `manual`. Turning a bodycam off cuts any live viewer immediately.

History is stored in the existing `mdt_audit_logs` table rather than a table of its own — the audit log already carries actor, name, timestamp and a details blob, so the callsign and reason ride along in `details`. Because the Roster's activity timeline already reads that table by `actor_citizenid`, bodycam entries appear there automatically; entries carry an `action_label` so they read as "Bodycam deactivated manually" rather than a raw action name. No new table, no migration, no extra view.

Note that `bodycam_on` / `bodycam_off` are intentionally left out of `Config.AuditTracking`'s category map. Unmapped actions are always recorded, which is the point: the record of a bodycam being switched off must not itself be switchable off from Settings.

### Camera tampering

Cameras can be shot out. A downed camera drops off the live feed list in the MDT (no View button) and comes back on its own after a cooldown.

```lua
Config.CameraTamper = {
    Enabled = true,
    HitRadius = 2.0,        -- metres from the bullet impact to the camera
    OfflineMs = 600000,     -- 10 minutes down
    RequireFirearm = true,
    EmitEvent = true,       -- fires ps-mdt:server:cameraTampered
    ReportsPerWindow = 12,  -- per-player throttle on impact reports
    ReportWindowMs = 1000,
}
```

**Officers cannot toggle cameras from the MDT by design** — a camera goes down because someone put a bullet in it.

Detection reads the shooter's last bullet impact position rather than watching an entity, so it covers player-placed cameras (which spawn a prop) *and* virtual cameras mapped onto existing world models through one code path. Impacts are validated server-side, so camera positions never reach the client: a client only reports where its own bullet landed, and implausible claims (an impact far from the shooter) are rejected.

To route the alert into a dispatch system, listen for the event rather than expecting the MDT to call your resource:

```lua
AddEventHandler('ps-mdt:server:cameraTampered', function(data)
    -- data: camId, label, coords, offlineMs, suspectSource, suspectCitizenId, suspectName
end)
```

### Applications (civilian job applications)

Civilians apply for a department in-game. Each department has its own command, so the applicant lands straight on the right form:

```lua
Config.Applications = {
    Enabled = true,
    Departments = {
        { id = 'police',    command = 'applypolice', label = 'LSPD Application' },
        { id = 'ambulance', command = 'applyems',    label = 'EMS Application' },
        { id = 'doj',       command = 'applydoj',    label = 'DOJ Application' },
    },
    CooldownMs = 300000,       -- per-department anti-spam
    NotifyOnDecision = true,   -- message the applicant on accept/reject (step 2)
    MaxAnswerLength = 2000,
}
```

**The questions are not configured here.** They're managed live in the MDT under **Management → Applications**, one set per department, so a department can change what it asks without a restart. Six field types are supported: short text, long text, multiple choice, yes/no, number, and link (URL) — each can be optional or required.

Answers are stored as a JSON snapshot of the questions *at submission time*, so editing or deleting a question later never re-labels or corrupts an application that was already sent. The two tables (`mdt_application_questions`, `mdt_applications`) self-heal on start, so no manual migration is needed.

**Reviewing** happens in the Roster tab: a **Roster / Applications** switch (shown to officers with `roster_manage_officers`) flips the panel to a list of submitted applications. Selecting one shows the applicant's answers; a reviewer accepts or rejects with an optional note. Applications are domain-scoped — police reviewers never see EMS applications and vice-versa, DOJ grouped with police. On a decision the applicant is messaged (if `NotifyOnDecision` and a mail bridge are present); a mail failure never blocks the decision.

### Rate limiting

A client can send NUI events as fast as it can generate them. These caps stop one misbehaving client from flooding the database — they're generous enough that a real officer writing quickly never hits them, and apply per player, per action.

```lua
Config.RateLimits = {
    Enabled = true,
    createReport   = { max = 8,  windowMs = 20000 },  -- at most 8 per 20s
    createCase     = { max = 8,  windowMs = 20000 },
    createBolo     = { max = 10, windowMs = 20000 },
    createCharge   = { max = 15, windowMs = 20000 },
    createBulletin = { max = 10, windowMs = 20000 },
    sendMessage    = { max = 20, windowMs = 15000 },
}
```

An action with no config entry is never throttled, so adding a limit elsewhere is just a config line plus a `RateLimitAction(src, 'name')` call. Buckets are cleared when a player disconnects.

### Department banking

Fines and impound fees were taken off citizens and then simply ceased to exist. They now land in the account of the department that collected them.

```lua
Config.DepartmentBanking = {
    Enabled = true,
    Method  = 'export',            -- 'export' | 'event' | 'custom' | 'none'

    Accounts = {                   -- account name defaults to the job name
        -- ['bcso'] = 'police',    -- only needed to override
    },
    Fallback = nil,                -- used when the department can't be determined

    Export = {
        resource = 'qb-banking',
        method   = 'AddMoney',
        args     = { 'account', 'amount', 'reason' },
    },
}
```

`args` is the call signature: `'account'`, `'amount'` and `'reason'` are substituted, anything else is passed through as written — so a banking script that wants its arguments in a different order, or extra ones, is a config change rather than a code change. Presets for Renewed-Banking, okokBanking and qb-management are in the config comments; `Method = 'custom'` takes a Lua function for anything else (ESX society accounts, for instance).

The department is recorded **with the impound**, not looked up when the fee is paid — an owner can settle the bill days later with nobody from that shift online. A failed deposit is logged loudly but never reverses the citizen's payment: that's a bookkeeping problem, not a transaction to roll back.

## MDT plate checks

Adds an automatic lookup against the MDT database (BOLO, reported stolen,
owner's warrants, impound history, insurance/registration) to any radar or
ANPR script. Hits are delivered to the scanning officer as a ps-dispatch
alert.

### Client (in your radar script)

```lua
-- Send each plate at most once per COOLDOWN. Without this guard a scanner
-- running every frame fires hundreds of events per minute — the bottleneck
-- is the network, not the database.
local COOLDOWN = 120000 -- ms, mirrors Config.PlateCheck.alertCooldown
local seen = {}

--- Call this whenever your radar reads or locks a plate.
function CheckPlateWithMDT(plate)
    if type(plate) ~= 'string' or plate == '' then return end
    plate = plate:gsub('%s+', ''):upper()

    local now = GetGameTimer()
    if seen[plate] and (now - seen[plate]) < COOLDOWN then return end

    -- Prune while writing so the table doesn't grow over a long shift.
    for known, at in pairs(seen) do
        if (now - at) >= COOLDOWN then seen[known] = nil end
    end
    seen[plate] = now

    TriggerServerEvent('myradar:checkPlate', plate, GetEntityCoords(PlayerPedId()))
end
```

### Server (in your radar script)

```lua
RegisterNetEvent('myradar:checkPlate', function(plate, coords)
    local src = source
    if type(plate) ~= 'string' or #plate > 16 then return end

    -- CreateThread because the export runs database queries: this keeps the
    -- event handler from blocking. ps-mdt does the job check, caches the
    -- result and throttles the alerts itself — nothing else is needed here.
    CreateThread(function()
        exports['ps-mdt']:PlateCheckAlert(src, plate, coords)
    end)
end)
```

### Lookup without an alert

If the radar shows the hits in its own UI:

```lua
CreateThread(function()
    local result = exports['ps-mdt']:CheckPlate(plate, src) -- src applies the job check
    -- result.denied   -> player is not allowed to run plates
    -- result.hits     -> { { key, label, detail, severity }, ... }
    -- result.severity -> 'critical' | 'warning' | nil
    -- result.model    -> "Karin Sultan", result.owner -> owner name
end)
```

### After changing records

Results are cached for up to `Config.PlateCheck.cacheSeconds`. To make a
freshly created BOLO take effect immediately:

```lua
exports['ps-mdt']:InvalidatePlateCache(plate) -- no argument clears everything
```

### Audit log retention

The audit log grows with every report, search, impound and login, and nothing used to remove rows from it. That's fine for a week and a problem after a year: the Activity page runs a `COUNT(*)` over the whole table on every page load, and InnoDB keeps no cached row count, so it slows down in step with the table.

```lua
Config.AuditRetention = {
    Enabled = true,
    Days = 90,          -- anything older is deleted; 0 disables deletion
    IntervalHours = 24, -- how often the sweep runs (also runs shortly after startup)
    BatchSize = 2000,   -- rows per statement, so the first sweep can't stall the server
}
```

The sweep adds the index it needs (`created_at`) on first run, and deletes in batches with a yield in between — a server that has been running for a year may have millions of rows to remove the first time, and one big `DELETE` would hold a lock far too long.

You can force a sweep without waiting for the timer:

```lua
exports['ps-mdt']:pruneAuditLogs()
```

Set `Enabled = false` to keep everything forever, or if you ship the log elsewhere and prune there.

### Internal Affairs

```lua
Config.IA = {
    CooldownMs = 300000,        -- how long a citizen must wait between complaints
    NotifyComplainant = true,   -- e-mail them when their complaint changes status
    MailSender = 'Internal Affairs',
}
```

Complaints are matched to a real officer by badge, then by name if it points at exactly one person. If it's ambiguous the complaint is left unassigned for IA to sort out, rather than being attached to the wrong officer.

### Other stuff worth changing

| Setting | Default | What it does |
|---------|---------|-------------|
| `Config.Fines.MaxAmount` | 100000 | Cap on fine amounts |
| `Config.Fines.CooldownMs` | 30000 | Cooldown between fines (ms) |
| `Config.Warrants.DefaultExpiryDays` | 7 | Days until a warrant expires |
| `Config.RegisterWeaponsAutomatically` | true | Auto-register weapons on purchase |
| `Config.RegisterCreatedWeapons` | false | Auto-register crafted weapons |
| `Config.UseWolfknightRadar` | true | Wolfknight plate reader integration |
| `Config.Fuel` | 'LegacyFuel' | Your fuel resource name |
| `Config.Radio.Enabled` | true | Push-to-talk from inside the MDT |
| `Config.Radio.VoiceSystem` | 'auto' | `auto`, `pma-voice`, `saltychat`, or `yaca` |
| `Config.Dashcam.Positions` | — | Per-model dashcam positions. Vehicles not listed here can't be viewed |
| `Config.OfficerStatus.Default` | 'active' | Status an officer starts a shift on |
| `Config.VehicleInsurance` / `Config.VehicleRegistration` / `Config.VehiclePoints` | — | Turn each vehicle column on or off. Disabled ones vanish from the grid entirely |
| `Config.CivilianAccess` | — | Civilian mode: profile and legislation view |
| `Config.Debug` | false | Debug logging |

## Preview
<img width="2445" height="1305" alt="Screenshot 2026-03-22 185605" src="https://github.com/user-attachments/assets/7f228a36-5d82-40ba-ade9-d9da78d249fd" />
<img width="2455" height="1310" alt="Screenshot 2026-03-22 185655" src="https://github.com/user-attachments/assets/e0291f16-efa6-4d86-b3ad-f82ccdb8deb3" />
<img width="2445" height="1316" alt="Screenshot 2026-03-22 185712" src="https://github.com/user-attachments/assets/f6c4bb93-c178-4b64-bb8c-3f38b7f09eba" />
<img width="2447" height="1306" alt="Screenshot 2026-03-22 185704" src="https://github.com/user-attachments/assets/d6dbba26-189c-427b-9e10-4c5c2d20056c" />
<img width="2431" height="1297" alt="Screenshot 2026-03-22 185726" src="https://github.com/user-attachments/assets/5ed25446-3706-4e35-8cc9-d18c265d1ed0" />


## Features

### Citizens
Look up any player. See their name, photo, gender, DOB, phone, fingerprint, job, vehicles, properties, arrest count, and linked reports. Edit licenses, add tags, upload photos, and take mugshots.

### Reports
Write incident reports with a rich text editor. Add suspects, victims, officers, charges, and evidence. Tag and restrict reports by department or rank. Two officers can write the same report at once and see each other's cursors live.

### Cases
Group related reports into investigations. Assign officers, set priority and status, attach files, track everything in one place.

### Evidence
Register evidence with type, serial, and location. Upload photos, track chain of custody, transfer between officers, link to cases and reports.

### Warrants
Issue warrants with expiry dates. Track felony/misdemeanor/infraction counts. Close them when served.

### BOLOs
Be On Lookout alerts for people and vehicles. Set status, share across departments.

### Vehicles
Search by plate, view registration and owner, manage DMV records and licence points. Insurance and registration checks hook into external resources, and each of those columns disappears from the grid entirely when you turn the feature off.

### Impound
Impound a vehicle from the MDT (only while it's sitting in a garage) or on the street with `/mdtimpound`. The on-site flow opens the same impound form the MDT uses, so an officer only ever learns one screen.

Every impound records the reason, officer, lot, fee, notes, and an optional photo link. Releasing doesn't wipe the record, so each vehicle keeps a full impound history. The fee grows with a daily storage charge that stops at a configurable cap, and a lot view lists everything currently held with its outstanding fees. Impounding a vehicle with an active BOLO resolves that BOLO automatically.

A vehicle can also be held for a set period — a fixed number of days, or until an officer says otherwise. Releasing it early is a separate permission, needs a reason, and is logged as an override. The on-site form warns the officer if the car is flagged stolen or has an open BOLO, shows the owner and how many times it's been impounded before, and spells out what the owner will actually end up paying once storage is counted.

The owner is e-mailed when their vehicle is impounded, when the fee is paid, and when it's released — they're rarely standing there when it happens, and often offline.

Vehicles nobody owns are a separate case: they're simply hauled away and the officer earns a small payout for keeping the streets clear, rate-limited by a cooldown and a per-shift cap.

### Weapons
Firearm registry with serial tracking and ownership history.

### Security Cameras
Place cameras around the map (23 prop models available). View feeds with pan, zoom, and FOV controls.

### Bodycams
Watch live feeds from on-duty officers.

### Dashcams
Live feeds from police vehicles, with per-model camera positions. Cars that haven't been configured are blocked server-side rather than showing a broken view.

### Map and Patrols
A live map of on-duty officers and police vehicles. Draw patrol zones, assign officers to them, and get entry and exit notifications. Dispatch calls show up on the same map, and units can be dragged onto a call to attach them.

### Officer Status
Officers set their own status (available, busy, on a call), which feeds the roster, the map, and dispatch.

### Radio
Push-to-talk from inside the MDT, so an officer can keep talking while typing a report. Detects pma-voice, SaltyChat, or YaCA automatically.

### Court and DOJ
A shared calendar for hearings and training, with per-category permissions and missed-hearing tracking. Reminders arrive as notifications even when the MDT is closed.

### Bulletin Board
Department noticeboard with per-job categories you can reorder, pin, and restrict.

### SOP
Standard operating procedures, grouped into categories, with acknowledgement tracking so you can see who has read what.

### FTO
Field training: assign trainees to training officers, record daily observation reports, and rate competencies.

### Civilian Mode
A cut-down MDT (profile and legislation only) that civilian resources can open — phone apps, courthouse scripts, and the like.

### Dashboard
Stats overview: reports this week vs last week, active units, job info.

### Dispatch
View and respond to dispatch calls. Hooks into ps-dispatch.

### Roster
All officers with duty status, callsign, and department. Supervisors assign callsigns from a grid that shows what's taken, reserved and free, rather than typing one and hoping.

### Leaderboard
Rankings by arrests, reports, and activity.

### Charges
Manage penal codes and charge definitions. Create, edit, and categorize charges by class (felony, misdemeanor, infraction) with configurable fines, jail time, and points.

### Awards
Recognize officers with department awards. Track commendations and achievements on officer profiles.

### Internal Affairs (IA)
File and manage internal affairs complaints against officers. Complaints are linked to the officer they name, so they actually reach that officer's profile, and the complainant is e-mailed whenever the status changes. Track complaint status through investigation stages (Open, Under Investigation, Investigated, Sustained, Exonerated, Unfounded, Closed). Includes a standalone complaint form accessible via `/complaint` command or export for civilian-facing resources. IA complaints appear in officer profiles under the IA History tab.

### PPR (Performance Planning & Review)
Create performance reviews for officers covering coachable moments, commendations, and developmental feedback. Supervisors can document incidents from cases, traffic stops, or any notable officer conduct. PPR records are tied to officer profiles and accessible from both the Personnel sidebar and the officer's profile PPR tab.

### Management
Admin panel for the department. Set permissions per rank, post bulletins, view audit logs, manage tags. There are 64 permissions you can assign per role, covering citizens, reports, cases, evidence, BOLOs, warrants, vehicles and impounds, weapons, charges, dispatch, cameras, bodycams, dashcams, patrols, the bulletin board, SOPs, FTO, the court calendar, and management access.

### Audit Trail
Every action gets logged. Who did what, when. Covers: logins, reports, cases, evidence, warrants, vehicles, weapons, charges, searches, dispatch, officers, sentencing, arrests, ICU. Each category toggles on/off from the settings page.

## Exports

For other resources to interact with the MDT.

### Client Exports

| Export | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `OpenMDT` | - | — | Opens the MDT interface for the current player |
| `CloseMDT` | - | — | Closes the MDT and restores player controls |
| `IsMDTOpen` | - | `boolean` | Returns whether the MDT is currently open |
| `IsLEOJob` | `jobName: string?` | `boolean` | Checks if a job is law enforcement. If no argument is passed, checks the current player's job |
| `isViewingCamera` | - | `boolean` | Returns whether the player is currently viewing a security camera feed |
| `openComplaint` | - | — | Opens the standalone IA complaint form (works outside the MDT, useful for civilian resources) |
| `openCivilianMDT` | - | — | Opens the MDT in civilian mode (profile + legislation view only). Use from phone apps, courthouse scripts, etc. |
| `impoundNearbyVehicle` | - | — | Runs the on-site impound on the vehicle the officer is in or standing next to. Hang this off a target or a keybind instead of the command |

### Server Exports

| Export | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `IsCidFelon` | `citizenid: string`, `cb: function?` | `boolean` | Checks if a citizen has any felony charges on record. Supports both callback and direct return |
| `registerWeapon` | `citizenid: string`, `weaponName: string`, `serial: string`, `info: string?` | - | Registers a weapon in the MDT firearms registry with ownership history |
| `GetCitizenPhoneNumber` | `citizenid: string` | `string?` | Returns a citizen's phone number |
| `isRequestVehicle` | `vehicleId: number` | `boolean` | **Deprecated.** Always returns `false`. Kept so v1 resources that call it don't error — impound state now lives in the `mdt_impound` table |

# 1of1 Servers - VPS & Dedicated Servers

[![1of1 Servers](https://github.com/user-attachments/assets/29e4ef8e-7b24-4821-a6ce-7c9e3c111fd1)](https://billing.1of1servers.com/aff.php?aff=1)

We are a VPS and dedicated server provider, specializing in strong gaming DDoS protection and 99.9% uptime.  

We host some of the biggest FiveM servers in the industry such as Prodigy RP, Smile RP, The Academy RP, and many more.  

---

### Features
- 6 Tbps DDoS Protection by Gcore or 477 Tbps by Magic Transit CloudFlare 
- 99.9% Network Uptime  
- NVMe SSD Storage  
- Unlimited Player Slots  
- Free transfer of files and setup  
- Free Windows licenses  
- Windows Remote Desktop  
- 24/7 Support with ~30 min average ticket response
