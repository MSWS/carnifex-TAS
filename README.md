# Carnifex-TAS

A Tool Assisted Speedrun Tool for Shavit's bhoptimer.

This plugin is loosely based on blacky's TAS, but is completely reworked to work with bhoptimer 2.5, also includes some new features/changes.

## Features

* Pausing
* Rewinding/Forwarding
* 100% gain AutoStrafer
* Time manipulation
* Working replays

(Still working on more features)

## Usage
* !tasmenu - Opens the TAS menu for the player if the style allows for TAS.

## Requirements
Latest bhoptimer version, compiled with [this](https://github.com/shavitush/bhoptimer/pull/893/commits/35b608af888067d570d26ecc246cf0f6821c8a01) patch for shavit-core.smx

## Installation

Compile the sp file (or download the smx from releases) and put it in addons/sourcemod/plugins

## Setup

### Style config
This TAS gets activated when the player enters a style with the specialstring "tas"

Example setup of shavit-styles.cfg:

```cfg
	"10"
	{
		
		"enabled"			"1" 
		"inaccessible"		"0" 

		
		"name"				"TAS" 
		"shortname"			"TAS" 
		"htmlcolor"			"797FD4" 
		"command"			"tas" 
		"clantag"			"TAS" 

	
		"autobhop"			"1"
		"easybhop"			"1" 
		"prespeed"			"0" 
		"velocity_limit"	"0.0"
		"bunnyhopping"		"1"


		"airaccelerate"		"1000.0" 
		"runspeed"			"260.00" 
		"unranked"			"0" 
		"noreplay"			"0" 

	
		"sync"				"1" 
		"strafe_count_w"	"0" 
		"strafe_count_a"	"1" 
		"strafe_count_s"	"0" 
		"strafe_count_d"	"1" 


		"rankingmultiplier"	"0.5" 
		"specialstring"		"tas" 
	}

```

### Prevent Bans

The AutoStrafer that's a part of this TAS will get detected by Anticheats such as BASH 2.0 and Oryx.

#### Bash 2.0
To prevent this you can add the following following line of code to onPlayerRunCmd within bash2.0's source file and compile. 

```
char sSpecial[128];
int style = Shavit_GetBhopStyle(client);
Shavit_GetStyleStrings(style, sSpecialString, sSpecial, 128);

if(StrContains(sSpecial, "tas", false) != -1) 
{
			 	bCheck = false;
} 
```
#### Oryx-AC
For oryx you only need to add oryx_bypass to the styles specialstring.


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)