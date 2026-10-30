// Dev-only helpers for headless runs (tools/headless.sh):
//   +areyep_probe 1    print engine state once a second
//   +areyep_report 1   once a parsed map is built, report codes with no tile/actor
//                      mapping, walls whose texture wasn't drawn from the VSWAP,
//                      and what spawned
//   +areyep_switchtest 1  throw every EoD switch after a second, report the result
//   +areyep_summon "A,B,C"  line those classes up in front of the player (frozen)
//   +areyep_exit 1|2|3 leave each level (normal / secret exit) once it's reported;
//                      3: by the normal exit four seconds in, through the intermission
//   +areyep_goto "x,y,angle"  stand the player on that tile, facing that way
//   +areyep_push "x,y,ang"  push that pushwall (byte angle), report the distance
//   +areyep_tile "x,y;x,y"  report those tiles' sector heights and codes
//   +areyep_cheat N    apply MCSCheats cheat N two seconds in
//   +areyep_fire 1     hold fire from a second in
//   +areyep_shoot "Class"  fire that projectile from the player every two seconds, at the nearest live monster
//   +areyep_shootowner "Class"  ... owned by a new actor of that class instead of the player
//   +areyep_give "A,@B"  give the player these a few tics into the level (@: as if walked onto)
//   +areyep_playmusic SONG  play this song four seconds after startup
//   +areyep_at "300:menu:OptionsMenu,370:quit"  run console commands (or open a menu) at those gametics
class AReyePDevProbe : StaticEventHandler
{
	int leveltics;
	int pushed; // areyep_push's pushwall

	override void UiTick()
	{
		// "tic:command,tic:command", run as a confirmed menu command (console
		// waits don't advance in headless runs)
		CVar at = CVar.FindCVar("areyep_at");
		if (at && at.GetString().length())
		{
			Array<String> cmds;
			at.GetString().Split(cmds, ",");
			for (int c = 0; c < cmds.Size(); c++)
			{
				int colon = cmds[c].IndexOf(":");
				if (colon > 0 && cmds[c].Left(colon).ToInt() == gametic)
				{
					String cmd = cmds[c].Mid(colon + 1);
					if (cmd.Left(5) ~== "menu:") { Menu.SetMenu(cmd.Mid(5)); continue; } // menu CCMDs refuse to run from here

					let item = new("OptionMenuItemSafeCommand");
					item.Init("", cmd);
					item.MenuEvent(Menu.MKEY_MBYes, false); // as if its prompt were answered
				}
			}
		}

		CVar song = CVar.FindCVar("areyep_playmusic");
		if (song && song.GetString().length() && gametic == 140) { S_ChangeMusic(song.GetString()); }

		CVar probe = CVar.FindCVar("areyep_probe");
		if (!probe || !probe.GetInt() || gametic % 35) { return; }

		console.printf("PROBE tic=%i state=%i map=%s menu=%s", gametic, gamestate, level.mapname, Menu.GetCurrentMenu() ? Menu.GetCurrentMenu().GetClassName() : 'None');

		GetPsyched psych = GetPsyched(Menu.GetCurrentMenu());
		if (psych)
		{
			console.printf("PROBE psyched curstate=%i ticcount=%i fadetarget=%i fadetime=%i starttic=%i maptime=%i menuactive=%i paused=%i",
				psych.curstate, psych.ticcount, psych.fadetarget, psych.fadetime, psych.starttic, level.maptime, menuactive, paused);
		}
	}

	override void WorldLoaded(WorldEvent e)
	{
		leveltics = 0;
	}

