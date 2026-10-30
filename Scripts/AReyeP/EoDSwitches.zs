// End of Destiny wall switches, fire shooting walls and remote pushwalls
// (AReyeP's "Map creation notes.txt", SWITCHES). A switch is a plane-1 overlay
// code under a "Switch off"/"Switch on" wall (0x39/0x3A); using it flips the
// wall art and acts on its channel:
//   384/385  toggle fire shooting walls 1/2 (codes 400-407 / 408-415)
//   386/387  move remote pushwalls 1/2 (codes 416-419 / 420-423)
//   388      ceiling lights (level 35)
// Fire wall timing, speed and damage are eod4sdl's (ShootFireballs, T_Projectile).

class EoDMap play
{
	const SWITCHOFF = 0x39;
	const SWITCHON = 0x3A;
	const SWITCHSPECIAL = 31; // ACS_Execute script number the switch lines carry; never run

	// Remote pushwall markers become ordinary pushwall markers (0x62), so the
	// TC builds and moves their slabs; the channel and direction are kept here
	clearscope static void Prepare(ParsedMap pm)
	{
		let data = EoDMapData(pm.extdata);
		if (!data) { pm.extdata = data = new("EoDMapData"); }

		for (int i = 0; i < pm.planes[1].Size(); i++)
		{
			int code = pm.planes[1][i];
			if (code < 416 || code > 423) { continue; }

			data.remotepushwalls.Push(i << 8 | (code - 416));
			pm.planes[1][i] = 0x62;
		}
	}

	clearscope static EoDMapData Data(ParsedMap pm)
	{
		let data = pm ? EoDMapData(pm.extdata) : null;
		return data ? data : EoDMapData(new("EoDMapData"));
	}

	// (group 0/1, byte angle) of the remote pushwall marker at a tile, or -1
	static int, int RemotePushwallAt(Vector2 grid)
	{
		MapHandler handler = MapHandler.Get();
		if (!handler || !handler.curmap) { return -1, 0; }

		ParsedMap pm = handler.curmap;
		EoDMapData data = Data(pm);
		int index = int(grid.y) * pm.width + int(grid.x);
		for (int r = 0; r < data.remotepushwalls.Size(); r++)
		{
			if (data.remotepushwalls[r] >> 8 != index) { continue; }

			int code = data.remotepushwalls[r] & 0xFF;
			static const int angles[] = { 0, 64, 128, 192 }; // E N W S
			return code / 4, angles[code % 4];
		}

		return -1, 0;
	}

	// Remote pushwalls only move from their switch
	static bool IsRemotePushwall(int polynum)
	{
		PolyobjectHandle po = PolyobjectHandle.FindPolyobj(polynum);
		if (!po) { return false; }

		return RemotePushwallAt(ParsedMap.CoordsToGrid(po.StartSpotPos)) > -1;
	}

	static void PushRemote(Actor activator, int group)
	{
		MapHandler handler = MapHandler.Get();
		if (!handler || !handler.curmap) { return; }

		ParsedMap pm = handler.curmap;
		EoDMapData data = Data(pm);
		for (int r = 0; r < data.remotepushwalls.Size(); r++)
		{
			int index = data.remotepushwalls[r] >> 8;
			int g, angle;
			[g, angle] = RemotePushwallAt((index % pm.width, index / pm.width));
			if (g != group) { continue; }

			PolyobjectHandle po = PolyobjectHandle.FindPolyobjAt(ParsedMap.GridToCoords((index % pm.width, index / pm.width)));
			if (po) { DoorHandler.OpenDoor(activator, po.PolyobjectNum, angle, -1, 4); }
		}
	}
}

// What EoDMap.Prepare keeps with a map (ParsedMap.extdata)
class EoDMapData
{
	Array<int> remotepushwalls; // tile index << 8 | marker
}

// Automatic doors (plane 0 0x90/0x91): open while the player stands beside one
// facing it, close when they leave, and ignore the use key (eod4sdl IsPlayerNearby)
class EoDAutoDoors play
{
	static bool IsAutoDoor(int polynum)
	{
		PolyobjectHandle po = PolyobjectHandle.FindPolyobj(polynum);
		if (!po || AReyePGame.CurrentFamily() != "EOD") { return false; }

		int t = MapHandler.TileAt(po.StartSpotPos);
		return t == 0x90 || t == 0x91;
	}

