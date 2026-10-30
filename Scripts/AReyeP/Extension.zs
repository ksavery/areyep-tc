// The AReyeP games' hooks into the TC (Scripts/Extensions/GameExtension.zs in
// the TC): Spear Resurrection (SR1, SR2) and End of Destiny (EOD) as games of
// their own, with MCS's screens, rules and status bars; and Wolfendoom (WFD), a
// Wolfenstein 3D mod, which keeps the TC's Wolf3D look and rules.
class AReyePExtension : GameExtension
{
	// MCS's in-game message (End of Destiny): one line at a time, replaced by the
	// next (SetMessage EoD image 0x61b2, drawn 0x61e6)
	ui String message;
	ui Color messagecolor;
	ui int messageuntil;

	ui Array<bool> held; // scan codes held, for AReyeP and MCS's cheats (MCSCheats)
	ui ClassicMessageBox cheatmessage;

	// Games ------------------------------------------------------------------

	override bool Handles(String ext) { return AReyePGame.IsGame(ext); }

	override void ListGames(in out Array<String> exts)
	{
		exts.Push("SR1");
		exts.Push("SR2");
		exts.Push("EOD");
		exts.Push("WFD");
	}

	override bool IsDefault() { return true; } // the TC's screens are AReyeP's before a game is picked

	override String DataSet(String ext) { return AReyePGame.Family(ext); }
	override String Title(String ext) { return AReyePGame.Title(ext); }
	override int GameType(String ext) { return AReyePGame.Family(ext) == "WFD" ? 0 : 1; } // Wolf3D or Spear rules; tables come from the game's family
	override int MapNumber(String ext, int slot) { return AReyePGame.MapNumber(ext, slot); }

	static clearscope int Slot(ParsedMap map)
	{
		return AReyePGame.SlotOf(map);
	}

	// Map building ---------------------------------------------------------------

	override void PrepareMap(ParsedMap map)
	{
		if (AReyePGame.Family(map.extension) == "EOD") { EoDMap.Prepare(map); }
	}

	override bool WallActor(String ext, int code) { return AReyePGame.WallActor(ext, code); }

	override int, int, String, String, bool LevelFlats(String game, ParsedMap map)
	{
		bool warped = AReyePGame.Warped();

		if (AReyePGame.Family(game) == "SR")
		{
			int ceiling, floor;
			[ceiling, floor] = AReyePGame.Flats(game, Slot(map), warped);
			return ceiling, floor, "", "", false;
		}

		// Wolfendoom: Wolf3D's ceilings by floor (vgaCeiling, WOLFDOOM.EXE image
		// 0x3da10, unchanged from Wolf3D); the TC would look them up by levelnum
		if (AReyePGame.Family(game) == "WFD")
		{
			static const int wdceilings[] = {
				0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0xBF, 0x4E, 0x4E, 0x4E, 0x1D, 0x8D, 0x4E, 0x1D, 0x2D, 0x1D, 0x8D,
				0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x2D, 0xDD, 0x1D, 0x1D, 0x98, 0x1D, 0x9D, 0x2D, 0xDD, 0xDD, 0x9D, 0x2D, 0x4D, 0x1D, 0xDD,
				0x7D, 0x1D, 0x2D, 0x2D, 0xDD, 0xD7, 0x1D, 0x1D, 0x1D, 0x2D, 0x1D, 0x1D, 0x1D, 0x1D, 0xDD, 0xDD, 0x7D, 0xDD, 0xDD, 0xDD };
			return wdceilings[clamp(Slot(map), 0, 59)], -1, "", "", false;
		}

		// End of Destiny textures its floors and ceilings from the map's row 0
		String floortex = AReyePGame.EoDFlatTexture(map, false, warped);
		String ceilingtex = AReyePGame.EoDFlatTexture(map, true, warped);

		// Sky levels: MCS's stars in place of the ceiling, under eod4sdl's clouds
		bool sky = AReyePGame.EoDSky(map, warped);
		if (sky)
		{
			TextureID stars = TexMan.CheckForTexture("EODSKY", TexMan.Type_Any);
			TextureID clouds = TexMan.CheckForTexture("EODCLOUD", TexMan.Type_Any);
			if (stars.IsValid()) { level.ChangeSky(clouds.IsValid() ? clouds : stars, stars); }
			level.skyspeed1 = 0.002;
			level.skyspeed2 = 0;
		}

		return -1, -1, ceilingtex, floortex, sky;
	}

