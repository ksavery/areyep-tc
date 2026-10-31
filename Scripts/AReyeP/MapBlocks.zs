// An X on the automap over anything solid that isn't a wall or a monster, such
// as a row of columns across a hallway, once you've seen its sector. Goes when
// the thing stops being solid, as a broken column does.
class AReyePBlockMarker : MapMarker
{
	Default
	{
		Scale 1.0;
	}

	States
	{
		Spawn:
			AMBK A -1;
			Stop;
	}

	override void Tick()
	{
		if (!master || !master.bSolid) { Destroy(); return; }

		Super.Tick();
	}
}

class AReyePBlockMarkers : StaticEventHandler
{
	bool pending;

	override void WorldLoaded(WorldEvent e)
	{
		pending = true;
	}

	override void WorldTick()
	{
		if (!pending) { return; }
		pending = false;

		MapHandler handler = MapHandler.Get();
		if (!handler || !handler.curmap || !AReyePGame.IsGame(handler.curmap.extension)) { return; }

		// Saved with the level, so only a save from before these has none
		if (ThinkerIterator.Create("AReyePBlockMarker", Thinker.STAT_MAPMARKER).Next()) { return; }

		let it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (!mo.bSolid || mo.bIsMonster || mo.player || mo is "Inventory") { continue; }

			let marker = Actor.Spawn("AReyePBlockMarker", mo.pos);
			if (!marker) { continue; }

			marker.master = mo;
			marker.args[1] = 1; // once its sector has been seen
			marker.args[2] = 1; // scaled with the map
		}
	}
}
