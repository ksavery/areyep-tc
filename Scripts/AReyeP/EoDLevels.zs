// End of Destiny per-level rules: start-of-level arsenals, the finale, Greed,
// "123 you're dead" (MCS's level setup at image 0x105df, PlayLoop timers 0x124d6)
class EoDLevelRules : EventHandler
{
	int exittime;
	int survival; // "123 you're dead": tics survived
	int flamecount; // spectre flame relighting (EoDSpectreFlame.A_FlameRelight)
	bool greeddone, greedgoal; // Greed: treasure all gone; a spot to head for
	Vector2 greedspot;

	// Story text shown as the level starts (eod4sdl's per-level flags; chunk 170 + n)
	static int LevelText(int slot)
	{
		switch (slot)
		{
			case 6: return 1;
			case 11: return 2;
			case 21: return 3;
			case 24: return 4;
		}

		return slot >= 26 && slot <= 37 ? slot - 21 : 0;
	}

	// Levels that start (and restart after a death) with a fixed arsenal, from
	// MCS's level setup: 1 the knife alone (the first map, so a new game, and the
	// challenge levels), 2 the pistol and a clip, 8 the Spear in hand (the rest of
	// the arsenal is kept). Medkits go with the weapons.
	static int Loadout(int slot)
	{
		switch (slot)
		{
			case 0: case 30: case 31: case 32: case 34: case 35: case 36: case 37: return 1;
			case 21: return 2; // Otto's dungeon: "disarmed of all except his pistol"
			case 28: return 2; // E1L1 Reborn
			case 25: return 8; // Hell on Earth
		}

		return 0;
	}

