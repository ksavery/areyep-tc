// AReyeP & MCS games, keyed by the extension tools/stage.py gives their data files.
//
// Family: the shared VSWAP / GraphicMaps / TileCodes set the game uses
// MapBase: map numbers are MapBase + slot + 1, so MAPINFO levelnums are unique per game
// (Wolfendoom keeps Wolf3D's episodes: MapBase + episode * 100 + floor, 5101-5610)
class AReyePGame
{
	static clearscope bool, String, String, int Info(String ext)
	{
		ext = ext.MakeUpper();

		if (ext == "SR1") { return true, "SR", "Spear Resurrection", 2000; }
		if (ext == "SR2") { return true, "SR", "Spear Resurrection (New Maps)", 3000; }
		if (ext == "EOD") { return true, "EOD", "Spear: End of Destiny", 4000; }
		if (ext == "WFD") { return true, "WFD", "Wolfendoom", 5000; }

		return false, "", "", -1;
	}

	static clearscope bool IsGame(String ext)
	{
		return MapBase(ext) > -1;
	}

	static clearscope String Family(String ext)
	{
		bool found;
		String family;
		[found, family] = Info(ext);
		return family;
	}

	static clearscope String Title(String ext)
	{
		bool found;
		String family, title;
		[found, family, title] = Info(ext);
		return title;
	}

	static clearscope int MapBase(String ext)
	{
		bool found;
		String family, title;
		int base;
		[found, family, title, base] = Info(ext);
		return base;
	}

	// SR and EoD run on MCS's Spear engine; Wolfendoom is a Wolfenstein 3D mod
	static clearscope bool IsMCS(String family)
	{
		return family == "SR" || family == "EOD";
	}

	// MAPINFO level number of a map slot (0-based, as in the GAMEMAPS file)
	static clearscope int MapNumber(String ext, int slot)
	{
		int base = MapBase(ext);
		if (Family(ext) == "WFD") { return base + (slot / 10 + 1) * 100 + slot % 10 + 1; }
		return base + slot + 1;
	}

	// The 0-based slot of a parsed map, -1 outside AReyeP games
	static clearscope int SlotOf(ParsedMap pm)
	{
		if (!pm || !IsGame(pm.extension)) { return -1; }

		int n = pm.mapnum - MapBase(pm.extension);
		if (Family(pm.extension) == "WFD") { return (n / 100 - 1) * 10 + n % 100 - 1; }
		return n - 1;
	}

	// Family of the parsed map being played (or about to be), "" outside AReyeP games
	static clearscope String CurrentFamily()
	{
		MapHandler handler = MapHandler.Get();
		if (!handler) { return ""; }

		ParsedMap pm = handler.curmap ? handler.curmap : handler.queuedmap;
		return pm ? Family(pm.extension) : "";
	}

	// 0-based map slot of the parsed map being played, -1 outside AReyeP games
	static clearscope int CurrentSlot()
	{
		MapHandler handler = MapHandler.Get();
		if (!handler) { return -1; }

		return SlotOf(handler.curmap ? handler.curmap : handler.queuedmap);
	}

	// The TC asks for Wolf3D songs by name for its title, menus and screens; the
	// AReyeP games play their own (StartCPMusic, SR image 0x9a41, EoD 0xccb2):
	// DemoLoop's title song, the control panel's menu song, the level-complete
	// and high score song, Victory's, the ending's. Before a game is picked, SR's.
	static clearscope String ModMusic(String song)
	{
		if (song == "" || song.Left(5) ~== "SRMUS" || song.Left(6) ~== "EODMUS" || song.Left(6) ~== "WFDMUS") { return ""; }

		String family = CurrentFamily();
		if (family == "") { family = Family(g_modgame); }
		if (family == "") { family = "SR"; }
		if (family == "WFD")
		{
			// WOLFDOOM.WFD keeps the Wolf3D AUDIOT order (STARTMUSIC 261).
			static const String names[] = { "CORNER", "DUNGEON", "WARMARCH", "GETTHEM", "HEADACHE", "HITLWLTZ", "INTROCW3", "NAZI_NOR", "NAZI_OMI", "POW", "SALUTE", "SEARCHN", "SUSPENSE", "VICTORS", "WONDERIN", "FUNKYOU", "ENDLEVEL", "GOINGAFT", "PREGNANT", "ULTIMATE", "NAZI_RAP", "ZEROHOUR", "TWELFTH", "ROSTER", "URAHERO", "VICMARCH", "PACMAN" };
			song = song.MakeUpper();
			if (song == "INTRO") { song = "NAZI_NOR"; }
			for (int i = 0; i < names.Size(); i++) { if (song == names[i]) { return String.Format("WFDMUS%02i", i); } }
			return "WFDMUS14";
		}
		bool eod = family == "EOD";

		int n = eod ? 2 : 3; // menu
		song = song.MakeUpper();
		if (song == "XTOWER2" || song == "NAZI_NOR" || song == "INTRO") { n = eod ? 17 : 15; }
		else if (song == "ENDLEVEL" || song == "ROSTER" || song == "XAWARD") { n = eod ? 16 : 27; }
		else if (song == "URAHERO") { n = eod ? 15 : 26; }
		else if (song == "XTHEEND") { n = eod ? 4 : 6; }

		return String.Format(eod ? "EODMUS%02i" : "SRMUS%02i", n);
	}

