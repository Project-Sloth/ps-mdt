Config = {}
ps = exports.ps_lib:init()

-- Basic Settings
Config.Debug = false -- Enable/disable debug mode (boolean)
Config.OnlyShowOnDuty = true -- Only allow the MDT to be opened when on duty (boolean)

-- Civilian Access Settings
Config.CivilianAccess = {
    enabled = true,   -- Allow civilians to open the MDT (profile + legislation view only)
    command = true,   -- Allow /mdt command for civilians
    showWarrants = true, -- Show active warrants on civilian profile
    showBolos = true,    -- Show active BOLOs on civilian profile
}

-- Time and Date Settings
Config.DateTime = {
    GameTime = true, -- If set to true, the game time will be used instead of the server time (boolean)
    TimeFormat = '24', -- Format for displaying time ('24' or '12')
    DateFormat = "DD-MM-YYYY" -- Format for displaying date (string: "MM-DD-YYYY", "DD-MM-YYYY", or "YYYY-MM-DD")
}

-- Department data sharing
Config.Sharing = {
    -- Mutual Sharing (Bidirectional)
    -- All departments in this group can see each other's data
    Mutual = {
        types = {
            'reports',
            'bodycams',
            'evidence',
            'bolos',
            'warrants'
        },
        departments = {
            'lspd',
            'bcso',
            'sahp'
        }
    },

    -- One-Way Sharing (Unidirectional)
    -- Viewers can see target department data, but not vice versa
    OneWay = {
        { -- Example: FIB and GOV 
            viewers = {
                'fib',
                'gov'
            },
            targets = {
                'lspd',
                'bcso',
                'sahp'
            },
            types = {
                'reports',
                'bodycams',
                'evidence',
                'bolos',
                'warrants',
            }
        },
    },
}

-- Keybinds
Config.Keys = {
    -- https://docs.fivem.net/docs/game-references/controls/ | Default QWERTY
    OpenMDT = {
        enabled = true, -- Enable/disable keybind (boolean)
        key = 'F11', -- Key to open MDT (string)
    },
}

-- Commands
Config.Commands = {
    Open = {
        enabled = true, -- Enable/disable command (boolean)
        command = 'mdt', -- Command to open MDT (string)
    },
    MessageOfTheDay = {
        enabled = true, -- Enable/disable command (boolean)
        command = 'motd', -- Command to set message of the day (string)
    },
}

-- Dispatch Settings
Config.Dispatch = {
    Resource = 'ps-dispatch',
    FilterByJob = true,
}

-- Wolfknight Plate Reader Settings
Config.UseWolfknightRadar = true -- Enable/disable Wolfknight radar integration
Config.WolfknightNotifyTime = 5000 -- Duration (ms) for plate reader notifications
Config.PlateScanForDriversLicense = true -- Check driver's license on plate scan

-- Fingerprint Settings
Config.FingerprintAutoFilled = false -- Auto-populate fingerprints on citizen profiles (if false, officers must manually add fingerprints)

-- Fingerprint Scan Integration
Config.FingerprintScan = {
    enabled = true,                                         -- Enable fingerprint scan trigger from MDT
    officerEvent = 'police:client:showFingerprint',          -- Client event triggered on the officer
    suspectEvent = 'police:client:showFingerprint',          -- Client event triggered on the suspect
}

-- Fuel Resource Name
Config.Fuel = 'LegacyFuel' -- Fuel resource name for vehicle fuel management


