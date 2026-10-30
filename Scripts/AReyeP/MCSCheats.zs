// AReyeP and MCS's own cheat keys, held down together in play, in place of
// Wolf3D's (CheckKeys: SR image 0xd0ed, messages 0xdd47; EoD 0x117e2 and
// 0x1273b). Their Wolf3D-style give-all costs the score and marks the game as
// cheated; M-L-I, the old Wolf3D one, is a trap; M-C-S and R-I-P are a joke.
// (The originals also add ten minutes to the level time; the engine's level
// clock can't be wound on here.)
class MCSCheats play
{
	enum Cheat
	{
		CH_NONE,
		CH_VERSION,   // B-A-T
		CH_MLI,       // M-L-I
		CH_MCS,       // M-C-S: "Try RIP!"
		CH_RIP,       // R-I-P: "Try MCS!"
		CH_ALL,       // SR C-A-T, EoD L-A-M-E
		CH_AMMO,      // EoD C-A-H
	};

	// Keyboard scan codes held together for each cheat, by game
	static ui int Match(String family, in out Array<bool> held)
	{
		if (Held(held, 0x30, 0x1e, 0x14)) { return CH_VERSION; } // B A T
		if (Held(held, 0x32, 0x26, 0x17)) { return CH_MLI; }     // M L I
		if (Held(held, 0x32, 0x2e, 0x1f)) { return CH_MCS; }     // M C S
		if (Held(held, 0x13, 0x17, 0x19)) { return CH_RIP; }     // R I P

		if (family == "EOD")
		{
			if (Held(held, 0x26, 0x1e, 0x32, 0x12)) { return CH_ALL; } // L A M E
			if (Held(held, 0x2e, 0x1e, 0x23)) { return CH_AMMO; }      // C A H
		}
		else if (Held(held, 0x2e, 0x1e, 0x14)) { return CH_ALL; }  // C A T

		return CH_NONE;
	}

	static ui bool Held(in out Array<bool> held, int a, int b, int c, int d = -1)
	{
		return held[a] && held[b] && held[c] && (d < 0 || held[d]);
	}

	static clearscope String Message(String family, int cheat, int slot, bool cheated)
	{
		bool eod = family == "EOD";
		switch (cheat)
		{
			case CH_VERSION:
				return eod ? "End of Destiny\nFinal Version 1.12\nMar.19, 2006\nBy AReyeP and MCS" : "Spear Resurrection\nFinal Version 1.00\nNov.13, 2001\nBy AReyeP and MCS";
			case CH_MLI:
				if (eod) { return "Visit www.areyep.com!"; }
				if (slot != 20) { return "Betagraphiken Saugen!"; }
				return cheated ? "Sorry, you cheated!" : "You reached the final level!";
			case CH_MCS: return "Try RIP!";
			case CH_RIP: return "Try MCS!";
			case CH_ALL:
				return eod ? "You now have 200% Health,\nall four Keys, all Weapons,\nand a backpack of Ammo!" : "You now have 200% Health,\n150 Ammo and all Keys!";
			case CH_AMMO: return "You now have 100% Health\nand a whole heap of Ammo!";
		}

		return "";
	}

	static void Apply(Actor mo, String family, int cheat, int slot)
	{
		if (!mo || !mo.player) { return; }
		bool eod = family == "EOD";

		switch (cheat)
		{
			case CH_MCS:
			case CH_RIP:
				mo.GiveInventory("Score", 1); // one point for the trouble
				break;
			case CH_MLI:
				// End of Destiny takes every gun away (but on the last level)
				if (eod && slot != 20) { TakeGuns(mo); }
				break;
			case CH_ALL:
				Cheated(mo);
				SetHealth(mo, 200);
				if (eod)
				{
					mo.GiveInventory("EoDBackpack", 1);
					static const Class<Weapon> guns[] = { "WolfPistol", "WolfMachineGun", "SRMk3", "SRMk4", "EoDRifle", "EoDRocketLauncher" };
					for (int g = 0; g < guns.Size(); g++) { mo.GiveInventory(guns[g], 1); }
					SetAmount(mo, "WolfClip", 200);
					SetAmount(mo, "SRAmmo2", 200);
					SetAmount(mo, "EoDRifleAmmo", 36);
					SetAmount(mo, "WolfRocketPickup", 20);
					mo.A_SelectWeapon("EoDRocketLauncher"); // GiveWeapon(6)
				}
				else
				{
					mo.GiveInventory("SRMk4", 1);
					SetAmount(mo, "WolfClip", 150);
					SetAmount(mo, "SRAmmo2", 150);
					mo.A_SelectWeapon("SRMk4"); // GiveWeapon(4)
				}
				static const Class<Inventory> keys[] = { "YellowKey", "BlueKey", "SRBloodKey", "SRElevatorKey" };
				for (int k = 0; k < keys.Size(); k++) { mo.GiveInventory(keys[k], 1); }
				break;
			case CH_AMMO:
				Cheated(mo);
				SetHealth(mo, 100);
				SetAmount(mo, "WolfClip", 100);
				SetAmount(mo, "SRAmmo2", 100);
				SetAmount(mo, "EoDRifleAmmo", 18);
				SetAmount(mo, "WolfRocketPickup", 10);
				break;
		}
	}

	// The give-alls zero the score and mark the game as cheated
	static void Cheated(Actor mo)
	{
		mo.TakeInventory("Score", 0x7FFFFFFF);
		mo.GiveInventory("MCSCheated", 1);
	}

	static void SetHealth(Actor mo, int amount)
	{
		mo.health = mo.player.health = amount;
	}

	static void SetAmount(Actor mo, Class<Inventory> cls, int amount)
	{
		Inventory inv = mo.FindInventory(cls);
		if (!inv)
		{
			mo.GiveInventory(cls, 1);
			inv = mo.FindInventory(cls);
		}
		if (!inv) { return; }

		inv.MaxAmount = max(inv.MaxAmount, amount);
		inv.Amount = amount;
	}

	static void TakeGuns(Actor mo)
	{
		Array<Inventory> guns;
		for (Inventory inv = mo.Inv; inv; inv = inv.Inv)
		{
			if (inv is "Weapon" && !(inv is "WolfKnife") && !(inv is "EoDSpear")) { guns.Push(inv); }
		}

		for (int g = 0; g < guns.Size(); g++) { mo.RemoveInventory(guns[g]); guns[g].Destroy(); }
		mo.A_SelectWeapon("WolfKnife");
	}
}

// Carried for the rest of the game once a give-all cheat is used (MCS's
// "cheated" flag: the last level's M-L-I tells on you)
class MCSCheated : Inventory
{
	Default
	{
		+Inventory.UNDROPPABLE
		+Inventory.UNTOSSABLE
		+Inventory.UNCLEARABLE
		Inventory.MaxAmount 1;
	}
}
