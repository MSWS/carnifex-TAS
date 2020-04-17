#define PLUGIN_NAME           "Carnifex - TAS"
#define PLUGIN_AUTHOR         "carnifex"
#define PLUGIN_DESCRIPTION    "Tool Assisted Speedrun plugin for shavit's bhoptimer"
#define PLUGIN_VERSION        "1.2"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shavit>
#include <smlib/entities>
#include <smlib/arrays>
#pragma dynamic 2621440


#pragma semicolon 1

MoveType  g_pauseMoveType = MOVETYPE_NONE;
ArrayList g_hFrameList[MAXPLAYERS + 1];
float g_CurrentFrame[MAXPLAYERS + 1];
bool g_bUsedFrame[MAXPLAYERS + 1];
bool g_bTASMode[MAXPLAYERS + 1];
bool g_bSpeedUpFromUnpause[MAXPLAYERS + 1];
bool g_bPaused[MAXPLAYERS + 1];
bool g_bFastForward[MAXPLAYERS + 1];
bool g_bRewind[MAXPLAYERS + 1];
bool g_bAutoStrafer[MAXPLAYERS + 1];
float g_fEditSpeed[MAXPLAYERS + 1];
float g_fTimescale[MAXPLAYERS + 1];
float gF_PauseOrigin[MAXPLAYERS+1][3];
float gF_PauseAngles[MAXPLAYERS+1][3];
float gF_PauseVelocity[MAXPLAYERS+1][3];
float g_fSpeedTicksPassed[MAXPLAYERS + 1];
float g_fLastYaw[MAXPLAYERS + 1];
float g_fLastMove[MAXPLAYERS + 1][2];
float g_flSidespeed = 450.0;
int g_nIgnoredCmds[MAXPLAYERS + 1];
float g_flLastGain[MAXPLAYERS + 1];

//fix replay data
ArrayList gA_SaveFrames[MAXPLAYERS+1];

int       g_LastButtons[MAXPLAYERS + 1];
bool      g_bHasEdited[MAXPLAYERS + 1];

#pragma newdecls required
#define FRAMESIZE 13

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_tasmenu", Command_OpenTAS, "Open the TAS menu.");
	RegConsoleCmd("+rewind", Command_Rewind);
	RegConsoleCmd("-rewind", Command_Rewind);
	RegConsoleCmd("+fastforward", Command_FastForward);
	RegConsoleCmd("-fastforward", Command_FastForward);
	
	LoadTranslations("carnifex-tas.phrases.txt");
	
}

public Action Command_Rewind(int client, int args)
{
	if(g_bTASMode[client] && IsPlayerAlive(client))
	{
		char sArg[32];
		GetCmdArg(0, sArg, sizeof(sArg));
		if(StrEqual(sArg, "+rewind"))
		{
			g_bRewind[client] = true;
		}
		else if(StrEqual(sArg, "-rewind"))
		{
			g_bRewind[client] = false;
		}
		
		if(!g_bPaused[client] == true) {
			PauseTAS(client);
		}
		OpenTASMenu(client);
	}
	
	return Plugin_Handled;
}


public float NormalizeAngle(float angle)
{
	float temp = angle;
	
	while (temp <= -180.0)
	{
		temp += 360.0;
	}
	
	while (temp > 180.0)
	{
		temp -= 360.0;
	}
	
	return temp;
} 


//taken from unknowncheats forum. unknowncheats.me/forum/counterstrike-global-offensive/257614-proper-autobhop-100-gain-strafer.html
void ApplyAutoStrafe(int client, int &buttons, float vel[3], float angles[3])
{
	if (GetEntityFlags(client) & FL_ONGROUND || GetEntityMoveType(client) & MOVETYPE_LADDER)
	return;
	
	if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT || buttons & IN_FORWARD || buttons & IN_BACK)
	{
		return;
	}
	
	float flVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
	
	float YVel = RadToDeg(ArcTangent2(flVelocity[1], flVelocity[0]));
	
	float diff_angle = NormalizeAngle(angles[1] - YVel);
	
	vel[1] = g_flSidespeed;
	
	if (diff_angle > 0.0)
		vel[1] = -g_flSidespeed;
	
	float flLastGain = g_flLastGain[client];
	float flAngleGain = RadToDeg(ArcTangent(vel[1] / vel[0]));
	
	
	if (!((flLastGain < 0.0 && flAngleGain < 0.0) || (flLastGain > 0.0 && flAngleGain > 0.0))) 
		angles[1] -= diff_angle;
	
	g_flLastGain[client] = flAngleGain;
}