	// Where Wolf3D fills with its teal, MCS's games show their rocky backdrop
	// (VGAGRAPH 3, the menus' MENUBLUE): tiled over the given screen rectangle.
	// False outside the AReyeP games, so the caller fills as before.
	static ui bool DrawBackdrop(int x, int y, int w, int h)
	{
		if (!MenuFamily() && !InPicker()) { return false; }
		if (w <= 0 || h <= 0) { return true; }

		TextureID tex = TexMan.CheckForTexture("MENUBLUE", TexMan.Type_Any);
		if (!tex.IsValid()) { return false; }

		double th = Screen.GetHeight(), tw = th * 1.6; // one 320x200 picture a screen tall
		for (double tx = 0; tx < Screen.GetWidth(); tx += tw)
		{
			Screen.DrawTexture(tex, false, tx, 0, DTA_DestWidthF, tw, DTA_DestHeightF, th,
				DTA_ClipLeft, x, DTA_ClipTop, y, DTA_ClipRight, x + w, DTA_ClipBottom, y + h);
		}

		return true;
	}

	// The game picker (or no game picked yet) is dressed as the AReyeP games,
	// whichever game was picked last (Wolfendoom keeps the TC's Wolf3D look)
	static ui bool InPicker()
	{
		return g_sod < 0 || Menu.GetCurrentMenu() is "GameMenu";
	}

	// Menu pictures: End of Destiny's own (EOD_<name>, tools/assets.py) while
	// it's the game, else the TC's names (SR's art in the AReyeP data)
	static clearscope TextureID MenuTex(String name, int usetype = TexMan.Type_Any)
	{
		String family = CurrentFamily();
		if (family == "") { family = Family(g_modgame); }
		if (family == "EOD" || family == "WFD")
		{
			TextureID own = TexMan.CheckForTexture((family == "EOD" ? "EOD_" : "WD_") .. name, usetype);
			if (own.IsValid()) { return own; }
		}

		return TexMan.CheckForTexture(name, usetype);
	}

	// The menus look like the game being played, else the one picked
	static ui bool MenuFamily()
	{
		String family = CurrentFamily();
		if (family == "") { family = Family(g_modgame); }
		return family == "SR" || family == "EOD";
	}

	// MCS's control panel windows are grey where Spear's are blue (DrawWindow,
	// SR image 0x8eba, EoD 0xc0f7: palette 0x17 inside, outlined 0xEC on the top
	// and left and 0x1C on the bottom and right). 0x17 is also the TC's menu text
	// colour, so the fill here is the darker 0x1E and the bevel 0xEC / 0x19.
	// False outside the games.
	static ui bool, Color, Color, Color WindowColors()
	{
		if (!MenuFamily() && !InPicker()) { return false, 0, 0, 0; }
		return true, 0x2C2C2C, 0x404040, 0x707070;
	}

	// The ending sequence menu for the game being played
	static clearscope Name FinaleMenu()
	{
		return CurrentFamily() == "EOD" ? 'EoDFinale' : 'SoDFinale';
	}

	// Points for a kill where the games differ from Wolf3D: MCS's KillActor
	// (SR image 0x10f00, EoD 0x14bcd). -1 means none at all.
	static int KillScore(Actor mo, String family)
	{
		if (family == "SR")
		{
			if (mo is "SRSuicideClone") { return 100; }
			return 0;
		}

		if (family != "EOD") { return 0; }

		if (mo is "SRSuicideClone" || mo is "EoDSpectreFlame") { return -1; }
		if (mo is "EoDTurret") { return 800; }
		if (mo is "EoDGhostFlame" || mo is "EoDSnowman") { return 500; }
		if (mo is "EoDHeinrich" || mo is "TransGrosse") { return 7000; }
		if (mo is "EoDUltraClone" || mo is "UberMutant") { return 3000; } // the Robot too
		if (mo is "BarnacleWilhelm") { return 6000; }
		if (mo is "DeathKnight") { return 8000; }
		if (mo is "AngelOfDeath") { return 10000; }
		if (mo is "Guard") { return 200; }
		if (mo is "Officer") { return 400; }
		if (mo is "Mutant" || mo is "SS") { return 500; }

		return 0;
	}

