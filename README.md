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

## FAQ
- **How do I add charges to a criminal in an Incident?** - After finding and adding the criminal citizen to the incident, right-click in the space under the criminal's name and select "Add Charge".

![](https://i.imgur.com/WVEDLnJ.png)

- **My dispatch calls are not being populated?** - You have not started the dispatch resource before the mdt or renamed the dispatch resource name and not made the necessary changes in mdt to reflect that. 

- **How do i access the other police panels?** - Just add the names to your jobs.lua in the shared folder.

- **If there are 7 diffrent departments why is there only 5 active unit counters?** - The counters are catagorized from left to right City, County, State, EMS and DOJ, this was done to keep the UI clean and becasue most aren't going to use all 7 departments.

# Reskins
The below repos are direct forks of ps-mdt and have been edited to fit certain countries/look.

* [US](https://github.com/OK1ez/ps-mdt/tree/main) Different layout and different colors. 
* [UK](https://github.com/Harraa/ps-mdt)

## EchoRP MDT QBCore Edit (WIP)

EchoRP MDT Released by Flawws#9999 from Echo RP rewritten and restructured for QBCore. 
This is no longer a fork so we are able to open issues on this repo.