-- Housing / Properties Integration
-- The MDT shows the properties a citizen owns on their profile. Every housing
-- resource stores this in a different table with different column names, so
-- pick the system you run below — or define a fully custom mapping.
--
-- To switch systems you normally ONLY change `Config.Housing.system`.
Config.Housing = {
    enabled = true,             -- false = hide the properties feature entirely (no housing DB queries are run)
    system  = 'qbx_properties', -- which preset below to use, or 'custom'

    -- Presets: ready-made schema mappings for popular housing resources.
    -- `columns` maps the MDT's internal fields to your table's real columns:
    --   owner      = column holding the owner's citizenid          (required)
    --   id         = column holding the property's unique id       (needed to open a single property)
    --   name       = column shown as the property name/label
    --   coords     = column holding coords as JSON (used for the "set waypoint" button; optional)
    --   keyholders = column holding keyholders as JSON array/object (optional)
    -- Set a column to nil if your system doesn't have it.
    --
    -- For TWO-TABLE systems (e.g. qb-houses), where the property definition and
    -- the ownership live in separate tables, add a `join` (see the qb_houses
    -- preset below for a complete example).
    Presets = {
        -- Qbox properties (default). This matches the table the MDT used before
        -- this option existed, so leaving it selected keeps the old behaviour.
        qbx_properties = {
            table = 'properties',
            columns = {
                owner      = 'owner',
                id         = 'id',
                name       = 'property_name',
                coords     = 'coords',
                keyholders = 'keyholders',
            },
        },

        -- Project Sloth Housing (ps-housing).
        -- ps-housing has no single coords column (it uses door_data), and the
        -- display name comes from `street`.
        ps_housing = {
            table = 'properties',
            columns = {
                owner      = 'owner_citizenid',
                id         = 'property_id',
                name       = 'street',
                coords     = 'door_data',
                keyholders = 'has_access',
            },
        },

        -- qb-houses (legacy QBCore). Two-table system: ownership lives in
        -- `player_houses`, the property definition (label + coords) lives in
        -- `houselocations`, linked by player_houses.house = houselocations.name.
        qb_houses = {
            table = 'player_houses',   -- ownership table
            columns = {
                owner      = 'citizenid',
                id         = 'id',
                name       = nil,      -- taken from the joined table (label)
                coords     = nil,      -- taken from the joined table (coords)
                keyholders = 'keyholders',
            },
            join = {
                table = 'houselocations',                 -- definitions table
                on    = { left = 'house', right = 'name' }, -- player_houses.house = houselocations.name
                columns = {                                -- pull these fields from the joined table instead
                    name   = 'label',
                    coords = 'coords',
                },
            },
        },

        -- Fully custom mapping. Set Config.Housing.system = 'custom' and edit
        -- the values below to match your housing resource's database.
        custom = {
            table = 'properties',
            columns = {
                owner      = 'owner',
                id         = 'id',
                name       = 'property_name',
                coords     = 'coords',
                keyholders = 'keyholders',
            },
            -- Uncomment and adjust for a two-table system:
            -- join = {
            --     table   = 'other_table',
            --     on      = { left = 'local_col', right = 'other_col' },
            --     columns = { name = 'label', coords = 'coords' },
            -- },
        },
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Vehicle MDT — License Points
-- ─────────────────────────────────────────────────────────────────────────────
-- "License points" are shown on a vehicle's MDT profile and (optionally) in the
-- vehicle list. Officers add them one at a time, or via quick presets, on the
-- vehicle detail view (requires the `vehicles_edit_dmv` permission).
Config.VehiclePoints = {
    enabled   = false, -- false = hide points everywhere (list column, profile, editor) and reject point writes
    visualMax = 12,   -- how many pips the points bar draws before showing a "+N" overflow badge
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Vehicle MDT — Insurance Integration
-- ─────────────────────────────────────────────────────────────────────────────
-- When enabled, a vehicle's STATUS (the pill shown top-right on the profile and
-- in the vehicle list) is driven LIVE by your insurance resource instead of being
-- set by hand — officers can no longer edit status/reason manually.
--
-- When DISABLED, the status simply defaults to "Valid" everywhere and NO insurance
-- lookups are performed.
--
-- The lookup is fully configurable so you can point it at whatever insurance script
-- you run. Example (m-Insurance), which uses a callback-style export:
--     exports['m-Insurance']:HasCarInsurance('ABC123', function(hasInsurance) ... end)
--
-- NOTE: lookups always FAIL OPEN — a missing resource/export, an error, or a
-- timeout is treated as "insured", so a broken insurance script can never wrongly
-- flag every vehicle as uninsured.
Config.VehicleInsurance = {
    enabled  = false,
    resource = 'm-Insurance',     -- resource that exposes the export
    export   = 'HasCarInsurance', -- export name to call

    -- How the export delivers its answer:
    --   callback = true  -> exports[resource]:export(plate, function(hasInsurance) end)
    --   callback = false -> local hasInsurance = exports[resource]:export(plate)
    callback = true,

    timeout  = 2000, -- ms to wait for a callback answer before failing open (treated as insured)

    -- Resolve insurance for EVERY row in the vehicle list? On large servers this is
    -- one lookup per vehicle. Set false to only resolve it on the detail view (the
    -- list then shows "Valid" until a vehicle is opened).
    resolveInList = true,

    -- How the insured/uninsured result maps onto the existing status/reason pill:
    insuredStatus   = 'valid',                -- status when the vehicle IS insured
    uninsuredStatus = 'uninsured',            -- status when it is NOT insured
    uninsuredReason = 'No active insurance',  -- reason text shown next to the pill
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Vehicle MDT — Registration Integration
-- ─────────────────────────────────────────────────────────────────────────────
-- A sibling of Config.VehicleInsurance. When enabled, a vehicle's REGISTRATION
-- (shown as its own Registered/Unregistered field on the profile + in the vehicle
-- list, and as a pill in the profile detail view) is resolved LIVE from a
-- configurable resource. When disabled, every vehicle simply reads "Registered"
-- and NO registration lookups are performed.
--
-- The lookup is fully configurable. Example (m-Insurance), which uses a
-- callback-style export:
--     exports['m-Insurance']:HasCarRegistration('ABC123', function(hasReg) ... end)
--
-- NOTE: lookups always FAIL OPEN — a missing resource/export, an error, or a
-- timeout is treated as "registered", so a broken script can never wrongly flag
-- every vehicle as unregistered.
Config.VehicleRegistration = {
    enabled  = false,
    resource = 'm-Insurance',        -- resource that exposes the export
    export   = 'HasCarRegistration', -- export name to call

    -- How the export delivers its answer:
    --   callback = true  -> exports[resource]:export(plate, function(hasReg) end)
    --   callback = false -> local hasReg = exports[resource]:export(plate)
    callback = true,

    timeout  = 2000, -- ms to wait for a callback answer before failing open (treated as registered)

    -- Resolve registration for EVERY row in the vehicle list? On large servers this
    -- is one lookup per vehicle. Set false to only resolve it on the detail view
    -- (the list then shows "Registered" until a vehicle is opened).
    resolveInList = true,

    -- Reason text shown next to the pill when a vehicle is NOT registered:
    unregisteredReason = 'No active registration',
}

-- Weapon Registration
Config.RegisterWeaponsAutomatically = true -- Auto-register weapons on purchase (ox_inventory and qb-inventory/qb-weapons)
Config.RegisterCreatedWeapons = false -- Also auto-register weapons on item creation (ox_inventory only)

-- Impound Locations (vector4: x, y, z, heading)
Config.ImpoundLocations = {
    [1] = vector4(409.09, -1623.37, 29.29, 232.07), -- LSPD Impound
    [2] = vector4(-436.42, 5982.29, 31.34, 136.0),  -- Paleto Impound
}

-- Job Settings
Config.PoliceJobType = "leo"
Config.PoliceJobs = {
    'lspd',
    'bcso',
    'sahp',
    'fib',
    'gov'
}

Config.DojJobType = "doj"
Config.DojJobs = {
    'lawyer',
    'judge',
}

Config.MedicalJobType = "ems"
Config.MedicalJobs = {
    'ambulance',
}

Config.Uploads = {
    MaxBytes = 5242880, -- 5 MB
    RateLimitPerMinute = 10, -- Max uploads per player per minute (0 = unlimited)
    AllowedAttachmentTypes = {
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
    },
    AllowedEvidenceImageTypes = {
        'image/jpeg',
        'image/png',
        'image/webp'
    }
}

-- Pagination Limits
Config.Pagination = {
    Citizens = 20, -- Citizens per page
    CitizenSearch = 20, -- Max citizen search results
    Cases = 20, -- Cases per page
    CitizenCharges = 2, -- Charges per page in the Citizen profile's Charges section
}

-- Fine Processing
Config.Fines = {
    MaxAmount = 100000,   -- Maximum fine amount ($) to prevent economy exploits
    CooldownMs = 30000,   -- Anti-spam cooldown between fines (milliseconds)
}

-- Warrant Defaults
Config.Warrants = {
    DefaultExpiryDays = 7, -- Default warrant expiry when no date is provided
}

-- Dashboard Cache TTLs (seconds)
Config.CacheTTL = {
    ReportStats = 30,
    ActiveUnits = 10,
    UsageMetrics = 60,
}

-- Tablet Animation
Config.Animation = {
    Dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
    Name = 'idle_a',
}

-- Mugshot Camera
Config.MugshotCamera = {
    DefaultFov = 50.0,
    FovMin = 15.0,
    FovMax = 80.0,
    FovSpeed = 5.0,
}

-- Security Camera Viewer
Config.CameraViewer = {
    RotationSpeed = 0.15,
    ZoomClamp = { min = 0.25, max = 10.0 },
    StartingZoom = 3.0,
    ZoomStep = 0.1,
    FovMin = 10.0,
    FovMax = 100.0,
    FovStep = 2.0,
    -- Yaw offset (degrees) applied to the *view* of cameras that spawn a real
    -- CCTV prop (player-placed ones). Those props face the opposite way from the
    -- camera's look direction, so the feed needs +180. Virtual cameras
    -- (spawns_model = false) are unaffected. Set to 0.0 if your prop models
    -- already look the right way.
    HeadingOffset = 180.0,
    -- On-screen CCTV overlay shown while viewing a camera
    Overlay = {
        enabled = true,
        showTimestamp = true,   -- real date/time (top right)
        recBlink = true,        -- blinking REC indicator (false = always on)
    },
}

-- ============================================================================
--  Dashcams (police vehicle cameras)
--  IMPORTANT: a vehicle only gets a working dashcam if its model is listed in
--  `Positions.models` below. Unconfigured vehicles still show in the camera
--  list, but opening them returns an error instead of a feed. There is no
--  `default` on purpose - this prevents every cop car from silently working.
--  Offsets are in the vehicle's local space: side = +right, forward = +front,
--  height = +up (metres), pitch = camera tilt (negative looks down). Rear
--  values are optional and fall back to the front values. Keys are spawn names.
-- ============================================================================
Config.Dashcam = {
    -- Only vehicles of this class are considered (18 = Emergency, same as the
    -- tracking system uses to identify police vehicles). Checked on the client.
    EmergencyClass = 18,
    -- How often (ms) the server pushes a unit's live position to dashcam
    -- viewers. Lower = smoother for far-away units, but more network traffic.
    UpdateInterval = 250,
    Positions = {
        models = {
            ['police']  = { side = 0.0, forward = 0.75, height = 0.55, pitch = 1.0, rearForward = 1.2, rearHeight = 0.60, rearPitch = 1.0 },
            -- ['police2'] = { side = 0.0, forward = 1.1, height = 0.85, pitch = -6.0 },

            -- Example with a rear camera tuned separately:
            -- ['fbi2'] = { forward = 2.0, height = 0.9, pitch = -5.0, rearForward = 2.4, rearHeight = 0.8, rearPitch = -8.0 },
        },
    },
}

-- Management permissions and defaults (per job grade)
Config.ManagementPermissions = {
    -- Citizens
    'citizens_search',
    'citizens_edit_licenses',
    -- BOLOs
    'bolos_view',
    'bolos_create',
    -- Vehicles
    'vehicles_search',
    'vehicles_edit_dmv',
    -- Weapons
    'weapons_search',
    'weapons_add',
    -- Cases
    'cases_view',
    'cases_create',
    'cases_edit',
    'cases_delete',
    -- Evidence
    'evidence_view',
    'evidence_create',
    'evidence_transfer',
    'evidence_upload',
    -- Reports
    'reports_view',
    'reports_create',
    'reports_delete',
    -- Warrants
    'warrants_view',
    'warrants_issue',
    'warrants_close',
    -- Charges
    'charges_view',
    'charges_edit',
    -- Dispatch
    'map_patrols_view',
    "map_patrols_manage",
    "map_patrols_edit",
    'dispatch_attach',
    'dispatch_route',
    -- Cameras & Bodycams
    'cameras_view',
    'bodycams_view',
    'dashcams_view',
    -- Notes
    'notes_edit_department',
    -- Roster
    'roster_manage_certifications',
    'roster_manage_officers',
    -- PPR
    'ppr_view',
    'ppr_manage',
    -- FTO
    'fto_view',
    'fto_manage',
    -- BulletIn Board
    'bulletin_view',
    'bulletin_post',
    'bulletin_pin',
    -- Calendar (court hearings are court_*; trainings/meetings/other are training_*)
    'court_view',
    'court_create',
    'court_edit',
    'court_delete',
    'training_view',
    'training_create',
    'training_edit',
    'training_delete',
    -- Internal Affairs
    'ia_view',
    'ia_manage',
    -- SOP
    'sop_view',
    'sop_manage',
    -- Management
    'management_permissions',
    'management_bulletins',
    'management_activity',
    'management_tags',
    'management_tracking',
    'management_settings',
}

-- Bodycam Settings (override defaults if needed, remove to use built-in defaults)
Config.Bodycam = {
    DutyEvent = 'QBCore:Server:OnJobUpdate',
    DutyEventMode = 'qbcore',
    MultiJobDutyEvent = 'ps-multijob:server:dutyChanged',
    DutyResource = 'qb-core',
    MultiJobResource = 'ps-multijob',
}

-- Officer Status (Map tab) ---------------------------------------------------
-- Defines every selectable status. `id` is the stable key stored in the DB and
-- sent over the wire — never rename an existing id, only add new ones, or
-- officers who saved an old status will fall back to Default below.
-- `id`   : stable key (string, no spaces, lowercase recommended)
-- `label`: display name shown in the UI
-- `color`: hex used for the badge/dot and map marker ring
-- `icon` : optional emoji/short glyph shown next to the label (purely visual)
-- To add a new status, just append a new entry — no other file needs to change.
Config.OfficerStatus = {
    list = {
        { id = 'active', label = 'Active', color = '#22C55E', icon = '●' },
        { id = 'busy',   label = 'Busy',   color = '#F59E0B', icon = '●' },
        -- Examples for future statuses (uncomment / adjust as needed):
        -- { id = 'enroute',   label = 'En Route',   color = '#3B82F6', icon = '●' },
        -- { id = 'unavailable', label = 'Unavailable', color = '#EF4444', icon = '●' },
        -- { id = 'break',     label = 'On Break',    color = '#8B5CF6', icon = '●' },
    },
    -- Status id assumed for any officer who has never set one.
    Default = 'active',
    -- Max length for the optional free-text note (e.g. "Traffic Stop").
    MaxNoteLength = 60,
    -- Minimum ms between two status changes from the same player (anti-spam).
    ChangeCooldownMs = 1500,
}

-- Optional defaults for role permissions by job/grade
-- Example:
-- Config.PermissionDefaults = {
--     police = {
--         ['0'] = { 'access_reports' },
--         ['1'] = { 'access_reports', 'view_bodycams' },
--     }
-- }
Config.PermissionDefaults = Config.PermissionDefaults or {}

-- HIGHLY recommended not tuse this natively. Use FiveManage for this.
-- Activity Tracking - Controls which actions are logged to the audit trail
-- Categories can be toggled on/off from the Settings page in the MDT
-- These are the DEFAULT values; runtime changes are stored in the mdt_settings table
Config.AuditTracking = {
    authentication = true,   -- Login/logout events
    reports = true,          -- Report create, update, delete
    cases = true,            -- Case CRUD, officer assignments, attachments
    evidence = true,         -- Evidence CRUD, transfers, images
    warrants = true,         -- Warrant issued/closed
    vehicles = true,         -- Vehicle updates, impound/release
    weapons = true,          -- Weapon create, update, delete
    charges = true,          -- Fines processed, charges updated
    searches = false,        -- Citizen/player/officer searches (high volume)
    dispatch = true,         -- Signal 100 activate/deactivate
    officers = true,         -- Callsign changes
    sentencing = true,       -- Jail sentencing
    arrests = true,          -- Arrest logging
    icu = true,              -- ICU record deletion
    cameras = true,          -- Security camera access
    bodycams = true,         -- Officer bodycam access
}

-- Camera models available for static camera placement
Config.CameraModels = {
    ['security_cam_01'] = 'v_serv_securitycam_1a',
    ['security_cam_02'] = 'v_serv_securitycam_03',
    ['security_cam_03'] = 'ba_prop_battle_cctv_cam_01a',
    ['security_cam_04'] = 'prop_cctv_cam_06a',
    ['security_cam_05'] = 'ba_prop_battle_cctv_cam_01b',
    ['security_cam_06'] = 'prop_cctv_cam_01b',
    ['security_cam_07'] = 'ch_prop_ch_cctv_cam_02a',
    ['security_cam_08'] = 'prop_cctv_cam_04c',
    ['security_cam_09'] = 'prop_cctv_cam_03a',
    ['security_cam_10'] = 'ch_prop_ch_cctv_cam_01a',
    ['security_cam_11'] = 'prop_cctv_cam_01a',
    ['security_cam_12'] = 'prop_cctv_cam_05a',
    ['security_cam_13'] = 'prop_cctv_cam_07a',
    ['security_cam_14'] = 'prop_cctv_cam_04b',
    ['security_cam_15'] = 'tr_prop_tr_camhedz_cctv_01a',
    ['security_cam_16'] = 'prop_cctv_cam_02a',
    ['security_cam_17'] = 'prop_cctv_cam_04a',
    ['cctv_cam_01'] = 'm24_1_prop_m24_1_carrier_bank_cctv_02',
    ['cctv_cam_02'] = 'xm_prop_x17_cctv_01a',
    ['cctv_cam_03'] = 'prop_cctv_pole_02',
    ['cctv_cam_04'] = 'm24_1_prop_m24_1_carrier_bank_cctv_01',
    ['cctv_cam_05'] = 'prop_cctv_pole_04',
    ['cctv_cam_06'] = 'xm_prop_x17_server_farm_cctv_01',
    ['cctv_cam_07'] = 'prop_cctv_pole_03',
    ['cctv_cam_08'] = 'p_cctv_s',
    ['cctv_cam_09'] = 'hei_prop_bank_cctv_02',
}

-- ============================================================================
--  Static Camera Placer (admin tool)
--  Opens an in-game menu to create / edit / reposition / delete static
--  security cameras using a 3D gizmo. The entry command is registered through
--  ox_lib's lib.addCommand, whose `restricted` field handles the admin gating
--  server-side (it auto-creates the `command.<name>` ace).
-- ============================================================================
Config.CameraPlacer = {
    command = 'cameraplacer',  -- Chat command that opens the placer menu
    restricted = 'group.admin', -- ox_lib restricted group/ace allowed to use it
}

-- Which Weapons should be allowed to be registered manually
Config.Weapons = {
    { model = "weapon_heavypistol", label = "Heavy Pistol" },
    { model = "weapon_sniperrifle", label = "Hunting Rifle" },
    { model = "weapon_ceramicpistol", label = "Ceramic Pistol" },
    { model = "weapon_doubleaction", label = "Double-Action Revolver" },
    { model = "weapon_navyrevolver", label = "Navy Revolver" },
    { model = "weapon_musket", label = "Musket" },
}
-- ============================================================================
--  Court / Calendar (hearings, meetings, trainings)
--  Drives the DOJ calendar: reminder SMS, invite e-mails, automatic status
--  lifecycle and the attendee quick-add groups.
-- ============================================================================
Config.Court = {
    -- How many minutes before a hearing the reminder SMS goes out.
    ReminderLeadMinutes = 15,

    -- ---- lb-phone integration -------------------------------------------
    Phone = {
        Resource = 'lb-phone',                       -- set '' to disable all phone messaging
        SmsSenderNumber = 'SA-COURT',                -- "from" number shown on reminder SMS (any string lb-phone accepts)
        MailSender = 'San Andreas Judicial System',  -- sender shown in the recipient's inbox
    },

    -- ---- Reminder SMS (replaces the old MDT notify) ----------------------
    Sms = {
        enabled = true,
        SendDelayMs = 25,    -- ms between each send so big invite lists don't spike the frame
    },

    -- ---- Invite e-mail on create -----------------------------------------
    Email = {
        enabled = true,
        -- If a hearing is created with MORE attendees than this, the per-person
        -- e-mails are skipped entirely (they still get the reminder SMS). This
        -- prevents lag spikes on huge invite lists.
        MaxRecipients = 25,
        SendDelayMs = 50,    -- ms between each mail send
    },

    -- ---- Automatic status lifecycle --------------------------------------
    AutoStatus = {
        enabled = true,
        -- scheduled  -> in_session  once scheduled_at is reached
        -- in_session -> completed   once scheduled_at + duration + grace passed
        CompleteGraceMinutes = 5,
        -- true  = a completed hearing is deleted (calendar self-cleans)
        -- false = a completed hearing is kept with status 'completed'
        DeleteOnComplete = true,
    },

    -- ---- Attendee quick-add groups (buttons in the create/edit modal) ----
    -- id:         stable identifier
    -- label:      button text
    -- role:       attendee role the bulk-added people get (see VALID_ROLES)
    -- domain:     'police' (police + DOJ share a calendar) or 'ems' (separate)
    -- jobType:    match against the framework job.type (leo / doj / ems ...)
    -- jobs:       optional explicit job-name whitelist (overrides jobType)
    -- maxGrade:   optional grade-level ceiling (e.g. rookies = grade 0-1)
    -- onlyOnDuty: only include players currently on duty
    Groups = {
        -- Police / DOJ domain
        { id = 'all_officers', label = 'All Officers',  role = 'officer',  domain = 'police', jobType = Config.PoliceJobType },
        { id = 'rookies',      label = 'Rookies',       role = 'officer',  domain = 'police', jobType = Config.PoliceJobType, maxGrade = 1 },
        { id = 'on_duty',      label = 'On-Duty Units', role = 'officer',  domain = 'police', jobType = Config.PoliceJobType, onlyOnDuty = true },
        { id = 'all_doj',      label = 'All DOJ',       role = 'attendee', domain = 'police', jobType = Config.DojJobType },
        { id = 'judges',       label = 'Judges',        role = 'judge',    domain = 'police', jobs = { 'judge' } },
        { id = 'lawyers',      label = 'Lawyers',       role = 'attendee', domain = 'police', jobs = { 'lawyer' } },

        -- EMS domain (separate calendar)
        { id = 'all_ems',       label = 'All EMS',        role = 'attendee', domain = 'ems', jobType = Config.MedicalJobType },
        { id = 'ems_rookies',   label = 'EMS Rookies',    role = 'trainee',  domain = 'ems', jobType = Config.MedicalJobType, maxGrade = 1 },
        { id = 'ems_on_duty',   label = 'On-Duty EMS',    role = 'attendee', domain = 'ems', jobType = Config.MedicalJobType, onlyOnDuty = true },
    },
}
-- ═══════════════════════════════════════════════════════════════════════════
--  Radio in MDT
--  Lets players push-to-talk on the radio while the MDT is open. Because the
--  MDT holds full NUI focus (keyboard goes to the UI, not the game), the UI
--  itself captures the PTT key and forwards it to the client, which drives the
--  active voice system. No extra RegisterKeyMapping is added — where possible
--  the player's EXISTING radio keybind is detected and reused.
-- ═══════════════════════════════════════════════════════════════════════════
Config.Radio = {
    Enabled = true,

    -- Which voice resource to drive:
    --   'auto'       → detect the first running one (order below in AutoDetect)
    --   'pma-voice' | 'saltychat' | 'yaca' → force a specific system
    VoiceSystem = 'auto',

    -- Fallback PTT key the MDT listens for IF the real keybind can't be read
    -- (browser KeyboardEvent value — a code like 'AltLeft'/'CapsLock' or a
    -- single character like 'n'). Pick a non-text key to avoid clashing with
    -- typing in reports. The real in-game radio key is auto-detected when
    -- possible and takes priority over this.
    PTTKey = 'AltLeft',

    -- Per-system trigger + which command's key to read for the NUI listener.
    --   type = 'command' → ExecuteCommand(start) / ExecuteCommand(stop)
    --   type = 'export'  → exports[resource][fn](state)
    -- `keyCmd` is the keymapping command whose bound key we read (nil = use the
    -- fallback PTTKey). `startCandidates` lets us match fork-renamed commands.
    Systems = {
        ['pma-voice'] = {
            type = 'command',
            start = '+radiotalk',
            stop = '-radiotalk',
            keyCmd = '+radiotalk',
            startCandidates = { '+radiotalk' },
        },
        ['saltychat'] = {
            type = 'command',
            start = '+primaryRadio',
            stop = '-primaryRadio',
            keyCmd = '+primaryRadio',
            -- SaltyChat forks name this differently; first registered wins.
            startCandidates = { '+primaryRadio', '+radioPrimary', '+SaltyChat_RadioPrimary' },
        },
        ['yaca'] = {
            type = 'export',
            resource = 'yaca-voice',
            fn = 'radioTalkingStart',
            -- YACA drives radio via an export; no stable command to read, so
            -- the NUI listens for the fallback PTTKey (set it to your YACA key).
            keyCmd = nil,
        },
    },

    -- 'auto' detection order: { system = key in Systems, resource = res name }.
    AutoDetect = {
        { system = 'pma-voice', resource = 'pma-voice' },
        { system = 'saltychat', resource = 'saltychat' },
        { system = 'yaca',      resource = 'yaca-voice' },
    },
}