CREATE TABLE IF NOT EXISTS `mdt_settings` (
  `key` varchar(100) NOT NULL,
  `value` longtext DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `mdt_settings` (`key`, `value`) VALUES
('jail_fines', '{"reductionOffers":[10,25,50],"maxFineAmount":100000}');

CREATE TABLE IF NOT EXISTS `mdt_bulletins` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `content` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profiles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `fullname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `callsign` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `badge_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rank` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profilepicture` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `certifications` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT NULL,
  `last_logout_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`),
  UNIQUE KEY `callsign` (`callsign`),
  KEY `badge_number` (`badge_number`),
  KEY `idx_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_messages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sender_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `receiver_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `receiver_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subject` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `read_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sender_citizenid` (`sender_citizenid`),
  KEY `receiver_citizenid` (`receiver_citizenid`),
  CONSTRAINT `FK_mdt_messages_sender` FOREIGN KEY (`sender_citizenid`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_messages_receiver` FOREIGN KEY (`receiver_citizenid`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_penal_codes` (
  `code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `charge_class` enum('felony','misdemeanor','infraction') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `months` int(10) unsigned NOT NULL DEFAULT 0,
  `fine` int(10) unsigned NOT NULL DEFAULT 0,
  `color` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`code`),
  KEY `label` (`label`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_permission_roles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `job` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `grade` int(10) unsigned NOT NULL,
  `permissions` json NOT NULL,
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_grade` (`job`,`grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `mdt_penal_codes` (`code`, `label`, `charge_class`, `months`, `fine`, `color`, `description`) VALUES
('P.C. 1001','Simple Assault','misdemeanor',7,500,'green','When a person intentionally or knowingly causes physical contact with another (without a weapon)'),
('P.C. 1002','Assault','misdemeanor',15,850,'orange','If a person intentionally or knowingly causes injury to another (without a weapon)'),
('P.C. 1003','Aggravated Assault','felony',20,1250,'orange','When a person unintentionally, and recklessly causes bodily injury to another as a result of a confrontation AND causes bodily injury'),
('P.C. 1004','Assault with a Deadly Weapon','felony',30,3750,'red','When a person intentionally, knowingly, or recklessly causes bodily injury to another person AND either causes serious bodily injury or uses or exhibits a deadly weapon'),
('P.C. 1005','Involuntary Manslaughter','felony',60,7500,'red','When a person unintentionally and recklessly causes the death of another'),
('P.C. 1006','Vehicular Manslaughter','felony',75,7500,'red','When a person unintentionally and recklessly causes the death of anther with a vehicle'),
('P.C. 1007','Attempted Murder of a Civilian','felony',50,7500,'red','When a non-government person intentionally attacks another with the intent to kill'),
('P.C. 1008','Second Degree Murder','felony',100,15000,'red','Any intentional killing that is not premeditated or planned. A situation in which the killer intends only to inflict serious bodily harm.'),
('P.C. 1009','Accessory to Second Degree Murder','felony',50,5000,'red','Being present and or participating in the act of parent charge'),
('P.C. 1010','First Degree Murder','felony',0,0,'red','Any intentional killing that is willful and premeditated with malice.'),
('P.C. 1011','Accessory to First Degree Murder','felony',0,0,'red','Being present and or participating in the act of parent charge'),
('P.C. 1012','Murder of a Public Servant or Peace Officer','felony',0,0,'red','Any intentional killing that is done to a government employee'),
('P.C. 1013','Attempted Murder of a Public Servant or Peace Officer','felony',65,10000,'red','Any attacks that are done to a government employee with the intent to cause death'),
('P.C. 1014','Accessory to the Murder of a Public Servant or Peace Officer','felony',0,0,'red','Being present and or participating in the act of parent charge'),
('P.C. 1015','Unlawful Imprisonment','misdemeanor',10,600,'green','The act of taking another against their will and holding them for an extended period of time'),
('P.C. 1016','Kidnapping','felony',15,900,'orange','The act of taking another against their will for a short period of time'),
('P.C. 1017','Accessory to Kidnapping','felony',7,450,'orange','Being present and or participating in the act of parent charge'),
('P.C. 1018','Attempted Kidnapping','felony',10,450,'orange','The act of trying to take someone against their will'),
('P.C. 1019','Hostage Taking','felony',20,1200,'orange','The act of taking another against their will for personal gain'),
('P.C. 1020','Accessory to Hostage Taking','felony',10,600,'orange','Being present and or participating in the act of parent charge'),
('P.C. 1021','Unlawful Imprisonment of a Public Servant or Peace Officer.','felony',25,4000,'orange','The act of taking a government employee against their will for an extended period of time'),
('P.C. 1022','Criminal Threats','misdemeanor',5,500,'orange','The act of stating the intent to commit a crime against another'),
('P.C. 1023','Reckless Endangerment','misdemeanor',10,1000,'orange','The act of disregarding safety of another which may place another in danger of death or bodily injury'),
('P.C. 1024','Gang Related Shooting','felony',30,2500,'red','The act in which a firearm is discharged in relation to gang activity'),
('P.C. 1025','Cannibalism','felony',0,0,'red','The act in which a persons consumes the flesh of another willingly'),
('P.C. 1026','Torture','felony',40,4500,'red','The act of causing harm to another to extract informaion and or for self enjoyment'),
('P.C. 2001','Petty Theft','infraction',0,250,'green','The theft of property below $50 amount'),
('P.C. 2002','Grand Theft','misdemeanor',10,600,'green','Theft of property above $700'),
('P.C. 2003','Grand Theft Auto A','felony',15,900,'green','The act of stealing a vehicle that belongs to someone else without permission'),
('P.C. 2004','Grand Theft Auto B','felony',35,3500,'green','The act of stealing a vehicle that belongs to someone else without permission while armed'),
('P.C. 2005','Carjacking','felony',30,2000,'orange','The act of someone forcefully taking a vehicle from its occupants'),
('P.C. 2006','Burglary','misdemeanor',10,500,'green','The act of entering into a building illegally with intent to commit a crime, especially theft.'),
('P.C. 2007','Robbery','felony',25,2000,'green','The action of taking property unlawfully from a person or place by force or threat of force.'),
('P.C. 2008','Accessory to Robbery','felony',12,1000,'green','Being present and or participating in the act of parent charge'),
('P.C. 2009','Attempted Robbery','felony',20,1000,'green','The action of attempting property unlawfully from a person or place by force or threat of force.'),
('P.C. 2010','Armed Robbery','felony',30,3000,'orange','The action of taking property unlawfully from a person or place by force or threat of force while armed.'),
('P.C. 2011','Accessory to Armed Robbery','felony',15,1500,'orange','Being present and or participating in the act of parent charge'),
('P.C. 2012','Attempted Armed Robbery','felony',25,1500,'orange','The action of attempting property unlawfully from a person or place by force or threat of force while armed.'),
('P.C. 2013','Grand Larceny','felony',45,7500,'orange','Theft of personal property having a value above a legally specified amount.'),
('P.C. 2014','Leaving Without Paying','infraction',0,500,'green','The act of leaving an establishment without paying for provided service'),
('P.C. 2015','Possession of Nonlegal Currency','misdemeanor',10,750,'green','Being in possession of stolen currency'),
('P.C. 2016','Possession of Government-Issued Items','misdemeanor',15,1000,'green','Being in possession of Items only acquireable by government employees'),
('P.C. 2017','Possession of Items Used in the Commission of a Crime','misdemeanor',10,500,'green','Being in possession of Items that were previously used to commit crimes'),
('P.C. 2018','Sale of Items Used in the Commission of a Crime','felony',15,1000,'orange','The act of selling items that were previously used to commit crimes'),
('P.C. 2019','Theft of an Aircraft','felony',20,1000,'green','The act of stealing an aircraft'),
('P.C. 3001','Impersonating','misdemeanor',15,1250,'green','The action of falsely identifying as another person to deceive'),
('P.C. 3002','Impersonating a Peace Officer or Public Servant','felony',25,2750,'green','The action of falsely identifying as a government employee to deceive'),
('P.C. 3003','Impersonating a Judge','felony',0,0,'green','The action of falsely identifying as a Judge to deceive'),
('P.C. 3004','Possession of Stolen Identification','misdemeanor',10,750,'green','To have another persons Identification without consent'),
('P.C. 3005','Possession of Stolen Government Identification','misdemeanor',20,2000,'green','To have the identification of a government employee without consent'),
('P.C. 3006','Extortion','felony',20,900,'orange','To threaten or cause harm to a person or property for financial gain'),
('P.C. 3007','Fraud','misdemeanor',10,450,'green','To deceive another for financial gain'),
('P.C. 3008','Forgery','misdemeanor',15,750,'green','To falsify legal documentation for personal gain'),
('P.C. 3009','Money Laundering','felony',0,0,'red','The processing stolen money for legal currency'),
('P.C. 4001','Trespassing','misdemeanor',10,450,'green','For a person to be within the bounds of a location of which they are not legally allowed'),
('P.C. 4002','Felony Trespassing','felony',15,1500,'green','For a person to have repeatedly entered the bounds of a location of which they are knowingly not legally allowed'),
('P.C. 4003','Arson','felony',15,1500,'orange','The use if fire and accelerants to will and maliciously destroy, harm or cause death to a person or property'),
('P.C. 4004','Vandalism','infraction',0,300,'green','The willful destruction of property'),
('P.C. 4005','Vandalism of Government Property','felony',20,1500,'green','The willful destruction of government property'),
('P.C. 4006','Littering','infraction',0,200,'green','The willful discard of refuse into to open and not in designated bin'),
('P.C. 5001','Bribery of a Government Official','felony',20,3500,'green','the use of money, favors and or property to gain favor with a government official'),
('P.C. 5002','Anti-Mask Law','infraction',0,750,'green','Wearing a mask in a prohibited zone'),
('P.C. 5003','Possession of Contraband in a Government Facility','felony',25,1000,'green','Being in possession of items that are illegal while within a government building'),
('P.C. 5004','Criminal Possession of Stolen Property','misdemeanor',10,500,'green','Being in possession of items stolen knowingly or not'),
('P.C. 5005','Escaping','felony',10,450,'green','The action of willful and knowingly leaving custody while legally being arrest, detained or in jail'),
('P.C. 5006','Jailbreak','felony',30,2500,'orange','The action of leaving state custody from a state or county detention facility'),
('P.C. 5007','Accessory to Jailbreak','felony',25,2000,'orange','Being present and or participating in the act of parent charge'),
('P.C. 5008','Attempted Jailbreak','felony',20,1500,'orange','The willful and intentional attempted escape from a state or county detention facility'),
('P.C. 5009','Perjury','felony',0,0,'green','The action of stating falsities while legally bound to speak the truth'),
('P.C. 5010','Violation of a Restraining Order','felony',20,2250,'green','The willful and knowing infringement upon court ordered protective documentation'),
('P.C. 5011','Embezzlement','felony',45,10000,'green','The willful and knowingly movement of funds from non personal bank accounts to personal bank accounts for personal gain'),
('P.C. 5012','Unlawful Practice','felony',15,1500,'orange','The action of performing a service without proper legal licensing and approval'),
('P.C. 5013','Misuse of Emergency Systems','infraction',0,600,'orange','Use of government emergency equipment for its non-intended purpose'),
('P.C. 5014','Conspiracy','misdemeanor',10,450,'green','The act of planning a crime but not yet commiting the crime'),
('P.C. 5015','Violating a Court Order','misdemeanor',0,0,'orange','The infringement of court ordered documentation'),
('P.C. 5016','Failure to Appear','misdemeanor',0,0,'orange','When someone who is legally bound to appear in court does not do so'),
('P.C. 5017','Contempt of Court','felony',0,0,'orange','The disruption of court proceedings in a courtroom while it is in session (judicial decision)'),
('P.C. 5018','Resisting Arrest','misdemeanor',5,300,'orange','The act of not allowing peace officers to take you into custody willingly'),
('P.C. 6001','Disobeying a Peace Officer','infraction',0,750,'green','The willful disregard of a lawful order'),
('P.C. 6002','Disorderly Conduct','infraction',0,250,'green','Acting in a manner that creates a hazardous or physically offensive condition by any act which serves no legitimate purpose of the actor. '),
('P.C. 6003','Disturbing the Peace','infraction',0,350,'green','Action in a manner that causes unrest and disrupts public order'),
('P.C. 6004','False Reporting','misdemeanor',10,750,'green','The act of reporting a crime that did not happen'),
('P.C. 6005','Harassment','misdemeanor',10,500,'orange','The repeated disruption or verbal attacks of another person'),
('P.C. 6006','Misdemeanor Obstruction of Justice','misdemeanor',10,500,'green','Acting in a way that hinders the process of Justice or lawful investigations'),
('P.C. 6007','Felony Obstruction of Justice','felony',15,900,'green','Acting in a way that hinders the process of Justice or lawful investigations while using violence'),
('P.C. 6008','Inciting a Riot','felony',25,1000,'orange','Causing civil unrest in a manner to incite a group to cause harm to people or property'),
('P.C. 6009','Loitering on Government Properties','infraction',0,500,'green','When someone is present in a government proper for an extended period of time'),
('P.C. 6010','Tampering','misdemeanor',10,500,'green','When someone willfully, knowingly and indirectly interfering with key points of a lawful investigation'),
('P.C. 6011','Vehicle Tampering','misdemeanor',15,750,'green','The willful and knowing interference the normal function of a vehicle'),
('P.C. 6012','Evidence Tampering','felony',20,1000,'green','The willful and knowing interference with evidence from a lawful investigation'),
('P.C. 6013','Witness Tampering','felony',0,0,'green','The willful and knowing coaching or coercing of a witness in a lawful investigation'),
('P.C. 6014','Failure to Provide Identification','misdemeanor',15,1500,'green','The act of not presenting identification when lawfully required to do so'),
('P.C. 6015','Vigilantism','felony',30,1500,'orange','The act of engaging in enforcing the law with legal authority to do so'),
('P.C. 6016','Unlawful Assembly','misdemeanor',10,750,'orange','when a large group gathers in a location that requires prior approval to do so'),
('P.C. 6017','Government Corruption','felony',0,0,'red','The act of using political position and power for self gain'),
('P.C. 6018','Stalking','felony',40,1500,'orange','When one person monitors another without their consent'),
('P.C. 6019','Aiding and Abetting','misdemeanor',15,450,'orange','To assist someone in committing or to encourage someone to commit a crime'),
('P.C. 6020','Harboring a Fugitive','misdemeanor',10,1000,'green','When someone willingly hides another who is wanted by the authorities'),
('P.C. 7001','Misdemeanor Possession of Marijuana','misdemeanor',5,250,'green','The possession of a quantity of marijuana in the amount of less the 4 blunts'),
('P.C. 7002','Felony manufacturing of Marijuana','felony',15,1000,'red','The possession of a quantity of marijuana that is from manufacturing'),
('P.C. 7003','Cultivation of Marijuana A','misdemeanor',10,750,'green','The possession of 4 or less marijuana plants'),
('P.C. 7004','Cultivation of Marijuana B','felony',30,1500,'orange','The possession of 5 or more marijuana plants'),
('P.C. 7005','Possession of Marijuana with Intent to Distribute','felony',30,3000,'orange','The possession of a quantity of Marijuana for distribution'),
('P.C. 7006','Misdemeanor Possession of Cocaine','misdemeanor',7,500,'green','The possession of cocaine in a small quantity usually for personal use'),
('P.C. 7007','Felony manufacturing Possession of Cocaine','felony',25,1500,'red','The possession of a quantity of cocaine that is from manufacturing'),
('P.C. 7008','Possession of Cocaine with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Cocaine for distribution'),
('P.C. 7009','Misdemeanor Possession of Methamphetamine','misdemeanor',7,500,'green','The possession of methamphetamine in a small quantity usually for personal use'),
('P.C. 7010','Felony manufacturing Possession of Methamphetamine','felony',25,1500,'red','The possession of a quantity of methamphetamine that is from manufacturing'),
('P.C. 7011','Possession of Methamphetamine with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Methamphetamine for distribution'),
('P.C. 7012','Misdemeanor Possession of Oxy / Vicodin','misdemeanor',7,500,'green','The possession of oxy / vicodin in a small quantity usually for personal use without prescription'),
('P.C. 7013','Felony manufacturing Possession of Oxy / Vicodin','felony',25,1500,'red','The possession of a quantity of oxy / vicodin that is from manufacturing'),
('P.C. 7014','Felony Possession of Oxy / Vicodin with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of oxy / vicodin for distribution'),
('P.C. 7015','Misdemeanor Possession of Ecstasy','misdemeanor',7,500,'green','The possession of ecstasy in a small quantity usually for personal use'),
('P.C. 7016','Felony manufacturing Possession of Ecstasy','felony',25,1500,'red','The possession of a quantity of ecstasy that is from manufacturing'),
('P.C. 7017','Possession of Ecstasy with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of ecstasy for distribution'),
('P.C. 7018','Misdemeanor Possession of Opium','misdemeanor',7,500,'green','The possession of opium in a small quantity usually for personal use'),
('P.C. 7019','Felony manufacturing Possession of Opium','felony',25,1500,'red','The possession of a quantity of opium that is from manufacturing'),
('P.C. 7020','Possession of Opium with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Opium for distribution'),
('P.C. 7021','Misdemeanor Possession of Adderall','misdemeanor',7,500,'green','The possession of adderall in a small quantity usually for personal use without prescription'),
('P.C. 7022','Felony manufacturing Possession of Adderall','felony',25,1500,'red','The possession of a quantity of adderall that is from manufacturing'),
('P.C. 7023','Possession of Adderall with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Adderall for distribution'),
('P.C. 7024','Misdemeanor Possession of Xanax','misdemeanor',7,500,'green','The possession of xanax in a small quantity usually for personal use without prescription'),
('P.C. 7025','Felony manufacturing Possession of Xanax','felony',25,1500,'red','The possession of a quantity of xanax that is from manufacturing'),
('P.C. 7026','Possession of Xanax with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Xanax for distribution'),
('P.C. 7027','Misdemeanor Possession of Shrooms','misdemeanor',7,500,'green','The possession of shrooms in a small quantity usually for personal use'),
('P.C. 7028','Felony manufacturing Possession of Shrooms','felony',25,1500,'red','The possession of a quantity of shrooms that is from manufacturing'),
('P.C. 7029','Possession of Shrooms with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of Shrooms for distribution'),
('P.C. 7030','Misdemeanor Possession of Lean','misdemeanor',7,500,'green','The possession of lean in a small quantity usually for personal use'),
('P.C. 7031','Felony manufacturing Possession of Lean','felony',25,1500,'red','The possession of a quantity of lean that is from manufacturing'),
('P.C. 7032','Possession of Lean with Intent to Distribute','felony',35,4500,'orange','The possession of a quantity of lean for distribution'),
('P.C. 7033','Sale of a controlled substance','misdemeanor',10,1000,'green','The sale of a substance that is controlled by law'),
('P.C. 7034','Drug Trafficking','felony',0,0,'red','The large scale movement of illegal drugs'),
('P.C. 7035','Desecration of a Human Corpse','felony',20,1500,'orange','When someone harms, disturbs or destroys the remains of another person'),
('P.C. 7036','Public Intoxication','infraction',0,500,'green','When someone is intoxicated above legal limit in public'),
('P.C. 7037','Public Indecency','misdemeanor',10,750,'green','The act of someone exposing themself in a way that infringes in public morals'),
('P.C. 8001','Criminal Possession of Weapon Class A','felony',10,500,'green','Possession of a Class A firearm without licensing'),
('P.C. 8002','Criminal Possession of Weapon Class B','felony',15,1000,'green','Possession of a Class B firearm without licensing'),
('P.C. 8003','Criminal Possession of Weapon Class C','felony',30,3500,'green','Possession of a Class C firearm without licensing'),
('P.C. 8004','Criminal Possession of Weapon Class D','felony',25,1500,'green','Possession of a Class D firearm without licensing'),
('P.C. 8005','Criminal Sale of Weapon Class A','felony',15,1000,'orange','The act of selling a Class A firearm without licensing'),
('P.C. 8006','Criminal Sale of Weapon Class B','felony',20,2000,'orange','The act of selling a Class B firearm without licensing'),
('P.C. 8007','Criminal Sale of Weapon Class C','felony',35,7000,'orange','The act of selling a Class C firearm without licensing'),
('P.C. 8008','Criminal Sale of Weapon Class D','felony',30,3000,'orange','The act of selling a Class D firearm without licensing'),
('P.C. 8009','Criminal Use of Weapon','misdemeanor',10,450,'orange','Use of a weapon while in commission of a crime'),
('P.C. 8010','Possession of Illegal Firearm Modifications','misdemeanor',10,300,'green','Being in possession of firearm modifications unlawfully'),
('P.C. 8011','Weapon Trafficking','felony',0,0,'red','The transportation of a large amount of weapons for one point to another'),
('P.C. 8012','Brandishing a Weapon','misdemeanor',15,500,'orange','The act of making a firearm purposely visible'),
('P.C. 8013','Insurrection','felony',0,0,'red','Attempting to overthrow the government with violence'),
('P.C. 8014','Flying into Restricted Airspace','felony',20,1500,'green','Piloting and aircraft into airspace that is governmentally controlled'),
('P.C. 8015','Jaywalking','infraction',0,150,'green','crossing a roadway in a manner that is hazardous to motor vehicles'),
('P.C. 8016','Criminal Use of Explosives','felony',30,2500,'orange','Use of explosives to committing a crime'),
('P.C. 9001','Driving While Intoxicated','misdemeanor',5,300,'green','Operating a motor vehicle while impaired by alcohol'),
('P.C. 9002','Evading','misdemeanor',5,400,'green','Hiding or running from lawful detainment'),
('P.C. 9003','Reckless Evading','felony',10,800,'orange','Recklessly disregarding safety and Hiding or running from lawful detainment while '),
('P.C. 9004','Failure to Yield to Emergency Vehicle','infraction',0,600,'green','Not giving way to emergency vehicles'),
('P.C. 9005','Failure to Obey Traffic Control Device','infraction',0,150,'green','Not following the safety devices of the roadway'),
('P.C. 9006','Nonfunctional Vehicle','infraction',0,75,'green','Having a vehicle that is no longer functional in the roadway'),
('P.C. 9007','Negligent Driving','infraction',0,300,'green','Driving in a manner as to unknowingly disregard safety'),
('P.C. 9008','Reckless Driving','misdemeanor',10,750,'orange','Driving in a manner as to knowingly disregard safety'),
('P.C. 9009','Third Degree Speeding','infraction',0,225,'green','Speeding 15 over the limit'),
('P.C. 9010','Second Degree Speeding','infraction',0,450,'green','Speeding 35 over the limit'),
('P.C. 9011','First Degree Speeding','infraction',0,750,'green','Speeding 50 over the limit'),
('P.C. 9012','Unlicensed Operation of Vehicle','infraction',0,500,'green','The operation of a motor vehicle without proper licensing'),
('P.C. 9013','Illegal U-Turn','infraction',0,75,'green','Performing a u-turn where it is prohibited'),
('P.C. 9014','Illegal Passing','infraction',0,300,'green','Passing other motor vehicles in a prohibited manner'),
('P.C. 9015','Failure to Maintain Lane','infraction',0,300,'green','Not staying in the correct lane with a motor vehicle'),
('P.C. 9016','Illegal Turn','infraction',0,150,'green','Performing a turn where it is prohibited'),
('P.C. 9017','Failure to Stop','infraction',0,600,'green','Not stopping for a lawful stop or traffic device'),
('P.C. 9018','Unauthorized Parking','infraction',0,300,'green','Parking a vehicle in a location that requires approval with any'),
('P.C. 9019','Hit and Run','misdemeanor',10,500,'green','Striking another person or vehicle and fleeing the location'),
('P.C. 9020','Driving without Headlights or Signals','infraction',0,300,'green','Operating a vehicle with no functional lights'),
('P.C. 9021','Street Racing','felony',15,1500,'green','Operating motorvehicles in a contest'),
('P.C. 9022','Piloting without Proper Licensing','felony',20,1500,'orange','Failure to be in possession of valid licensing when operating an aircraft'),
('P.C. 9023','Unlawful Use of a Motor Vehicle','misdemeanor',10,750,'green','The use of a motor vehicle without a lawful reason'),
('P.C. 10001','Hunting in Restricted Areas','infraction',0,450,'green','Harvesting game in areas where it is prohibited to do so'),
('P.C. 10002','Unlicensed Hunting','infraction',0,450,'green','Harvesting game without proper licensing'),
('P.C. 10003','Animal Cruelty','misdemeanor',10,450,'green','The act of abusing an animal knowingly or not'),
('P.C. 10004','Hunting with a Non-Hunting Weapon','misdemeanor',10,750,'green','To use a weapon not lawfully stated or manufactured to be used for the harvesting of wild game'),
('P.C. 10005','Hunting outside of hunting hours','infraction',0,750,'green','Harvesting animals outside of specified time to do so'),
('P.C. 10006','Overhunting','misdemeanor',10,1000,'green','Taking more than legally specified amount of game'),
('P.C. 10007','Poaching','felony',20,1250,'red','Harvesting an animal that is listed as legally non-harvestable')
ON DUPLICATE KEY UPDATE
  `label` = VALUES(`label`),
  `charge_class` = VALUES(`charge_class`),
  `months` = VALUES(`months`),
  `fine` = VALUES(`fine`),
  `color` = VALUES(`color`),
  `description` = VALUES(`description`);

CREATE TABLE IF NOT EXISTS `mdt_notes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `owner` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_notes_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_department_notes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profiles_clocking` (
  `profileId` int(10) unsigned NOT NULL,
  `clockindate` timestamp NOT NULL DEFAULT current_timestamp(),
  `clockoutdate` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  KEY `FK_mdt_profiles_clocking_mdt_profiles` (`profileId`),
  CONSTRAINT `FK_mdt_profiles_clocking_mdt_profiles` FOREIGN KEY (`profileId`) REFERENCES `mdt_profiles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profiles_gallery` (
  `profileId` int(10) unsigned NOT NULL,
  `image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `label` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datecreated` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `FK_mdt_profiles_gallery_mdt_profiles` (`profileId`),
  CONSTRAINT `FK_mdt_profiles_gallery_mdt_profiles` FOREIGN KEY (`profileId`) REFERENCES `mdt_profiles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profiles_identifiers` (
  `profileId` int(10) unsigned NOT NULL,
  `content` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `datecreated` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `FK_mdt_profiles_identifiers_mdt_profiles` (`profileId`),
  CONSTRAINT `FK_mdt_profiles_identifiers_mdt_profiles` FOREIGN KEY (`profileId`) REFERENCES `mdt_profiles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profiles_tags` (
  `profileId` int(10) unsigned NOT NULL,
  `tag` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  UNIQUE KEY `unique_profile_tag` (`profileId`, `tag`),
  KEY `FK_mdt_profiles_tags_mdt_profiles` (`profileId`),
  CONSTRAINT `FK_mdt_profiles_tags_mdt_profiles` FOREIGN KEY (`profileId`) REFERENCES `mdt_profiles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_profile_sessions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `profile_id` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `source` int(11) DEFAULT NULL,
  `login_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `logout_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `profile_id` (`profile_id`),
  KEY `citizenid` (`citizenid`),
  KEY `idx_profile_logout` (`profile_id`, `logout_at`),
  CONSTRAINT `FK_mdt_profile_sessions_profiles` FOREIGN KEY (`profile_id`) REFERENCES `mdt_profiles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `contentyjs` longblob DEFAULT NULL,
  `contentplaintext` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `author` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `authorplaintext` VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datecreated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dateupdated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_author` (`author`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_charges` (
  `reportid` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `charge` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `count` int(10) unsigned NOT NULL DEFAULT 1,
  `time` int(10) unsigned DEFAULT NULL,
  `fine` int(10) unsigned DEFAULT NULL,
  KEY `FK_mdt_reports_charges_mdt_reports` (`reportid`),
  KEY `FK_mdt_reports_charges_mdt_penal_codes` (`charge`),
  KEY `idx_charges_citizenid` (`citizenid`),
  CONSTRAINT `FK_mdt_reports_charges_mdt_penal_codes` FOREIGN KEY (`charge`) REFERENCES `mdt_penal_codes` (`label`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_reports_charges_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_evidence` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stored` tinyint(4) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `FK_mdt_reports_evidence_mdt_reports` (`reportid`),
  CONSTRAINT `FK_mdt_reports_evidence_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_involved` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_mdt_reports_involved_mdt_reports` (`reportid`),
  KEY `idx_involved_citizenid` (`citizenid`),
  CONSTRAINT `FK_mdt_reports_involved_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_restrictions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `type` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `identifier` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_mdt_reports_restrictions_mdt_reports` (`reportid`),
  CONSTRAINT `FK_mdt_reports_restrictions_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_tags` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `tag` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_mdt_reports_tags_mdt_reports` (`reportid`),
  CONSTRAINT `FK_mdt_reports_tags_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_reports_warrants` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) NOT NULL DEFAULT '',
  `felonies` int(10) unsigned NOT NULL DEFAULT 0,
  `misdemeanors` int(10) unsigned NOT NULL DEFAULT 0,
  `infractions` int(10) unsigned NOT NULL DEFAULT 0,
  `expirydate` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_warrant` (`reportid`, `citizenid`),
  KEY `FK_mdt_reports_warrants_mdt_reports` (`reportid`),
  KEY `FK_mdt_reports_warrants_mdt_profiles` (`citizenid`),
  CONSTRAINT `FK_mdt_reports_warrants_mdt_profiles` FOREIGN KEY (`citizenid`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_reports_warrants_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_arrests` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `officer_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `officer_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `reportid` (`reportid`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `FK_mdt_arrests_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_arrests_profiles` FOREIGN KEY (`citizenid`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_cases` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `case_number` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `summary` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('open','in_progress','closed') NOT NULL DEFAULT 'open',
  `priority` enum('low','medium','high') NOT NULL DEFAULT 'medium',
  `assigned_department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_by_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `case_number` (`case_number`),
  KEY `status` (`status`),
  KEY `assigned_department` (`assigned_department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_case_officers` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `case_id` int(10) unsigned NOT NULL,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('primary','assisting','supervisor') NOT NULL DEFAULT 'assisting',
  `assigned_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assigned_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `case_id` (`case_id`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `FK_mdt_case_officers_cases` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_case_officers_profiles` FOREIGN KEY (`citizenid`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_case_attachments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `case_id` int(10) unsigned NOT NULL,
  `type` enum('photo','document','other') NOT NULL DEFAULT 'document',
  `url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uploaded_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `case_id` (`case_id`),
  CONSTRAINT `FK_mdt_case_attachments_cases` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_case_reports` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `case_id` int(10) unsigned NOT NULL,
  `report_id` int(10) unsigned NOT NULL,
  `linked_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `linked_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_case_report` (`case_id`, `report_id`),
  KEY `case_id` (`case_id`),
  KEY `report_id` (`report_id`),
  CONSTRAINT `FK_case_reports_cases` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_case_reports_reports` FOREIGN KEY (`report_id`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_evidence_items` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `case_id` int(10) unsigned DEFAULT NULL,
  `report_id` int(10) unsigned DEFAULT NULL,
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `serial` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stash_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stored` tinyint(1) NOT NULL DEFAULT 0,
  `last_holder` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `case_id` (`case_id`),
  KEY `report_id` (`report_id`),
  KEY `last_holder` (`last_holder`),
  CONSTRAINT `FK_mdt_evidence_items_cases` FOREIGN KEY (`case_id`) REFERENCES `mdt_cases` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `FK_mdt_evidence_items_reports` FOREIGN KEY (`report_id`) REFERENCES `mdt_reports` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_evidence_custody` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `evidence_id` int(10) unsigned NOT NULL,
  `from_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `to_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action` enum('collected','transferred','stored','released','updated','viewed') NOT NULL DEFAULT 'collected',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `evidence_id` (`evidence_id`),
  CONSTRAINT `FK_mdt_evidence_custody_items` FOREIGN KEY (`evidence_id`) REFERENCES `mdt_evidence_items` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_evidence_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `evidence_id` int(10) unsigned NOT NULL,
  `url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uploaded_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `evidence_id` (`evidence_id`),
  CONSTRAINT `FK_mdt_evidence_images_items` FOREIGN KEY (`evidence_id`) REFERENCES `mdt_evidence_items` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_audit_logs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `actor_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actor_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `details` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `entity_type` (`entity_type`),
  KEY `entity_id` (`entity_id`),
  KEY `actor_citizenid` (`actor_citizenid`),
  KEY `action` (`action`),
  KEY `created_at` (`created_at`),
  KEY `idx_entity_lookup` (`entity_type`, `entity_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Extend player_vehicles with MDT fields (fresh install)
ALTER TABLE `player_vehicles`
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_information` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_points` int(11) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_status` enum('valid','suspended','expired','impounded') NOT NULL DEFAULT 'valid',
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_stolen` tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_boloactive` tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `mdt_vehicle_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;

CREATE TABLE IF NOT EXISTS `mdt_weapons` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `serial` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `scratched` tinyint(1) NOT NULL DEFAULT 0,
  `owner` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `information` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weaponClass` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weaponModel` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `unique_serial` (`serial`),
  KEY `FK_mdt_weapons_mdt_profiles` (`owner`),
  CONSTRAINT `FK_mdt_weapons_mdt_profiles` FOREIGN KEY (`owner`) REFERENCES `mdt_profiles` (`citizenid`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_weapon_ownership_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `serial` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weapon_model` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weapon_class` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `information` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `changed_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reason` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_mdt_weapon_history_serial` (`serial`),
  KEY `idx_mdt_weapon_history_owner` (`owner`),
  CONSTRAINT `FK_mdt_weapon_history_weapons` FOREIGN KEY (`serial`) REFERENCES `mdt_weapons` (`serial`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_cameras` (
  `cam_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cam_label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cam_type` enum('placed','store','bank','jewelry','government','medical','other') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'placed',
  `model` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'security_cam_03',
  `coords` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rotation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `can_rotate` BOOLEAN NOT NULL DEFAULT TRUE,
  `is_online` BOOLEAN NOT NULL DEFAULT TRUE,
  `spawns_model` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'TRUE = spawns 3D model (player-placed), FALSE = virtual camera (uses existing world model)',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`cam_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- DEFAULT CAMERA DATA (remove if not needed for your server)
INSERT IGNORE INTO `mdt_cameras` (`cam_id`, `cam_label`, `cam_type`, `coords`, `rotation`, `image`, `can_rotate`, `is_online`, `spawns_model`, `created_by`) VALUES
('PCB01', 'Pacific Bank: Lobby', 'bank', '{"x":257.45,"y":210.07,"z":109.08}', '{"x":-25.0,"y":0.0,"z":28.05}', 'https://files.fivemerr.com/images/45bab512-5836-4449-8831-fbe67d7c886f.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('PCB02', 'Pacific Bank: Foyer', 'bank', '{"x":232.86,"y":221.46,"z":107.83}', '{"x":-25.0,"y":0.0,"z":-140.91}', 'https://files.fivemerr.com/images/4a50b347-aa12-4df2-9efc-cf3f38cc1d41.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('PCB03', 'Pacific Bank: Vault', 'bank', '{"x":252.27,"y":225.52,"z":103.99}', '{"x":-35.0,"y":0.0,"z":-74.87}', 'https://files.fivemerr.com/images/7c1604e9-480b-41d2-9c6b-1899c763fb51.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('LTD01', 'Ltd Grove St', 'store', '{"x":-53.14,"y":-1746.71,"z":31.54}', '{"x":-35.0,"y":0.0,"z":-168.9182}', 'https://files.fivemerr.com/images/1ff40a9c-ee6e-4c6f-9273-15bae452375e.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('RLQ01', 'Rob\'s Liqour Prosperity St', 'store', '{"x":-1482.9,"y":-380.463,"z":42.363}', '{"x":-35.0,"y":0.0,"z":79.53281}', 'https://files.fivemerr.com/images/b5bcfe95-3c3f-4dde-a0b9-2024ea5bfa08.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('RLQ02', 'Rob\'s Liqour San Andreas Ave', 'store', '{"x":-1224.874,"y":-911.094,"z":14.401}', '{"x":-35.0,"y":0.0,"z":-6.778894}', 'https://files.fivemerr.com/images/f4aba38b-faa0-4050-ab00-ec55d8a1068d.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('LTD02', 'Ltd Ginger St', 'store', '{"x":-718.153,"y":-909.211,"z":21.49}', '{"x":-35.0,"y":0.0,"z":-137.1431}', 'https://files.fivemerr.com/images/ca78a638-f17a-4456-9061-1648b593e394.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24701', '24/7 Innocence Blvd', 'store', '{"x":23.885,"y":-1342.441,"z":31.672}', '{"x":-35.0,"y":0.0,"z":-142.9191}', 'https://files.fivemerr.com/images/ca78a638-f17a-4456-9061-1648b593e394.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('RLQ03', 'Rob\'s Liqour El Rancho Blvd', 'store', '{"x":1133.024,"y":-978.712,"z":48.515}', '{"x":-35.0,"y":0.0,"z":-137.302}', 'https://files.fivemerr.com/images/63f7c1dd-c537-44a4-9076-2dd9227dfa97.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('LTD03', 'Ltd West Mirror Drive', 'store', '{"x":1151.93,"y":-320.389,"z":71.33}', '{"x":-35.0,"y":0.0,"z":-119.4468}', 'https://files.fivemerr.com/images/686831ef-ed81-4882-bd23-72c2754e38ab.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24702', '24/7 Clinton Ave', 'store', '{"x":383.402,"y":328.915,"z":105.541}', '{"x":-35.0,"y":0.0,"z":118.585}', 'https://files.fivemerr.com/images/2b19a04e-0f1d-4725-8262-1da93b30391e.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('LTD04', 'Ltd Banham Canyon Dr', 'store', '{"x":-1832.057,"y":789.389,"z":140.436}', '{"x":-35.0,"y":0.0,"z":-91.481}', 'https://files.fivemerr.com/images/c6f53e50-75da-4e4c-806c-08be6822e884.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('RLQ04', 'Rob\'s Liqour Great Ocean Hwy', 'store', '{"x":-2966.15,"y":387.067,"z":17.393}', '{"x":-35.0,"y":0.0,"z":32.92229}', 'https://files.fivemerr.com/images/f25096f5-5724-4f4b-8a75-b7f968dd67ef.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24703', '24/7 Ineseno Road ', 'store', '{"x":-3046.749,"y":592.491,"z":9.808}', '{"x":-35.0,"y":0.0,"z":-116.673}', 'https://files.fivemerr.com/images/055956f5-6f62-48a7-80d0-c6d94540b6e4.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24704', '24/7 Barbareno Rd', 'store', '{"x":-3246.489,"y":1010.408,"z":14.705}', '{"x":-35.0,"y":0.0,"z":-135.2151}', 'https://files.fivemerr.com/images/14b9a9ff-4cf0-4373-a784-0723bec9c3b2.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24705', '24/7 Route 68', 'store', '{"x":539.773,"y":2664.904,"z":44.056}', '{"x":-35.0,"y":0.0,"z":-42.947}', 'https://files.fivemerr.com/images/4535c506-42dc-4ca9-9f6e-ece7215e1b7f.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('RLQ05', 'Rob\'s Liqour Route 68', 'store', '{"x":1169.855,"y":2711.493,"z":40.432}', '{"x":-35.0,"y":0.0,"z":127.17}', 'https://files.fivemerr.com/images/b8b8e6ff-234a-461f-8636-02c1c9247aeb.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24706', '24/7 Senora Fwy', 'store', '{"x":2673.579,"y":3281.265,"z":57.541}', '{"x":-35.0,"y":0.0,"z":-80.242}', 'https://files.fivemerr.com/images/cf0b6dc6-3310-441a-ad00-2666fe89c700.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24707', '24/7 Alhambra Dr', 'store', '{"x":1966.24,"y":3749.545,"z":34.143}', '{"x":-35.0,"y":0.0,"z":163.065}', 'https://files.fivemerr.com/images/6c3eb8b8-c8a5-4a25-895c-44724ac24a6f.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('24708', '24/7 Senora Fwy', 'store', '{"x":1729.522,"y":6419.87,"z":37.262}', '{"x":-35.0,"y":0.0,"z":-160.089}', 'https://files.fivemerr.com/images/64918129-eb25-4bd6-abe7-cc6263e36f1d.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('FLB01', 'Fleeca Bank Legion Square', 'bank', '{"x":144.871,"y":-1043.044,"z":31.017}', '{"x":-35.0,"y":0.0,"z":-143.9796}', 'https://files.fivemerr.com/images/92659204-5c5d-44ab-a14f-68a7f83e01f3.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('FLB02', 'Fleeca Bank Hawick/Power', 'bank', '{"x":309.341,"y":-281.439,"z":55.88}', '{"x":-35.0,"y":0.0,"z":-146.1595}', 'https://files.fivemerr.com/images/17a41043-bc9d-4a0c-945d-63d03ff4660d.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('FLB03', 'Fleeca Bank Hawick/San Vitas', 'bank', '{"x":-355.7643,"y":-52.506,"z":50.746}', '{"x":-35.0,"y":0.0,"z":-143.8711}', 'https://files.fivemerr.com/images/ead3415f-bdc5-447f-9d6f-287c77211388.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('FLB04', 'Fleeca Bank Del Perro Blvd', 'bank', '{"x":-1214.226,"y":-335.86,"z":39.515}', '{"x":-35.0,"y":0.0,"z":-97.862}', 'https://files.fivemerr.com/images/6d00ce1d-6078-4a69-8cfb-ebed60cbf833.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('FLB05', 'Fleeca Bank Great Ocean Hwy', 'bank', '{"x":-2958.885,"y":478.983,"z":17.406}', '{"x":-35.0,"y":0.0,"z":-34.69595}', 'https://files.fivemerr.com/images/dbb2ec99-8212-47f2-9f79-e0b787608ce2.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('PLB01', 'Paleto Bank', 'bank', '{"x":-102.939,"y":6467.668,"z":33.424}', '{"x":-35.0,"y":0.0,"z":24.66}', 'https://files.fivemerr.com/images/ff06da26-2cd6-4337-a1ca-c738d4267ae5.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('VGY01', 'Vangelico Jewelery: Front Right', 'jewelry', '{"x":-627.54,"y":-239.74,"z":40.33}', '{"x":-35.0,"y":0.0,"z":5.78}', 'https://files.fivemerr.com/images/348eca1b-17ad-48fc-8f03-1c21bd87dadc.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('VGY02', 'Vangelico Jewelery: Front Left', 'jewelry', '{"x":-627.51,"y":-229.51,"z":40.24}', '{"x":-35.0,"y":0.0,"z":-95.78}', 'https://files.fivemerr.com/images/707df30b-440e-4e55-ac93-c1878c381cee.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('VGY03', 'Vangelico Jewelery: Back Left', 'jewelry', '{"x":-620.3,"y":-224.31,"z":40.23}', '{"x":-35.0,"y":0.0,"z":165.78}', 'https://files.fivemerr.com/images/371e5386-c901-451d-a3c4-ce7a371bee86.png', TRUE, TRUE, FALSE, 'SYSTEM'),
('VGY04', 'Vangelico Jewelery: Side', 'jewelry', '{"x":-622.57,"y":-236.3,"z":40.31}', '{"x":-35.0,"y":0.0,"z":5.78}', 'https://files.fivemerr.com/images/4c90514e-7a31-4654-a7a9-40864d106028.png', TRUE, TRUE, FALSE, 'SYSTEM');

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` enum('citizen','vehicle','weapon','property','other') NOT NULL DEFAULT 'citizen',
  `subject_id` varchar(50) NOT NULL COMMENT 'citizenid, plate, serial, etc depending on type',
  `subject_name` varchar(100) DEFAULT NULL COMMENT 'Full name, vehicle model, weapon type, etc',
  `reportId` int(11) unsigned DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('active','inactive','resolved') NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  KEY `type` (`type`),
  KEY `subject_id` (`subject_id`),
  KEY `status` (`status`),
  KEY `reportId` (`reportId`),
  CONSTRAINT `FK_mdt_bolos_reports` FOREIGN KEY (`reportId`) REFERENCES `mdt_reports` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_impound` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `vehicleid` int(11) NOT NULL,
  `linkedreport` int(10) unsigned DEFAULT NULL,
  `fee` int(11) NOT NULL DEFAULT 0,
  `time` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `vehicleid` (`vehicleid`),
  KEY `linkedreport` (`linkedreport`),
  CONSTRAINT `FK_mdt_impound_reports` FOREIGN KEY (`linkedreport`) REFERENCES `mdt_reports` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TEST DATA (uncomment for development/testing only)
-- INSERT IGNORE INTO `mdt_bolos` (`id`, `type`, `subject_id`, `subject_name`, `reportId`, `notes`, `status`) VALUES
-- (1, 'citizen', 'PRQ22104', 'John Doe', 1, 'Missing person - last seen downtown', 'active'),
-- (2, 'vehicle', 'ABC123', 'Elegy Retro Custom', 2, 'Stolen vehicle - armed and dangerous occupants', 'inactive'),
-- (3, 'weapon', 'WP001234', 'Glock 19', 3, 'Used in armed robbery', 'resolved');

SET @OLDTMP_SQL_MODE=@@SQL_MODE, SQL_MODE='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
DELIMITER //
CREATE TRIGGER `mdt_reports_charges_after_delete` AFTER UPDATE ON `mdt_reports_charges` FOR EACH ROW BEGIN
    UPDATE mdt_reports_warrants
    SET
        felonies = (
            SELECT SUM(CASE WHEN mc.charge_class = 'felony' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = OLD.reportid
        ),
        misdemeanors = (
            SELECT SUM(CASE WHEN mc.charge_class = 'misdemeanor' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = OLD.reportid
        ),
        infractions = (
            SELECT SUM(CASE WHEN mc.charge_class = 'infraction' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = OLD.reportid
        )
    WHERE reportid = OLD.reportid;
END//
DELIMITER ;
SET SQL_MODE=@OLDTMP_SQL_MODE;

SET @OLDTMP_SQL_MODE=@@SQL_MODE, SQL_MODE='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
DELIMITER //
CREATE TRIGGER `mdt_reports_charges_after_insert` AFTER INSERT ON `mdt_reports_charges` FOR EACH ROW BEGIN
    UPDATE mdt_reports_warrants
    SET
        felonies = (
            SELECT SUM(CASE WHEN mc.charge_class = 'felony' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = NEW.reportid
        ),
        misdemeanors = (
            SELECT SUM(CASE WHEN mc.charge_class = 'misdemeanor' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = NEW.reportid
        ),
        infractions = (
            SELECT SUM(CASE WHEN mc.charge_class = 'infraction' THEN 1 ELSE 0 END)
        FROM mdt_reports_charges AS mrc
                     INNER JOIN mdt_penal_codes AS mc
                                ON mrc.charge = mc.label
            WHERE mrc.reportid = NEW.reportid
        )
    WHERE reportid = NEW.reportid;
END//
DELIMITER ;
SET SQL_MODE=@OLDTMP_SQL_MODE;

-- --------------------------------------------------------
-- Tags master table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_tags` (
  `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(25) NOT NULL,
  `type` ENUM('officer','report','both') NOT NULL DEFAULT 'officer',
  `color` VARCHAR(7) NOT NULL DEFAULT '#6b7280',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_tag_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Default Officer Tags
INSERT IGNORE INTO mdt_tags (name, type, color) VALUES
('SWAT', 'officer', '#3b82f6'),
('FTO', 'officer', '#10b981'),
('Detective', 'officer', '#8b5cf6'),
('Probation', 'officer', '#f59e0b'),
('Command', 'officer', '#ef4444'),
('K9 Certified', 'officer', '#06b6d4'),
('Air Certified', 'officer', '#ec4899');

-- Default Report Tags
INSERT IGNORE INTO mdt_tags (name, type, color) VALUES
('Robbery', 'report', '#ef4444'),
('Armed', 'report', '#f97316'),
('Priority', 'report', '#f59e0b'),
('Active', 'report', '#10b981'),
('Ballistics', 'report', '#8b5cf6'),
('Gang Related', 'report', '#ec4899'),
('Drug Related', 'report', '#06b6d4'),
('Traffic', 'report', '#3b82f6'),
('Domestic', 'report', '#6b7280'),
('Assault', 'report', '#ef4444'),
('High Priority', 'report', '#f59e0b'),
('Confidential', 'report', '#8b5cf6'),
('Active Investigation', 'report', '#10b981');

CREATE TABLE IF NOT EXISTS `mdt_report_vehicles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reportid` int(10) unsigned NOT NULL,
  `plate` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_mdt_report_vehicles_mdt_reports` (`reportid`),
  KEY `idx_report_vehicles_plate` (`plate`),
  CONSTRAINT `FK_mdt_report_vehicles_mdt_reports` FOREIGN KEY (`reportid`) REFERENCES `mdt_reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_awards` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `icon` varchar(50) NOT NULL DEFAULT 'emoji_events',
  `category` varchar(50) NOT NULL DEFAULT 'general',
  `goal_type` varchar(50) NOT NULL,
  `goal_amount` int(10) unsigned NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `mdt_awards` (`name`, `description`, `icon`, `category`, `goal_type`, `goal_amount`) VALUES
('First Report', 'File your first report in the MDT system', 'description', 'reports', 'reports', 1),
('50 Reports Filed', 'File 50 reports demonstrating consistent documentation', 'description', 'reports', 'reports', 50),
('100 Reports Filed', 'File 100 reports showing dedication to thorough record-keeping', 'description', 'reports', 'reports', 100),
('First Arrest', 'Make your first arrest and file the arrest report', 'local_police', 'arrests', 'arrests', 1),
('50 Arrests', 'Process 50 arrests as a seasoned officer', 'local_police', 'arrests', 'arrests', 50),
('Case Worker', 'Work on 25 cases as an investigator', 'work', 'cases', 'cases', 25),
('$100K Fined', 'Issue a total of $100,000 in fines', 'payments', 'financial', 'totalFined', 100000),
('10 Warrants Issued', 'Issue 10 warrants for suspects', 'gavel', 'warrants', 'warrants', 10);

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;