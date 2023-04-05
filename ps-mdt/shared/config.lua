Config = Config or {}

Config.UsingDefaultQBApartments = true
Config.OnlyShowOnDuty = true
Config.UseCQCMugshot = true

-- Front, Back Side. Use 4 for both sides, we recommend leaving at 1 for default.
Config.MugPhotos = 1

-- Images for mug shots will be uploaded here. Add a Discord webhook. 
Config.Webhook = ''

-- Clock-in notifications for duty. Add a Discord webhook.
-- Command /mdtleaderboard, will display top players per clock-in hours.
Config.ClockinWebhook = ''

-- If set to true = Fine gets automatically removed from bank automatically charging the player.
-- If set to false = The fine gets sent as an Invoice to their phone and it us to the player to pay for it, can remain unpaid and ignored.
Config.BillVariation = true

-- Set up your inventory to automatically retrieve images when a weapon is registered at a weapon shop or self-registered.
-- If you're utilizing lj-inventory's latest version from GitHub, no further modifications are necessary. 
-- However, if you're using a different inventory system, please refer to the "Inventory Edit | Automatic Add Weapons with images" section in ps-mdt's README.
Config.InventoryForWeaponsImages = "lj-inventory"

-- "LegacyFuel", "lj-fuel", "ps-fuel"
Config.Fuel = "ps-fuel"

-- Google Docs Link
Config.sopLink = {
    ['police'] = '',
    ['ambulance'] = '',
    ['bcso'] = '',
    ['doj'] = '',
    ['sast'] = '',
    ['sasp'] = '',
    ['doc'] = '',
    ['lssd'] = '',
    ['sapr'] = '',
}

-- Google Docs Link
Config.RosterLink = {
    ['police'] = '',
    ['ambulance'] = '',
    ['bcso'] = '',
    ['doj'] = '',
    ['sast'] = '',
    ['sasp'] = '',
    ['doc'] = '',
    ['lssd'] = '',
    ['sapr'] = '',	
}

Config.PoliceJobs = {
    ['police'] = true,
    ['lspd'] = true,
    ['bcso'] = true,
    ['sast'] = true,
    ['sasp'] = true,
    ['doc'] = true,
    ['lssd'] = true,
    ['sapr'] = true,
    ['pa'] = true
}

Config.AmbulanceJobs = {
    ['ambulance'] = true,
    ['doctor'] = true
}

Config.DojJobs = {
    ['lawyer'] = true,
    ['judge'] = true
}

-- This is a workaround solution because the qb-menu present in qb-policejob fills in an impound location and sends it to the event. 
-- If the impound locations are modified in qb-policejob, the changes must also be implemented here to ensure consistency.

Config.ImpoundLocations = {
    [1] = vector4(436.68, -1007.42, 27.32, 180.0),
    [2] = vector4(-436.14, 5982.63, 31.34, 136.0),
}

-- Support for Wraith ARS 2X. 

Config.UseWolfknightRadar = false
Config.WolfknightNotifyTime = 5000 -- How long the notification displays for in milliseconds (30000 = 30 seconds)

-- IMPORTANT: To avoid making excessive database queries, modify this config to true 'CONFIG.use_sonorancad = true' setting in the configuration file located at 'wk_wars2x/config.lua'. 
-- Enabling this setting will limit plate checks to only those vehicles that have been used by a player.

Config.LogPerms = {
	['ambulance'] = {
		[4] = true,
	},
	['police'] = {
		[4] = true,
	},
    ['bcso'] = {
		[4] = true,
	},
    ['sast'] = {
		[4] = true,
	},
    ['sasp'] = {
		[4] = true,
	},
    ['sapr'] = {
		[4] = true,
	},
    ['doc'] = {
		[4] = true,
	},
    ['lssd'] = {
		[4] = true,
	},
}