public Action Command_FastForward(int client, int args)
{
	if(g_bTASMode[client] && IsPlayerAlive(client))
	{
		char sArg[32];
		GetCmdArg(0, sArg, sizeof(sArg));
		if(StrEqual(sArg, "+fastforward"))
		{
			g_bFastForward[client] = true;
		}
		else if(StrEqual(sArg, "-fastforward"))
		{
			g_bFastForward[client] = false;
		}
		
		if(!g_bPaused[client] == true) {
			PauseTAS(client);
		}
		OpenTASMenu(client);
	}
	
	return Plugin_Handled;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual) 
{
	PrintToServer("STYLECHANGED ID: %i", client);
	if(g_bUsedFrame[client] == false)
	{
		g_hFrameList[client] = CreateArray(FRAMESIZE);
		gA_SaveFrames[client] = CreateArray(8);
		g_bUsedFrame[client] = true;
	}
	
	int size = GetArraySize(g_hFrameList[client]);
	
	if(size != 0) {
		g_hFrameList[client].Clear();
	}
	
	g_CurrentFrame[client]       = 0.0;
	doStyleCheck(client, newstyle);
	
}

public Action Command_OpenTAS(int client, int args){
	int style = Shavit_GetBhopStyle(client);
	doStyleCheck(client, style);
}

void OpenTASMenu(int client) {
	Menu menu = new Menu(Menu_TAS);
	menu.SetTitle("TAS menu");
	PrintToServer("MENU ID: %i", client);
	if(g_bTASMode[client])
	{
		char sDisplay[32];
		menu.AddItem("pr", g_bPaused[client]?"Resume":"Pause");
		menu.AddItem("rw", g_bRewind[client]?"-rewind":"+rewind");
		menu.AddItem("ff", g_bFastForward[client]?"-fastforward":"+fastforward");
		FormatEx(sDisplay, sizeof(sDisplay), "Edit Speed: %.2f", g_fEditSpeed[client]);
		menu.AddItem("editspeed", sDisplay);
		menu.AddItem("as", g_bAutoStrafer[client]?"Autostrafer: ON":"Autostrafer: OFF");
		FormatEx(sDisplay, sizeof(sDisplay), "Timescale: %.1f", g_fTimescale[client]);
		menu.AddItem("ts", sDisplay);
		menu.AddItem("exit", "Exit TAS Mode");
		
		if(g_bSpeedUpFromUnpause[client] == false)
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fTimescale[client]);
		} 
	} 
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}



