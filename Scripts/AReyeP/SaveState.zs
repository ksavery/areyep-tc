// SR's state that a save doesn't keep: SRRules is a static handler. The TC
// restores the parsed map itself (MapHandler.RestoreParsedMap).
class AReyePSaveState : EventHandler
{
	bool warped;

	override void WorldLoaded(WorldEvent e)
	{
		SRRules rules = SRRules.Get();
		if (!e.IsSaveGame || !rules) { return; }

		rules.warped = warped;
		rules.slot = AReyePGame.CurrentFamily() == "SR" ? AReyePGame.CurrentSlot() : -1;
	}

	override void WorldTick()
	{
		SRRules rules = SRRules.Get();
		if (rules) { warped = rules.warped; }
	}
}
