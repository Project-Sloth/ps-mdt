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
| [screenshot-basic](https://github.com/citizenfx/screenshot-basic) | Mugshot capture |


Optional but HIGHLY RECOMMENDED:

| Resource | Why |
|----------|-----|
| [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch) | Dispatch integration |

## Installation

### 1. Import the database

Run `sql/qbcore.sql` against your FiveM database. This creates all the tables the MDT needs. Use phpMyAdmin, HeidiSQL, or whatever database tool you prefer.

### 2. Set your FiveManage API keys

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

### 3. Build the frontend

If you grabbed a release with `web/dist` already in it, skip this step. During beta, source code will not be released.

Otherwise:

```
cd resources/[qb]/ps-mdt/web
npm install
npm run build
```

### 4. Add to server.cfg

```
ensure ps_lib
ensure oxmysql
ensure ox_lib
ensure ps-mdt
```

ps-mdt has to start after its dependencies.

## Preview
<img width="2441" height="1152" alt="image" src="https://github.com/user-attachments/assets/bdfeefe5-6fa0-4629-85f5-73b49dbe6db1" />
<img width="2446" height="1151" alt="image" src="https://github.com/user-attachments/assets/8a77935e-dc8c-419a-b50c-0f00ac4c628b" />
<img width="2434" height="1153" alt="image" src="https://github.com/user-attachments/assets/285747e8-ba1c-4af4-b28a-6755f5743994" />

## Configuration

All config lives in `config.lua`.

### Jobs

Which jobs can access the MDT:

```lua
Config.PoliceJobType = "leo"
Config.PoliceJobs = { 'lspd', 'bcso', 'sahp', 'fib', 'gov' }

Config.DojJobType = "doj"
Config.DojJobs = { 'doj', 'lawyer' }

Config.MedicalJobType = "ems"
Config.MedicalJobs = { 'ambulance' }
```

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

### Discord webhooks

```lua
Config.Webhooks = {
    DutyLog = 'https://discord.com/api/webhooks/...',     -- clock in/out
    IncidentLog = 'https://discord.com/api/webhooks/...',  -- reports filed
}
```

Leave empty to disable.

### Impound locations

```lua
Config.ImpoundLocations = {
    [1] = vector4(409.09, -1623.37, 29.29, 232.07),  -- LSPD
    [2] = vector4(-436.42, 5982.29, 31.34, 136.0),   -- Paleto
}
```

### Other stuff worth changing

| Setting | Default | What it does |
|---------|---------|-------------|
| `Config.Fines.MaxAmount` | 100000 | Cap on fine amounts |
| `Config.Fines.CooldownMs` | 30000 | Cooldown between fines (ms) |
| `Config.Warrants.DefaultExpiryDays` | 7 | Days until a warrant expires |
| `Config.RegisterWeaponsAutomatically` | true | Auto-register weapons on purchase |
| `Config.RegisterCreatedWeapons` | false | Auto-register crafted weapons |
| `Config.UseWolfknightRadar` | true | Wolfknight plate reader integration |
| `Config.UseCQCMugshot` | true | CQC mugshot trigger |
| `Config.Fuel` | 'LegacyFuel' | Your fuel resource name |
| `Config.Debug` | false | Debug logging |

## Features

### Citizens
Look up any player. See their name, photo, gender, DOB, phone, fingerprint, job, vehicles, properties, arrest count, and linked reports. Edit licenses, add tags, upload photos, and take mugshots.

### Reports
Write incident reports with a rich text editor. Add suspects, victims, officers, charges, and evidence. Tag and restrict reports by department or rank.

### Cases
Group related reports into investigations. Assign officers, set priority and status, attach files, track everything in one place.

### Evidence
Register evidence with type, serial, and location. Upload photos, track chain of custody, transfer between officers, link to cases and reports.

### Warrants
Issue warrants with expiry dates. Track felony/misdemeanor/infraction counts. Close them when served.

### BOLOs
Be On Lookout alerts for people and vehicles. Set status, share across departments.

### Vehicles
Search by plate, view registration and owner, manage DMV records. Handle impounds with configurable lot locations.

### Weapons
Firearm registry with serial tracking and ownership history.

### Security Cameras
Place cameras around the map (23 prop models available). View feeds with pan, zoom, and FOV controls.

### Bodycams
Watch live feeds from on-duty officers.

### Dashboard
Stats overview: reports this week vs last week, active units, job info.

### Dispatch
View and respond to dispatch calls. Hooks into ps-dispatch.

### Roster
All officers with duty status, callsign, and department.

### Leaderboard
Rankings by arrests, reports, and activity.

### Management
Admin panel for the department. Set permissions per rank, post bulletins, view audit logs, manage tags. There are 25 permissions you can assign per role covering citizens, BOLOs, vehicles, weapons, cases, evidence, reports, warrants, charges, dispatch, cameras, bodycams, notes, and management access.

### Audit Trail
Every action gets logged. Who did what, when. Covers: logins, reports, cases, evidence, warrants, vehicles, weapons, charges, searches, dispatch, officers, sentencing, arrests, ICU. Each category toggles on/off from the settings page.

## Exports

For other resources to interact with the MDT:

```lua
exports['ps-mdt']:OpenMDT()
exports['ps-mdt']:CloseMDT()
exports['ps-mdt']:IsMDTOpen()            -- returns boolean
exports['ps-mdt']:IsLEOJob(jobName)      -- returns boolean
exports['ps-mdt']:isViewingCamera()      -- returns boolean
```