public int Menu_TAS(Menu menu, MenuAction action, int client, int param2)
{
	if(!g_bTASMode[client]) {
		return 0;
	} 
	
	
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "pr"))
		{		
			PauseTAS(client);
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "rw"))
		{
			if(!g_bPaused[client]) {
				PauseTAS(client);
			}
			g_bRewind[client] = !g_bRewind[client];
			
			if(g_bRewind[client])
			{
				g_bFastForward[client] = false;
			}
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "ff"))
		{
			if(!g_bPaused[client]) {
				PauseTAS(client);
			}
			g_bFastForward[client] = !g_bFastForward[client];
			
			if(g_bFastForward[client])
			{
				g_bRewind[client] = false;
			}
			
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "editspeed"))
		{
			g_fEditSpeed[client] *= 2;
			
			if(g_fEditSpeed[client] > 128)
			{
				g_fEditSpeed[client] = 0.25;
			}
			OpenTASMenu(client);
		}
		else if (StrEqual(sInfo, "as"))
		{
			ToggleAutoStrafer(client);
			OpenTASMenu(client);
		}
		else if(StrEqual(sInfo, "ts"))
		{
			g_fTimescale[client] += 0.1;
			if(g_fTimescale[client] > 1.05)
			{
				g_fTimescale[client] = 0.2;
			}
			
			setTimescale(client, g_fTimescale[client]);
			
			OpenTASMenu(client); 
		}
		
		
		else if(StrEqual(sInfo, "enter"))
		{
			char sSpecial[128];
			int style = Shavit_GetBhopStyle(client);
			Shavit_GetStyleStrings(style, sSpecialString, sSpecial, 128);
			
		}
		
		else if(StrEqual(sInfo, "exit"))
		{
			OpenExitTASPrompt(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ToggleAutoStrafer(int client) {
	
	if(!g_bAutoStrafer[client] == true){
		g_bAutoStrafer[client] = true;
		
	} else {
		g_bAutoStrafer[client] = false;
	}
	
}

void RecordFrame(int client, int buttons)
{
	float vPos[3];
	Entity_GetAbsOrigin(client, vPos);
	
	float vAng[3];
	GetClientEyeAngles(client, vAng);
	
	float vVel[3];
	Entity_GetAbsVelocity(client, vVel);
	
	timer_snapshot_t snapshot;
	Shavit_SaveSnapshot(client, snapshot);
	
	any data[FRAMESIZE];
	data[0]  = vPos[0];
	data[1]  = vPos[1];
	data[2]  = vPos[2];
	data[3]  = vAng[0];
	data[4]  = vAng[1];
	data[5]  = buttons;
	data[6]  = vVel[0];
	data[7]  = vVel[1];
	data[8]  = vVel[2];
	data[9]  = snapshot.fCurrentTime;
	data[10] = snapshot.iGoodGains;
	data[11] = snapshot.iJumps;
	data[12] = snapshot.iStrafes;
	
	//reconstruct replay format since natives don't allow extracting invididual frames
	any replayData[8];
	replayData[0]  = vPos[0];
	replayData[1]  = vPos[1];
	replayData[2]  = vPos[2];
	replayData[3]  = vAng[0];
	replayData[4]  = vAng[1];
	replayData[5]  = buttons;
	replayData[6] = 0;
	replayData[7] = GetEntityMoveType(client);
	
	g_CurrentFrame[client] = float(PushArrayArray(g_hFrameList[client], data, sizeof(data)));
	g_CurrentFrame[client] = float(PushArrayArray(gA_SaveFrames[client], replayData, sizeof(replayData)));
}

stock void TeleportToFrame(int client, bool useVelocity = false, int buttons = 0)
{
	if(RoundToFloor(g_CurrentFrame[client]) >= GetArraySize(g_hFrameList[client])) return;
	
	any data[FRAMESIZE];
	GetArrayArray(g_hFrameList[client], RoundToFloor(g_CurrentFrame[client]), data, sizeof(data));
	
	float vPos[3];
	vPos[0] = data[0];
	vPos[1] = data[1];
	vPos[2] = data[2];
	
	float vAng[3];
	vAng[0] = data[3];
	vAng[1] = data[4];
	vAng[2] = 0.0;
	
	float vVel[3];
	if(useVelocity == true)
	{
		vVel[0] = data[6];
		vVel[1] = data[7];
		vVel[2] = data[8];
	}
	
	timer_snapshot_t snapshot;
	Shavit_SaveSnapshot(client, snapshot);
	
	snapshot.fCurrentTime     = view_as<float>(data[9]);
	snapshot.iGoodGains       = data[10];
	snapshot.iJumps      = data[11];
	snapshot.iStrafes = data[12];
	
	Shavit_SetReplayData(client, gA_SaveFrames[client]);
	Shavit_LoadSnapshot(client, snapshot);
	
	TeleportEntity(client, vPos, vAng, vVel);
}

public void Shavit_OnTimeIncrementPost(int client, float time, stylesettings_t stylesettings)
{
	//g_hFrameList[client].Clear();
	
	if(g_bTASMode[client])
	{
		g_bPaused[client]      = false;
		g_bFastForward[client] = false;
		g_bRewind[client]      = false;
	}
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data) 
{
	if(type == Zone_Start)
	{
		g_hFrameList[client].Clear();
		gA_SaveFrames[client].Clear();
		Shavit_SetPlayerPreFrame(client, 0);
	}
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float perfs)
{
	g_hFrameList[client].Clear();
	gA_SaveFrames[client].Clear();
}

void PauseTAS(int client)
{
	
	if(!Shavit_InsideZone(client, Zone_Start, Track_Main) && !Shavit_InsideZone(client, Zone_Start, Track_Bonus))
	{
		if(g_bPaused[client])
		{	
		
			
			if(RoundToFloor(g_CurrentFrame[client]) >= GetArraySize(g_hFrameList[client])) return;
			
			any data[FRAMESIZE];
			GetArrayArray(g_hFrameList[client], RoundToFloor(g_CurrentFrame[client]), data, sizeof(data));
			
			float vPos[3];
			vPos[0] = data[0];
			vPos[1] = data[1];
			vPos[2] = data[2];
			
			float vAng[3];
			vAng[0] = data[3];
			vAng[1] = data[4];
			vAng[2] = 0.0;
			
			float vVel[3];
			
			
			vVel[0] = data[6];
			vVel[1] = data[7];
			vVel[2] = data[8];
			
			
			timer_snapshot_t snapshot;
			Shavit_SaveSnapshot(client, snapshot);
			
			snapshot.fCurrentTime     = view_as<float>(data[9]);
			snapshot.iGoodGains       = data[10];
			snapshot.iJumps      = data[11];
			snapshot.iStrafes = data[12];
			
			
			
			Shavit_LoadSnapshot(client, snapshot);
			
			
			Shavit_ResumeTimer(client);
			g_bPaused[client] = false;
			SetEntityMoveType(client, MOVETYPE_WALK);
			TeleportEntity(client, vPos, vAng, vVel);
			
			int size = GetArraySize(g_hFrameList[client]);
			any data1[FRAMESIZE];
			for(int i = 0; i < size-1; i++) {
				GetArrayArray(g_hFrameList[client], i, data1, sizeof(data));
				if(view_as<float>(data1[9]) > view_as<float>(data[9]))
				{
					g_hFrameList[client].Erase(i);
					gA_SaveFrames[client].Erase(i);
					size = GetArraySize(g_hFrameList[client]);
					i -= 1;
				}
			}
			
			Shavit_SetReplayData(client, gA_SaveFrames[client]);
		}
		
		else
		{
			GetClientAbsOrigin(client, gF_PauseOrigin[client]);
			GetClientEyeAngles(client, gF_PauseAngles[client]);
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_PauseVelocity[client]);
			SetEntityMoveType(client, MOVETYPE_NONE);
			Shavit_PauseTimer(client);
			g_bPaused[client] = true;

		}
	} else 
	{
		Shavit_PrintToChat(client, "%t", "PauseStartZone", client);
	}
	
}

void OpenExitTASPrompt(int client)
{
	Menu menu = new Menu(Menu_ExitTAS);
	menu.SetTitle("Exit TAS Mode?");
	menu.AddItem("y", "Yes");
	menu.AddItem("n", "No");
	menu.ExitBackButton = true;
	menu.ExitButton     = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void setTimescale(int client, float timescale) 
{
	Shavit_SetClientTimescale(client, timescale);
}

public int Menu_ExitTAS(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if(StrEqual(sInfo, "y"))
		{
			Shavit_ChangeClientStyle(client, 0);
			ExitTASMode(client);
		}
		else if(StrEqual(sInfo, "n"))
		{
			OpenTASMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		delete menu;
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit || param2 == MenuCancel_ExitBack)
		{
			OpenTASMenu(client);
		}
	}
}


void ExitTASMode(int client)
{
	g_bTASMode[client] = false;
	
	if(g_bPaused[client] == true)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	
	g_bPaused[client]    = false;
	if(Shavit_GetTimerStatus(client) == Timer_Running) {
		Shavit_StopTimer(client, false);
	}
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	g_hFrameList[client].Clear();
	gA_SaveFrames[client].Clear();
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{ 
		InitializePlayerSettings(client);
		//SDKHook(client, SDKHook_PreThinkPost, Hook_PreThink); 
	}
	
	//SDKHook(client, SDKHook_PostThink, Hook_PostThink);
}

public void OnClientDisconnect(int client)
{
	if(g_bTASMode[client])
	{
		ExitTASMode(client);
	}
}

void InitializePlayerSettings(int client)
{
	
	
	
	g_bFastForward[client]       = false;
	g_bRewind[client]            = false;
	g_bPaused[client]            = false;
	g_fEditSpeed[client]         = 0.5;
	g_fTimescale[client]         = 0.9;
	g_fTimescale[client]        += 0.1;
	g_bTASMode[client]           = false;
	
	int style = Shavit_GetBhopStyle(client);
	doStyleCheck(client, style);
	
}

public void doStyleCheck(int client, int newstyle) {
	
	char sSpecial[128];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, 128);
	
	if(StrContains(sSpecial, "tas", false) != -1) 
	{
		g_bTASMode[client] = true;
		OpenTASMenu(client);
	} else 
	{
		g_bTASMode[client] = false;
		ExitTASMode(client);
	}
}



