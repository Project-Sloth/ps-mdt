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