	override void WorldTick()
	{
		if (++leveltics == 5)
		{
			CVar report = CVar.FindCVar("areyep_report");
			if (report && report.GetInt()) { Report(); }
		}

		if (leveltics == 3) { SummonRow(); }

		CVar gotocv = CVar.FindCVar("areyep_goto");
		if (gotocv && gotocv.GetString().length() && leveltics == 40 && players[0].mo)
		{
			Array<String> v;
			gotocv.GetString().Split(v, ",");
			if (v.Size() >= 3)
			{
				players[0].mo.SetOrigin((ParsedMap.GridToCoords((v[0].ToInt(), v[1].ToInt())), 0), false);
				players[0].mo.angle = v[2].ToInt();
			}
		}

		// "x,y,byteangle": push the pushwall on that tile (0 E, 64 N, 128 W, 192 S),
		// then report how far it went
		CVar pushcv = CVar.FindCVar("areyep_push");
		if (pushcv && pushcv.GetString().length() && players[0].mo && (leveltics == 40 || leveltics == 400))
		{
			Array<String> v;
			pushcv.GetString().Split(v, ",");
			if (v.Size() >= 3)
			{
				Vector2 at = ParsedMap.GridToCoords((v[0].ToInt(), v[1].ToInt()));
				PolyobjectHandle po, near;
				ThinkerIterator pit = ThinkerIterator.Create('PolyobjectHandle');
				while (near = PolyobjectHandle(pit.Next())) { if ((near.StartSpotPos - at).Length() < 40) { po = near; break; } }
				if (!po && leveltics == 40)
				{
					console.printf("PUSH no pushwall at %s (%.0f, %.0f)", pushcv.GetString(), at.x, at.y);
					pit = ThinkerIterator.Create('PolyobjectHandle');
					while (near = PolyobjectHandle(pit.Next())) { if ((near.StartSpotPos - at).Length() < 160) { console.printf("  poly %i start (%.0f, %.0f)", near.PolyobjectNum, near.StartSpotPos.x, near.StartSpotPos.y); } }
				}
				else if (leveltics == 40) { pushed = po.PolyobjectNum; DoorHandler.OpenDoor(players[0].mo, po.PolyobjectNum, v[2].ToInt(), -1, 4); }
				PolyobjectHandle moved = leveltics == 400 ? PolyobjectHandle.FindPolyobj(pushed) : null;
				if (moved) { console.printf("PUSH moved %.2f tiles", (moved.StartSpotPos - moved.Origin).Length() / 64); }
			}
		}

		CVar tilecv = CVar.FindCVar("areyep_tile");
		if (tilecv && tilecv.GetString().length() && leveltics == 10) { ReportTiles(tilecv.GetString()); }

		CVar cheatcv = CVar.FindCVar("areyep_cheat");
		if (cheatcv && cheatcv.GetInt() && leveltics == 70 && players[0].mo)
		{
			String fam = AReyePGame.CurrentFamily();
			int slot = AReyePGame.CurrentSlot();
			int cheat = abs(cheatcv.GetInt());
			console.printf("CHEAT %i: %s", cheat, MCSCheats.Message(fam, cheat, slot, players[0].mo.FindInventory("MCSCheated") != null));

			// Negative: through the network event the cheat keys send (MCSRules)
			if (cheatcv.GetInt() < 0) { EventHandler.SendNetworkEvent("mcscheat", cheat); }
			else { MCSCheats.Apply(players[0].mo, fam, cheat, slot); }
		}

		CVar shootcv = CVar.FindCVar("areyep_shoot");
		if (shootcv && shootcv.GetString().length() && leveltics > 0 && leveltics % 70 == 0 && players[0].mo)
		{
			Class<Actor> cls = shootcv.GetString();
			// Aimed at the nearest live monster if one is close, else the nearest
			// body (to see projectiles pass it), else straight ahead
			Actor pmo = players[0].mo;
			double aim = pmo.angle;
			Actor nearest, body;
			let it = ThinkerIterator.Create("Actor");
			Actor a;
			while (a = Actor(it.Next()))
			{
				if (!a.bIsMonster || pmo.Distance2D(a) >= 512) { continue; }
				if (a.health > 0) { if (!nearest || pmo.Distance2D(a) < pmo.Distance2D(nearest)) { nearest = a; } }
				else if (!body || pmo.Distance2D(a) < pmo.Distance2D(body)) { body = a; }
			}
			if (!nearest) { nearest = body; }
			if (nearest) { aim = pmo.AngleTo(nearest); }

			Actor missile = cls ? Actor.Spawn(cls, pmo.Vec3Angle(32, aim, 0)) : null;
			if (missile)
			{
				CVar owner = CVar.FindCVar("areyep_shootowner");
				missile.target = owner && owner.GetString().length() ? Actor.Spawn(owner.GetString(), pmo.pos) : pmo; // e.g. the wall shooter, as in play
				missile.angle = aim;
				missile.vel.xy = Actor.AngleToVector(aim, missile.speed);
			}
			if (cls) { console.printf("SHOOT %s %s", shootcv.GetString(), missile ? String.Format("at %.0f,%.0f,%.0f vel %.1f", missile.pos.x, missile.pos.y, missile.pos.z, missile.vel.length()) : "not spawned"); }
			else { console.printf("SHOOT unknown class %s", shootcv.GetString()); }
		}

		CVar firecv = CVar.FindCVar("areyep_fire");
		if (firecv && firecv.GetInt() && players[0].mo && leveltics > 35 && (players[0].WeaponState & WF_WEAPONREADY)) { players[0].mo.FireWeapon(null); } // fire whenever ready

		CVar give = CVar.FindCVar("areyep_give");
		if (give && give.GetString().length() && leveltics == 10 && players[0].mo)
		{
			Array<String> items;
			give.GetString().Split(items, ",");
			for (int i = 0; i < items.Size(); i++)
			{
				// "@Class": picked up the usual way, as if walked onto
				if (items[i].Left(1) == "@")
				{
					Actor pmo = players[0].mo;
					Class<Actor> cls = items[i].Mid(1);
					Inventory item = cls ? Inventory(Actor.Spawn(cls, pmo.pos)) : null;
					if (item) { item.Touch(pmo); } // as if walked onto
				}
				else { players[0].mo.A_GiveInventory(items[i]); }
			}
		}

		CVar exitcv = CVar.FindCVar("areyep_exit");
		if (exitcv && exitcv.GetInt() == 3 && leveltics == 140) { level.ExitLevel(0, false); } // as the elevator does, intermission and all
		else if (exitcv && exitcv.GetInt() && exitcv.GetInt() < 3 && leveltics == 20)
		{
			String next = exitcv.GetInt() == 2 ? level.NextSecretMap : level.NextMap;
			console.printf("EXIT -> %s", next);
			level.ChangeLevel(next, 0, CHANGELEVEL_NOINTERMISSION);
		}

		CVar watch = CVar.FindCVar("areyep_watch");
		if (watch && watch.GetString().length() && leveltics % 35 == 0) { Watch(watch.GetString()); }

		CVar wake = CVar.FindCVar("areyep_wake");
		if (wake && wake.GetInt() && leveltics == 40)
		{
			ThinkerIterator it = ThinkerIterator.Create("ClassicBase");
			ClassicBase mo;
			while (mo = ClassicBase(it.Next()))
			{
				if (mo.health <= 0 || !players[0].mo) { continue; }
				mo.target = players[0].mo;
				mo.bAmbush = false;
				mo.SetStateLabel("See");
			}
		}

		CVar remove = CVar.FindCVar("areyep_remove");
		if (remove && remove.GetString().length() && leveltics == 105)
		{
			Array<String> names;
			remove.GetString().Split(names, ",");
			for (int n = 0; n < names.Size(); n++)
			{
				ThinkerIterator it = ThinkerIterator.Create(names[n]);
				Actor mo;
				while (mo = Actor(it.Next())) { mo.Destroy(); }
			}
		}

		CVar hurt = CVar.FindCVar("areyep_hurt");
		if (watch && hurt && hurt.GetInt() && leveltics == 70) { Hurt(watch.GetString(), hurt.GetInt()); }

		CVar test = CVar.FindCVar("areyep_switchtest");
		if (!test || !test.GetInt()) { return; }

		if (leveltics == 35 || leveltics == 140) { SwitchTest(leveltics == 35); }
	}