public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(g_bTASMode[client] == true && IsPlayerAlive(client))
	{
		if(g_bPaused[client] == true) // Players can rewind/fastforward when paused
		{
			float frameSkips;
			if(g_bFastForward[client])
			{
				frameSkips += g_fEditSpeed[client];
			}
			if(g_bRewind[client])
			{
				frameSkips -= g_fEditSpeed[client];
			}
			
			int size = GetArraySize(g_hFrameList[client]);
			
			if(size != 0 && frameSkips != 0)
			{
				g_CurrentFrame[client] += frameSkips;
				
				if(g_CurrentFrame[client] < 0)
				{
					g_CurrentFrame[client] = float(GetArraySize(g_hFrameList[client]) - 1);
				}
				else if(g_CurrentFrame[client] >= GetArraySize(g_hFrameList[client]))
				{
					g_CurrentFrame[client] = 0.0;
				}
				g_bHasEdited[client] = true;
			}
			
			if(!(g_LastButtons[client] & IN_JUMP) && (buttons & IN_JUMP))
			{
				if(g_bPaused[client] == true)
				{
					PauseTAS(client);
				}
				
				OpenTASMenu(client);
			}
			else
			{
				TeleportToFrame(client, false, buttons);
			}
		}
		else // Record run
		{
			if(!Shavit_InsideZone(client, Zone_Start, Track_Main) && !Shavit_InsideZone(client, Zone_Start, Track_Bonus))
			{	
				float fSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
				g_fSpeedTicksPassed[client] += fSpeed;
				if(g_fSpeedTicksPassed[client] >= 1.0)
				{
					g_fSpeedTicksPassed[client] -= 1.0;
					//bAA = true;
					g_fLastMove[client][0] = vel[0];
					g_fLastMove[client][1] = vel[1];
					g_fLastYaw[client] = angles[1];
					RecordFrame(client, buttons);
				}
				
			// Fix boosters
				if(GetEntityFlags(client) & FL_BASEVELOCITY)
				{
					float vBaseVel[3];
					Entity_GetBaseVelocity(client, vBaseVel);
					
					if(vBaseVel[2] > 0)
					{
						vBaseVel[2] *= 1.0 / GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
					}
					
					Entity_SetBaseVelocity(client, vBaseVel);
				}
				
				//we need to throttle this because csgo can't handle laggedMovementValue very well..
				if(g_bAutoStrafer[client]) {
					
					if(g_fTimescale[client] != 1.0) {
						int ignore_amount = RoundFloat(1.0/g_fTimescale[client]);
						
						if ( ++g_nIgnoredCmds[client] < ignore_amount )
						{
							
							return Plugin_Continue;
						}
					}
					
					ApplyAutoStrafe(client, buttons, vel, angles);
					g_nIgnoredCmds[client] = 0;
				}
				
			// Client just unpaused and is going through the slow-motion start so they have time to react
				if(g_bSpeedUpFromUnpause[client])
				{				
					fSpeed += 0.01;
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
					if(fSpeed >= g_fTimescale[client])
					{
						g_bSpeedUpFromUnpause[client] = false;
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fTimescale[client]);
					}
				}
				
			// Fix a bug
				if(GetEntityMoveType(client) == g_pauseMoveType)
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
				}
			}
		}
	}
	g_LastButtons[client] = buttons;
	return Plugin_Changed;
}