Config.PenalCode = {
    [1] = {
        [1] = {title = 'Aggravated Trespass', class = 'Crime', id = 'S 69 of CJPOA', months = 10, fine = 1500, color = 'orange'},
        [2] = {title = 'Drunk and Disorderly', class = 'FINE', id = 'S 91(1) CJA', months = 0, fine = 500, color = 'green'},
        [3] = {title = 'Person acting in a anti-social manner.', class = 'Crime', id = 'S 50 PRA', months = 15, fine = 1600, color = 'orange'},
    },
    [2] = {
        [1] = {title = 'Actual Bodily Harm', class = 'Crime', id = 'S 47 OAPA', months = 20, fine = 2750, color = 'red'},
        [2] = {title = 'Assault with Intent to Resist Arrest', class = 'Crime', id = 'S 38 OAPA', months = 10, fine = 1500, color = 'orange'},
        [3] = {title = 'Common Assault', class = 'Crime', id = 'S 39 CJA', months = 15, fine = 2000, color = 'orange'},
        [4] = {title = 'Grevious Bodily Harm', class = 'Crime', id = 'S 20 OAPA', months = 25, fine = 3000, color = 'red'},
        [5] = {title = 'Grevious Bodily Harm with Intent', class = 'Crime', id = 'S 18 OAPA', months = 30, fine = 3250, color = 'red'},
        [6] = {title = 'Kidnapping', class = 'Crime', id = 'Common Law', months = 20, fine = 2750, color = 'red'},
        [7] = {title = 'Murder', class = 'Crime', id = 'Common Law', months = 120, fine = 10000, color = 'red'},
        [8] = {title = 'Threats to Kill', class = 'Crime', id = 'S 16 OAPA', months = 15, fine = 2500, color = 'orange'},
        
    },
    [3] = {
        [1] = {title = 'Arson', class = 'Crime', id = 'Section 1(3) Criminal Damage Act 1971', months = 15, fine = 1250, color = 'orange'},
        [2] = {title = 'Criminal Damage', class = 'Crime', id = 'Section 1(1) Criminal Damage Act 1971', months = 10, fine = 1000, color = 'green'},
        [3] = {title = 'Criminal Damage to Endanger Life', class = 'Crime', id = 'Section 1(2) Criminal Damage Act 1971', months = 20, fine = 2750, color = 'red'},
        [4] = {title = 'Possession with Intent to Damage', class = 'Crime', id = 'Section 3 Criminal Damage Act 1971', months = 15, fine = 1250, color = 'orange'},
        [5] = {title = 'Threats to Damage', class = 'Crime', id = 'Section 2 Criminal Damage Act 1971', months = 10, fine = 1000, color = 'green'},
    },
    [4] = {
        [1] = {title = 'Possession of Drugs', class = 'Crime', id = 'Section 5(2) Misuse of Drugs Act 1971', months = 15, fine = 1250, color = 'orange'},
        [2] = {title = 'Possession with Intent to Supply', class = 'Crime', id = 'Section 5(3) Misuse of Drugs Act 1971', months = 20, fine = 2750, color = 'red'},
        [3] = {title = 'Production of Controlled Substances Class B-A', class = 'Crime', id = 'Section 4(2) Misuse of Drugs Act 1971', months = 20, fine = 2750, color = 'red'},
        [4] = {title = 'Supplying of Drugs', class = 'Crime', id = 'Section 4(3) Misuse of Drugs Act 1971', months = 20, fine = 2750, color = 'red'},
        [5] = {title = 'Money Laundering Arrangement', class = 'Crime', id = 'Proceeds of Crime Act 2002', months = 20, fine = 2750, color = 'red'},
    },
    [5] = {
        [1] = {title = 'Carrying a firearm with criminal intent', class = 'Crime', id = 'Section 18 Firearms Act 1968', months = 25, fine = 3500, color = 'red'},
        [2] = {title = 'Carrying a firearm in a public place', class = 'Crime', id = 'Section 19 Firearms Act 1968', months = 18, fine = 2800, color = 'red'},
        [3] = {title = 'Possesing Section 1 Firearm without Certificate', class = 'Crime', id = 'Section 1 Firearms Act 1968', months = 10, fine = 1600, color = 'green'},
        [4] = {title = 'Possession of a firearm with intent to cause fear', class = 'Crime', id = 'Section 16A Firearms Act 1968', months = 15, fine = 2000, color = 'orange'},
        [5] = {title = 'Possesion of a firearm with intent to injure', class = 'Crime', id = 'Section 16 Firearms Act 1968', months = 25, fine = 3500, color = 'red'},
        [6] = {title = 'Possesion of Prohibited weapons (EXCLUDING SECTION 1)', class = 'Crime', id = 'Section 5 Firearms Act 1968', months = 20, fine = 3000, color = 'red'},
        [7] = {title = 'Trespassing with Firearm', class = 'Crime', id = 'Section 20 Firearms Act 1968', months = 18, fine = 2800, color = 'red'},
        [8] = {title = 'Use of firearm to resist arrest', class = 'Crime', id = 'Section 17(1) Firearms Act 1968', months = 30, fine = 4000, color = 'red'},

    },
    [6] = {
        [1] = {title = 'Assault on Police', class = 'Crime', id = 'Section 89 Police Act 1996', months = 20, fine = 3000, color = 'red'},
        [2] = {title = 'Assisting an Offender', class = 'Crime', id = 'Section 4(1) Criminal Law Act 1967', months = 15, fine = 2800, color = 'red'},
        [3] = {title = 'Breach of Peace', class = 'FINE', id = 'Common Law', months = 0, fine = 1000, color = 'green'},
        [4] = {title = 'Escape(Lawful Custody)', class = 'Crime', id = 'Common Law', months = 15, fine = 2800, color = 'red'},
        [5] = {title = 'Misconduct in a Public Office', class = 'Crime', id = 'Common Law', months = 5, fine = 1000, color = 'green'},
        [6] = {title = 'Obstruct Police', class = 'Crime', id = 'Section 89 Police Act 1996', months = 10, fine = 2000, color = 'orange'},
        [7] = {title = 'Trespass on a Protected Site', class = 'Crime', id = 'Section 128 Serious Organised Crime and Police Act', months = 15, fine = 2500, color = 'orange'},
        [8] = {title = 'Wasting Police Time', class = 'FINE', id = 'Section 5(2) Criminal Law Act 1967', months = 0, fine = 1000, color = 'green'},
    },
    [7] = {
        [1] = {title = 'Affray(Threats unlawful violence)', class = 'Crime', id = 'Section 3 Public Order Act 1986', months = 10, fine = 2000, color = 'orange'},
        [2] = {title = 'Aggrivated Trespass', class = 'Crime', id = 'Section 68 Criminal Justice and Public Order Act', months = 15, fine = 2500, color = 'orange'},
        [3] = {title = 'Fear and Provocation of Violence', class = 'Crime', id = 'Section 119 Criminal Justice and Immigration Act', months = 15, fine = 2500, color = 'orange'},
        [4] = {title = 'Harassment Alarm or Distress', class = 'Crime', id = 'Section 5 Public Order Act 1986', months = 15, fine = 2500, color = 'orange'},
        [5] = {title = 'Violence for Securing Entry', class = 'Crime', id = 'Section 6 Criminal Law Act 1977', months = 25, fine = 3500, color = 'red'},
        [6] = {title = 'Violet Disorder', class = 'Crime', id = 'Section 2 Public Order Act 1986', months = 20, fine = 3000, color = 'red'},
    },    
    [8] = {
        [1] = {title = 'Bomb Haux', class = 'Crime', id = 'Section 51 Criminal Law Act 1977', months = 25, fine = 3500, color = 'red'},
        [2] = {title = 'Terrorist Interpratation(Terrorist Act)', class = 'Crime', id = 'Section 1 Terrorism Act 2000', months = 30, fine = 4000, color = 'red'},
    },
    [9] = {
        [1] = {title = 'Aggravated Burglary', class = 'Crime', id = 'Section 10 Theft Act 1968', months = 20, fine = 2500, color = 'red'},
        [2] = {title = 'Burglary', class = 'Crime', id = 'Section 9 Theft Act 1968', months = 15, fine = 2000, color = 'red'},
        [3] = {title = 'Going Equipped to Steal', class = 'Crime', id = 'Section 25 Theft Act 1968', months = 10, fine = 1250, color = 'orange'},
        [4] = {title = 'Handling Stolen Goods(Possession)', class = 'Crime', id = 'Section 22 Theft Act 1968', months = 12, fine = 1750, color = 'orange'},
        [5] = {title = 'Robbery', class = 'Crime', id = 'Section 8(1) Theft Act 1968', months = 25, fine = 3500, color = 'red'},
        [6] = {title = 'Taking without Owners Consent', class = 'Crime', id = 'Section 12(1) Theft Act 1968', months = 15, fine = 2000, color = 'red'},
        [7] = {title = 'Theft', class = 'Crime', id = 'Section 9 Theft Act 1968', months = 15, fine = 2000, color = 'red'},
        [8] = {title = 'Vehicle Interference ', class = 'Crime', id = 'Section 9 Criminal Attempts Act 1981', months = 10, fine = 1500, color = 'orange'},
    },
    [10] = {
        [1] = {title = 'Aggrivated Vehicle Taking', class = 'Crime', id = 'Section 12a Theft Act 1968', months = 20, fine = 2500, color = 'red'},
        [2] = {title = 'Causing Danger to Road Users', class = 'Crime', id = 'Section 22A Road Traffic Act 1988', months = 10, fine = 1000, color = 'orange'},
        [3] = {title = 'Dangerous Driving(Includes Speeding)', class = 'Crime', id = 'Section 2 Road Traffic Act 1988', months = 5, fine = 750, color = 'green'},
        [4] = {title = 'Death by Careless/Inconsiderate Driving', class = 'Crime', id = 'Section 2B Road Traffic Act 1988', months = 60, fine = 5000, color = 'red'},
        [5] = {title = 'Driving, or being in charge, when under the influence of drugs/alcohol', class = 'Crime', id = 'Section 5 Road Traffic Act 1988', months = 10, fine = 1000, color = 'orange'},
    },
    [11] = {
        [1] = {title = 'Offensive Weapons(Possession)', class = 'Crime', id = 'Section 1 Prevention of Crime Act 1953', months = 20, fine = 2500, color = 'red'},
        [2] = {title = 'Pointed and Bladed Articles in a Public Place', class = 'Crime', id = 'Section 139 Criminal Justice Act 1988', months = 15, fine = 2000, color = 'red'},
    }
}

