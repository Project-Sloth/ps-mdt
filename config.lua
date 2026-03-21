Config = {}
ps = exports.ps_lib:init()

-- Basic Settings
Config.Debug = false -- Enable/disable debug mode (boolean)
Config.OnlyShowOnDuty = true -- Only allow the MDT to be opened when on duty (boolean)

-- Time and Date Settings
Config.DateTime = {
    GameTime = true, -- If set to true, the game time will be used instead of the server time (boolean)
    TimeFormat = '24', -- Format for displaying time ('24' or '12')
    DateFormat = "MM-DD-YYYY" -- Format for displaying date (string: "MM-DD-YYYY", "DD-MM-YYYY", or "YYYY-MM-DD")
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

-- Discord Webhook Settings
Config.Webhooks = {
    DutyLog = '', -- Discord webhook for clock in/out logging. Leave empty to disable.
    IncidentLog = '', -- Discord webhook for incident/report logging. Leave empty to disable.
}

-- Mugshot Settings
Config.UseCQCMugshot = true -- Trigger mugshot before jailing (boolean)

-- Fingerprint Settings
Config.FingerprintAutoFilled = false -- Auto-populate fingerprints on citizen profiles (if false, officers must manually add fingerprints)

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
    'doj',
    'lawyer',
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
    Dict = 'amb@world_human_tourist_map@male@base',
    Name = 'base',
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
    'dispatch_attach',
    'dispatch_route',
    -- Cameras & Bodycams
    'cameras_view',
    'bodycams_view',
    -- Notes
    'notes_edit_department',
    -- Roster
    'roster_manage_certifications',
    -- Management
    'management_permissions',
    'management_bulletins',
    'management_activity',
}

-- Bodycam Settings
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