	void SummonRow()
	{
		CVar summon = CVar.FindCVar("areyep_summon");
		Actor mo = players[0].mo;
		if (!summon || !mo || !summon.GetString().length()) { return; }

		Array<String> names;
		summon.GetString().Split(names, ",");
		for (int n = 0; n < names.Size(); n++)
		{
			Class<Actor> cls = names[n];
			if (!cls) { console.printf("SUMMON unknown class %s", names[n]); continue; }

			Vector2 at = mo.pos.xy + Actor.RotateVector((160, (n - (names.Size() - 1) / 2.0) * 56), mo.angle);
			Actor a = Actor.Spawn(cls, (at, mo.floorz));
			if (!a) { continue; }

			a.angle = a.AngleTo(mo);
			CVar live = CVar.FindCVar("areyep_summonlive");
			if (live && live.GetInt()) { continue; }

			a.bDormant = true; // stand still for the picture
			a.A_ChangeLinkFlags(0);
		}
	}

	override void WorldThingDamaged(WorldEvent e)
	{
		CVar watch = CVar.FindCVar("areyep_watch");
		if (!watch || !watch.GetString().length() || !e.Thing) { return; }

		console.printf("WATCH damage tic=%i %s -%i (%s) by %s/%s, health now %i", level.maptime, e.Thing.GetClassName(), e.Damage, e.DamageType,
			e.Inflictor ? e.Inflictor.GetClassName() : 'None', e.DamageSource ? e.DamageSource.GetClassName() : 'None', e.Thing.health);
	}

