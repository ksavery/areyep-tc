// Wolfendoom's episodes. Its floors are parsed maps that all run as "Level", so
// they can't be MAPINFO episodes of their own: New Game (AReyePNewGame) opens
// WDEpisodeMenu, whose items note the episode picked (areyep_wdepisode) and go
// on to the skill menu for MAPINFO's LEVEL episode; AReyePExtension.StartingMap
// then builds that episode's first floor.

// New Game: Wolfendoom's episode menu, or on as before for the other games
class AReyePNewGame : GenericMenu
{
	bool done;

	override void Ticker() { Next(); }
	override void Drawer() { Next(); }

	void Next()
	{
		if (done) { return; }
		done = true;

		Close();
		Menu.SetMenu(AReyePGame.Family(g_modgame) == "WFD" ? 'WDEpisodeMenu' : 'PlayerclassMenu');
	}
}

// Spaced like the TC's episode menu (EpisodeMenu.Drawer): two-line entries
// 26 apart and 30 high
class WDEpisodeMenu : IconListMenu
{
	override void Drawer()
	{
		ListMenuItemSelectable previous;
		for (int i = 0; i < mDesc.mItems.Size(); i++)
		{
			let item = ListMenuItemSelectable(mDesc.mItems[i]);
			if (!item) { continue; }

			if (previous) { item.SetY(previous.GetY() + 26); }
			item.mHeight = 30;
			previous = item;
		}

		Super.Drawer();
	}
}

// One episode: "WDEpisode <text>, <hotkey>, <episode 1-6>" in MENUDEF
class ListMenuItemWDEpisode : ListMenuItemTextItem
{
	int episode;

	void Init(ListMenuDescriptor desc, String text, String hotkey, int ep)
	{
		text.Replace("\\n", "\n"); // two lines, as Wolf3D's episodes (MENUDEF keeps \n as written)
		Super.Init(desc, text, hotkey, 'SkillMenu', 9); // MAPINFO's LEVEL episode
		episode = ep;
	}

	override bool Activate()
	{
		CVar picked = CVar.FindCVar("areyep_wdepisode");
		if (picked) { picked.SetInt(episode); }

		return Super.Activate();
	}
}