Config.AllowedJobs = {}
for index, value in pairs(Config.PoliceJobs) do
    Config.AllowedJobs[index] = value
end
for index, value in pairs(Config.AmbulanceJobs) do
    Config.AllowedJobs[index] = value
end
for index, value in pairs(Config.DojJobs) do
    Config.AllowedJobs[index] = value
end

Config.ColorNames = {
    [0] = "Metallic Black",
    [1] = "Metallic Graphite Black",
    [2] = "Metallic Black Steel",
    [3] = "Metallic Dark Silver",
    [4] = "Metallic Silver",
    [5] = "Metallic Blue Silver",
    [6] = "Metallic Steel Gray",
    [7] = "Metallic Shadow Silver",
    [8] = "Metallic Stone Silver",
    [9] = "Metallic Midnight Silver",
    [10] = "Metallic Gun Metal",
    [11] = "Metallic Anthracite Grey",
    [12] = "Matte Black",
    [13] = "Matte Gray",
    [14] = "Matte Light Grey",
    [15] = "Util Black",
    [16] = "Util Black Poly",
    [17] = "Util Dark silver",
    [18] = "Util Silver",
    [19] = "Util Gun Metal",
    [20] = "Util Shadow Silver",
    [21] = "Worn Black",
    [22] = "Worn Graphite",
    [23] = "Worn Silver Grey",
    [24] = "Worn Silver",
    [25] = "Worn Blue Silver",
    [26] = "Worn Shadow Silver",
    [27] = "Metallic Red",
    [28] = "Metallic Torino Red",
    [29] = "Metallic Formula Red",
    [30] = "Metallic Blaze Red",
    [31] = "Metallic Graceful Red",
    [32] = "Metallic Garnet Red",
    [33] = "Metallic Desert Red",
    [34] = "Metallic Cabernet Red",
    [35] = "Metallic Candy Red",
    [36] = "Metallic Sunrise Orange",
    [37] = "Metallic Classic Gold",
    [38] = "Metallic Orange",
    [39] = "Matte Red",
    [40] = "Matte Dark Red",
    [41] = "Matte Orange",
    [42] = "Matte Yellow",
    [43] = "Util Red",
    [44] = "Util Bright Red",
    [45] = "Util Garnet Red",
    [46] = "Worn Red",
    [47] = "Worn Golden Red",
    [48] = "Worn Dark Red",
    [49] = "Metallic Dark Green",
    [50] = "Metallic Racing Green",
    [51] = "Metallic Sea Green",
    [52] = "Metallic Olive Green",
    [53] = "Metallic Green",
    [54] = "Metallic Gasoline Blue Green",
    [55] = "Matte Lime Green",
    [56] = "Util Dark Green",
    [57] = "Util Green",
    [58] = "Worn Dark Green",
    [59] = "Worn Green",
    [60] = "Worn Sea Wash",
    [61] = "Metallic Midnight Blue",
    [62] = "Metallic Dark Blue",
    [63] = "Metallic Saxony Blue",
    [64] = "Metallic Blue",
    [65] = "Metallic Mariner Blue",
    [66] = "Metallic Harbor Blue",
    [67] = "Metallic Diamond Blue",
    [68] = "Metallic Surf Blue",
    [69] = "Metallic Nautical Blue",
    [70] = "Metallic Bright Blue",
    [71] = "Metallic Purple Blue",
    [72] = "Metallic Spinnaker Blue",
    [73] = "Metallic Ultra Blue",
    [74] = "Metallic Bright Blue",
    [75] = "Util Dark Blue",
    [76] = "Util Midnight Blue",
    [77] = "Util Blue",
    [78] = "Util Sea Foam Blue",
    [79] = "Uil Lightning blue",
    [80] = "Util Maui Blue Poly",
    [81] = "Util Bright Blue",
    [82] = "Matte Dark Blue",
    [83] = "Matte Blue",
    [84] = "Matte Midnight Blue",
    [85] = "Worn Dark blue",
    [86] = "Worn Blue",
    [87] = "Worn Light blue",
    [88] = "Metallic Taxi Yellow",
    [89] = "Metallic Race Yellow",
    [90] = "Metallic Bronze",
    [91] = "Metallic Yellow Bird",
    [92] = "Metallic Lime",
    [93] = "Metallic Champagne",
    [94] = "Metallic Pueblo Beige",
    [95] = "Metallic Dark Ivory",
    [96] = "Metallic Choco Brown",
    [97] = "Metallic Golden Brown",
    [98] = "Metallic Light Brown",
    [99] = "Metallic Straw Beige",
    [100] = "Metallic Moss Brown",
    [101] = "Metallic Biston Brown",
    [102] = "Metallic Beechwood",
    [103] = "Metallic Dark Beechwood",
    [104] = "Metallic Choco Orange",
    [105] = "Metallic Beach Sand",
    [106] = "Metallic Sun Bleeched Sand",
    [107] = "Metallic Cream",
    [108] = "Util Brown",
    [109] = "Util Medium Brown",
    [110] = "Util Light Brown",
    [111] = "Metallic White",
    [112] = "Metallic Frost White",
    [113] = "Worn Honey Beige",
    [114] = "Worn Brown",
    [115] = "Worn Dark Brown",
    [116] = "Worn straw beige",
    [117] = "Brushed Steel",
    [118] = "Brushed Black steel",
    [119] = "Brushed Aluminium",
    [120] = "Chrome",
    [121] = "Worn Off White",
    [122] = "Util Off White",
    [123] = "Worn Orange",
    [124] = "Worn Light Orange",
    [125] = "Metallic Securicor Green",
    [126] = "Worn Taxi Yellow",
    [127] = "police car blue",
    [128] = "Matte Green",
    [129] = "Matte Brown",
    [130] = "Worn Orange",
    [131] = "Matte White",
    [132] = "Worn White",
    [133] = "Worn Olive Army Green",
    [134] = "Pure White",
    [135] = "Hot Pink",
    [136] = "Salmon pink",
    [137] = "Metallic Vermillion Pink",
    [138] = "Orange",
    [139] = "Green",
    [140] = "Blue",
    [141] = "Mettalic Black Blue",
    [142] = "Metallic Black Purple",
    [143] = "Metallic Black Red",
    [144] = "Hunter Green",
    [145] = "Metallic Purple",
    [146] = "Metaillic V Dark Blue",
    [147] = "MODSHOP BLACK1",
    [148] = "Matte Purple",
    [149] = "Matte Dark Purple",
    [150] = "Metallic Lava Red",
    [151] = "Matte Forest Green",
    [152] = "Matte Olive Drab",
    [153] = "Matte Desert Brown",
    [154] = "Matte Desert Tan",
    [155] = "Matte Foilage Green",
    [156] = "DEFAULT ALLOY COLOR",
    [157] = "Epsilon Blue",
    [158] = "Unknown",
}