	// Damage every live actor of the listed classes, as if the player shot it
	// "x,y;x,y": each tile's sector heights, wall and actor codes
	void ReportTiles(String list)
	{
		MapHandler handler = MapHandler.Get();
		if (!handler || !handler.curmap) { return; }

		Array<String> tiles;
		list.Split(tiles, ";");
		for (int i = 0; i < tiles.Size(); i++)
		{
			Array<String> xy;
			tiles[i].Split(xy, ",");
			if (xy.Size() < 2) { continue; }

			int x = xy[0].ToInt(), y = xy[1].ToInt();
			int index = y * handler.curmap.width + x;
			Vector2 at = ParsedMap.GridToCoords((x, y));
			Sector sec = level.PointInSector(at);
			console.printf("TILE %i,%i wall %i actor %i floor %.0f ceiling %.0f", x, y, handler.curmap.planes[0][index], handler.curmap.planes[1][index], sec.CenterFloor(), sec.CenterCeiling());
			TextureID ftex;
			TileInfo ftile;
			[ftex, ftile] = handler.curmap.GetSpecialTileTexture(TileInfo.TILE_DOORFRAME, (x, y));
			if (ftile) { console.printf("  doorframe tile %s / %s -> %s, touched %i %i", ftile.tex[0], ftile.tex[1], TexMan.GetName(ftex), GraphicsHandler.CheckTouched(ftile.tex[0]), GraphicsHandler.CheckTouched(ftile.tex[1])); }
			else { console.printf("  no doorframe tile"); }

			for (int l = 0; l < sec.lines.Size(); l++)
			{
				Line ln = sec.lines[l];
				for (int sd = 0; sd < 2; sd++)
				{
					if (ln.sidedef[sd]) { console.printf("  line %i side %i (%s) mid %s", l, sd, ln.sidedef[sd].sector == sec ? "own" : "other", TexMan.GetName(ln.sidedef[sd].GetTexture(Side.mid))); }
				}
			}
		}
	}

	void Hurt(String classes, int amount)
	{
		Array<String> names;
		classes.Split(names, ",");
		for (int n = 0; n < names.Size(); n++)
		{
			ThinkerIterator it = ThinkerIterator.Create(names[n]);
			Actor mo;
			while (mo = Actor(it.Next()))
			{
				if (mo.bShootable && mo.health > 0) { mo.DamageMobj(players[0].mo, players[0].mo, amount, 'None'); }
			}
		}
	}

	// One line a second per live actor of the listed classes (and the player)
	void Watch(String classes)
	{
		Actor pl = players[0].mo;
		if (pl)
		{
			Weapon w = pl.player ? pl.player.ReadyWeapon : null;
			console.printf("WATCH t=%i player health=%i weapon=%s ammo1=%i ammo2=%i locks=%i%i%i%i", leveltics / 35, pl.health, w ? w.GetClassName() : 'None', pl.CountInv("WolfClip"), pl.CountInv("SRAmmo2"),
				pl.CheckKeys(60, false, true), pl.CheckKeys(61, false, true), pl.CheckKeys(62, false, true), pl.CheckKeys(63, false, true));
		}

		Array<String> names;
		classes.Split(names, ",");
		for (int n = 0; n < names.Size(); n++)
		{
			ThinkerIterator it = ThinkerIterator.Create(names[n]);
			Actor mo;
			while (mo = Actor(it.Next()))
			{
				String st = String.Format("%c%s tics=%i", 0x41 + mo.frame, ClassicBase(mo) && mo.sprite == mo.GetSpriteIndex(ClassicBase(mo).basesprite) ? "" : String.Format("(spr %i)", mo.sprite), mo.tics);
				console.printf("WATCH t=%i %s health=%i state=%s dist=%.0f speed=%.2f solid=%i shootable=%i height=%.0f", leveltics / 35, mo.GetClassName(), mo.health, st, pl ? mo.Distance2D(pl) : -1, mo.Speed, mo.bSolid, mo.bShootable, mo.height);
			}
		}
	}

