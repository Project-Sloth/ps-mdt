# Project Sloth MDT

For all support questions, ask in our [Discord](https://www.discord.gg/projectsloth) support chat. Do not create issues if you need help. Issues are for bug reporting and new features only.

## Dependencies

- [QBCore](https://github.com/qbcore-framework/qb-core)
- [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch) [If you intend to use it, make sure this starts before the mdt!]
- [oxmysql](https://github.com/overextended/oxmysql)

# Installation
* Download ZIP
* Drag and drop resource into your server files, make sure to remove -main in the folder name
* Run the attached SQL script (mdt.sql)
* Start resource through server.cfg
* Restart your server.

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

## Wolfknight Plate Reader & Radar Compatibility

Support for Wolfknight Radar & Plate Reader
https://github.com/WolfKnight98/wk_wars2x

Plate reader automatically locks and alerts Police if:

* Vehicle owner is Wanted
* Vehicle owner has no drivers licence
* Vehicle has a BOLO

**IMPORTANT:**

* Ensure you set "CONFIG.use_sonorancad = true" in wk_wars2x/config.lua

This reduces the plate reader events to player's vehicles and doesn't query the database for hundreds of NPC vehicles

**Video Demonstration**
https://youtu.be/w9PAVc3ER_c

![image](https://i.imgur.com/KZPMHQX.png)
![image](https://i.imgur.com/OIIrAcb.png)
![image](https://i.imgur.com/6maboG3.png)
![image](https://i.imgur.com/DkhQxDq.png)

## FAQ
- **How do I add charges to a criminal in an Incident?** - After finding and adding the criminal citizen to the incident, right-click in the space under the criminal's name and select "Add Charge".

![](https://i.imgur.com/WVEDLnJ.png)

- **My dispatch calls are not being populated?** - You have not started the dispatch resource before the mdt or renamed the dispatch resource name and not made the necessary changes in mdt to reflect that.

# Reskins
The below repos are direct forks of ps-mdt and have been edited to fit certain countries/look.

* [US](https://github.com/OK1ez/ps-mdt/tree/main) Different layout and different colors.
* [UK](https://github.com/Harraa/ps-mdt)

## EchoRP MDT QBCore Edit (WIP)

EchoRP MDT Released by Flawws#9999 from Echo RP rewritten and restructured for QBCore.
This is no longer a fork so we are able to open issues on this repo.