Config.ColorInformation = {
    [0] = "black",
    [1] = "black",
    [2] = "black",
    [3] = "darksilver",
    [4] = "silver",
    [5] = "bluesilver",
    [6] = "silver",
    [7] = "darksilver",
    [8] = "silver",
    [9] = "bluesilver",
    [10] = "darksilver",
    [11] = "darksilver",
    [12] = "matteblack",
    [13] = "gray",
    [14] = "lightgray",
    [15] = "black",
    [16] = "black",
    [17] = "darksilver",
    [18] = "silver",
    [19] = "utilgunmetal",
    [20] = "silver",
    [21] = "black",
    [22] = "black",
    [23] = "darksilver",
    [24] = "silver",
    [25] = "bluesilver",
    [26] = "darksilver",
    [27] = "red",
    [28] = "torinored",
    [29] = "formulared",
    [30] = "blazered",
    [31] = "gracefulred",
    [32] = "garnetred",
    [33] = "desertred",
    [34] = "cabernetred",
    [35] = "candyred",
    [36] = "orange",
    [37] = "gold",
    [38] = "orange",
    [39] = "red",
    [40] = "mattedarkred",
    [41] = "orange",
    [42] = "matteyellow",
    [43] = "red",
    [44] = "brightred",
    [45] = "garnetred",
    [46] = "red",
    [47] = "red",
    [48] = "darkred",
    [49] = "darkgreen",
    [50] = "racingreen",
    [51] = "seagreen",
    [52] = "olivegreen",
    [53] = "green",
    [54] = "gasolinebluegreen",
    [55] = "mattelimegreen",
    [56] = "darkgreen",
    [57] = "green",
    [58] = "darkgreen",
    [59] = "green",
    [60] = "seawash",
    [61] = "midnightblue",
    [62] = "darkblue",
    [63] = "saxonyblue",
    [64] = "blue",
    [65] = "blue",
    [66] = "blue",
    [67] = "diamondblue",
    [68] = "blue",
    [69] = "blue",
    [70] = "brightblue",
    [71] = "purpleblue",
    [72] = "blue",
    [73] = "ultrablue",
    [74] = "brightblue",
    [75] = "darkblue",
    [76] = "midnightblue",
    [77] = "blue",
    [78] = "blue",
    [79] = "lightningblue",
    [80] = "blue",
    [81] = "brightblue",
    [82] = "mattedarkblue",
    [83] = "matteblue",
    [84] = "matteblue",
    [85] = "darkblue",
    [86] = "blue",
    [87] = "lightningblue",
    [88] = "yellow",
    [89] = "yellow",
    [90] = "bronze",
    [91] = "yellow",
    [92] = "lime",
    [93] = "champagne",
    [94] = "beige",
    [95] = "darkivory",
    [96] = "brown",
    [97] = "brown",
    [98] = "lightbrown",
    [99] = "beige",
    [100] = "brown",
    [101] = "brown",
    [102] = "beechwood",
    [103] = "beechwood",
    [104] = "chocoorange",
    [105] = "yellow",
    [106] = "yellow",
    [107] = "cream",
    [108] = "brown",
    [109] = "brown",
    [110] = "brown",
    [111] = "white",
    [112] = "white",
    [113] = "beige",
    [114] = "brown",
    [115] = "brown",
    [116] = "beige",
    [117] = "steel",
    [118] = "blacksteel",
    [119] = "aluminium",
    [120] = "chrome",
    [121] = "wornwhite",
    [122] = "offwhite",
    [123] = "orange",
    [124] = "lightorange",
    [125] = "green",
    [126] = "yellow",
    [127] = "blue",
    [128] = "green",
    [129] = "brown",
    [130] = "orange",
    [131] = "white",
    [132] = "white",
    [133] = "darkgreen",
    [134] = "white",
    [135] = "pink",
    [136] = "pink",
    [137] = "pink",
    [138] = "orange",
    [139] = "green",
    [140] = "blue",
    [141] = "blackblue",
    [142] = "blackpurple",
    [143] = "blackred",
    [144] = "darkgreen",
    [145] = "purple",
    [146] = "darkblue",
    [147] = "black",
    [148] = "purple",
    [149] = "darkpurple",
    [150] = "red",
    [151] = "darkgreen",
    [152] = "olivedrab",
    [153] = "brown",
    [154] = "tan",
    [155] = "green",
    [156] = "silver",
    [157] = "blue",
    [158] = "black",
}

Config.ClassList = {
    [0] = "Compact",
    [1] = "Sedan",
    [2] = "SUV",
    [3] = "Coupe",
    [4] = "Muscle",
    [5] = "Sport Classic",
    [6] = "Sport",
    [7] = "Super",
    [8] = "Motorbike",
    [9] = "Off-Road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Van",
    [13] = "Bike",
    [14] = "Boat",
    [15] = "Helicopter",
    [16] = "Plane",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Train"
}

function GetJobType(job)
	if Config.PoliceJobs[job] then
		return 'police'
	elseif Config.AmbulanceJobs[job] then
		return 'ambulance'
	elseif Config.DojJobs[job] then
		return 'doj'
	else
		return nil
	end
end