	void SwitchTest(bool use)
	{
		ThinkerIterator it = ThinkerIterator.Create("EoDSwitch");
		EoDSwitch sw;
		while (sw = EoDSwitch(it.Next()))
		{
			Vector2 g = ParsedMap.CoordsToGrid(sw.pos.xy);
			if (use) { sw.Use(players[0].mo); }
			console.printf("SWITCH %i,%i kind=%i on=%i", g.x, g.y, sw.kind, sw.IsOn());
		}

		it = ThinkerIterator.Create("EoDShooterWall");
		EoDShooterWall w;
		while (w = EoDShooterWall(it.Next()))
		{
			Vector2 g = ParsedMap.CoordsToGrid(w.pos.xy);
			console.printf("SHOOTER %i,%i group=%i active=%i dir=%i", g.x, g.y, w.group, w.active, w.dir);
		}

		int balls = 0;
		it = ThinkerIterator.Create("EoDWallFireball");
		while (it.Next()) { balls++; }
		console.printf("FIREBALLS %i", balls);

		ParsedMap pm = MapHandler.Get().curmap;
		EoDMapData data = EoDMap.Data(pm);
		for (int r = 0; r < data.remotepushwalls.Size(); r++)
		{
			int index = data.remotepushwalls[r] >> 8;
			Vector2 spot = ParsedMap.GridToCoords((index % pm.width, index / pm.width));
			PolyobjectHandle po = PolyobjectHandle.FindPolyobjAt(spot);
			console.printf("REMOTE %i,%i marker=%i moved=%.0f", index % pm.width, index / pm.width, data.remotepushwalls[r] & 0xFF, po ? (po.GetPos() - spot).length() : -1);
		}
	}

	void Report()
	{
		ParsedMap map = MapHandler.Get() ? MapHandler.Get().curmap : null;
		if (!map)
		{
			console.printf("REPORT no parsed map (level %s)", level.mapname);
			return;
		}

		MapHandler handler = MapHandler.Get();
		String game = ParsedMap.GetGameName(map.gametype, map.extension);
		console.printf("REPORT map='%s' file=%s ext=%s gametype=%i tables=%s mapnum=%i", map.mapname, map.datafile.path, map.extension, map.gametype, game, map.mapnum);
		if (map.info) { console.printf("REPORT info: %s '%s' music=%s next=%s secretnext=%s", map.info.mapname, map.info.levelname, map.info.music, map.info.nextmap, map.info.nextsecretmap); }

		Array<int> nowall, untouched, noactor;
		for (int i = 0; i < map.width * map.height; i++)
		{
			int t = map.planes[0][i];
			TileInfo tile = map.TileAtIndex(t, map.gametype);
			if (!tile) { AddUnique(nowall, t); }
			else if (tile.flags & (TileInfo.TILE_WALL | TileInfo.TILE_DOOR) && !GraphicsHandler.CheckTouched(tile.tex[0])) { AddUnique(untouched, t); }

			int a = map.planes[1][i];
			if (a <= 0 || a == 98 || a == 99 || (a >= 19 && a <= 22)) { continue; } // empty, secret door marker, walk-over exit, player starts
			if (!ActorMap.GetActor(handler.actormaps, map.gametype, a, 4, game)) { AddUnique(noactor, a); }
		}

		console.printf("REPORT plane0 codes with no tile info: %s", ListCodes(nowall, true));
		console.printf("REPORT wall/door codes whose texture wasn't drawn: %s", ListCodes(untouched, true));
		console.printf("REPORT object codes with no actor: %s", ListCodes(noactor, false));

		Array<String> names;
		Array<int> counts;
		ThinkerIterator it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			String n = mo.GetClassName();
			int idx = names.Find(n);
			if (idx == names.Size()) { names.Push(n); counts.Push(1); }
			else { counts[idx]++; }
		}

		String spawned = "";
		for (int n = 0; n < names.Size(); n++) { spawned.AppendFormat("%s%s x%i", n ? ", " : "", names[n], counts[n]); }
		console.printf("REPORT spawned: %s", spawned);

		// One hit point sample per enemy class (AReyePGame.SkillHealth)
		Array<Name> hpnames;
		String hp = "";
		ThinkerIterator hit = ThinkerIterator.Create("ClassicBase");
		Actor e;
		while (e = Actor(hit.Next()))
		{
			if (!e.bIsMonster || hpnames.Find(e.GetClassName()) != hpnames.Size()) { continue; }
			hpnames.Push(e.GetClassName());
			hp.AppendFormat(" %s=%i", e.GetClassName(), e.health);
		}
		console.printf("REPORT health:%s", hp);