	// Chase speed, set on first sight (FirstSighting: SR image 0x11830, EoD
	// 0x156a6), in TC units of 512 Wolf speed. 0 keeps the TC's.
	static double ChaseSpeed(Actor mo, String family)
	{
		bool eod = family == "EOD";
		if (family != "SR" && !eod) { return 0; }

		if (mo is "SRSuicideClone") { return eod ? 6 : 0; } // SR: the TC dog's
		if (mo is "EoDSpectreFlame" || mo is "EoDSnowman") { return 800 / 512.; }
		if (mo is "EoDUltraClone" || mo is "EoDRobot" || mo is "EoDHeinrich") { return 4; }
		if (mo is "Guard" || mo is "SS") { return 4; }
		if (mo is "Officer") { return 5; }
		if (mo is "Mutant") { return 3; }
		if (mo is "AngelOfDeath") { return 3; }
		if (mo is "TransGrosse") { return 0x780 / 512.; }
		if (mo is "UberMutant") { return 5; }
		if (mo is "BarnacleWilhelm") { return 4; }
		if (mo is "DeathKnight") { return 0x900 / 512.; }
		if (mo is "SRAngelGhost") { return 3; }
		if (mo is "SRBossGhost4") { return 0x280 / 512.; }
		if (mo is "SRBossGhost5") { return 0x300 / 512.; }
		if (mo is "SRBossGhost3") { return 0x380 / 512.; }
		if (mo is "SRBossGhost1") { return 0x400 / 512.; }
		if (mo is "SRBossGhost2") { return 0x484 / 512.; }
		if (mo is "SRBossGhost6") { return 0x504 / 512.; }

		return 0;
	}

	// Enemy hit points by skill, from MCS's starthitpoints tables: SR editor's
	// SPEAR.EXE (unpacked image offset 0x3AB66, 24 per skill) and EoD's (DS:0x1D04,
	// 16 per skill). Classes they don't cover keep the TC's values.
	static int, int, int, int, bool SkillHealth(Actor mo, String family)
	{
		bool eod = family == "EOD";
		if (family != "SR" && !eod) { return 0, 0, 0, 0, false; }

		// EoD's SpawnBoss (image 0x1ad63) takes these from the same table
		if (eod)
		{
			if (mo is "EoDSpectreFlame") { return 5, 5, 5, 5, true; }
			if (mo is "EoDGhostFlame") { return 25, 25, 25, 25, true; }
			if (mo is "EoDSnowman") { return 25, 50, 75, 100, true; }
			if (mo is "EoDHeinrich") { return 1500, 1500, 1500, 1500, true; }
			if (mo is "EoDRobot") { return 1000, 1000, 1000, 1000, true; }
			if (mo is "EoDUltraClone") { return 1400, 1400, 1400, 1400, true; }
			if (mo is "EoDTurret") { return 384, 384, 384, 384, true; } // set outright, not from the table
		}

		if (mo is "SRSuicideClone") { return eod ? 1 : 20, eod ? 1 : 20, eod ? 1 : 35, eod ? 1 : 50, true; }
		if (mo is "Guard") { return 40, 45, 55, 65, true; }
		if (mo is "Officer") { return 80, 85, 95, 105, true; }
		if (mo is "SS") { return 140, 155, 165, 175, true; }
		if (mo is "Mutant") { return 80, 90, 105, 115, true; }
		if (mo is "AngelOfDeath") { return 2150, 2250, 2350, 3825, true; }
		if (mo is "TransGrosse") { return 1450, 1550, 1650, 1750, true; } // Grau Adler
		if (mo is "UberMutant") { return 1150, 1250, 1350, 1450, true; } // Super Clone
		if (mo is "BarnacleWilhelm") { return 1250, 1350, 1450, 1550, true; } // Hiroshima Hyoto / Otto von Thugg
		if (mo is "DeathKnight") { return 1650, 1750, 1850, 2925, true; } // Baron von Schmitt
		if (mo is "WolfSpectre") { return 5, eod ? 5 : 10, eod ? 5 : 15, eod ? 5 : 25, true; }

		return 0, 0, 0, 0, false;
	}