	// A dev "+areyep_startmap GAMEMAPS.SR1:Black_Forest" starts on that map;
	// Wolfendoom starts on the first floor of the episode picked (WDEpisodeMenu)
	override ParsedMap StartingMap(MapHandler handler)
	{
		if (!areyep_startmap.length())
		{
			if (AReyePGame.Family(g_modgame) != "WFD") { return null; }

			int episode = clamp(areyep_wdepisode, 1, 6);
			return handler.parsedmaps.GetMapDataByNumber(AReyePGame.MapNumber("WFD", (episode - 1) * 10), "GAMEMAPS.WFD");
		}

		ParsedMap start;

		String target = areyep_startmap;
		target.Substitute("_", " ");

		Array<String> parts;
		target.Split(parts, ":");
		for (int m = 0; parts.Size() > 1 && m < handler.parsedmaps.maps.Size(); m++)
		{
			ParsedMap pm = handler.parsedmaps.maps[m];
			if (pm.datafile.path ~== parts[0] && AReyePGame.CleanName(pm.mapname) ~== parts[1]) { start = pm; }
		}
		if (!start) { console.printf("areyep_startmap: no map '%s'", areyep_startmap); }

		CVar startmap = CVar.FindCVar("areyep_startmap");
		if (startmap) { startmap.SetString(""); }

		return start;
	}

	// Doors and pushwalls ---------------------------------------------------------

	// End of Destiny remote pushwalls only move from their switch, and its
	// automatic doors only for the player walking up to them
	override bool AllowDoorUse(String game, Line ln, Actor activator)
	{
		if (EoDMap.IsRemotePushwall(ln.Args[0])) { return false; }
		if (activator && activator.player && EoDAutoDoors.IsAutoDoor(ln.Args[0])) { return false; }

		return true;
	}

	// End of Destiny's own samples (OpenDoor/CloseDoor, image 0x18a41): rusted
	// doors (90 + 2 * 6) keep the old ones, wooden doors creak (SNDSEQ)
	override int DoorSound(String game, PolyobjectHandle po, bool pushwall)
	{
		if (AReyePGame.Family(game) == "WFD") { return pushwall ? 10 : 8; }
		if (AReyePGame.Family(game) != "EOD") { return -1; }
		if (pushwall) { return 7; }

		int code = MapHandler.TileAt(po.StartSpotPos);
		int lock = code >= 90 && code <= 105 ? (code - 90) / 2 : 0;

		return lock == 6 ? 1 : lock == 7 ? 6 : 5;
	}

	override int PushwallMoves(String game, int setting) { return AReyePGame.PushwallMoves(setting); }

	// Actors and rules ------------------------------------------------------------

	override void SetupEnemy(String game, ClassicBase mo)
	{
		String family = AReyePGame.Family(game);

		int h0, h1, h2, h3;
		bool found;
		[h0, h1, h2, h3, found] = AReyePGame.SkillHealth(mo, family);
		if (found) { mo.skillhealth0 = h0; mo.skillhealth1 = h1; mo.skillhealth2 = h2; mo.skillhealth3 = h3; }

		int score = AReyePGame.KillScore(mo, family);
		if (score) { mo.scoreamt = max(score, 0); }

		double chase = AReyePGame.ChaseSpeed(mo, family);
		if (chase > 0) { mo.Speed = chase; }
	}

	// MCS's messages for the TC's pistol and machine gun (EoD shows them, SR prints none)
	override String PickupMessage(String game, Inventory item)
	{
		if (item.PickupMsg.length() || !AReyePGame.IsMCS(AReyePGame.Family(game))) { return ""; } // the item's own; Wolf3D prints none

		if (item is "WolfMachineGun") { return "You picked up a machinegun"; }
		if (item is "WolfPistol") { return "You picked up a pistol"; }

		return "";
	}

	// The AReyeP games' Spear: SR's level 18 (slot 17, both mapsets), End of
	// Destiny's Heinrich (slot 24)
	override int SpearEndsLevel(String game, ParsedMap map)
	{
		String family = AReyePGame.Family(game);
		int slot = Slot(map);

		return (family == "SR" && slot == 17) || (family == "EOD" && slot == 24);
	}

	// Music and screens -------------------------------------------------------------

	override String Music(String game, String song) { return AReyePGame.ModMusic(song); }