		// Actors whose current frame has no sprite texture (a missing Sprite/canvas)
		Array<Name> nosprite;
		String missing = "";
		ThinkerIterator sit = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(sit.Next()))
		{
			if (!a.curstate || a.bInvisible || a.sprite == a.GetSpriteIndex("TNT1") || nosprite.Find(a.GetClassName()) != nosprite.Size()) { continue; }

			TextureID tex = a.curstate.GetSpriteTexture(0);
			if (tex.IsValid() && a.sprite != a.GetSpriteIndex("UNKN")) { continue; }

			nosprite.Push(a.GetClassName());
			missing.AppendFormat(" %s", a.GetClassName());
		}
		console.printf("REPORT no sprite:%s", missing.length() ? missing : " none");

		// Elevator switch faces wired as normal / secret exits
		int normalexits = 0, secretexits = 0;
		for (int l = 0; l < level.lines.Size(); l++)
		{
			Line ln = level.lines[l];
			if (ln.special != 80 || ln.args[0] != 10) { continue; }
			if (ln.args[2] == 10) { secretexits++; } else { normalexits++; }
		}
		console.printf("REPORT exits: %i normal, %i secret switch faces", normalexits, secretexits);

		// What the player starts the level with
		String held = "";
		if (players[0].mo)
		{
			for (Inventory item = players[0].mo.inv; item; item = item.inv)
			{
				if (item is "Weapon" || item is "Ammo") { held.AppendFormat(" %s=%i", item.GetClassName(), item.amount); }
			}
			if (players[0].ReadyWeapon || players[0].PendingWeapon != WP_NOCHANGE)
			{
				Weapon w = players[0].PendingWeapon != WP_NOCHANGE ? players[0].PendingWeapon : players[0].ReadyWeapon;
				held.AppendFormat(" (in hand: %s)", w ? w.GetClassName() : 'None');
			}
		}
		console.printf("REPORT player:%s", held);

		// Door slabs (polyobjects) should sit on door tiles: list the ones that don't,
		// and door tiles with no slab
		Array<int> slabtiles;
		String stray = "";
		int parked = 0, pushwalls = 0;
		ThinkerIterator pit = ThinkerIterator.Create("PolyobjectHandle");
		PolyobjectHandle po;
		while (po = PolyobjectHandle(pit.Next()))
		{
			Vector2 g = ParsedMap.CoordsToGrid(po.Origin);
			if (g.x < 0 || g.y < 0 || g.x >= map.width || g.y >= map.height) { parked++; continue; } // unused slabs wait off the map
			int gi = int(g.y) * map.width + int(g.x);
			slabtiles.Push(gi);
			if (map.planes[1][gi] == 98) { pushwalls++; continue; } // pushwall marker
			TileInfo t = map.TileAtIndex(map.planes[0][gi], map.gametype);
			if (!t || !(t.flags & TileInfo.TILE_DOOR)) { stray.AppendFormat(" %i,%i(0x%02X)", int(g.x), int(g.y), map.planes[0][gi]); }
		}
		String noslab = "";
		for (int i = 0; i < map.width * map.height; i++)
		{
			TileInfo t = map.TileAtIndex(map.planes[0][i], map.gametype);
			if (t && t.flags & TileInfo.TILE_DOOR && slabtiles.Find(i) == slabtiles.Size()) { noslab.AppendFormat(" %i,%i", i % map.width, i / map.width); }
		}
		console.printf("REPORT doors: %i slabs (%i pushwalls, +%i parked); on non-door tiles:%s; door tiles without slab:%s", slabtiles.Size(), pushwalls, parked, stray.length() ? stray : " none", noslab.length() ? noslab : " none");

		for (int s = 0; s < level.sectors.Size(); s++)
		{
			Sector sec = level.sectors[s];
			if (sec.CenterFloor() == sec.CenterCeiling()) { continue; }

			console.printf("REPORT flats: floor=%s ceiling=%s", TexMan.GetName(sec.GetTexture(Sector.floor)), TexMan.GetName(sec.GetTexture(Sector.ceiling)));
			break;
		}
	}

	// Keeps the list sorted
	static void AddUnique(in out Array<int> list, int value)
	{
		if (list.Find(value) != list.Size()) { return; }

		int i = 0;
		while (i < list.Size() && list[i] < value) { i++; }
		list.Insert(i, value);
	}

	static String ListCodes(Array<int> list, bool hex)
	{
		if (!list.Size()) { return "none"; }

		String ret = "";
		for (int i = 0; i < list.Size(); i++)
		{
			ret.AppendFormat(hex ? "%s0x%02X" : "%s%i", i ? " " : "", list[i]);
		}

		return ret;
	}
}
