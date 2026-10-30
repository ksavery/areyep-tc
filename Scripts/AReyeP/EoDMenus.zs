// End of Destiny's text screens, read with the TC's Wolf3D article reader
// (OldHelpMenu: ^P pages, ^C colours, ^G pictures). The articles are VGAGRAPH
// text chunks, written to Data/EoD/ by tools/assets.py; ^G picture n is EODVnnnn.

// Read This! from the main menu: the game's story, manual and credits (SR's
// HELPART, EoD's VGAGRAPH chunk 170; tools/assets.py), as MCS's CP_ReadThis
class MCSReadThis : OldHelpMenu
{
	override void Init(Menu parent)
	{
		InitCommon(parent);

		sharewareremap = false;
		allowexit = true;

		String family = AReyePGame.CurrentFamily();
		if (family == "") { family = AReyePGame.Family(g_modgame); }
		graphicprefix = family == "WFD" ? "WDV" : family == "EOD" ? "EODV" : "SRV";
		if (family == "WFD")
		{
			border = TexMan.CheckForTexture("WD_BORDER", TexMan.Type_Any);
			GameHandler.ChangeMusic("CORNER"); // WOLFDOOM.WFD CP_ReadThis, image 0x6caf
		}
		ParseFile(family == "WFD" ? "Data/WFD/Help.txt" : family == "EOD" ? "Data/EoD/Help.txt" : "Data/SR/Help.txt");
	}
}

// Story shown as a level starts (eod4sdl LevelText: text 1-16 = chunk 170 + n)
class EoDLevelText : OldHelpMenu
{
	override void Init(Menu parent)
	{
		InitCommon(parent);

		sharewareremap = false;
		allowexit = true;
		graphicprefix = "EODV";

		EoDTextLog log = EoDTextLog(StaticEventHandler.Find("EoDTextLog"));
		ParseFile(String.Format("Data/EoD/Text%02d.txt", log ? log.pending : 0));
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		// Paging past the last page starts the level
		if ((mkey == MKEY_Enter || mkey == MKEY_Right) && mScreen >= pages.Size() - 1) { mkey = MKEY_Back; }
		if (mkey == MKEY_Back) { EventHandler.SendNetworkEvent("eodtextread"); }

		return Super.MenuEvent(mkey, fromcontroller);
	}
}

// The ending: four full-screen pictures, then the "thanks for playing" article
class EoDFinale : OldHelpMenu
{
	static const String pictures[] = { "EODEND1", "EODEND3", "EODEND4", "EODEND2" };
	int picture;

	override void Init(Menu parent)
	{
		InitCommon(parent);

		sharewareremap = false;
		allowexit = false;
		graphicprefix = "EODV";
		ParseFile("Data/EoD/End.txt");
	}

	override void Drawer()
	{
		if (picture < pictures.Size())
		{
			screen.Dim(0, 1.0, 0, 0, screen.GetWidth(), screen.GetHeight());
			TextureID tex = TexMan.CheckForTexture(pictures[picture], TexMan.Type_Any);
			if (tex.IsValid()) { screen.DrawTexture(tex, false, 0, 0, DTA_320x200, true); }
			return;
		}

		Super.Drawer();
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (picture < pictures.Size())
		{
			if (mkey == MKEY_Enter || mkey == MKEY_Right || mkey == MKEY_Back)
			{
				picture++;
				MenuSound("menu/activate");
				return true;
			}
			return false;
		}

		if ((mkey == MKEY_Enter || mkey == MKEY_Right) && mScreen >= pages.Size() - 1) { mkey = MKEY_Back; }
		return Super.MenuEvent(mkey, fromcontroller);
	}
}

// Which story screens this game has shown (each once per new game, not again
// when the level restarts after a death), and the one waiting to be shown
class EoDTextLog : StaticEventHandler
{
	Array<int> shown;
	int pending;

	override void NewGame()
	{
		shown.Clear();
		pending = 0;
	}

	void Queue(int text)
	{
		if (shown.Find(text) != shown.Size()) { return; }

		shown.Push(text);
		pending = text;
	}

	override void UiTick()
	{
		if (!pending || gamestate != GS_LEVEL || Menu.GetCurrentMenu()) { return; }

		// Headless map reports shouldn't wait on a story screen
		CVar report = CVar.FindCVar("areyep_report");
		if (report && report.GetInt()) { return; }

		Menu.SetMenu('EoDLevelText');
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name == "eodtextread") { pending = 0; }
	}
}