	override void WorldLoaded(WorldEvent e)
	{
		exittime = 0;
		survival = 0;
		flamecount = 0;
		greeddone = greedgoal = false;
		if (e.IsSaveGame || AReyePGame.CurrentFamily() != "EOD") { return; }

		int slot = AReyePGame.CurrentSlot();
		Shade(slot);
		UncountPushwalls();
		EoDTextLog log = EoDTextLog(StaticEventHandler.Find("EoDTextLog"));
		if (log && LevelText(slot)) { log.Queue(LevelText(slot)); }

		if (slot == 33)
		{
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p] && players[p].mo) { players[p].mo.GiveInventory("EoDLastStand", 1); }
			}
		}

		int loadout = Loadout(slot);
		if (!loadout) { return; }

		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p] || !players[p].mo) { continue; }
			Actor mo = players[p].mo;

			if (loadout == 8)
			{
				mo.A_GiveInventory("EoDSpear");
				mo.A_SelectWeapon("EoDSpear");
				continue;
			}

			for (Inventory item = mo.inv; item;)
			{
				Inventory next = item.inv;
				if (item is "Weapon" || item is "Ammo" || item is "EoDPortableMedkit") { item.Destroy(); }
				item = next;
			}

			mo.A_GiveInventory("WolfKnife");
			if (loadout >= 2)
			{
				mo.A_GiveInventory("WolfPistol");
				mo.A_SetInventory("WolfClip", 8);
				mo.A_SelectWeapon("WolfPistol");
			}
			else { mo.A_SelectWeapon("WolfKnife"); }
		}
	}

	// Stock classes voiced with EoD's own samples: FirstSighting (image 0x156a6),
	// T_Shoot (0x1b6bc) and A_DeathScream (0x1a46f) by class
	override void WorldThingSpawned(WorldEvent e)
	{
		Actor mo = e.Thing;
		if (!mo || !mo.bIsMonster || AReyePGame.CurrentFamily() != "EOD") { return; }

		if (mo is "TransGrosse") { SetVoice(mo, "eod/grausight", "eod/gatling", "eod/graudeath"); }
		else if (mo is "BarnacleWilhelm") { SetVoice(mo, "eod/ottosight", "eod/gatling", "eod/ottodeath"); }
		else if (mo is "DeathKnight") { SetVoice(mo, "eod/baronsight", "eod/mk4", "eod/barondeath"); }
		else if (mo is "AngelOfDeath") { SetVoice(mo, "eod/angelsight", "", "eod/angeldeath"); }
		else if (mo is "UberMutant") { SetVoice(mo, "", "eod/mk4", "eod/clonebossdeath"); }
		else if (mo is "SRSuicideClone") { SetVoice(mo, "", "", ""); }
		else if (mo is "Guard") { SetVoice(mo, "eod/halt", "eod/nazifire", "eod/nazideath"); }
		else if (mo is "Officer") { SetVoice(mo, "eod/spion", "eod/nazifire", "eod/nazideath"); }
		else if (mo is "SS") { SetVoice(mo, "eod/schutzad", "eod/ssfire", "eod/nazideath"); }
		else if (mo is "Mutant") { SetVoice(mo, "", "eod/nazifire", "eod/ahhhg"); }
	}

	static void SetVoice(Actor mo, String see, String attack, String death)
	{
		mo.SeeSound = see;
		if (attack.Length()) { mo.AttackSound = attack; }
		mo.DeathSound = death;
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (AReyePGame.CurrentFamily() != "EOD") { return; }

		// Guards, officers and SS cut down with the knife or the rifle give the
		// one scream reserved for it (A_DeathScream: chosen weapon 0 or 5)
		Actor killer = e.Thing.target;
		if ((e.Thing is "Guard" || e.Thing is "Officer" || e.Thing is "SS") && killer && killer.player)
		{
			Weapon w = killer.player.ReadyWeapon;
			if (w is "WolfKnife" || w is "EoDRifle") { e.Thing.DeathSound = "eod/deathscream10"; }
		}

		// Hell on Earth ends with the hell Grau Adler
		if (exittime || !(e.Thing is "TransGrosse") || AReyePGame.CurrentSlot() != 25) { return; }

		exittime = level.maptime + 105;
	}

	// End of Destiny's secrets are its secret markers alone (bo_secret and
	// bo_supersecret, eod4sdl wl_act1.cpp); the TC counts each pushwall as one too
	void UncountPushwalls()
	{
		for (int s = 0; s < level.sectors.Size(); s++)
		{
			Sector sec = level.sectors[s];
			if (!(sec.flags & Sector.SECF_SECRET)) { continue; }

			sec.flags &= ~(Sector.SECF_SECRET | Sector.SECF_WASSECRET);
			level.total_secrets--;
		}
	}

	// eod4sdl's distance shading, which the DOS game doesn't have: each of Kyle
	// Albert's beta maps holds a strength (1, or 2 for darker nearer) and a colour
	// to shade towards in row 0 (wl_game.cpp feature flags). Near-black for all
	// but Hell on Earth (red). UZDoom's light falloff stands in for his tables.
	static const int shadestrength[] = { 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1 };
	const SHADELIGHT1 = 255;
	const SHADELIGHT2 = 224;

	void Shade(int slot)
	{
		if (slot < 0 || slot >= shadestrength.Size()) { return; }

		int light = shadestrength[slot] == 2 ? SHADELIGHT2 : SHADELIGHT1;
		for (int s = 0; s < level.sectors.Size(); s++)
		{
			Sector sec = level.sectors[s];
			sec.SetLightLevel(min(sec.lightlevel, light));
			sec.SetFade(slot == 25 ? 0xC80000 : 0x040404); // Hell on Earth's red, else near-black
		}
	}

	override void WorldTick()
	{
		if (exittime && level.maptime >= exittime)
		{
			exittime = 0;
			level.ExitLevel(0, false);
		}

		if (AReyePGame.CurrentFamily() != "EOD") { return; }
		if (level.maptime % 35) { return; }

		if (AReyePGame.CurrentSlot() == 30) { Greed(); }

		// "123 you're dead": 1000 points a second survived; after three minutes
		// the level ends with health restored
		if (AReyePGame.CurrentSlot() == 33 && !exittime)
		{
			survival += 35;
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (!playeringame[p] || !players[p].mo) { continue; }
				players[p].mo.A_GiveInventory("Score", 1000);
				if (survival >= 180 * 35) { EoDLastStand.Finish(players[p].mo); }
			}
		}

		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (playeringame[p] && players[p].mo && players[p].mo.health > 0) { BurnAndRegen(players[p].mo); }
		}
	}

	// Greed, once a second (PlayLoop image 0x12502 and the direction pickers'
	// mapon 30 cases): every enemy chases and flees by the treasure rather than
	// you, suicide clones dodge by it too while any is left. The spot is the last
	// treasure (or Artefact of Death) in map order. With no treasure left, a gong,
	// the elevator key at (31, 33), and the blocking codes penning them in go.
	void Greed()
	{
		int left;
		Vector2 best = (-1, -1);

		ThinkerIterator it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			bool treasure = (mo is "JeweledCross" || mo is "Chalice" || mo is "Chest" || mo is "Crown") && !Inventory(mo).owner;
			if (!treasure && !(mo is "SRDeathArtefact")) { continue; }
			if (treasure) { left++; }

			Vector2 at = ParsedMap.CoordsToGrid(mo.pos.xy);
			if (at.y > best.y || (at.y == best.y && at.x > best.x))
			{
				best = at;
				greedspot = mo.pos.xy;
				greedgoal = true;
			}
		}

		if (!left && !greeddone)
		{
			greeddone = true;
			S_StartSound("eod/gong", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			Actor.Spawn("EoDObjElevatorKeyKey4", (ParsedMap.GridToCoords((31, 33)), 0));

			for (int y = 0; y < 64; y++)
			{
				for (int x = 0; x < 64; x++)
				{
					Vector2 at = ParsedMap.GridToCoords((x, y));
					if (MapHandler.ActorAt(at) != 261) { continue; }

					Sector sec = level.PointInSector(at);
					for (int l = 0; l < sec.lines.Size(); l++) { sec.lines[l].flags &= ~Line.ML_BLOCKMONSTERS; }
				}
			}
		}

		if (!greedgoal) { return; }

		ThinkerIterator enemies = ThinkerIterator.Create("ClassicBase");
		ClassicBase enemy;
		while (enemy = ClassicBase(enemies.Next()))
		{
			enemy.goal = greedspot;
			enemy.goalmode = enemy is "SRSuicideClone" && !greeddone ? 2 : 1;
		}
	}

	// Once a second: the fireplace (0x4E) and hell wall (0x57) burn 1 health off
	// anyone standing beside them; the well of health (object 322) heals 2 up to
	// 100 (eod4sdl BurnPlayer / RegenPlayer)
	static void BurnAndRegen(Actor mo)
	{
		Vector2 here = ParsedMap.CoordsToGrid(mo.pos.xy);
		for (int d = 0; d < 4; d++)
		{
			static const int dx[] = { 1, 0, -1, 0 };
			static const int dy[] = { 0, -1, 0, 1 };
			int t = MapHandler.TileAt(ParsedMap.GridToCoords((here.x + dx[d], here.y + dy[d])));
			if (t != 0x4E && t != 0x57) { continue; }

			mo.DamageMobj(null, null, 1, "Fire", DMG_NO_ARMOR);
			mo.A_StartSound("eod/takedamage", CHAN_BODY);
			break;
		}

		if (MapHandler.ActorAt(mo.pos.xy) == 322 && mo.health < 100)
		{
			mo.GiveBody(2, 100);
			mo.A_StartSound("eod/sound43", CHAN_ITEM); // ENDBONUS2
		}
	}
}

// "123 you're dead" (slot 33): the only way out is death, which costs no life:
// the fatal hit is turned aside and the level ends with health restored
class EoDLastStand : Inventory
{
	Default
	{
		+Inventory.UNDROPPABLE
		+Inventory.UNTOSSABLE
		Inventory.MaxAmount 1;
		Inventory.InterHubAmount 0;
	}

	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (!passive || !owner || damage < owner.health) { return; }

		newdamage = owner.health - 1;
		owner.A_StartSound("eod/takedamage", CHAN_VOICE);
		Finish(owner);
	}

	static void Finish(Actor mo)
	{
		mo.A_SetHealth(100);
		mo.TakeInventory("EoDLastStand", 1);

		EoDLevelRules rules = EoDLevelRules(EventHandler.Find("EoDLevelRules"));
		if (rules && !rules.exittime) { rules.exittime = level.maptime + 35; }
	}
}
