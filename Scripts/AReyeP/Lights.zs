// Dynamic lights for the AReyeP games' own lamps, torches and flames. The TC's
// lamps light themselves when its dynamic lights option is on (Game.AttachLight);
// these follow the same option, checked once a second so a change shows quickly.
class AReyePLights : EventHandler
{
	Array<Actor> lamps;
	bool scanned; // A parsed map spawns its things before this handler sees them

	// SR's and EoD's hanging lamps have the pool of light they cast drawn on the
	// floor below them, in the bottom rows of the sprite. A dynamic light lights
	// the real floor, so with them on those rows are cleared (the TC does the same
	// for its own lamps through their shadow masks); turned off, the art is redrawn
	static const String pools[] = { "LIT3A0", "LIT5A0", "LITRA0", "SRBLA0", "E000G0", "E000Q0", "E001Q0" };
	const POOLTOP = 40;
	bool poolsgone;

	override void WorldLoaded(WorldEvent e)
	{
		poolsgone = false; // A new level, or a load, draws the art afresh
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.Thing || !IsLamp(e.Thing)) { return; }

		lamps.Push(e.Thing);
		Light(e.Thing);
	}

	override void WorldTick()
	{
		if (!scanned)
		{
			scanned = true;
			lamps.Clear();
			ThinkerIterator it = ThinkerIterator.Create("Actor");
			Actor mo;
			while (mo = Actor(it.Next())) { if (IsLamp(mo)) { lamps.Push(mo); } }
		}

		if (level.maptime % GameTicRate) { return; }

		UpdatePools();

		for (int i = lamps.Size() - 1; i >= 0; i--)
		{
			if (!lamps[i]) { lamps.Delete(i); continue; }
			Light(lamps[i]);
		}
	}

	void UpdatePools()
	{
		String family = AReyePGame.CurrentFamily();
		if (family != "SR" && family != "EOD") { return; }

		CVar dynlights = CVar.GetCVar("g_dynamiclights", players[consoleplayer]);
		bool want = dynlights && dynlights.GetInt();
		if (!want && !poolsgone) { return; }

		// Cleared again each second while lights are on: the TC redraws the art
		// whenever it activates a game's graphics
		poolsgone = want;
		if (want)
		{
			for (int i = 0; i < pools.Size(); i++)
			{
				Canvas cv = TexMan.GetCanvas(pools[i], TexMan.Type_Any);
				if (cv) { cv.Dim(0x0, 0.0, 0, POOLTOP, 64, 64 - POOLTOP, overwritealpha:true); }
			}
			return;
		}

		MapHandler handler = MapHandler.Get();
		String dataset = handler && handler.curmap ? GameExtension.GetDataSet(handler.curmap.extension) : "";
		if (dataset.length()) { GraphicsHandler.Activate(dataset); }
	}

	static bool IsLamp(Actor mo)
	{
		return mo is "EoDObjBlueCeilingLight" || mo is "EoDObjCyanCeilingLight" || mo is "EoDObjChandelier" ||
			mo is "EoDObjBlueFloorLamp" || mo is "EoDObjIndoorTorch" || mo is "EoDObjOutdoorTorch" ||
			mo is "EoDObjStationaryFlame" || mo is "EoDObjFireLogs" || mo is "EoDObjCandlestand" ||
			mo is "EoDObjTableWithSkullCandle" || mo is "SRIndoorTorch" || IsTCLamp(mo);
	}

	// The TC's own lamps, which SR's and EoD's maps use too: they light
	// themselves; in these games they get a second light on top
	static bool IsTCLamp(Actor mo)
	{
		return mo is "FloorLamp" || mo is "HangingChandelier" || mo is "GreenCeilingLight";
	}

	// A second, plain light where the lamp is, so it lights its surroundings
	// more strongly than one light can
	static void Light2(Actor mo)
	{
		if (mo is "EoDObjCandlestand" || mo is "EoDObjTableWithSkullCandle") { Boost(mo, 32, 0xFFD070, 32); }
		else if (mo is "EoDObjStationaryFlame" || mo is "EoDObjFireLogs") { Boost(mo, 48, 0xFF8020, 16); }
		else if (mo is "EoDObjBlueCeilingLight" || mo is "EoDObjBlueFloorLamp") { Boost(mo, 56, 0x9090FF, 48); }
		else if (mo is "EoDObjCyanCeilingLight") { Boost(mo, 56, 0x90FFFF, 48); }
		else if (mo is "EoDObjChandelier") { Boost(mo, 64, 0xFFF0C0, 48); }
		else { Boost(mo, 64, 0xFF9030, 48); }
	}

	static void Boost(Actor mo, int radius, color clr, double z)
	{
		CVar dynlights = CVar.GetCVar("g_dynamiclights", players[consoleplayer]);
		if (dynlights && dynlights.GetInt()) { mo.A_AttachLight("Boost", DynamicLight.PointLight, clr, radius, 0, 0, (0, 0, z)); }
		else { mo.A_RemoveLight("Boost"); }
	}

	// Blinking lights light and go dark with their frames, every tic (their Tick)
	static void Light(Actor mo)
	{
		if (mo is "SRBlinkingLight" || mo is "EoDBlinkingLight") { return; }
		LampLight(mo);
	}

	static void Dark(Actor mo)
	{
		mo.A_RemoveLight("Light");
		mo.A_RemoveLight("DownLight");
		mo.A_RemoveLight("Boost");
	}

	static void LampLight(Actor mo)
	{
		if (IsTCLamp(mo))
		{
			if (AReyePGame.CurrentFamily() == "") { return; }
			Boost(mo, mo is "FloorLamp" ? 40 : 56, mo is "GreenCeilingLight" && !(mo is "RedCeilingLight") ? 0xC0FFC0 : 0xFFF0C0, mo is "FloorLamp" ? 36 : 54);
			return;
		}

		// The light switch level swaps its ceiling lights to the dead ones' art
		State dead = GetDefaultByType("EoDObjDeadCeilingLight").SpawnState;
		if (mo is "EoDObjBlueCeilingLight" && dead && mo.sprite == dead.sprite && mo.frame == dead.frame)
		{
			mo.A_RemoveLight("Light");
			mo.A_RemoveLight("DownLight");
			mo.A_RemoveLight("Boost");
			return;
		}

		// A little wider than the TC's own lamps, so a lit room reads as lit
		if (mo is "EoDObjBlueCeilingLight") { Game.AttachLight(mo, 64, 0x9090FF, (0, 0, 56), DYNAMICLIGHT.LF_SPOT, 20, 55, 90); }
		else if (mo is "EoDObjCyanCeilingLight") { Game.AttachLight(mo, 64, 0x90FFFF, (0, 0, 56), DYNAMICLIGHT.LF_SPOT, 20, 55, 90); }
		else if (mo is "EoDObjChandelier") { Game.AttachLight(mo, 72, 0xFFF0C0, (0, 0, 56), DYNAMICLIGHT.LF_SPOT, 20, 55, 90); }
		else if (mo is "EoDObjBlueFloorLamp") { Game.AttachLight(mo, 56, 0x9090FF, (0, 0, 40)); }
		else if (mo is "EoDObjCandlestand" || mo is "EoDObjTableWithSkullCandle") { Game.AttachLight(mo, 40, 0xFFD070, (0, 0, 32)); }
		else if (mo is "EoDObjStationaryFlame" || mo is "EoDObjFireLogs") { Game.AttachLight(mo, 64, 0xFF8020, (0, 0, 16)); }
		else { Game.AttachLight(mo, 88, 0xFF9030, (0, 0, 48)); } // torches

		Light2(mo);
	}
}

// The AReyeP games' own defaults for some of the TC's options, set once in their
// config (areyep.ini, apart from the stock TC's): dynamic lights on, textured
// floors and ceilings, and Esc in the menu back to the game rather than quit.
// After that the player's own choices stand.
class AReyePDefaults : StaticEventHandler
{
	const DEFAULTSSET = 1;

	override void UiTick()
	{
		CVar applied = CVar.FindCVar("areyep_defaults");
		if (!applied || applied.GetInt() >= DEFAULTSSET) { return; }

		SetDefault("g_dynamiclights", 1);
		SetDefault("g_useflats", 3);
		SetDefault("g_menubackstyle", 1);
		applied.SetInt(DEFAULTSSET);
	}

	ui static void SetDefault(Name option, int value)
	{
		CVar cv = CVar.FindCVar(option);
		if (cv) { cv.SetInt(value); }
	}
}
