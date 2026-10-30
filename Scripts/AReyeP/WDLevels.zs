// Wolfendoom uses Wolf3D's actors, with its own DigiMap (WOLFDOOM.WFD file
// 0x3c476). Sound fields are changed on instances, so other games keep theirs.
class WDLevelRules : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		Actor mo = e.Thing;
		if (!mo || AReyePGame.CurrentFamily() != "WFD") { return; }
		if (mo.player)
		{
			mo.PainSound = "wd/sound16";
			mo.DeathSound = "wd/sound9";
		}

		if (mo is "GretelGrosse") { Voice(mo, "wd/sound82", "wd/sound59", "wd/sound83"); }
		else if (mo is "HansGrosse") { Voice(mo, "wd/sound55", "wd/sound59", "wd/sound56"); }
		else if (mo is "DrSchabbs") { Voice(mo, "wd/sound64", "", "wd/sound63"); }
		else if (mo is "FakeHitler") { Voice(mo, "wd/sound62", "wd/sound58", "wd/sound65"); }
		else if (mo is "HitlerMech") { Voice(mo, "wd/sound53", "wd/sound59", "wd/sound70"); }
		else if (mo is "Hitler") { Voice(mo, "wd/sound57", "wd/sound59", "wd/sound54"); }
		else if (mo is "Giftmacher") { Voice(mo, "wd/sound80", "wd/sound59", "wd/sound79"); }
		else if (mo is "Fettgesicht") { Voice(mo, "wd/sound81", "wd/sound59", "wd/sound84"); }
		else if (mo is "Dog") { Voice(mo, "wd/sound41", "wd/sound68", "wd/sound10"); }
		else if (mo is "Guard") { Voice(mo, "wd/sound21", "wd/sound58", "wd/guarddeath"); }
		else if (mo is "SS") { Voice(mo, "wd/sound51", "wd/sound60", "wd/guarddeath"); }
		else if (mo is "Officer") { Voice(mo, "wd/sound66", "wd/sound58", "wd/guarddeath"); }
		else if (mo is "Mutant") { Voice(mo, "", "wd/sound58", "wd/sound52"); }

		if (mo is "WolfPistol") { mo.AttackSound = "wd/sound24"; }
		else if (mo is "WolfMachineGun") { mo.AttackSound = "wd/sound26"; }
		else if (mo is "WolfChaingun") { mo.AttackSound = "wd/sound11"; }

		Inventory item = Inventory(mo);
		if (!item) { return; }
		if (mo is "WolfClip") { item.PickupSound = "wd/sound31"; }
		else if (mo is "WolfMachineGun") { item.PickupSound = "wd/sound30"; }
		else if (mo is "WolfChaingun") { item.PickupSound = "wd/sound38"; }
		else if (mo is "YellowKey" || mo is "BlueKey") { item.PickupSound = "wd/sound12"; }
		else if (mo is "JeweledCross") { item.PickupSound = "wd/sound35"; }
		else if (mo is "Chalice") { item.PickupSound = "wd/sound36"; }
		else if (mo is "Chest") { item.PickupSound = "wd/sound37"; }
		else if (mo is "Crown") { item.PickupSound = "wd/sound45"; }
		else if (mo is "DogFood" || mo is "PlateofFood") { item.PickupSound = "wd/sound33"; }
		else if (mo is "FirstAidKit") { item.PickupSound = "wd/sound34"; }
		else if (mo is "Life") { item.PickupSound = "wd/sound44"; }
	}

	static void Voice(Actor mo, String see, String attack, String death)
	{
		mo.SeeSound = see;
		if (attack.Length()) { mo.AttackSound = attack; }
		mo.DeathSound = death;
	}
}