	static void Tick(Actor mo)
	{
		if (!mo || mo.health <= 0) { return; }

		Vector2 here = ParsedMap.CoordsToGrid(mo.pos.xy);
		for (int d = 0; d < 4; d++)
		{
			static const int dx[] = { 1, 0, -1, 0 };
			static const int dy[] = { 0, -1, 0, 1 };
			Vector2 spot = ParsedMap.GridToCoords((here.x + dx[d], here.y + dy[d]));

			int t = MapHandler.TileAt(spot);
			if (t != 0x90 && t != 0x91) { continue; }
			if (abs(Actor.DeltaAngle(mo.angle, d * 90)) > 45) { continue; } // facing it

			PolyobjectHandle po = PolyobjectHandle.FindPolyobjAt(spot);
			if (!po) { continue; }

			DoorEffector eff = DoorEffector(po.FindEffector("DoorEffector"));
			if (eff && (eff.Status == DoorEffector.WDST_OPEN || eff.Status == DoorEffector.WDST_OPENING || eff.Status == DoorEffector.WDST_FIRSTOPENING))
			{
				eff.Counter = max(eff.Counter, 35); // keep it open while they're here
				continue;
			}

			// Open it through its own activation line (it carries the slide angle)
			Sector sec = level.PointInSector(spot);
			for (int l = 0; l < sec.lines.Size(); l++)
			{
				Line ln = sec.lines[l];
				if (ln.special != Polyobj_DoorSlide) { continue; }

				DoorHandler.OpenDoor(mo, ln.Args[0], ln.Args[2], ln.Args[4], ln.Args[1], ln.Args[3]);
				break;
			}
		}
	}
}

// Overlay codes 384-388: invisible, inside the switch wall
class EoDSwitch : Actor
{
	int kind; // 0/1 fire wall channel, 2/3 pushwall channel, 4 lights

	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
	}

	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		kind = MapHandler.ActorAt(pos.xy) - 384;

		// Every face of the switch wall can be used
		Sector sec = level.PointInSector(pos.xy);
		for (int l = 0; l < sec.lines.Size(); l++)
		{
			Line ln = sec.lines[l];
			if (!ln.frontsector || !ln.backsector) { continue; }

			ln.special = 80;
			ln.args[0] = EoDMap.SWITCHSPECIAL;
			ln.activation = SPAC_Use | SPAC_UseBack;
		}
	}

	bool IsOn()
	{
		return MapHandler.TileAt(pos.xy) == EoDMap.SWITCHON;
	}

	// Swap the wall between the switch off/on pages (0x39 -> 112/113, 0x3A -> 114/115)
	void SetOn(bool on)
	{
		MapHandler handler = MapHandler.Get();
		Vector2 grid = ParsedMap.CoordsToGrid(pos.xy);
		int index = int(grid.y) * handler.curmap.width + int(grid.x);
		handler.curmap.planes[0][index] = on ? EoDMap.SWITCHON : EoDMap.SWITCHOFF;

		Sector sec = level.PointInSector(pos.xy);
		for (int l = 0; l < sec.lines.Size(); l++)
		{
			Line ln = sec.lines[l];
			for (int s = 0; s < 2; s++)
			{
				if (!ln.sidedef[s]) { continue; }

				String name = TexMan.GetName(ln.sidedef[s].GetTexture(Side.mid));
				for (int dark = 0; dark < 2; dark++)
				{
					if (name != String.Format("EoD/Wall%04i", (on ? 112 : 114) + dark)) { continue; }

					ln.sidedef[s].SetTexture(Side.mid, TexMan.CheckForTexture(String.Format("EoD/Wall%04i", (on ? 114 : 112) + dark), TexMan.Type_Any));
				}
			}
		}
	}

	void Use(Actor activator)
	{
		bool on = !IsOn();
		SetOn(on);
		A_StartSound("switches/elevator", CHAN_AUTO);

		switch (kind)
		{
			case 0:
			case 1:
				ThinkerIterator it = ThinkerIterator.Create("EoDShooterWall");
				EoDShooterWall w;
				while (w = EoDShooterWall(it.Next()))
				{
					if (w.group == kind) { w.active = !w.active; w.delay = EoDShooterWall.FIREDELAY; }
				}
				break;
			case 2:
			case 3:
				EoDMap.PushRemote(activator, kind - 2);
				break;
			case 4:
				EoDLights.Set(on);
				break;
		}
	}
}

// Ceiling light switch: lit and dead blue ceiling lights swap art, all light
// switches follow, and the level dims while the lights are off (the dimming
// amount is a guess; EoD shades the level then)
class EoDLights play
{
	const DIMMING = 48;

	static void Set(bool on)
	{
		ThinkerIterator it = ThinkerIterator.Create("EoDSwitch");
		EoDSwitch sw;
		while (sw = EoDSwitch(it.Next()))
		{
			if (sw.kind == 4 && sw.IsOn() != on) { sw.SetOn(on); }
		}

		State lit = GetDefaultByType("EoDObjBlueCeilingLight").SpawnState;
		State dead = GetDefaultByType("EoDObjDeadCeilingLight").SpawnState;
		State from = on ? dead : lit, to = on ? lit : dead;

		it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.sprite == from.sprite && mo.frame == from.frame) { mo.sprite = to.sprite; mo.frame = to.frame; }
		}

		if (on) { Dim(-DIMMING); }
		else { Dim(); }
	}

	static void Dim(int amount = DIMMING)
	{
		for (int s = 0; s < level.sectors.Size(); s++)
		{
			level.sectors[s].lightlevel -= amount;
		}
	}
}