	override bool DrawBackdrop(String game, int x, int y, int w, int h) { return AReyePGame.DrawBackdrop(x, y, w, h); }

	override bool, Color, Color, Color WindowColors(String game)
	{
		bool custom;
		Color fill, top, bottom;
		[custom, fill, top, bottom] = AReyePGame.WindowColors();
		return custom, fill, top, bottom;
	}

	// MCS's skill faces carry the rock backdrop in their pictures: no window there
	// Below, an empty game is the game picker (AReyeP's look); Wolfendoom keeps the TC's Wolf3D look
	static bool MCSLook(String game) { return AReyePGame.IsMCS(AReyePGame.Family(game)); }

	override bool MenuBox(String game, Menu current) { return !(MCSLook(game) && current is "SkillMenu"); }

	override bool ReadThis(String game) { return MCSLook(game) || AReyePGame.Family(game) == "WFD"; }

	override int DisabledColor(String game) { return MCSLook(game) ? Font.FindFontColor("AReyePMenuDisable") : -1; }

	override TextureID MenuTexture(String game, String name, int usetype) { return AReyePGame.MenuTex(name, usetype); }

	override int FadeColor(String game) { return MCSLook(game) ? 0x0 : -1; } // the rocky backdrop covers the screen; MCS fades through black

	// MCS's intermission fills with palette 0x1D, a dark grey, where Wolf3D has teal
	// (LevelCompleted's VWB_Bar: SR image 0xa04e, EoD the same)
	override int IntermissionColor(String game) { return MCSLook(game) ? 0x383838 : -1; }

	override Name FinaleMenu(String game) { return AReyePGame.FinaleMenu(); }

	override int Episode(String game) { return MCSLook(game) || AReyePGame.Family(game) == "WFD" ? 9 : -1; } // MAPINFO's LEVEL episode (Wolfendoom picks its episode in WDEpisodeMenu first)

	// Straight on to the game picker: the TC's Wolf3D intro (LoadScreen) isn't part of the AReyeP games
	override bool SkipIntro(String game) { return true; }

	override String IntroGraphic(String game, String which)
	{
		if (AReyePGame.Family(game) == "WFD")
		{
			if (which == "startup" || which == "startup2" || which == "title") { return "WDTITLE"; }
			if (which == "warning") { return "WDSTART"; }
			if (which == "credits") { return "WDCREDIT"; }
			return "";
		}

		if (AReyePGame.Family(game) == "EOD")
		{
			// EoD's sign-on is only the 88x64 "AReyeP and MCS present": open on the title
			if (which == "startup" || which == "startup2" || which == "title") { return "EODTITLE"; }
			if (which == "credits") { return "EODCREDT"; }
			if (which == "warning") { return "EODPRES"; }
			return "";
		}

		// SR's, also before a game is picked
		if (which == "startup" || which == "startup2") { return "SRSTART"; }
		if (which == "title") { return "SRTITLE"; }
		if (which == "credits") { return "SRCREDIT"; }
		if (which == "warning") { return "SRPRES"; }
		return "";
	}

	// MCS's sign-on: "AReyeP and MCS present..." on black, where Spear has its
	// PG-13 notice (SR image 0xa2f9, EoD 0xd464)
	override bool DrawIntroScreen(String game, String which, TextureID tex)
	{
		if (which != "warning" || AReyePGame.Family(game) == "WFD") { return false; }

		screen.DrawTexture(tex, false, 110, 60, DTA_320x200, true);
		return true;
	}

	// Status bar and messages ---------------------------------------------------------

