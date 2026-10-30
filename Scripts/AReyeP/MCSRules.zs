// Rules of MCS's engine that Spear Resurrection and End of Destiny share, from
// the editor's-version SPEAR.EXEs (unpacked; SR / EoD image offsets)
class MCSRules : EventHandler
{
	int deathkills; // enemies the Artefact of Death takes before it's used up
	bool srfuse; // SR's suicide clones share one fuse
	Array<Actor> clips;

	static clearscope MCSRules Get()
	{
		return MCSRules(EventHandler.Find("MCSRules"));
	}

	static clearscope bool IsFamily(String family)
	{
		return family == "SR" || family == "EOD";
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) { return; }

		deathkills = Random[MCS](4, 5);
		srfuse = false;
	}

	// MCS's TakeDamage grunts (TAKEDAMAGESND) when nothing attacked: hurt by acid,
	// landmines, the death artefact, a clone's or drum's blast (TakeRandomDamage)
	// or EoD's burning floors; shots and fireballs pass their attacker and stay
	// silent (eod4sdl wl_agent.cpp TakeDamage, wl_act2.cpp TakeRandomDamage)
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.Thing || !e.Thing.player || e.Damage <= 0) { return; }
		if (e.DamageSource && !(e.DamageSource is "SRFloorHazard") && e.DamageType != 'Explosion') { return; }

		String family = AReyePGame.CurrentFamily();
		if (family == "SR") { e.Thing.A_StartSound("sr/sound16", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE); }
		else if (family == "EOD") { e.Thing.A_StartSound("eod/takedamage", CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE); }
	}

	// The cheat keys (AReyePExtension.InputProcess)
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name != "mcscheat" || !goobers || !(sv_cheats || (!netgame && !deathmatch))) { return; }

		MCSCheats.Apply(players[e.Player].mo, AReyePGame.CurrentFamily(), e.Args[0], AReyePGame.CurrentSlot());
	}

	// SR's first map: enemies drop the full outdoor clip, not half a clip
	// (KillActor, SR 0x10f50)
	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.Thing || AReyePGame.CurrentFamily() != "SR") { return; }

		if (e.Thing.GetClass() == "WolfClip" && AReyePGame.CurrentSlot() == 0) { clips.Push(e.Thing); }

		// SR's guards drop its pistol to a player who has none, except on maps 10,
		// 13 and 22; its officers never do (KillActor, SR 0x10ea0)
		if (e.Thing is "Officer") { ClassicBase(e.Thing).dropweapon = null; }
		else if (e.Thing is "Guard")
		{
			int slot = AReyePGame.CurrentSlot();
			ClassicBase(e.Thing).dropweapon = (slot == 10 || slot == 13 || slot == 22) ? null : (Class<Inventory>)("SRPistolPickup");
		}
	}

	// Wolf3D / Lost Episodes weapons a cheat can hand out have no place in MCS's
	// games; the TC chaingun sits beside the Mk3 in slot 4 with its art and Ammo 1,
	// so an empty Mk4 would fall back to it
	static const String tcweapons[] = { "WolfChaingun", "WolfChaingunLost", "WolfKnifeLost", "WolfPistolLost", "WolfMachineGunLost", "WolfFlameThrower", "WolfRocketLauncher" };
	static const String mcsweapons[] = { "SRMk3", "SRMk3", "WolfKnife", "WolfPistol", "WolfMachineGun", "", "EoDRocketLauncher" };

	void SwapTCWeapons(Actor mo, String family)
	{
		// End of Destiny's own guns aren't in Spear Resurrection
		if (family == "SR")
		{
			Array<Inventory> eodguns;
			for (Inventory inv = mo.Inv; inv; inv = inv.Inv)
			{
				if (inv is "EoDRifle" || inv is "EoDRocketLauncher" || inv is "EoDSpear") { eodguns.Push(inv); }
			}

			for (int g = 0; g < eodguns.Size(); g++)
			{
				bool inhand = mo.player && mo.player.ReadyWeapon == eodguns[g];
				mo.RemoveInventory(eodguns[g]);
				eodguns[g].Destroy();
				if (inhand) { mo.player.PendingWeapon = WP_NOCHANGE; mo.A_SelectWeapon("WolfPistol"); }
			}
		}

		for (int w = 0; w < tcweapons.Size(); w++)
		{
			Class<Inventory> tc = tcweapons[w];
			Inventory have = mo.FindInventory(tc);
			if (!have || have.GetClass() != tc) { continue; } // exactly: SRMk3 is a WolfChaingun

			bool inhand = mo.player && mo.player.ReadyWeapon == have;
			mo.RemoveInventory(have);
			have.Destroy();

			String mcs = mcsweapons[w];
			if (mcs == "EoDRocketLauncher" && family != "EOD") { mcs = ""; }
			if (mcs.length())
			{
				mo.GiveInventory(mcs, 1);
				if (inhand) { mo.A_SelectWeapon(mcs); }
			}
			else if (inhand && mo.player) { mo.player.PendingWeapon = WP_NOCHANGE; mo.A_SelectWeapon("WolfKnife"); }
		}
	}

	override void WorldTick()
	{
		String fam = AReyePGame.CurrentFamily();
		if (IsFamily(fam))
		{
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p] && players[p].mo) { SwapTCWeapons(players[p].mo, fam); }
			}
		}

		String family = AReyePGame.CurrentFamily();
		if (!IsFamily(family)) { clips.Clear(); return; }

		for (int i = 0; i < clips.Size(); i++)
		{
			Actor clip = clips[i];
			if (!clip || !clip.bDropped || Inventory(clip).owner) { continue; }

			Actor full = Actor.Spawn("SROutdoorClip", clip.pos);
			if (full) { full.bDropped = true; }
			clip.Destroy();
		}
		clips.Clear();

		ThinkerIterator it = ThinkerIterator.Create("ClassicBase");
		ClassicBase mo;
		while (mo = ClassicBase(it.Next()))
		{
			if (Walker(mo)) { GrabItems(mo, family); }
		}
	}

	// Enemies moving by T_Chase, T_Path or the boss and clone chases (not the
	// flames, ghosts or turrets) pick up what's on the tile they reach
	static bool Walker(ClassicBase mo)
	{
		if (mo.health <= 0 || !mo.bShootable || mo.bCorpse || mo.bDormant) { return false; }
		if (!(mo is "ClassicNazi" || mo is "ClassicBoss")) { return false; }
		if (mo is "EoDGhostMover" || mo is "EoDTurret" || mo is "WolfSpectre") { return false; }

		return mo.vel.xy != (0, 0) || mo.InStateSequence(mo.CurState, mo.ResolveState("Chase"));
	}

	// 1: guards, officers and SS heal while hurt; 2: these bosses heal up to
	// twice their hit points (SR 0x15807, EoD 0x1ba3a and the 0x1bc22 caps)
	static int HealGroup(Actor mo, String family)
	{
		if (mo is "Guard" || mo is "Officer" || mo is "SS") { return 1; }
		if (mo is "TransGrosse" || mo is "BarnacleWilhelm" || mo is "DeathKnight") { return 2; }
		if (family == "EOD" && mo is "EoDUltraClone" && !(mo is "EoDRobot")) { return 2; } // Heinrich too

		return 0;
	}

	// SR 0x15708, EoD 0x1b8d0
	static void GrabItems(ClassicBase mo, String family)
	{
		Vector2 tile = ParsedMap.CoordsToGrid(mo.pos.xy);
		int group = HealGroup(mo, family);
		bool greed = family == "EOD" && AReyePGame.CurrentSlot() == 30;

		BlockThingsIterator it = BlockThingsIterator.Create(mo, 32);
		while (it.Next())
		{
			Inventory item = Inventory(it.thing);
			if (!item || item.owner || ParsedMap.CoordsToGrid(item.pos.xy) != tile) { continue; }

			int heal, snd;
			if (item is "FirstAidKit") { heal = group == 1 ? 25 : 100; snd = 34; }
			else if (item is "PlateofFood") { heal = group == 1 ? 10 : 40; snd = 33; }
			else if (item is "DogFood") { heal = group == 1 ? 10 : 20; snd = 7; }

			if (heal && group)
			{
				if (mo.health > (group == 1 ? mo.StartHealth - 1 : mo.StartHealth * 2)) { continue; }
				mo.health += heal;
			}
			else if (greed && (item is "JeweledCross" || item is "Chalice" || item is "Chest" || item is "Crown"))
			{
				// Greed: they steal the treasure, and it counts as found
				snd = item is "JeweledCross" ? 36 : item is "Chalice" ? 35 : item is "Chest" ? 37 : 45;
				level.found_items++;
			}
			else { continue; }

			item.A_StartSound(String.Format("%s/sound%d", family == "EOD" ? "eod" : "sr", snd), CHAN_ITEM);
			item.Destroy();
		}
	}

	// MCS's blast (EoD 0x150b3, SR 0x11296): a box reaching one or two tiles out
	// each way at random; 200 damage to everything shootable in it, chaining
	// into drums (and, in EoD, suicide clones). The player is hurt separately.
	static void ExplodeArea(Actor src, String family)
	{
		Vector2 tile = ParsedMap.CoordsToGrid(src.pos.xy);
		int x0 = int(tile.x) - Random[MCS](1, 2), y0 = int(tile.y) - Random[MCS](1, 2);
		int x1 = int(tile.x) + Random[MCS](1, 2), y1 = int(tile.y) + Random[MCS](1, 2);

		Array<Actor> hit;
		BlockThingsIterator it = BlockThingsIterator.Create(src, 192);
		while (it.Next())
		{
			Actor mo = it.thing;
			if (mo == src || mo.player || !mo.bShootable || mo.health <= 0) { continue; }

			Vector2 t = ParsedMap.CoordsToGrid(mo.pos.xy);
			if (t.x < x0 || t.x > x1 || t.y < y0 || t.y > y1) { continue; }

			hit.Push(mo);
		}

		for (int i = 0; i < hit.Size(); i++)
		{
			Actor mo = hit[i];
			if (!mo || mo.health <= 0) { continue; }

			if (mo is "MCSDrum" || (family == "EOD" && mo is "SRSuicideClone")) { mo.DamageMobj(src, src, mo.health, 'MCSChain', DMG_FORCED); }
			else { mo.DamageMobj(src, src, 200, 'Explosion'); }
		}
	}

	// The player's share of a drum: within two and a quarter tiles each way
	// (EoD 0x15ab9); TakeRandomDamage(25, 10)
	static void BlastPlayers(Actor src)
	{
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p]) { continue; }
			Actor pl = players[p].mo;
			if (!pl || pl.health <= 0) { continue; }
			if (abs(pl.pos.x - src.pos.x) >= 144 || abs(pl.pos.y - src.pos.y) >= 144 || !src.CheckSight(pl)) { continue; }

			pl.DamageMobj(src, src, SRFloorHazard.RandomDamage(25, 10), 'Explosion');
		}
	}
}

// Exploding drum (KillActor, and the chain in the blast above): hurts the player
// close by, may leave something behind, and sets off its surroundings. A drum
// set off by another shows itself for 18 tics before its fireball.
class MCSDrum : ExplosiveOilDrum
{
	override void Die(Actor source, Actor inflictor, int dmgflags, Name meansofdeath)
	{
		bool chained = meansofdeath == 'MCSChain';
		String family = AReyePGame.CurrentFamily();

		bShootable = false;
		bSolid = false; // the wreck doesn't block (Wolf3D's actors only block while shootable)
		MCSRules.BlastPlayers(self);
		LeaveBehind(chained);
		MCSRules.ExplodeArea(self, family);

		Super.Die(source, inflictor, dmgflags, meansofdeath);
		if (chained) { SetStateLabel("Chained"); }
	}

	virtual void LeaveBehind(bool chained) {}

	void DropHere(Class<Actor> cls)
	{
		Actor mo = Spawn(cls, pos);
		if (mo) { mo.bDropped = true; }
	}
}