// Codes 400-415: shooter walls. Group 1 is 400-407, group 2 408-415; in each,
// inactive E N W S then active E N W S.
class EoDShooterWall : Actor
{
	const FIREDELAY = 50; // state 0x23d4: a fireball every 50 tics (70 Hz) while on

	int group;
	bool active;
	double dir;
	int delay;

	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
	}

	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		int code = MapHandler.ActorAt(pos.xy) - 400;
		group = code / 8;
		active = code % 8 >= 4;
		dir = (code % 4) * 90;
		delay = FIREDELAY;
	}

	override void Tick()
	{
		Super.Tick();
		if (!active || level.isFrozen()) { return; }

		delay -= 2; // two Wolf tics per game tic
		if (delay > 0) { return; }
		delay = FIREDELAY;

		// Only into an open tile
		Vector2 ahead = pos.xy + AngleToVector(dir, 64);
		int t;
		TileInfo tile;
		[t, tile] = MapHandler.TileAt(ahead);
		if (tile && tile.flags & TileInfo.TILE_SOLID) { return; }

		// From the floor: the sprite is a whole Wolf 64x64 frame drawn up from the
		// actor, which puts the flame at mid-height as in the original
		Vector2 start = pos.xy + AngleToVector(dir, 40); // clear of the (solid) shooter wall
		Actor ball = Spawn("EoDWallFireball", (start, level.PointInSector(start).floorplane.ZAtPoint(start)));
		if (ball)
		{
			ball.target = self;
			ball.angle = dir;
			ball.Vel3DFromAngle(ball.speed, dir, 0);
		}
	}
}

// MCS's fireball (image 0x1bdd7): speed 0x2400 a 70 Hz tic (18 units a game
// tic), silent, 30-61 to the player; it kills guards, officers, SS, mutants and
// suicide clones outright and does 100 to anything else (T_Projectile 0x19bea)
class EoDWallFireball : WolfProjectile
{
	Default
	{
		Speed 18;
		Height 56; // Wolf's hits are flat: anything in its path, the player's full height
		DamageType "WolfNaziFire";
		DamageFunction (30 + Random[EoDFire](0, 31));
		+BRIGHT
	}

	States
	{
		Spawn:
			D093 A 3 Bright; // SPR_FIREBALL_1 (front view; the other seven are its rotations)
			Loop;
		Death:
			D094 EFG 6 Bright; // SPR_FIREBALL_EXP1-3
			Stop;
	}

	override int SpecialMissileHit(Actor victim)
	{
		if (victim.player || !victim.bShootable) { return -1; }

		// MCS's KillActor gives the player the points and picks the drop by the
		// player's weapons, whatever did the killing; and the death is the
		// ordinary one (not the TC's burning, nor a drop chosen by the wall)
		Actor credit = NearestPlayer(victim);
		if (victim is "Guard" || victim is "Officer" || victim is "SS" || victim is "Mutant" || victim is "Dog")
		{
			victim.DamageMobj(self, credit ? credit : target, victim.health + 1000, 'MCSFire', DMG_FORCED);
			return -1;
		}

		victim.DamageMobj(self, credit ? credit : target, 100, 'MCSFire'); // no boss damage factor
		return -1;
	}

	static Actor NearestPlayer(Actor from)
	{
		Actor nearest;
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			Actor mo = playeringame[p] ? players[p].mo : null;
			if (mo && mo.health > 0 && (!nearest || from.Distance3D(mo) < from.Distance3D(nearest))) { nearest = mo; }
		}

		return nearest;
	}
}

class EoDRules : EventHandler
{
	override void WorldTick()
	{
		if (AReyePGame.CurrentFamily() == "EOD")
		{
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p]) { EoDAutoDoors.Tick(players[p].mo); }
			}
		}

		// EoD starts every level with the ceiling lights off
		if (level.maptime != 2) { return; }

		ThinkerIterator it = ThinkerIterator.Create("EoDSwitch");
		EoDSwitch sw;
		while (sw = EoDSwitch(it.Next()))
		{
			if (sw.kind == 4) { EoDLights.Dim(); return; }
		}
	}

	override void WorldLinePreActivated(WorldEvent e)
	{
		Line ln = e.ActivatedLine;

		if (ln.special != 80 || ln.args[0] != EoDMap.SWITCHSPECIAL) { return; }
		e.ShouldActivate = false;

		// The switch is the wall sector this line borders that isn't the user's
		for (int s = 0; s < 2; s++)
		{
			Sector sec = s ? ln.backsector : ln.frontsector;
			if (!sec || sec == e.Thing.cursector) { continue; }

			ThinkerIterator ti = ThinkerIterator.Create("EoDSwitch");
			EoDSwitch sw;
			while (sw = EoDSwitch(ti.Next()))
			{
				if (sw.cursector == sec) { sw.Use(e.Thing); return; }
			}
		}
	}
}
