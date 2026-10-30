// Keep the TC's intermission for the other games; Wolfendoom uses its own
// VGAGRAPH breathing portrait and victory picture.
class AReyePStats : ClassicStats
{
	override void Start(wbstartstruct wb)
	{
		Super.Start(wb);
		if (AReyePGame.CurrentFamily() != "WFD") { return; }

		Breathe[0] = TexMan.CheckForTexture("WDBREATHE0", TexMan.Type_Any);
		Breathe[1] = TexMan.CheckForTexture("WDBREATHE1", TexMan.Type_Any);
		BJFinal = TexMan.CheckForTexture("WDBJFINAL", TexMan.Type_Any);
	}
}