	ui void DrawWDBar(ClassicStatusBar sb, ParsedMap map, int points, int lives)
	{
		// Wolfendoom's VGAGRAPH 86, 91-132 uses Wolf3D's 320x40 bar layout.
		sb.DrawImage("WDBAR", (160, 198), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_CENTER_BOTTOM);
		PlayerInfo player = sb.CPlayer;
		if (points < 0) { points = sb.GetAmount("Score"); }
		if (lives < 0) { lives = LifeHandler.GetLives(player.mo); }
		DrawNumber(sb, Slot(map) % 10 + 1, 16, 2, "WD");
		DrawNumber(sb, points % 1000000, 48, 6, "WD");
		DrawNumber(sb, max(lives, 0), 112, 1, "WD");
		DrawNumber(sb, player.health, 168, 3, "WD");
		DrawNumber(sb, player.mo.CountInv("WolfClip"), 208, 3, "WD");
		sb.DrawMugShot(136, 164, face:"WDF", accuracy:7);
		sb.DrawImage(player.mo.FindInventory("YellowKey", true) ? "WDYKEY" : "WDNOKEY", (241, 167), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
		sb.DrawImage(player.mo.FindInventory("BlueKey", true) ? "WDBKEY" : "WDNOKEY", (241, 183), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
		Weapon w = player.ReadyWeapon;
		String pic = w is "WolfKnife" ? "WDKNIFE" : w is "WolfMachineGun" ? "WDMGUN" : w is "WolfChaingun" ? "WDCGUN" : "WDPISTOL";
		sb.DrawImage(pic, (256, 167), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
	}

	override bool DrawStatusBar(String game, ClassicStatusBar sb, int points, int lives)
	{
		ParsedMap map = MapHandler.GetCurrentMap();
		if (!map) { return false; }
		if (AReyePGame.Family(game) == "WFD") { DrawWDBar(sb, map, points, lives); return true; }
		if (!MCSLook(game)) { return false; }

		DrawBar(sb, map, points, lives, AReyePGame.Family(game) == "EOD" ? "EOD" : "SR");
		return true;
	}

	// SR's and EoD's status bars (VGAGRAPH chunk 90, pieces named in
	// tools/assets.py; TEXTURES.SR / TEXTURES.EOD give them <prefix>BAR,
	// <prefix>NUMn ...): the same picture numbering and number boxes. Positions
	// are the DOS LatchNumber/LatchDrawPic spots, relative to the bar's top left.
	// SR has a second ammo box and a lit weapon strip; EoD one ammo box for the
	// weapon in hand and a picture of it.
	ui void DrawBar(ClassicStatusBar sb, ParsedMap map, int points, int lives, String prefix)
	{
		bool eod = prefix == "EOD";
		sb.DrawImage(prefix .. "BAR", (160, 198), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_CENTER_BOTTOM);

		PlayerInfo player = sb.CPlayer;
		if (points < 0) { points = sb.GetAmount("Score"); }
		if (lives < 0) { lives = LifeHandler.GetLives(player.mo); }

		DrawNumber(sb, Slot(map) + 1, 16, 2, prefix);
		DrawNumber(sb, points % (eod ? 10000000 : 1000000), 48, eod ? 7 : 6, prefix);
		DrawNumber(sb, clamp(lives, 0, 9), 112, eod ? 2 : 1, prefix);
		DrawNumber(sb, player.health, 168, 3, prefix);

		Weapon w = player.ReadyWeapon;
		if (eod)
		{
			// Ammo of the weapon in hand (none for the knife and the Spear)
			if (w && w.AmmoType1) { DrawNumber(sb, player.mo.CountInv(w.AmmoType1), 208, 3, prefix); }
		}
		else
		{
			DrawNumber(sb, player.mo.CountInv("WolfClip"), 208, 3, prefix);
			DrawNumber(sb, player.mo.CountInv("SRAmmo2"), 264, 3, prefix);
		}

		sb.DrawMugShot(136, 162, face:eod ? "EOF" : "SRF", accuracy:7); // all seven health rows of faces

		// Gold, bronze, blood and elevator keys in a 2x2 block
		static const Class<Key> keys[] = { "YellowKey", "BlueKey", "RedKey", "GreenKey" };
		for (int k = 0; k < 4; k++)
		{
			String pic = player.mo.FindInventory(keys[k], true) ? String.Format("%sKEY%i", prefix, k + 1) : prefix .. "NOKEY";
			sb.DrawImage(pic, (240 + (k / 2) * 8, 162 + (k % 2) * 16), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
		}

		if (eod)
		{
			// knife pistol MG Mk3 Mk4 rifle launcher Spear (eod4sdl KNIFEPIC + weapon)
			static const Class<Weapon> weapons[] = { "WolfKnife", "WolfPistol", "WolfMachineGun", "SRMk3", "SRMk4", "EoDRifle", "WolfRocketLauncher", "EoDSpear" };
			for (int n = weapons.Size() - 1; w && n >= 0; n--)
			{
				if (!(w is weapons[n])) { continue; }

				sb.DrawImage(String.Format("EODWPN%i", n), (264, 176), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
				break;
			}
			return;
		}

		// Weapon strip 1-5 with the selected slot lit
		int wslot = 0;
		if (w) { wslot = clamp(w.SlotNumber, 0, 5); }
		sb.DrawImage(String.Format("SRWPN%i", wslot), (303, 162), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
	}

	// Right-aligned digits in a box of 'width' characters starting at bar column x
	ui void DrawNumber(ClassicStatusBar sb, int value, int x, int width, String prefix)
	{
		String digits = String.Format("%i", max(value, 0));
		int len = min(digits.Length(), width);
		for (int c = 0; c < len; c++)
		{
			sb.DrawImage(String.Format("%sNUM%c", prefix, digits.ByteAt(digits.Length() - len + c)), (x + (width - len + c) * 8, 174), StatusBarCore.DI_SCREEN_CENTER_BOTTOM | StatusBarCore.DI_ITEM_LEFT_TOP);
		}
	}

	// Red (palette 0x35) by default, yellow (0x46) for super secrets; at (1, 1) of
	// the 320x200 screen over a black shadow one pixel down and right
	ui void ShowMessage(String text, int seconds = 5, Color clr = 0xFF4040)
	{
		message = text;
		messagecolor = clr;
		messageuntil = gametic + seconds * GameTicRate;
	}

	override void DrawOverlay(String game, ClassicStatusBar sb)
	{
		if (gametic >= messageuntil || !message.length() || automapactive) { return; }

		screen.DrawText(SmallFont, Font.CR_UNTRANSLATED, 2, 2, message, DTA_320x200, true, DTA_FillColor, 0);
		screen.DrawText(SmallFont, Font.CR_UNTRANSLATED, 1, 1, message, DTA_320x200, true, DTA_FillColor, messagecolor);
	}

	// MCS's games print nothing in play but End of Destiny's own messages (SR none
	// at all): the TC's notification log stays off for them
	override bool ProcessNotify(String game, ClassicStatusBar sb, int printlevel, String outline)
	{
		if (!MCSLook(game)) { return false; }

		String text = ZScriptTools.StripControlCodes(outline);
		while (text.length() && (text.ByteAt(text.length() - 1) == 0x0A || text.ByteAt(text.length() - 1) == 0x0D)) { text.DeleteLastCharacter(); }

		if (AReyePGame.Family(game) == "EOD" && (text.Left(14) == "You picked up " || text == "Knife Fury!" || text == "God mode!")) { ShowMessage(text); }

		console.printfex(PRINT_LOG, text);
		return true;
	}

	// End of Destiny's secret markers (EoDSecretTrigger; image 0x129b6): three
	// seconds, red for a secret area and yellow (palette 0x46) for a super one
	override bool ProcessMidPrint(String game, ClassicStatusBar sb, String msg)
	{
		String text = ZScriptTools.StripControlCodes(msg);
		if (text == "You found a secret area") { ShowMessage(text, 3); return true; }
		if (text == "You found a super secret area") { ShowMessage(text, 3, 0xFFF620); return true; }

		return false;
	}

	// Input -----------------------------------------------------------------------------

	// SR and EoD have their own cheat keys in place of Wolf3D's
	override bool InputProcess(String game, InputEvent e)
	{
		if (!MCSLook(game)) { return false; }

		bool down = e.Type == InputEvent.Type_KeyDown;
		if (down && cheatmessage) { cheatmessage.Close(); }

		if (held.Size() < 256) { held.Resize(256); }
		if ((down || e.Type == InputEvent.Type_KeyUp) && e.KeyScan >= 0 && e.KeyScan < 256) { held[e.KeyScan] = down; }
		if (!down || gamestate != GS_LEVEL || menuactive || !goobers) { return false; } // only with "Enable Wolf3D-style cheats" on

		String family = AReyePGame.Family(game);
		int cheat = MCSCheats.Match(family, held);
		if (!cheat) { return false; }

		for (int k = 0; k < held.Size(); k++) { held[k] = false; } // once per press, as the original waits for a key

		PlayerPawn pmo = players[consoleplayer].mo;
		String text = MCSCheats.Message(family, cheat, AReyePGame.CurrentSlot(), pmo && pmo.FindInventory("MCSCheated"));
		cheatmessage = ClassicMessageBox.PrintMessage(text, "BG_", 0x8c8c8c, 1);
		EventHandler.SendNetworkEvent("mcscheat", cheat);
		return true;
	}

	override bool StockCheats(String game) { return !MCSLook(game); }
}
