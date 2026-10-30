// End of Destiny's weather (MCS's code, editor's SPEAR.EXE image offsets).
//
// Row 0 cells 4-7 of each map hold a sky mode for the level before (4, 5) and
// after (6, 7) an Artefact of Displacement: 0 the textured ceiling, 1 a sky,
// 2 and up a sky with Wolf4SDL-style snow (level setup 0x10d51, ThreeDRefresh
// 0x6043, DrawSnow 0x5186). When a pair differs and one of it is 2 or more the
// weather comes and goes (0xf3f4): after each 30 s spell the flake count climbs
// to 300 or drains to 2, one flake at a time (PlayLoop 0x1244d). The count
// lives across levels and starts at none in a new game.
//
// MCS draws the flakes everywhere on the level, behind walls only. Here they
// fall only on open tiles judged outdoors: an area bounded by walls and doors
// whose walls are mostly the snowy ones (snow-topped wall, snowy hedges).
class EoDWeather : StaticEventHandler
{
	const MAXFLAKES = 300;
	const SPELL = 2100; // 70 Hz tics

	int flakes, timer;
	bool rising;

	// This level's
	int mapnum;
	bool varies;
	Array<bool> outdoors;

	static const int snowywalls[] = { 64, 66, 67, 68 };

	override void NewGame()
	{
		flakes = 0;
	}

	override void WorldLoaded(WorldEvent e)
	{
		mapnum = -1;
	}

	override void WorldTick()
	{
		if (AReyePGame.CurrentFamily() != "EOD") { return; }

		MapHandler handler = MapHandler.Get();
		if (!handler || !handler.curmap) { return; }
		ParsedMap pm = handler.curmap;
		if (pm.planes[0].Size() < 8) { return; }

		if (mapnum != pm.mapnum) { Survey(pm); }

		if (varies)
		{
			for (int frame = 0; frame < 2; frame++) { Step(); } // two 70 Hz frames a tic
		}

		int mode = pm.planes[0][(AReyePGame.Warped() ? 6 : 4) + (varies ? 1 : 0)];
		if (mode < 2) { return; }

		// A steady snowfall falls at full strength (MCS would keep whatever count
		// the last changing level left, none at all after a new game)
		int count = varies ? flakes : MAXFLAKES;
		Actor mo = players[consoleplayer].mo;
		if (mo && count > 0) { Snow(mo, pm, count); }
	}

	void Step()
	{
		timer++;
		if (timer <= SPELL) { return; }

		if (rising)
		{
			if (flakes >= MAXFLAKES) { timer = 0; rising = false; }
			else if (Random[EoDWeather](0, 255) <= 0x20) { flakes++; }
		}
		else
		{
			if (flakes <= 2) { timer = 0; rising = true; }
			else if (Random[EoDWeather](0, 255) <= 0x40) { flakes--; }
		}
	}

	void Survey(ParsedMap pm)
	{
		mapnum = pm.mapnum;

		Array<int> p0;
		p0.Copy(pm.planes[0]);
		bool before = p0[4] >= 2 || p0[5] >= 2, after = p0[6] >= 2 || p0[7] >= 2;
		varies = (before && p0[4] != p0[5]) || (after && p0[6] != p0[7]);

		int w = pm.width, h = pm.height;
		outdoors.Clear();
		outdoors.Resize(w * h);
		if (!before && !after) { return; }

		// Flood each area (open floor, stopped by walls, doors and pushwalls) and
		// weigh the wall faces round it
		Array<int> area, stack, members;
		area.Resize(w * h);
		for (int i = 0; i < w * h; i++) { area[i] = -1; }

		int areas = 0;
		for (int start = w; start < w * h; start++)
		{
			if (area[start] >= 0 || !Open(pm, start)) { continue; }

			int snowy = 0, faces = 0;
			members.Clear();
			stack.Push(start);
			area[start] = areas;

			while (stack.Size())
			{
				int t = stack[stack.Size() - 1];
				stack.Pop();
				members.Push(t);

				int x = t % w, y = t / w;
				for (int d = 0; d < 4; d++)
				{
					static const int dx[] = { 1, -1, 0, 0 };
					static const int dy[] = { 0, 0, 1, -1 };
					int nx = x + dx[d], ny = y + dy[d];
					if (nx < 0 || nx >= w || ny < 1 || ny >= h) { continue; }

					int n = ny * w + nx;
					if (Open(pm, n))
					{
						if (area[n] < 0) { area[n] = areas; stack.Push(n); }
						continue;
					}

					int code = p0[n];
					if (code <= 0 || code >= 0x5A) { continue; }

					faces++;
					for (int s = 0; s < snowywalls.Size(); s++)
					{
						if (code == snowywalls[s]) { snowy++; break; }
					}
				}
			}

			if (faces && snowy * 5 >= faces)
			{
				for (int m = 0; m < members.Size(); m++) { outdoors[members[m]] = true; }
			}
			areas++;
		}

		CVar report = CVar.FindCVar("areyep_report");
		if (report && report.GetInt())
		{
			int outside;
			for (int i = 0; i < outdoors.Size(); i++) { if (outdoors[i]) { outside++; } }
			console.printf("REPORT weather: modes %i %i / %i %i%s, %i of %i open tiles outdoors", p0[4], p0[5], p0[6], p0[7], varies ? " (changing)" : "", outside, OpenTiles(pm));
		}
	}

	static int OpenTiles(ParsedMap pm)
	{
		int n;
		for (int t = pm.width; t < pm.width * pm.height; t++) { if (Open(pm, t)) { n++; } }
		return n;
	}

	// Floor a flake can fall on: not a wall, door, automatic door or pushwall
	static bool Open(ParsedMap pm, int t)
	{
		int code = pm.planes[0][t];
		if (code < 0x6B || code == 0x90 || code == 0x91) { return false; }

		return pm.planes[1][t] != 0x62;
	}

	// Flakes drifting down from the ceiling over outdoor tiles within 320 units;
	// at the full 300 that's ten a tic
	void Snow(Actor mo, ParsedMap pm, int count)
	{
		int spawns = count * 10 / MAXFLAKES;
		if (Random[EoDSnow](0, MAXFLAKES - 1) < count * 10 % MAXFLAKES) { spawns++; }

		for (int n = 0; n < spawns; n++)
		{
			Vector2 at = mo.pos.xy + (FRandom[EoDSnow](-320, 320), FRandom[EoDSnow](-320, 320));
			Vector2 grid = ParsedMap.CoordsToGrid(at);
			if (grid.x < 0 || grid.y < 1 || grid.x >= pm.width || grid.y >= pm.height) { continue; }
			if (!outdoors[int(grid.y) * pm.width + int(grid.x)]) { continue; }

			Sector sec = level.PointInSector(at);
			double floorz = sec.floorplane.ZAtPoint(at), ceilz = sec.ceilingplane.ZAtPoint(at);
			if (ceilz - floorz < 32) { continue; } // inside a wall

			double fall = FRandom[EoDSnow](0.8, 1.4);
			mo.A_SpawnParticle(0xF0F0FF, SPF_FULLBRIGHT, int((ceilz - floorz) / fall), FRandom[EoDSnow](2.5, 4.0), 0,
				at.x - mo.pos.x, at.y - mo.pos.y, ceilz - mo.pos.z, FRandom[EoDSnow](-0.3, 0.3), FRandom[EoDSnow](-0.3, 0.3), -fall);
		}
	}
}
