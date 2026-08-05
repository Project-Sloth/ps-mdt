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

    -- Let citizens see and settle the impound fees on their OWN vehicles.
    -- Paying the release fee is paperwork, not police work: an officer had to be
    -- present to take the money, which meant a citizen with an impounded car had to
    -- find one and ask them to press a button. This lets them pay it themselves.
    -- The vehicle still isn't released until an officer releases it — this only
    -- settles the bill.
    payImpounds = true,
}

-- Time and Date Settings
Config.DateTime = {
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
            'police',
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
                'police',
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
    Status = {
        enabled = true, -- Enable/disable command (boolean)
        command = 'mdtstatus', -- /mdtstatus <id> [note...] (string)
        -- No RegisterKeyMapping on purpose (it would add one entry per status
        -- to everyone's GTA key-binding settings). Players who want a status
        -- on a key bind it themselves via the F8 console, e.g.:
        --   bind keyboard F5 "mdtstatus enroute"
        --   bind keyboard F6 "mdtstatus onscene"
        --   bind keyboard F7 "mdtstatus active"
        -- (Run once; FiveM persists binds. `unbind keyboard F5` removes it.)
    },
}

-- Dispatch Settings
Config.Dispatch = {
    -- Which dispatch resource feeds the MDT. Supported providers:
    --   'ps' → ps-dispatch   'qs' → qs-dispatch   'cd' → cd_dispatch
    -- 'auto' picks whichever of those three is currently running.
    Provider = 'auto',
    FilterByJob = true,
}

-- 10-codes offered in the "Create Call" modal. `code` shows in the dropdown,
-- `label` is the human name (also used as the call title if none is typed).
Config.DispatchCodes = {
    { code = '10-13', label = 'Officer Needs Assistance' },
    { code = '10-71', label = 'Shooting' },
    { code = '10-90', label = 'Robbery' },
    { code = '10-80', label = 'Pursuit' },
    { code = '10-15', label = 'Civil Disturbance' },
    { code = '10-52', label = 'Ambulance Needed' },
    { code = '10-53', label = 'Vehicle Accident' },
    { code = '10-66', label = 'Suspicious Activity' },
    { code = '10-11', label = 'Traffic Stop' },
    { code = '10-62', label = 'Meet Complainant' },
    { code = '911',   label = 'General 911 Call' },
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

-- Phone integration (single source of truth) ---------------------------------
-- One place for everything phone-related: resolving a citizen's number for the
-- MDT profile AND sending court reminder SMS / invite e-mails. Point this at your
-- phone resource once and both features use it, so they can never drift apart.
-- Leave Resource = '' to use charinfo.phone for display and disable court SMS/mail.
Config.Phone = {
    -- Which phone script does your server run? Set this one value:
    --
    --   'lb-phone'          lb-phone
    --   'jpr-phonesystem'   JPR Phone System
    --   'yseries'           YSeries (teamsgg)
    --   'none'              no phone script — court SMS and e-mails are off,
    --                       phone numbers come from the character's charinfo
    --   'custom'            something else — see the Custom block at the end
    --
    -- Nothing else needs changing to switch: how each script has to be called
    -- is handled in server/backend/phone.lua.
    Provider = 'lb-phone',

    -- Use the character's charinfo.phone when the phone script has no number
    -- for them. Leave this on — JPR Phone cannot look up another player's
    -- number at all, so with it off court SMS have no address to send to.
    UseCharinfoFallback = true,

    -- Shown as the sender on court messages.
    SmsSenderNumber = 'SA-COURT',                    -- "from" on reminder SMS
    MailSender      = 'San Andreas Judicial System', -- sender in the inbox

    -- Worth knowing per script:
    --   JPR Phone — its SMS export runs on the player's client, so reminder
    --     SMS only reach players who are ONLINE. Its e-mails do reach offline
    --     players, so keep Config.Court.Email enabled.
    --   YSeries — reminders arrive as a phone notification, which is
    --     addressed by server id and therefore reaches ONLINE players only;
    --     its e-mails reach everyone, so keep Config.Court.Email enabled.
    --     E-mails and number lookups need no setup.

    -- ── Only for Provider = 'custom' ─────────────────────────────────────────
    -- Everything above is enough for the built-in options. This is for a phone
    -- script that is not listed; leave it untouched otherwise. The field
    -- reference is at the top of server/backend/phone.lua, next to the
    -- built-in definitions you can copy from.
    Custom = {
        Resource = '',
        Number = { kind = 'none' },
        Sms    = { kind = 'none' },
        Mail   = { kind = 'none' },
    },
}


-- Callsigns
-- Officers pick a callsign from a grid rather than typing one, so the range has to be
-- defined somewhere. There is deliberately NO global fallback: a job with no range
-- configured is a configuration mistake, and the MDT says so instead of quietly
-- handing out numbers from a range nobody chose.
--
-- Lookup order for an officer:
--   1. Callsigns.Jobs[<job name>]      — e.g. 'lspd'
--   2. Callsigns.JobTypes[<job type>]  — e.g. 'leo'
--   3. nothing → the picker refuses and tells you which job is unconfigured
--
-- A Jobs entry replaces the JobTypes entry completely; it is not merged into it. If
-- one department needs its own block of numbers, spell that block out in full.
--
-- Per block:
--   Min, Max   (required) the pickable range
--   Pad        digits to pad to: 2 → 01..99, 3 → 001..999. 0 or omitted = no padding
--   Prefix     e.g. 'L-' gives L-01. Omitted = bare numbers
--   PageSize   boxes shown before "Load more" (default 20)
--   Reserved   restricted, not forbidden: only somebody with the
--              roster_callsign_reserved permission may hand these out
--   Blocked    forbidden outright. No permission unlocks a blocked callsign — it is
--              the config saying "this number does not exist". Use it for numbers the
--              radio uses, numbers you're holding back, or ones you never want issued.
--
-- Reserved and Blocked take a LIST of entries — single numbers and ranges:
--   Reserved = {
--       { n = 1, why = 'Chief of Police' },             -- one number
--       { from = 2, to = 5, why = 'Command staff' },    -- a range
--   }
--
-- The bracket form ([1] = 'Chief of Police') is NOT accepted, and that's deliberate.
-- In Lua a keyless entry IS index 1, so writing
--       { [1] = 'Chief of Police', { from = 2, to = 5, why = 'Command staff' } }
-- makes the range overwrite the Chief while the file is being read — the string is
-- gone before any code can see it, so it can't be detected, only prevented. The
-- resource therefore refuses the bracket form outright and tells you what to write.
Config.Callsigns = {
    JobTypes = {
        leo = {
            Min = 1,
            Max = 100,
            Pad = 2,
            Prefix = '1A',
            PageSize = 24,

            -- Restricted: needs roster_callsign_reserved.
            Reserved = {
                { n = 1, why = 'Chief of Police' },
                { from = 2, to = 5, why = 'Command staff' },
            },

            -- Forbidden: nobody, ever.
            Blocked = {
                -- { n = 99, why = 'Dispatch uses this on the radio' },
                { from = 90, to = 100, why = 'Held back for future units' },
            },
        },

        ems = {
            Min = 1,
            Max = 60,
            Pad = 2,
            Prefix = 'M-',
            PageSize = 24,
            Reserved = {
                { n = 1, why = 'Chief of Medicine' },
            },
            Blocked = {
                { from = 50, to = 60, why = 'Held back for future units' },
            },
        },

        doj = {
            Min = 1,
            Max = 30,
            Pad = 2,
            Prefix = 'DOJ-',
            PageSize = 24,
            Reserved = {
                { n = 1, why = 'Chief of Justice' },
            },
            Blocked = {
                { from = 2, to = 5, why = 'Held back for future units' },
            },
        },
    },

    -- Optional. Anything in here overrides the job type block entirely for that one job.
    Jobs = {
        -- bcso = {
        --     Min = 200,
        --     Max = 299,
        --     Pad = 3,
        --     Prefix = 'S-',
        --     PageSize = 24,
        --     Reserved = { { n = 200, why = 'Sheriff' } },
        --     Blocked  = { { from = 290, to = 299, why = 'Reserved for air units' } },
        -- },
    },
}


-- Internal Affairs
Config.IA = {
    -- Anti-spam: how long a citizen must wait between filing complaints.
    CooldownMs = 300000, -- 5 minutes

    -- E-mail the complainant when their complaint changes status. Uses the phone
    -- resource from Config.Phone; silently skipped if none is running.
    NotifyComplainant = true,
    MailSender = 'Internal Affairs',
}


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

        -- added by cheeseburger.apocalypse, thank u <3
        nolag_properties = {
            table = 'properties_owners',
            columns = {
                owner      = 'identifier',
                id         = 'property_id',
                name       = nil,
                coords     = nil,       -- disabled: metadata isn't a flat {x,y,z}, so "set waypoint" won't show
                keyholders = nil,
            },
            join = {
                table   = 'properties',
                on      = { left = 'property_id', right = 'id' },
                columns = {
                    name       = 'label',
                    keyholders = 'keyholders',
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
Config.RegisterWeaponsAutomatically = false -- Auto-register weapons on purchase (ox_inventory and qb-inventory/qb-weapons)
Config.RegisterCreatedWeapons = false -- Also auto-register weapons on item creation (ox_inventory only)

-- Weapon Image Path 
Config.WeaponImagePath = 'nui://ox_inventory/web/images/'
-- ─────────────────────────────────────────────────────────────────────────────
-- Impound
-- ─────────────────────────────────────────────────────────────────────────────
-- Releasing a vehicle puts it straight back into the owner's garage — they
-- retrieve it there like any other car. Lots are purely a record of WHERE the
-- vehicle is being held while impounded.
Config.Impound = {
    -- Master switch for the whole impound feature.
    --
    -- Off means off everywhere, not merely hidden: the on-site command is never
    -- registered, every server callback refuses, the tab and the dashboard tile
    -- disappear, the civilian view stops offering to settle fees, and the plate
    -- check drops its impound-history flag. A server that tows through another
    -- resource should not have a second half-wired impound system sitting
    -- behind a hidden button.
    --
    -- Existing records are left alone. Turning this back on brings the history
    -- back exactly as it was, and vehicles already held stay held — the state
    -- lives in mdt_impound and player_vehicles, not in this flag.
    Enabled = true,

    Lots = {
        { id = 'lspd',   label = 'LSPD Impound' },
        { id = 'paleto', label = 'Paleto Impound' },
    },

    -- Impound reasons offered in the MDT, each with a default fee (the officer
    -- can still edit the fee when impounding).
    -- `hold` is the duration id (see Durations below) that gets pre-selected when an
    -- officer picks this reason. It's a recommendation, not a rule: the officer can
    -- always change it before filing. Omit it and the reason falls back to
    -- DefaultDuration.
    Reasons = {
        { label = 'Evidence / Investigation', fee = 0,    hold = 'hold' },
        { label = 'Reckless Driving',         fee = 750,  hold = '1d' },
        { label = 'Illegal Parking',          fee = 250,  hold = 'immediate' },
        { label = 'Unregistered Vehicle',     fee = 500,  hold = 'immediate' },
        { label = 'Stolen Vehicle Recovery',  fee = 0,    hold = 'immediate' },
        { label = 'DUI',                      fee = 1500, hold = '3d' },
        { label = 'Illegal Modifications',    fee = 1000, hold = '1d' },
        { label = 'Abandoned Vehicle',        fee = 300,  hold = 'immediate' },
    },

    DefaultFee = 500,
    MaxFee     = 50000,
    -- Account the release fee is taken from ('bank' or 'cash').
    FeeAccount = 'bank',
    -- Require the fee to be paid before a vehicle can be released.
    RequireFeePaid = true,

    -- How long the vehicle is held before it may be released at all.
    --   days = 0    → releasable straight away
    --   days = n    → held for n days
    --   days = nil  → held until an officer decides otherwise
    -- The fee still has to be paid on top; the hold is about time, not money.
    Durations = {
        { id = 'immediate', label = 'Releasable immediately', days = 0 },
        { id = '1d',        label = '1 day',                  days = 1 },
        { id = '3d',        label = '3 days',                 days = 3 },
        { id = '7d',        label = '7 days',                 days = 7 },
        { id = 'hold',      label = 'Until an officer releases it' },
    },
    DefaultDuration = 'hold',

    -- Collecting the fee takes money out of a citizen's account. An officer pressing a
    -- button on the other side of the map to do that is a strange kind of power — no
    -- towing company on earth debits your account remotely.
    --
    -- So Collect becomes what it pretends to be: a payment taken at the counter, with
    -- both people standing there. The owner must be within this many metres of the
    -- officer. Citizens who aren't nearby can still settle the bill themselves in the
    -- civilian MDT (Config.CivilianAccess.payImpounds).
    --
    -- Set to 0 to disable the check and go back to collecting from any distance.
    CollectRange = 6.0,

    -- How many vehicles the lot view lists before the "Load more" button. A busy lot
    -- otherwise renders every held vehicle at once and the modal scrolls forever.
    LotPageSize = 10,

    -- E-mail the owner when their vehicle is impounded, charged, or released.
    -- The owner is usually nowhere near the vehicle when it happens, so an on-screen
    -- notification they never see is worse than useless. Uses Config.Phone.
    NotifyOwner = true,
    MailSender  = 'Vehicle Impound Unit',

    -- Storage fee: grows for every day the vehicle sits in the lot, capped so it
    -- can never run away. Computed from the impound date, never accumulated by a
    -- timer, so it survives restarts and can't drift.
    Storage = {
        PerDay  = 500,
        MaxDays = 7,    -- after this many days the storage fee stops growing
    },

    -- On-site impound: /impound takes the vehicle the officer is in, or the
    -- nearest one. Vehicles that nobody owns (NPC traffic) are simply removed and
    -- the officer gets a small payout for keeping the streets clear.
    OnSite = {
        Command   = 'mdtimpound',
        -- How far the officer may stand from the vehicle.
        MaxDistance = 6.0,

        -- The officer documents the vehicle, then radios it in. Both steps are
        -- cancellable: walking away aborts the impound and nothing is written.
        Sequence = {
            NotepadMs = 4500,   -- writing it up on the clipboard
            RadioMs   = 6000,   -- calling the tow truck in
        },

        -- Once the paperwork is done the vehicle fades out and is removed.
        FadeMs = 1500,

        Cleanup = {
            -- Payout for removing an unowned vehicle, randomised in this range.
            RewardMin   = 100,
            RewardMax   = 200,
            Account     = 'cash',
            -- Anti-abuse: seconds between payouts, and how many an officer can
            -- earn per shift (resets when they go off duty / the server restarts).
            -- everything is logged
            Cooldown    = 120,
            MaxPerShift = 20,
        },
    },
}

-- Job Settings
Config.PoliceJobType = "leo"
Config.PoliceJobs = {
    'police',
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

-- ── Plate checks (ANPR / radar) ──────────────────────────────────────────────
-- Lets a plate scanner ask the MDT what it knows about a plate, and pushes a
-- ps-dispatch alert to the scanning officer when something is worth stopping
-- for. Hook it up from your radar resource:
--
--     exports['ps-mdt']:PlateCheckAlert(source, plate, coords)  -- look up + alert
--     local res = exports['ps-mdt']:CheckPlate(plate)           -- look up only
--
-- The lookup works without ps-dispatch; only the alert is skipped then.
Config.PlateCheck = {
    -- Chat command for manual checks and testing. false disables it.
    command = 'checkplate',

    -- Job types allowed to run plate checks. CheckAuth (the MDT's general
    -- access gate) also accepts EMS and DOJ, which have no business querying
    -- plates — so this narrows it to police only by default. Add job types to
    -- widen it, or set to false to allow everyone CheckAuth accepts.
    allowedJobTypes = { Config.PoliceJobType },

    -- Write an entry to mdt_audit_logs so who ran which plate stays
    -- reviewable. Only scans that actually ALERT are logged: a continuous
    -- radar passes hundreds of plates a minute and logging each one would
    -- bury the interesting queries and out-write the rest of the MDT.
    audit = true,
    auditEveryScan = false, -- true: log every single scan (write-heavy)

    -- ── Built for continuous scanning ────────────────────────────────────
    -- Repeat lookups of the same plate are answered from memory for this
    -- long instead of hitting the database again. Concurrent lookups of one
    -- plate additionally share a single query.
    -- Rough sizing: one entry per distinct plate seen within cacheSeconds,
    -- shared across ALL officers. On a busy 500-slot server with 30 units
    -- scanning, 2000 is comfortable (a few hundred KB); raise cacheSeconds
    -- before raising the cap if the database is the bottleneck.
    cacheSeconds = 60,
    cacheMaxEntries = 2000,

    -- Do not alert the same officer about the same plate again within this
    -- many seconds. 0 disables the cooldown.
    alertCooldown = 120,

    -- Hard ceiling on plate alerts per officer per minute, so a street full
    -- of flagged cars stays readable. 0 disables the ceiling.
    maxAlertsPerMinute = 6,

    -- Which flags are looked for, and how urgent a hit is.
    -- 'critical' -> priority 1 alert (red card + urgent sound)
    -- 'warning'  -> routine alert
    checks = {
        bolo         = { enabled = true,  severity = 'critical' },
        stolen       = { enabled = true,  severity = 'critical' },
        warrants     = { enabled = true,  severity = 'critical' }, -- owner wanted
        -- Registered owner has no driver licence. Only an explicit `false` in
        -- their metadata counts — a missing entry is treated as unknown, not
        -- as unlicensed, so characters whose framework never wrote the key do
        -- not all light up. (Compare Config.PlateScanForDriversLicense, which
        -- does the same for the Wolfknight radar integration.)
        driverLicense = { enabled = true, severity = 'warning' },
        -- Impound HISTORY, not a yes/no: how often this vehicle has ended up
        -- in a lot. Below minCount it stays quiet (one impound says nothing),
        -- from criticalCount it counts as critical — as does a vehicle whose
        -- record says it is currently held, since it should not be driving.
        impounds     = { enabled = true,  severity = 'warning', minCount = 2, criticalCount = 5 },
        insurance    = { enabled = true,  severity = 'warning'  }, -- needs Config.VehicleInsurance
        registration = { enabled = true,  severity = 'warning'  }, -- needs Config.VehicleRegistration
        unregistered = { enabled = false, severity = 'warning'  }, -- plate has no vehicle record at all
    },

    alert = {
        enabled = true,
        -- Stay silent on clean plates. Leave this true unless the scanner is
        -- manually triggered: a ping on every passing car is noise within
        -- minutes, and officers stop reading the alerts entirely.
        silentWhenClean = true,
        code = '10-28',   -- shown on the alert card
        alertTime = 12,   -- seconds on screen
    },
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
    CitizenCharges = 5, -- Charges per page in the Citizen profile's Charges section
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

-- ---------------------------------------------------------------------------
-- Personnel data cleanup (Phase 1 core)
-- ---------------------------------------------------------------------------
-- When an officer is terminated, the boss panel can optionally wipe that
-- person's PERSONAL MDT footprint. The guiding rule: remove only data that
-- belongs to the individual (their own file/footprint) and that cannot harm
-- ongoing investigations or other officers' records.
--
-- DELETED (their own data): profile tags, sessions, identifiers, clock records,
--   gallery, officer status, SOP acknowledgements, their FTO trainee file,
--   PPRs written ABOUT them, messages they sent, patrol membership, and audit
--   log entries about them.
--
-- ALWAYS KEPT (investigative / shared / other officers): reports, charges,
--   evidence, BOLOs, cases, warrants, arrests, weapons, court records,
--   licenses, the core mdt_profiles identity row (kept so FK-cascaded
--   investigative rows like warrants are never removed), award/penal/SOP
--   definitions, and any record the person authored in SOMEONE ELSE'S file
--   (e.g. DORs they wrote as a trainer, PPRs they authored about others).
--
-- The cleanup engine schema-checks every table/column at runtime, so missing
-- or renamed tables are skipped instead of erroring. Toggle the optional parts:
Config.PersonnelCleanup = {
    -- Master switch: even if the boss ticks the box, cleanup only runs when this
    -- is true. Lets server owners disable the destructive path entirely.
    Enabled = true,

    -- Remove audit-log rows whose subject (entity_id) is the fired person.
    -- Their actions-as-actor logs are left intact for accountability unless you
    -- also enable DeleteActorAuditLogs below.
    DeleteSubjectAuditLogs = true,

    -- Also remove audit-log rows where the fired person was the ACTOR. Off by
    -- default because it erases "who did what" history other staff may rely on.
    DeleteActorAuditLogs = false,

    -- Remove messages the fired person sent.
    DeleteSentMessages = true,
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
    'dispatch_assign',
    'dispatch_notes',

    -- Impound
    'vehicle_impound',
    'vehicle_impound_release',
    'vehicle_impound_override',
    -- Cameras & Bodycams
    'cameras_view',
    'bodycams_view',
    'dashcams_view',
    -- Notes
    'notes_edit_department',
    -- Roster
    'roster_manage_certifications',
    'roster_manage_officers',
    'roster_callsign_reserved',
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
    -- Where the bodycam lens sits, relative to the officer (metres, in the
    -- ped's own local space: side = right, forward = ahead, height = up from
    -- the ped's feet). Separate values while seated, since a driver sits
    -- lower and closer to the windscreen than a standing officer.
    -- Remove the whole Position block to use the built-in defaults.
    Position = {
        onFoot  = { side = 0.0, forward = 0.12, height = 0.45, pitch = -8.0 },
        vehicle = { side = 0.0, forward = -0.02, height = 0.45, pitch = -4.0 },
    },

    -- Duty event wiring
    DutyEvent = 'QBCore:Server:OnJobUpdate',
    DutyEventMode = 'qbcore',
    MultiJobDutyEvent = 'ps-multijob:server:dutyChanged',
    DutyResource = 'qb-core',
    MultiJobResource = 'ps-multijob',

    -- Officers control their own bodycam. Turning it off is deliberately NOT blocked —
    -- it is recorded instead. Every change lands in mdt_bodycam_log with who, when and
    -- why, readable in the MDT. Accountability rather than a lock.
    Command = 'bodycam',

    -- Default for the "switch automatically with duty" preference in Settings, used
    -- until a player saves their own choice.
    AutoDutyDefault = true,

    -- Tell the officer when their bodycam changes state.
    NotifyOfficer = true,

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
    -- `dashboard` controls whether the status appears as a chip in the
    -- dashboard's dispatch breakdown widget. Officers in a hidden status
    -- still count toward the "online" total — only the chip is omitted.
    -- Omitting the key entirely counts as `dashboard = true`.
    list = {
        { id = 'active',      label = 'Available',        color = '#22C55E', icon = '●', dashboard = true },
        { id = 'busy',        label = 'Busy',             color = '#F59E0B', icon = '●', dashboard = true },
        { id = 'enroute',     label = 'En Route',         color = '#3B82F6', icon = '●', dashboard = false },
        { id = 'onscene',     label = 'On Scene',         color = '#06B6D4', icon = '●', dashboard = true },
        { id = 'break',       label = 'Meal Break',       color = '#8B5CF6', icon = '●', dashboard = false },
        { id = 'training',    label = 'Training',         color = '#0EA5E9', icon = '●', dashboard = false },
        { id = 'unavailable', label = 'Unavailable',      color = '#6B7280', icon = '●', dashboard = false },
    },
    -- Status id assumed for any officer who has never set one.
    Default = 'active',
    -- Max length for the optional free-text note (e.g. "Traffic Stop").
    MaxNoteLength = 30,
    -- Minimum ms between two status changes from the same player (anti-spam).
    ChangeCooldownMs = 1500,

    -- ── Automatic status from dispatch lifecycle ────────────────────────────
    -- Attach to a call        -> EnRouteStatus
    -- Arrive at call coords   -> OnSceneStatus
    -- Detach / call dismissed -> RevertStatus
    -- The automation NEVER fights the officer: it only replaces statuses
    -- listed in Overridable, and a manual status change while en route /
    -- on scene disengages the automation for that call entirely.
    Auto = {
        Enabled = true,
        EnRouteStatus = 'enroute',
        OnSceneStatus = 'onscene',
        RevertStatus  = 'active',
        -- Statuses the automation is allowed to replace on assignment.
        -- Deliberate away-states (break/training/unavailable) are preserved:
        -- assigning such an officer leaves their status untouched.
        Overridable = { 'active', 'busy', 'enroute', 'onscene' },
        -- Metres (2D) from the call coords that count as "arrived".
        OnSceneRadius = 100.0,
        -- Client proximity poll interval while en route (ms).
        ArrivalCheckMs = 5000,
        -- Failsafe: calls that are never closed/detached (e.g. provider call
        -- silently expired) auto-revert after this many minutes. 0 = disabled.
        MaxEngagementMinutes = 45,
    },
}

-- ---------------------------------------------------------------------------
--  Department policy permissions
-- ---------------------------------------------------------------------------
-- Permissions that come WITH A RANK, the way a department's own regulations
-- would grant them — not something a supervisor hands out in the Management
-- tab. In the MDT they show up ticked and locked, labelled "Department Policy".
--
-- Example:
-- Config.PermissionDefaults = {
--     police = {
--         ['0'] = { 'access_reports' },
--         ['1'] = { 'view_bodycams' },   -- sergeants and up, see Cumulative
--     }
-- }
Config.PermissionDefaults = Config.PermissionDefaults or {}

-- Ranks build on each other: a grade also gets everything the lower grades
-- are granted. In the example above a grade 1 officer holds BOTH
-- access_reports and view_bodycams, and grades you never list still inherit
-- from below instead of ending up with nothing.
-- Set to false if each grade should only get its own exact list.
Config.PermissionDefaultsCumulative = true

-- How policy interacts with what a boss configures in the Management tab:
--
--   'merge'          Policy always applies, on top of whatever is stored.
--                    Add a permission here and every matching rank has it
--                    immediately, including ranks saved months ago. Bosses
--                    grant EXTRA permissions on top; they cannot revoke
--                    policy ones. (Recommended, and what most people expect
--                    the word "defaults" to mean.)
--
--   'seed'           The old behaviour: policy only fills in a rank that has
--                    never been saved in the MDT. The first time a boss saves
--                    that rank — even without changing anything — this config
--                    stops affecting it for good.
--
--   'authoritative'  Policy is the only source. The Management tab becomes
--                    read-only in effect; for servers that manage permissions
--                    in this file exclusively.
Config.PermissionDefaultsMode = 'merge'

-- ---------------------------------------------------------------------------
--  Camera tampering
-- ---------------------------------------------------------------------------
-- Cameras can be shot out. Detection works off the shooter's last bullet impact
-- position rather than an entity, so it covers BOTH player-placed cameras (which spawn a
-- prop) and virtual cameras mapped onto existing world models, with one code path and no
-- dependency on any other resource.
--
-- Officers cannot toggle cameras from the MDT by design — a camera goes down because
-- someone put a bullet in it, and comes back on its own after a cooldown.
Config.CameraTamper = {
    Enabled = true,

    -- How close a bullet impact must land to count as a hit on the camera, in metres.
    -- Generous enough to feel fair, tight enough that stray rounds don't kill cameras.
    HitRadius = 2.0,

    -- How long a camera stays down after being shot.
    OfflineMs = 600000,   -- 10 minutes

    -- Only count impacts from actual firearms (melee/explosions ignored).
    RequireFirearm = true,

    -- Fire `ps-mdt:server:cameraTampered` so a server can route the alert into whatever
    -- dispatch it runs. The MDT itself doesn't call into another resource.
    EmitEvent = true,

    -- Client-side gap between two reported shots. CEventGunShot fires per round, so this
    -- keeps sustained automatic fire from reporting every single one. Short enough that a
    -- follow-up shot at a camera still counts.
    ReportCooldownMs = 250,

    -- Server-side throttle on impact reports, per player, as a second line of defence.
    ReportsPerWindow = 12,
    ReportWindowMs = 1000,
}

-- ---------------------------------------------------------------------------
--  Applications (civilian job applications)
-- ---------------------------------------------------------------------------
-- Civilians apply for a department in-game via a command. Each department has its own
-- command so the applicant lands straight on the right form. The QUESTIONS themselves
-- are NOT configured here — they're managed live in the MDT (Management → Applications),
-- so a department can change what it asks without a config edit or restart.
Config.Applications = {
    Enabled = true,

    -- One command per department. `id` must match the department id used everywhere else
    -- (the job name is the natural choice). `label` is the form's title. `description` is
    -- the chat autocomplete hint; omit it and it defaults to "Apply to <label>".
    Departments = {
        { id = 'police',    command = 'applypolice', label = 'LSPD Application', description = 'Apply to join the LSPD' },
        { id = 'ambulance', command = 'applyems',    label = 'EMS Application',  description = 'Apply to join EMS' },
        { id = 'doj',       command = 'applydoj',    label = 'DOJ Application',  description = 'Apply to join the DOJ' },
    },

    -- Anti-spam: how long a citizen must wait between submissions to the SAME department.
    CooldownMs = 300000,   -- 5 minutes

    -- Message the applicant on accept/reject (needs lb-phone or your mail bridge).
    NotifyOnDecision = true,

    -- Hard cap on a single answer's length, mirroring other free-text guards.
    MaxAnswerLength = 2000,
}

-- ---------------------------------------------------------------------------
--  Rate limiting
-- ---------------------------------------------------------------------------
-- A client can send NUI events as fast as it can generate them. These caps stop one
-- misbehaving client from flooding the database with records. They're deliberately
-- generous — a real officer writing quickly will never hit them — and apply per player,
-- per action. { max, windowMs }: at most `max` of that action per `windowMs`.
Config.RateLimits = {
    Enabled = true,

    createReport   = { max = 8,  windowMs = 20000 },
    createCase     = { max = 8,  windowMs = 20000 },
    createBolo     = { max = 10, windowMs = 20000 },
    createCharge   = { max = 15, windowMs = 20000 },
    createBulletin = { max = 10, windowMs = 20000 },
    sendMessage    = { max = 20, windowMs = 15000 },
}

-- ---------------------------------------------------------------------------
--  Department banking
-- ---------------------------------------------------------------------------
-- Fines and impound fees were taken off citizens and then simply ceased to exist.
-- That money should land somewhere: the department that collected it.
--
-- Every banking script has its own idea of how to be paid, so this doesn't pick one.
-- Choose a Method and fill in the block for it; if none of them fit, write Custom.
Config.DepartmentBanking = {
    Enabled = true,

    -- How the money gets in. 'export' | 'event' | 'custom' | 'none'
    Method = 'export',

    -- The account name is the job name by default (police -> 'police'). Use this only
    -- to override — e.g. to pour BCSO's takings into the same pot as the LSPD.
    Accounts = {
        -- ['bcso']      = 'police',
        -- ['sasp']      = 'police',
        -- ['ambulance'] = 'ems',
    },

    -- Where the money goes when the department can't be determined (an old impound
    -- record from before this existed, say). Leave nil to skip the deposit instead.
    Fallback = nil,

    -- Method = 'export'
    --   exports[resource][method](unpack(args))
    -- `args` is the call signature: the strings 'account', 'amount' and 'reason' are
    -- replaced with the real values, anything else is passed through as written. That
    -- covers scripts that want the arguments in a different order, or extra ones.
    Export = {
        resource = 'qb-banking',
        method   = 'AddMoney',
        args     = { 'account', 'amount', 'reason' },

        -- Renewed-Banking:
        --   resource = 'Renewed-Banking', method = 'addAccountMoney',
        --   args = { 'account', 'amount' }
        --
        -- okokBanking:
        --   resource = 'okokBanking', method = 'AddMoney',
        --   args = { 'account', 'amount' }
        --
        -- qb-management (older QBCore):
        --   resource = 'qb-management', method = 'AddMoney',
        --   args = { 'account', 'amount' }
        --
        -- esx_addonaccount is not an export — use Method = 'custom' below.
    },

    -- Method = 'event'  →  TriggerEvent(name, unpack(args))
    Event = {
        name = 'qb-banking:server:AddMoney',
        args = { 'account', 'amount', 'reason' },
    },

    -- Method = 'custom'
    -- The escape hatch: anything the two above can't express. Return true if the money
    -- actually landed — a false return is logged, not silently swallowed.
    ---@param account string  -- resolved account name, e.g. 'police'
    ---@param amount number
    ---@param reason string
    ---@return boolean
    Custom = function(account, amount, reason)
        -- ESX example:
        -- TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. account,
        --     function(acc) acc.addMoney(amount) end)
        -- return true
        return false
    end,
}

-- ---------------------------------------------------------------------------
--  Audit log retention
-- ---------------------------------------------------------------------------
-- The audit log grows with every report, search, impound and login, and nothing
-- ever removed rows from it. That's fine for a week and a problem after a year:
-- the Activity page runs a COUNT(*) over the whole table on every page load, and
-- InnoDB has no cached row count, so it gets slower in step with the table.
--
-- Keeping a bounded window fixes that at the root. Set Enabled = false if you'd
-- rather keep everything forever (or ship it off to FiveManage and prune there).
Config.AuditRetention = {
    Enabled = true,

    -- Anything older than this is deleted. 0 disables deletion entirely.
    Days = 90,

    -- How often the sweep runs. It also runs once shortly after startup.
    IntervalHours = 24,

    -- Rows deleted per statement. The sweep loops until it's done, yielding between
    -- batches, so the very first run on a huge table doesn't hold a long lock or
    -- stall the server thread.
    BatchSize = 2000,
}

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

    -- When a hearing created from a warrant is completed, auto-resolve the
    -- linked BOLO (matched on the warrant's reportId). Set false to opt out.
    ResolveBolosOnComplete = true,

    -- Default lead time (days) for hearings scheduled straight from a warrant
    -- via the "Schedule hearing" button in the warrants list.
    WarrantHearingLeadDays = 2,

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