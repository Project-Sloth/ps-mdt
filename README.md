# Project Sloth MDT

For all support questions, ask in our [Discord](https://www.discord.gg/projectsloth) support chat. Do not create issues if you need help. Issues are for bug reporting and new features only.

## Dependencies

- [QBCore](https://github.com/qbcore-framework/qb-core)
- [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qb-apartments](https://github.com/qbcore-framework/qb-apartments) | [Config](https://github.com/Project-Sloth/ps-mdt/blob/0ce2ab88d2ca7b0a49abfb3f7f8939d0769c7b73/shared/config.lua#L3) available to enable or disable. 

# Installation
* Download ZIP
* Drag and drop resource into your server files, make sure to remove -main in the folder name
* Run the attached SQL script (mdt.sql)
* Start resource through server.cfg
* Restart your server.

# Weapon Info Export

Adds server export for inserting weaponinfo records, that can be used elsewhere in your server, such as weapon purchase, to add information to the mdt. Below is the syntax for this, all arguments are strings.

```
exports['ps-mdt']:CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)
```
![image](https://user-images.githubusercontent.com/82112471/226144189-0cf7a87c-d9bc-4d1f-a9fb-6f14f92cb68b.png)

## Self Register Weapons
* Your citizens can self-register weapons found on their inventory. Event to trigger is below if you're using qb-target.
```
ps-mdt:client:selfregister
```

https://user-images.githubusercontent.com/82112471/226150422-0c4776f0-0927-4b07-a272-972dd1c20077.mp4

# Automatic Mugshot Pictures
![image](https://user-images.githubusercontent.com/82112471/226207146-086c5508-7e6f-4345-a157-3ec2fd588138.png)

## Setup for Automatic Mugshot
* Set Config.UseCQCMugshot to true, It is true by default. (Line 5 in Config.lua)
```lua
Config.UseCQCMugshot = true
```
* Choose what photos you want by changing this: (Line 8 in Config.lua)
```lua
-- Front, Back Side. Use 4 for both sides, we recommend leaving at 1 for default.
Config.MugPhotos = 1
```
* Create a Discord Webhook and paste it here: (Line 11 in Config.lua)
```lua
-- Images for mug shots will be uploaded here. Add a Discord webhook. 
Config.Webhook = ''
```

# Clock In/Out & Leaderboard
* Triggers when officers Toggle Duty from inside the mdt.
![image](https://user-images.githubusercontent.com/82112471/228130546-6366ed1e-f5a8-428c-8680-0c384d2cff52.png)
![image](https://user-images.githubusercontent.com/82112471/228330602-1a914461-5d61-4e12-80d4-154c8da3dee1.png)


# Jailing & Community Service
* If you're getting kicked for attempted exploit abuse when jailing. Located the follow event below on qb-policejob > server > main.lua

```lua
police:server:JailPlayer
```

* Then comment out around line [779](https://github.com/qbcore-framework/qb-policejob/blob/937499495aa73538710737c14bd1b26d233dd599/server/main.lua#L779) as seen below

```lua
-- if #(playerCoords - targetCoords) > 2.5 then return DropPlayer(src, "Attempted exploit abuse") end
```

# Inventory Edit | Automatic Add Weapons with images
* [lj-inventory](https://github.com/loljoshie/lj-inventory) will come already with the changes needed for this to work. 
* [qb-inventory](https://github.com/qbcore-framework/qb-inventory) follow instructions below. 

1. Edit the following event
```
RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
```
```
        elseif QBCore.Shared.SplitStr(shopType, "_")[1] == "Itemshop" then
            if Player.Functions.RemoveMoney("cash", price, "itemshop-bought-item") then
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                    itemData.info.quality = 100
                end
                local serial = itemData.info.serie
                local imageurl = ("https://cfx-nui-qb-inventory/html/images/%s.png"):format(itemData.name)
                local notes = "Purchased at Ammunation"
                local owner = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                local weapClass = 1
                local weapModel = QBCore.Shared.Items[itemData.name].label
                AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
                TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
                QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
                exports['ps-mdt']:CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)
                TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
            elseif bankBalance >= price then
                Player.Functions.RemoveMoney("bank", price, "itemshop-bought-item")
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                    itemData.info.quality = 100
                end
                local serial = itemData.info.serie
                local imageurl = ("https://cfx-nui-qb-inventory/html/images/%s.png"):format(itemData.name)
                local notes = "Purchased at Ammunation"
                local owner = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                local weapClass = 1
                local weapModel = QBCore.Shared.Items[itemData.name].label
                AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
                TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
                QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
				exports['ps-mdt']:CreateWeaponInfo(serial, imageurl, notes, owner, weapClass, weapModel)
                TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
            else
                QBCore.Functions.Notify(src, "You don't have enough cash..", "error")
            end
````

# Wolfknight Plate Reader & Radar Compatibility

Support for Wolfknight Radar & Plate Reader
https://github.com/WolfKnight98/wk_wars2x

Plate reader automatically locks and alerts Police if:

* Vehicle owner is Wanted
* Vehicle owner has no drivers licence
* Vehicle has a BOLO

**IMPORTANT:**

* Ensure you set "CONFIG.use_sonorancad = true" in wk_wars2x/config.lua

This reduces the plate reader events to player's vehicles and doesn't query the database for hundreds of NPC vehicles

### Video Demonstration
https://youtu.be/w9PAVc3ER_c

![image](https://i.imgur.com/KZPMHQX.png)
![image](https://i.imgur.com/OIIrAcb.png)
![image](https://i.imgur.com/6maboG3.png)
![image](https://i.imgur.com/DkhQxDq.png)

### Traffic Stop Radialmenu Alert

* When initiating a traffic stop allows you to notify your fellow officers of your location and provide details about the current location and stopped vehicle through the radial menu.


1. Add the following code right above `function READER:Main()` on `cl_plate_reader.lua`

```
local Vehicle = nil
local function GetFrontPlate()
	local data = {
		locked = READER.vars.cams["front"].locked,
		plate = READER.vars.cams["front"].plate,
		veh = Vehicle,
	}
	return data
end exports("GetFrontPlate", GetFrontPlate)
``` 

2. Add the following into `cl_plate_reader.lua` after `local veh = UTIL:GetVehicleInDirection( PLY.veh, start, offset )` on the function `function READER:Main()`
```
			if i == 1 then
				Vehicle = veh
			end
```

* Should look like this after completing the above steps.
![image](https://i.imgur.com/ryefT3n.png)

3. Add **ps-mdt:client:trafficStop** into the Radialmenu

* Preview:
![image](https://user-images.githubusercontent.com/82112471/230744641-72480046-966f-4145-a4a3-ad7fd329870c.png)

# Roster and SOPs Setup

* You need a Google Document / Sheet link that is viewable.

Paste the link you got in the config here:
```
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
```

# Preview
![image](https://user-images.githubusercontent.com/82112471/217596976-5147fefa-24e2-4b98-b167-4e151b8a9a8c.png)
![image](https://user-images.githubusercontent.com/82112471/217597024-2c1493fc-4439-4b56-abbd-f9149e987b9e.png)
![image](https://user-images.githubusercontent.com/82112471/217597103-c271720a-4c1b-4a13-8e17-a27727cb0e95.png)
![image](https://user-images.githubusercontent.com/82112471/217597192-f9a63728-d2d0-4dfe-bd8b-373df1f9e969.png)
![image](https://user-images.githubusercontent.com/82112471/217597248-85d2d074-7fcd-4a54-ac57-8d1103047bc0.png)
![image](https://user-images.githubusercontent.com/82112471/217597338-aefcaed1-db9e-4b17-be45-3e0a66416b63.png)
![image](https://user-images.githubusercontent.com/82112471/217597379-d936fb8e-e33a-4817-8997-16447158afb8.png)
![image](https://user-images.githubusercontent.com/82112471/217597433-cd24bd41-a515-4fac-a896-807494501c39.png)

# Multi Departments
* LSPD
![image](https://i.imgur.com/2HmsTa3.png)
* BCSO
![image](https://i.imgur.com/9WVU0Kz.png)
* SASP
![image](https://i.imgur.com/6tLNVkb.png)
* SAST
![image](https://i.imgur.com/G5b2vGU.png)
* SAPR
![image](https://i.imgur.com/cu1ZsfW.png)
* LSSD
![image](https://i.imgur.com/IsqZddu.png)
* DOC
![image](https://i.imgur.com/lFi4jDH.png)

# FAQ
- **How do I add charges to a criminal in an Incident?** - After finding and adding the criminal citizen to the incident, right-click in the space under the criminal's name and select "Add Charge".

![](https://i.imgur.com/WVEDLnJ.png)

- **My dispatch calls are not being populated?** - You have not started the dispatch resource before the mdt or renamed the dispatch resource name and not made the necessary changes in mdt to reflect that.

# Reskins
The below repos are direct forks of ps-mdt and have been edited to fit certain countries/look.

* [US](https://github.com/OK1ez/ps-mdt/tree/main) Different layout and different colors.
* [UK](https://github.com/Harraa/ps-mdt)

# Credits
* Originally Echo RP MDT released by [Flawws#999](https://github.com/FlawwsX/erp_mdt)
* [CQC-Scripting](https://github.com/CQC-Scripting) for their [cqc-mugshot](https://github.com/CQC-Scripting/cqc-mugshot)
* [JoeSzymkowicz](https://github.com/JoeSzymkowicz)
* [MonkeyWhisper](https://github.com/MonkeyWhisper)
* [Snipe](https://github.com/pushkart2) 
* [BackSH00TER](https://github.com/BackSH00TER)
* [nggcasey](https://github.com/nggcasey)
* [OK1ez](https://github.com/OK1ez) 
* [Crayons0814](https://github.com/Crayons0814) 
* [LeSiiN](https://github.com/LeSiiN)
* [ImXirvin](https://github.com/ImXirvin)
* [lenzh](https://github.com/lenzh)
* Everyone else that we may have missed, thank you! 