	// An Artefact of Displacement was used on this map (SRRules)
	static clearscope bool Warped()
	{
		SRRules rules = SRRules.Get();
		return rules && rules.warped;
	}

	// GAMEMAPS names are fixed 16-byte fields: cut at the first NUL and trim padding
	static clearscope String CleanName(String name)
	{
		int len = 0;
		while (len < int(name.Length()) && name.ByteAt(len) >= 0x20) { len++; }

		return ZScriptTools.Trim(name.Left(len));
	}

	// Solid ceiling/floor palette colours for a map slot, or -1, -1 if the game
	// doesn't override them. SR: MCS's VGAClearScreen (SPEAR.EXE, SOD2SDL.EXE)
	// reads the ceiling from two 23-entry tables (normal, and after the player
	// has used an Artefact of Displacement); the floor is grey 0x19, except
	// black on map 0 always and on maps 10, 13 and 22 after a teleport.
	static clearscope int, int Flats(String ext, int slot, bool warped)
	{
		if (Family(ext) == "SR")
		{
			static const int ceilings[] = { 0x00, 0x4F, 0x6F, 0xDF, 0xBF, 0xAF, 0x2D, 0xDE, 0x1E, 0xDD, 0xA0, 0x9F, 0xE5, 0x7F, 0x2E, 0xEE, 0x7F, 0x1D, 0x6F, 0x2F, 0x1D, 0xDC, 0xA0 };
			static const int warpedceilings[] = { 0x00, 0x4F, 0x6F, 0xDF, 0xBF, 0xAF, 0x2D, 0xDE, 0x1E, 0xDD, 0x00, 0x9F, 0xE5, 0x00, 0x2E, 0xDE, 0x1D, 0x1D, 0x6F, 0x2F, 0x00, 0x85, 0x00 };

			slot = clamp(slot, 0, 22);

			int floor = 0x19;
			if (slot == 0 || (warped && (slot == 10 || slot == 13 || slot == 22))) { floor = 0x00; }

			return warped ? warpedceilings[slot] : ceilings[slot], floor;
		}

		return -1, -1;
	}

	// How many tiles a pushwall may slide. SR's 2011 mapset was made for the SDL
	// engine, whose pushwalls slide until something stops them (its secret runs
	// are 3 and 4 tiles long); the DOS games stop at 2 like Wolf3D (MovePWalls,
	// SR image 0x13e50, EoD 0x19282)
	static clearscope int PushwallMoves(int setting)
	{
		MapHandler handler = MapHandler.Get();
		ParsedMap pm = handler ? (handler.curmap ? handler.curmap : handler.queuedmap) : null;
		if (pm && pm.extension ~== "SR2") { return 64; }

		return setting;
	}

	// Actor codes End of Destiny sets in wall tiles, which stay walls: switches
	// (384-388) and fire-shooting walls (400-415)
	static clearscope bool WallActor(String ext, int code)
	{
		if (Family(ext) != "EOD") { return false; }
		return (code >= 384 && code <= 388) || (code >= 400 && code <= 415);
	}

	// EoD's row 0 cells 4, 5 (6, 7 after a teleport) hold the level's sky modes;
	// any but 0 puts the star sky in place of the ceiling (DrawStarSky, image
	// 0x4faa, called from 0x59af)
	static bool EoDSky(ParsedMap map, bool warped)
	{
		if (!map || map.planes[0].Size() < 8) { return false; }

		int at = warped ? 6 : 4;
		return map.planes[0][at] > 0 || map.planes[0][at + 1] > 0;
	}

	// EoD's "FlexDesign" row 0: (0,0)/(1,0) floor/ceiling texture, (2,0)/(3,0)
	// the pair used once the player has teleported. A code is either a floor/
	// ceiling selector 0xF0-0x10F (VSWAP pages 192-223) or a wall code, whose
	// light page is used. Returns "" when the map has no texture there.
	static String EoDFlatTexture(ParsedMap map, bool ceiling, bool warped)
	{
		if (!map || map.planes[0].Size() < 4) { return ""; }

		int code = map.planes[0][(warped ? 2 : 0) + (ceiling ? 1 : 0)];
		int page = -1;
		if (code >= 0xF0 && code <= 0x10F) { page = 192 + code - 0xF0; }
		else if (code >= 0x01 && code <= 0x59) { page = (code - 1) * 2; }

		return page < 0 ? "" : String.Format("EoD/Wall%04i", page);
	}
}

