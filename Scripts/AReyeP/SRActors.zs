// Spear Resurrection actors.
//
// Art comes from VSWAP.SR via Data/GraphicMaps/SR.txt (tools/sr_sprites.py):
// stock Spear sprite names show SR's redrawn art, SR* names are SR-only pages.
// Behaviour follows AReyeP's SR manual (offline areyep.com copy), with values
// read from MCS's code: the editor's-version SPEAR.EXE unpacked with
// tools/unlzexe.py, GetBonus switch at image 0x12422 (tools/cases.py).

// Ammo type 2 (MCS Mk3/Mk4). The manual allows 150 of each ammo type.
class SRAmmo2 : Ammo
{
	Default
	{
		//$Category Spear Resurrection/Ammo
		//$Title Ammo 2 (clip)
		Inventory.Amount 8;
		Inventory.MaxAmount 150;
		Inventory.Icon "I_CLIP_O";
		Inventory.AltHUDIcon "I_CLIP";
		Inventory.PickupMessage "";
		Inventory.PickupSound "pickups/ammo";
		Ammo.BackpackAmount 20;
		Ammo.BackpackMaxAmount 150;
	}

	States
	{
		Spawn:
			SRA2 A -1;
			Loop;
	}
}

class SRAmmo2Crate : SRAmmo2
{
	Default
	{
		//$Title Ammo 2 (crate of 25)
		Inventory.Amount 25;
		Inventory.PickupSound "pickups/ammobox";
	}

	States
	{
		Spawn:
			SRC2 A -1;
			Loop;
	}
}

class SROutdoorClip : WolfClip
{
	States
	{
		Spawn:
			SROA A -1;
			Loop;
	}
}

class SRPistolPickup : WolfPistol
{
	Default
	{
		Weapon.AmmoGive 4;
	}

	States
	{
		Spawn:
			SRPI A -1;
			Loop;
	}
}

// MCS Mk3: chaingun-class weapon on ammo type 2 (art in the Spear chaingun slot)
class SRMk3 : WolfChaingun
{
	Default
	{
		//$Category Spear Resurrection/Weapons
		//$Title MCS Mk3
		Tag "MCS Mk3";
		Weapon.AmmoType "SRAmmo2";
		Weapon.AmmoGive 6;
		Inventory.PickupMessage "You picked up an MCS Mk3"; // MCS's message (EoD shows it, SR prints none)
	}
}

// MCS Mk4: four barrels, "uses ammunition at an almost frightening rate"
class SRMk4 : SRMk3
{
	Default
	{
		//$Title MCS Mk4
		Tag "MCS Mk4";
		Inventory.PickupSound "sr/sound20";
		Weapon.SelectionOrder 0;
		Weapon.SlotNumber 5;
		Inventory.PickupMessage "You picked up an MCS Mk4"; // MCS's message (EoD shows it, SR prints none)
	}

	States
	{
		Spawn:
			SRM4 A -1;
			Loop;
		Ready: // raised and lowered by ClassicWeapon's states, as the TC's own guns
			SRMK A 1 A_WeaponReady();
			Loop;
		Fire:
			SRMK B 2;
		Hold:
			SRMK C 2 Bright A_FireGun(4.0);
			SRMK D 2 Bright A_FireGun(4.0);
			SRMK E 2 {
				A_FireGun(4.0);
				A_ReFire();
			}
			SRMK A 0 A_Jump(256, "Ready");
	}
}

class SRBloodKey : RedKey
{
	Default
	{
		//$Category Spear Resurrection/Keys
		//$Title Blood Key
	}

	States
	{
		Spawn:
			SRKB A -1;
			Stop;
	}
}

class SRElevatorKey : GreenKey
{
	Default
	{
		//$Category Spear Resurrection/Keys
		//$Title Elevator Key
	}

	States
	{
		Spawn:
			SRKE A -1;
			Stop;
	}
}

// Small medkit: +5% (Spear's dog food slot gave 4)
class SRSmallMedkit : DogFood
{
	Default
	{
		Inventory.Amount 5;
		Inventory.PickupSound "sr/sound7";
	}
}

class SRBlackDiamond : Score
{
	Default
	{
		//$Category Spear Resurrection/Treasure
		//$Title Black Diamond
		+COUNTITEM
		+Inventory.NEVERLOCAL
		Inventory.Amount 2500;
		Inventory.PickupSound "sr/sound13";
		Inventory.PickupMessage "";
	}

	States
	{
		Spawn:
			SRBD A -1;
			Stop;
	}
}

class SRBloodySkeleton : BoneswithBlood
{
	States
	{
		Spawn:
			SRBS A -1;
			Loop;
	}
}

// Artefact of Life: health up to the next of 125/150/175/200%, 25 of each ammo
// type, and an extra life when US_RndT() <= 96 (97 in 256). Counts as treasure.
class SRArtefactLife : CustomInventory
{
	Default
	{
		//$Category Spear Resurrection/Artefacts
		//$Title Artefact of Life
		+COUNTITEM
		+Inventory.AUTOACTIVATE
		+Inventory.BIGPOWERUP
		Inventory.MaxAmount 0;
		Inventory.PickupSound "pickups/life";
		Inventory.PickupMessage "";
	}

	States
	{
		Spawn:
			LIFE A -1 Bright;
			Loop;
		Pickup:
			LIFE A 0 {
				A_SetHealth(clamp((health + 1) / 25 * 25 + 25, 125, 200));
				A_GiveInventory("WolfClip", 25);
				A_GiveInventory("SRAmmo2", 25);
				if (Random[SRLife](0, 255) <= 96) { LifeHandler.GiveLife(self); }
				return true;
			}
			Stop;
	}
}

// Artefact of Invulnerability: 30 seconds (2100 tics); also 10000 points
class SRGodModeArtefact : PowerupGiver
{
	Default
	{
		//$Category Spear Resurrection/Artefacts
		//$Title Artefact of Invulnerability
		+COUNTITEM
		+Inventory.AUTOACTIVATE
		+Inventory.BIGPOWERUP
		Inventory.MaxAmount 0;
		Powerup.Type "PowerInvulnerable";
		Powerup.Duration -30;
		Inventory.PickupSound "sr/sound2";
		Inventory.PickupMessage "God mode!"; // MCS's message (EoD shows it, SR prints none)
	}

	States
	{
		Spawn:
			SRGM A -1 Bright;
			Stop;
	}

	override bool TryPickup(in out Actor toucher)
	{
		if (!Super.TryPickup(toucher)) { return false; }

		toucher.GiveInventory("Score", 10000);
		return true;
	}
}

// Berry bushes: good ones heal 10% (only when below 100%), poisonous ones take 16%
class SRGoodBerryBush : Health
{
	Default
	{
		//$Category Spear Resurrection/Health
		//$Title Berry Bush (+10%)
		+Inventory.AUTOACTIVATE
		Inventory.Amount 10;
		Inventory.MaxAmount 100;
		Inventory.PickupSound "pickups/food";
		Inventory.PickupMessage "";
	}

	States
	{
		Spawn:
			SRBB A -1;
			Stop;
	}
}

class SRBadBerryBush : CustomInventory
{
	Default
	{
		//$Category Spear Resurrection/Health
		//$Title Berry Bush (poisonous, -16%)
		+Inventory.AUTOACTIVATE
		Inventory.MaxAmount 0;
		Inventory.PickupSound "sr/sound16"; // TAKEDAMAGESND, via TakeDamage
		Inventory.PickupMessage "";
	}

	States
	{
		Spawn:
			SRBB B -1;
			Stop;
		Pickup:
			SRBB B 0 {
				DamageMobj(null, null, 16, 'Poison', DMG_NO_ARMOR);
				return true;
			}
			Stop;
	}
}

// Floor hazards that act on whoever moves onto their tile
class SRFloorHazard : Actor
{
	bool spent;

	Default
	{
		Radius 20;
		Height 8;
		+NOBLOCKMAP
		+DONTSPLASH
	}

	virtual bool Affects(Actor mo) { return mo.bShootable && (mo.player || mo.bIsMonster) && mo.health > 0; }

	// MCS's TakeRandomDamage(base, range): skill 1 base + 0..range-1, skill 2 five
	// more, skills 0 and 3 base + 10 + 0..2*range-1 (the baby skill's damage
	// factor then applies, as for all TC damage)
	static int RandomDamage(int base, int range)
	{
		switch (G_SkillPropertyInt(SKILLP_ACSReturn))
		{
			case 1: return base + Random[SRDamage](0, range - 1);
			case 2: return base + 5 + Random[SRDamage](0, range - 1);
		}

		return base + 10 + Random[SRDamage](0, range * 2 - 1);
	}
	virtual void Trigger(Actor mo) {}

	override void Tick()
	{
		Super.Tick();
		if (spent) { return; }

		BlockThingsIterator it = BlockThingsIterator.Create(self, 32);
		while (it.Next())
		{
			Actor mo = it.thing;
			if (!mo || mo == self || !Affects(mo)) { continue; }
			if (abs(mo.pos.x - pos.x) > 32 || abs(mo.pos.y - pos.y) > 32 || mo.pos.z > floorz + 8) { continue; }

			Trigger(mo);
			if (spent || bDestroyed) { return; }
		}
	}
}

// Artefact of Death: "kills anyone who moves over it, including you!"
// MCS's code is TakeDamage(1000), so god mode protects you.
class SRDeathArtefact : SRFloorHazard
{
	Default
	{
		//$Category Spear Resurrection/Artefacts
		//$Title Artefact of Death
	}

	States
	{
		Spawn:
			BASK A -1;
			Stop;
	}

	// Enemies die on it too, four or five a level (one count shared by all
	// artefacts); the one after that takes it away (SR 0x157d1, EoD 0x1ba04)
	override void Trigger(Actor mo)
	{
		MCSRules rules = MCSRules.Get();
		bool usedup;
		if (!mo.player && rules)
		{
			if (rules.deathkills <= 0)
			{
				usedup = true;
				rules.deathkills = Random[MCS](4, 5);
			}
			rules.deathkills--;
		}

		mo.DamageMobj(self, self, 1000, 'Extreme');
		if (usedup) { Destroy(); }
	}
}

// Landmine: TakeRandomDamage(25, 10) for the player; kills enemies that step on it
class SRLandmine : SRFloorHazard
{
	Default
	{
		//$Category Spear Resurrection/Hazards
		//$Title Landmine
		DeathSound "sr/sound82"; // LANDMINESND
	}

	States
	{
		Spawn:
			SRLM A -1;
			Stop;
		Death:
			SRXB B 5 Bright A_Scream();
			SRXB CD 5 Bright;
			Stop;
	}

	override void Trigger(Actor mo)
	{
		int damage = mo.player ? RandomDamage(25, 10) : mo.health;

		mo.DamageMobj(self, self, damage, 'Explosion');
		spent = true;
		SetStateLabel("Death");
	}
}

// Green toxic sludge: a pickup that does TakeRandomDamage(10, 10) and is used up
class SRToxicSlime : SRFloorHazard
{
	Default
	{
		//$Category Spear Resurrection/Hazards
		//$Title Toxic Slime
	}

	States
	{
		Spawn:
			SRSL A -1;
			Stop;
	}

	override bool Affects(Actor mo) { return mo.player && mo.health > 0; }

	override void Trigger(Actor mo)
	{
		mo.DamageMobj(self, self, RandomDamage(10, 10), 'Slime');
		Destroy();
	}
}

// Red exploding drum: 35 hit points; leaves toxic slime half the time when shot
// (one time in five when set off by another blast)
class SRExplodingDrum : MCSDrum
{
	Default
	{
		Health 35;
		DeathSound "sr/sound85";
	}

	States
	{
		Spawn:
			SRXB A -1;
			Stop;
		Chained:
			SRXB A 9;
		Death:
			SRXB B 5 Bright {
				A_Scream();
				Game.AttachLight(self, 48.0, "Yellow", (0, 0, 24));
			}
			SRXB C 5 Bright;
			SRXB D 10 Bright;
			SRXB E -1 A_RemoveLight("Light");
			Stop;
	}

	override void LeaveBehind(bool chained)
	{
		if (Random[MCS](0, 255) < (chained ? 0x30 : 0x80)) { DropHere("SRToxicSlime"); }
	}
}

// Artefact of Displacement: touching it moves you to the matching destination.
// Map codes 100/102 are artefacts 1/2, 101/103 their single destination each.
class SRTeleportArtefact : SRFloorHazard
{
	int channel;

	Property Channel:channel;

	Default
	{
		//$Category Spear Resurrection/Artefacts
		//$Title Artefact of Displacement 1
		SRTeleportArtefact.Channel 1;
		+BRIGHT
	}

	States
	{
		Spawn:
			SRTP A -1 Bright;
			Stop;
	}

	override bool Affects(Actor mo) { return mo.player && mo.health > 0; }

	override void Trigger(Actor mo)
	{
		ThinkerIterator it = ThinkerIterator.Create("SRTeleportDestination");
		SRTeleportDestination dest;
		while (dest = SRTeleportDestination(it.Next()))
		{
			if (dest.channel != channel) { continue; }

			Spawn("WolfTeleportOut", mo.pos, ALLOW_REPLACE);
			mo.Teleport((dest.pos.xy, mo.floorz), mo.angle, TELF_KEEPVELOCITY);
			Spawn("WolfTeleportIn", mo.pos, ALLOW_REPLACE);

			// Some SR levels switch to "outside" floor/ceiling colours once you've warped
			SRRules rules = SRRules.Get();
			if (rules && !rules.warped && !rules.zoned)
			{
				rules.warped = true;
				let flats = ReplacementHandler(StaticEventHandler.Find("ReplacementHandler"));
				if (flats) { flats.CheckFlats(); }
			}
			return;
		}
	}
}

class SRTeleportArtefact2 : SRTeleportArtefact
{
	Default
	{
		//$Title Artefact of Displacement 2
		SRTeleportArtefact.Channel 2;
	}
}

class SRTeleportDestination : Actor
{
	int channel;

	Property Channel:channel;

	Default
	{
		//$Category Spear Resurrection/Artefacts
		//$Title Displacement Destination 1
		SRTeleportDestination.Channel 1;
		+NOBLOCKMAP
		+NOSECTOR
		+DONTSPLASH
	}

	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
	}
}

class SRTeleportDestination2 : SRTeleportDestination
{
	Default
	{
		//$Title Displacement Destination 2
		SRTeleportDestination.Channel 2;
	}
}

// Fake teleport: looks like an artefact, does nothing
class SRFakeTeleport : ClassicDecoration
{
	Default
	{
		-SOLID
		+BRIGHT
	}

	States
	{
		Spawn:
			SRTP A -1 Bright;
			Stop;
	}
}

// Suicide clone: Spear's dog slot. Homes in and explodes at arm's reach.
class SRSuicideClone : Dog
{
	Default
	{
		//$Category Spear Resurrection/Enemies
		//$Title Suicide Clone
		ClassicBase.BaseSprite "SCLN";
		Height 64; // drawn full height, like the soldiers (the TC dog it's built on is 38, too low to hit with mouselook)
		MeleeRange 96; // the box check below is the real test
		DropItem "None";
	}

	bool fuse; // EoD's clones each have a fuse; SR's share one (MCSRules.srfuse)

	// MCS's clone chase (SR 0x152df, EoD 0x1b34e): reaching you it jumps and
	// beeps, arming itself if you're within two tiles; reaching you armed it
	// blows up: TakeRandomDamage(25, 10) to you whatever's between, and in EoD
	// MCS's blast around it. Shot down, SR's just dies; EoD's still blows,
	// sparing you (KillActor).
	States
	{
		Melee:
			"####" E 0 {
				// within a tile and a step of you on both axes
				double reach = 64 + Speed;
				if (!target || abs(target.pos.x - pos.x) > reach || abs(target.pos.y - pos.y) > reach) { return ResolveState("Approach"); }

				A_Stop();
				if (Armed()) { return ResolveState("Blast"); }
				return ResolveState(null);
			}
			"####" E 5 A_FaceTarget();
			"####" F 5;
			"####" G 5 A_Arm();
			"####" E 5;
			"####" A 5;
			Goto Chase;
		Approach: // closer first (no melee check this tic)
			"####" A 1 A_NaziChase(null, null);
			Goto Chase;
		Blast:
			"####" E 0 {
				SetArmed(false);
				bool eod = AReyePGame.CurrentFamily() == "EOD";
				if (!eod) { A_StartSound("sr/sound10", CHAN_AUTO); } // LONGEXPLOSIONSND
				if (target && target.player) { target.DamageMobj(self, self, SRFloorHazard.RandomDamage(25, 10), 'Explosion'); }
				DamageMobj(self, self, health, eod ? 'MCSChain' : 'None', DMG_FORCED);
			}
			Stop;
	}

	bool Armed()
	{
		if (AReyePGame.CurrentFamily() == "EOD") { return fuse; }

		MCSRules rules = MCSRules.Get();
		return rules && rules.srfuse;
	}

	void SetArmed(bool on)
	{
		if (AReyePGame.CurrentFamily() == "EOD") { fuse = on; return; }

		MCSRules rules = MCSRules.Get();
		if (rules) { rules.srfuse = on; }
	}

	void A_Arm()
	{
		A_StartSound(AReyePGame.CurrentFamily() == "EOD" ? "eod/bombtrigger" : "sr/sound41", CHAN_WEAPON); // BOMBTRIGGERSND
		if (target && abs(target.pos.x - pos.x) <= 128 && abs(target.pos.y - pos.y) <= 128) { SetArmed(true); }
	}

	// EoD's clone goes up however it dies
	override void Die(Actor source, Actor inflictor, int dmgflags, Name meansofdeath)
	{
		if (AReyePGame.CurrentFamily() == "EOD")
		{
			bShootable = false;
			A_StartSound("eod/longexplosion", CHAN_AUTO);
			MCSRules.ExplodeArea(self, "EOD");
		}

		Super.Die(source, inflictor, dmgflags, meansofdeath);
	}
}

// Wolf3D-style ghosts (invulnerable, chase, hurt on contact) in SR art. The last
// level's leave their pedestals; everything else solid still stops them
class SRGhost : PacManGhost
{
	// Saves from before ClassicBase kept its sprite through a load have them blank
	override void Tick()
	{
		if (!sprite && health > 0) { sprite = SpawnState.sprite; }

		Super.Tick();
	}

	override bool CanCollideWith(Actor other, bool passive)
	{
		if (other is "SRBossPedestal") { return false; }

		return Super.CanCollideWith(other, passive);
	}
}

class SRGrimReaper : SRGhost
{
	Default
	{
		//$Category Spear Resurrection/Enemies
		//$Title Grim Reaper
	}

	States
	{
		Spawn:
			SRGR A 0 A_Jump(128, "Yellow"); // Half of them look like the shootable ghost (SpawnGhosts)
			Goto Super::Spawn;
		Yellow:
			SRGH A 0;
			Goto Super::Spawn;
	}
}

// The one ghost that can be shot (SpawnGhosts, SR image 0x14e80): it dissolves,
// worth 2000 points and not a kill, with a one in four chance of leaving treasure
// (KillActor 0x11189). The Reaper's and the bosses' spawns leave them unshootable.
class SRYellowGhost : PacManGhost
{
	Default
	{
		//$Category Spear Resurrection/Enemies
		//$Title Yellow Ghost
		-INVULNERABLE
		ClassicBase.ScoreAmount 2000;
	}

	States
	{
		Spawn:
			SRGH A 0;
			Goto Super::Spawn;
		Death:
			SRGD ABC 5;
			SRGD D -1;
			Stop;
	}

	override void Die(Actor source, Actor inflictor, int dmgflags, Name MeansOfDeath)
	{
		Super.Die(source, inflictor, dmgflags, MeansOfDeath);

		if (Random[MCS](0, 255) >= 0x40) { return; }

		Class<Actor> treasure = "Crown";
		if (Random[MCS](0, 255) < 0x65) { treasure = "JeweledCross"; }
		else
		{
			int roll = Random[MCS](0, 255);
			if (roll >= 0x65 && roll < 0xB5) { treasure = "Chalice"; }
			else if (Random[MCS](0, 255) < 0xE7) { treasure = "Chest"; }
		}

		Actor mo = Spawn(treasure, pos, ALLOW_REPLACE);
		if (mo) { mo.bDropped = true; }
	}
}

// Afterlife ghosts of the dead bosses: Hans, Gretel, Schabbs, Fettgesicht,
// Wilhelm, Trans (from their art; the pedestals come in the same order)
class SRBossGhost1 : SRGhost { States { Spawn: SRG1 A 0; Goto Super::Spawn; } }
class SRBossGhost2 : SRGhost { States { Spawn: SRG2 A 0; Goto Super::Spawn; } }
class SRBossGhost3 : SRGhost { States { Spawn: SRG3 A 0; Goto Super::Spawn; } }
class SRBossGhost4 : SRGhost { States { Spawn: SRG4 A 0; Goto Super::Spawn; } }
class SRBossGhost5 : SRGhost { States { Spawn: SRG5 A 0; Goto Super::Spawn; } }
class SRBossGhost6 : SRGhost { States { Spawn: SRG6 A 0; Goto Super::Spawn; } }

// Angel ghost (red demon, three frames)
class SRAngelGhost : SRGhost
{
	Default
	{
		//$Category Spear Resurrection/Enemies
		//$Title Angel Ghost
	}

	States
	{
		Spawn:
			SRAG ABC 5 A_Look();
			Loop;
		Chase:
			SRAG ABC 5 A_NaziChase();
			Loop;
		Melee:
			SRAG A 0 A_FaceTarget();
			SRAG ABC 5 A_CustomMeleeAttack(MeleeDamage, "", "", "WolfNazi", false);
			Goto Chase;
	}
}

// Corpses
class SRDeadSuicideClone : DeadGuard { States { Spawn: SCLN K -1; Stop; } }
class SRDeadSS : DeadGuard { States { Spawn: WBLU N -1; Stop; } }
class SRDeadClone : DeadGuard { States { Spawn: WMUT O -1; Stop; } }
class SRDeadOfficer : DeadGuard { States { Spawn: WWHT O -1; Stop; } }

// Animated lights and torches
class SRBlinkingLight : GreenCeilingLight
{
	States
	{
		Spawn:
			SRBL A 6 Bright;
			SRBL B 4 Bright;
			Loop;
	}

	// The TC lights it every tic; its light goes out on the dark frame (B)
	override void Tick()
	{
		Super.Tick();

		if (frame == 1) { AReyePLights.Dark(self); }
		else { AReyePLights.Boost(self, 56, 0x9090FF, 54); }
	}
}

class SRIndoorTorch : SRSolidDecoration
{
	Default
	{
		+BRIGHT
	}

	States
	{
		Spawn:
			SRTI ABCD 5 Bright;
			Loop;
	}
}

class SROutdoorTorch : SRIndoorTorch
{
	States
	{
		Spawn:
			SRTO ABCD 5 Bright;
			Loop;
	}
}

// Static decorations: blocking and walk-over. ClassicDecoration's height of 0
// lets the player (CANPASS) step over it, so the blocking ones stand a tile tall
// like the TC's own (MCS's statinfo "block": SR image 0x3a962, EoD 0x3f6ea)
class SRSolidDecoration : ClassicDecoration
{
	Default
	{
		Height 64;
	}

	// As in the original, these stop people, not missiles: those only stop for
	// walls and whatever they can hurt
	override bool CanCollideWith(Actor other, bool passive)
	{
		if (other.bMissile && !bShootable) { return false; }

		return Super.CanCollideWith(other, passive);
	}
}

// Breakable column (map code 0x107): 50 hit points, knocked down in three 12-tic
// (70 Hz) frames with MCS's column sound, leaving rubble you can walk over
// (SpawnColumn SR image 0x147da / EoD 0x1a6de, KillActor SR 0x1109c / EoD 0x14e01)
class SRBreakableColumn : SRSolidDecoration
{
	Default
	{
		Health 50;
		+SHOOTABLE
		+NOBLOOD
		+DONTTHRUST
		DeathSound "sr/sound68";
		DamageFactor "WolfNazi", 0.0; // as the TC's: enemy fire passes it by
		DamageFactor "WolfNaziRocket", 0.0;
		DamageFactor "WolfNaziFire", 0.0;
		DamageFactor "WolfNaziSyringe", 0.0;
	}

	States
	{
		Spawn:
			COLW A -1;
			Stop;
		Death:
			SRCB A 6 { A_Scream(); A_UnSetSolid(); }
			SRCB BC 6;
			SRCB D -1;
			Stop;
	}
}

// A flat (wall) sprite you can walk through, such as End of Destiny's webs
class SRFlatDecoration : WolfWallSprite
{
	Default
	{
		-SOLID
	}
}

class SRDecoration : ClassicDecoration
{
	Default
	{
		-SOLID
	}
}

class SRBrokenColumn : SRDecoration { States { Spawn: SRCD A -1; Stop; } }
class SRSmallRocks1 : SRDecoration { States { Spawn: SRR1 A -1; Stop; } }
class SRSmallRocks2 : SRDecoration { States { Spawn: SRR2 A -1; Stop; } }
class SRHangingPlant : SRDecoration { Default { +SPAWNCEILING +NOGRAVITY } States { Spawn: SRHP A -1; Stop; } }
class SRRocksSkulls : SRDecoration { States { Spawn: SRRS A -1; Stop; } }
class SRBones1 : SRDecoration { States { Spawn: SRB1 A -1; Stop; } }
class SRBones2 : SRDecoration { States { Spawn: SRB1 B -1; Stop; } }
class SRBones3 : SRDecoration { States { Spawn: SRB3 A -1; Stop; } }
class SRWhiteSkull : SRDecoration { States { Spawn: SRSK A -1; Stop; } }
class SRPinkSkull : SRDecoration { States { Spawn: SRSK B -1; Stop; } }
class SRBoxesOnFloor : SRDecoration { States { Spawn: SRBX A -1; Stop; } }
class SRBlackPuddle : SRDecoration { States { Spawn: SRPU A -1; Stop; } }

class SRBossPedestal : SRSolidDecoration {}
class SRStoneColumn : SRSolidDecoration { States { Spawn: SRSC A -1; Stop; } }
class SRChoppingTable : SRSolidDecoration { States { Spawn: SRBT A -1; Stop; } }
class SRHitlerPedestal : SRBossPedestal { States { Spawn: SRHS A -1; Stop; } }
class SRPlainPedestal : SRSolidDecoration { States { Spawn: SRPD A -1; Stop; } }
class SRPedestalPot : SRSolidDecoration { States { Spawn: SRPD B -1; Stop; } }
class SRDesk : SRSolidDecoration { States { Spawn: SRDK A -1; Stop; } }
class SRBanner : SRSolidDecoration { States { Spawn: SRBN A -1; Stop; } }
class SRDeadTree : SRSolidDecoration { States { Spawn: SRDT A -1; Stop; } }
class SRWellFull : SRSolidDecoration { States { Spawn: SRWL A -1; Stop; } }
class SRWellEmpty : SRSolidDecoration { States { Spawn: SRWL B -1; Stop; } }
class SRRustyDrum : SRSolidDecoration { States { Spawn: SRRD A -1; Stop; } }

// Boss pedestals (Afterlife), full and empty
class SRPedestalHans : SRBossPedestal { States { Spawn: SRPB A -1; Stop; } }
class SRPedestalGretel : SRBossPedestal { States { Spawn: SRPB B -1; Stop; } }
class SRPedestalSchabbs : SRBossPedestal { States { Spawn: SRPB C -1; Stop; } }
class SRPedestalFatface : SRBossPedestal { States { Spawn: SRPB D -1; Stop; } }
class SRPedestalWilhelm : SRBossPedestal { States { Spawn: SRPB E -1; Stop; } }
class SRPedestalTrans : SRBossPedestal { States { Spawn: SRPB F -1; Stop; } }
class SREmptyPedestalHans : SRBossPedestal { States { Spawn: SRPE A -1; Stop; } }
class SREmptyPedestalGretel : SRBossPedestal { States { Spawn: SRPE B -1; Stop; } }
class SREmptyPedestalSchabbs : SRBossPedestal { States { Spawn: SRPE C -1; Stop; } }
class SREmptyPedestalFatface : SRBossPedestal { States { Spawn: SRPE D -1; Stop; } }
class SREmptyPedestalWilhelm : SRBossPedestal { States { Spawn: SRPE E -1; Stop; } }
class SREmptyPedestalTrans : SRBossPedestal { States { Spawn: SRPE F -1; Stop; } }

// Game-wide SR rules that live on the player rather than on map things, and
// MCS's hard-coded per-level effects (PlayLoop, image 0xda60 onwards)
class SRRules : StaticEventHandler
{
	int slot; // map slot (0-22) of the current SR map, -1 elsewhere
	bool warped; // An Artefact of Displacement was used on this map (alternate flats; EoD's too)
	const ANGELDEATHTICS = 105; // Its death animation, and a moment after
	int exittime;
	bool zoned; // This map's alternate flats are on the area past its artefacts instead
	int zonemap;
	Array<int> outside; // Sectors in that area
	int outsideprobe; // One of them to check they're still painted
	TextureID outsidefloor, outsideceiling;

	// SR with the TC's textures setting on: each room gets End of Destiny's floor
	// and ceiling nearest its walls, an elevator the steel of its own walls, a
	// doorway a threshold of its own (a door tile is one sector, so the rooms'
	// floors can't meet under the door), and the outside earth under the night sky
	int texmap;
	Array<TextureID> texfloor, texceiling; // By sector
	Array<double> texangle; // Turning a doorway's threshold to run along its door
	int texprobe;
	int texstyle; // 2: floors only, under the TC's own ceilings; 3: floors and ceilings
	const ELEVATORTILE = 21;
	const HIROSHIMA = 9; // Map slot
	const AFTERLIFESLOT = 20; // Map slot: its "outside" is the afterlife
	const RAMPARTS = 21; // Map slot: a castle top, under SR's sky blue (0x85) past its artefacts
	const GREATESCAPE = 12; // Map slot: a dungeon, cobbled throughout
	const COBBLES = 215;
	const HEDGEFIRST = 66; // SR's hedges and plant walls (66-70): a path between them is outside
	const HEDGELAST = 70;
	const ELEVATORCODE = 22; // The elevator's steel walls
	const ELEVATORCODE2 = 63; // Its other steel, the same panel on its east and west faces
	const ELEVATORFLAT = 200; // The elevator floor and ceiling: End of Destiny's dark metal grid
	const THRESHOLD = 219;
	const EARTH = 197;
	int stormtimer[3];
	int ambienttimer;
	bool needloadout[MAXPLAYERS];

	override void NewGame()
	{
		for (int p = 0; p < MAXPLAYERS; p++) { needloadout[p] = true; }
	}

	override void PlayerRespawned(PlayerEvent e)
	{
		needloadout[e.PlayerNumber] = true;
		if (slot >= 0) { Loadout(e.PlayerNumber); }
	}

	// New life (image 0xc680): 100% health, 8 ammo 1, 4 ammo 2, and the pistol
	// except on maps 0 and 12, where you start with only the knife
	void Loadout(int p)
	{
		needloadout[p] = false;

		PlayerPawn mo = players[p].mo;
		if (!mo) { return; }

		mo.A_SetHealth(100);
		mo.A_SetInventory("WolfClip", 8);
		mo.A_SetInventory("SRAmmo2", 4);

		if (slot == 0 || slot == 12)
		{
			mo.A_TakeInventory("WolfPistol");
			mo.A_SelectWeapon("WolfKnife");
		}
	}

	static clearscope SRRules Get()
	{
		return SRRules(StaticEventHandler.Find("SRRules"));
	}

	override void WorldUnloaded(WorldEvent e)
	{
		warped = false;
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (!e.IsSaveGame) { warped = false; }

		// A new life was owed to the session, not this save: the title screen's
		// NewGame leaves it set. An autosave from a level's start counts as a respawn
		if (e.IsSaveGame && level.time > GameTicRate)
		{
			for (int p = 0; p < MAXPLAYERS; p++) { needloadout[p] = false; }
		}

		if (e.IsSaveGame) { MarkBronzeDoors(); }

		exittime = 0;
		zonemap = 0;
		texmap = 0;
		slot = -1;
		ambienttimer = 0;
		for (int t = 0; t < 3; t++) { stormtimer[t] = 0; }
	}

	// The Angel of Death ends the game: the TC's maps do this with a specialaction,
	// which the shared Level map can't have for just one map
	override void InterfaceProcess(ConsoleEvent e)
	{
		if (e.Name == "srvictory") { Menu.SetMenu('SRVictoryCards'); }
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!e.IsManual && e.Name == "srvictorydone") { level.ExitLevel(0, false); }
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (slot == 20 && e.Thing is "AngelofDeath") { exittime = level.maptime + ANGELDEATHTICS; }
	}

	override void WorldTick()
	{
		if (exittime && level.maptime >= exittime)
		{
			exittime = 0;
			EventHandler.SendInterfaceEvent(consoleplayer, "srvictory");
		}

		if (level.maptime == 1) { StartLevel(); }
		else if (slot < 0) { FindSlot(); } // A loaded save is past that
		ZoneFlats();
		TextureSR();
		if (slot == 0) { Storm(); }
		else if (slot == 20 || slot == 21 || slot == 22) { Ambience(); }
	}

	void FindSlot()
	{
		ParsedMap map = MapHandler.Get() ? MapHandler.Get().curmap : null;
		bool sr = map && AReyePGame.Family(map.extension) == "SR";
		slot = sr ? map.mapnum - AReyePGame.MapBase(map.extension) - 1 : -1;
	}

	// Afterlife's Fuehrer posters, with their death year painted out like its
	// sarcophagus plaque's (SRAFTPS0-1, tools/assets.py)
	void AfterlifePosters()
	{
		if (slot != AFTERLIFESLOT) { return; }

		for (int page = 0; page < 2; page++)
		{
			TextureID from = TexMan.CheckForTexture(String.Format("SR/Wall%04i", 102 + page), TexMan.Type_Any);
			TextureID to = TexMan.CheckForTexture(String.Format("SRAFTPS%i", page), TexMan.Type_Any);
			if (!from.IsValid() || !to.IsValid()) { continue; }

			for (int l = 0; l < level.lines.Size(); l++)
			{
				for (int k = 0; k < 2; k++)
				{
					Side sd = level.lines[l].sidedef[k];
					if (sd && sd.GetTexture(Side.mid) == from) { sd.SetTexture(Side.mid, to); }
				}
			}
		}
	}

	void StartLevel()
	{
		FindSlot();
		AfterlifePosters();

		// Afterlife opens with the gold key in hand
		if (slot == AFTERLIFESLOT)
		{
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p] && players[p].mo) { players[p].mo.GiveInventory("YellowKey", 1); }
			}
		}
		bool sr = slot >= 0;
		MarkBronzeDoors();

		// INTRART1-5: level 13's capture, and each boss's level
		EoDTextLog log = EoDTextLog(StaticEventHandler.Find("EoDTextLog"));
		int text = slot == 12 ? 1 : slot == 4 ? 2 : slot == 9 ? 3 : slot == 14 ? 4 : slot == 17 ? 5 : 0;
		if (log && text) { log.Queue(text); }

		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p] || !players[p].mo) { continue; }

			if (sr && needloadout[p]) { Loadout(p); }

			// GetBonus refuses ammo type 1 at 150 (cmpw $0x96 on gamestate's ammo)
			Inventory clip = players[p].mo.FindInventory("WolfClip");
			if (clip) { clip.MaxAmount = sr ? 150 : clip.Default.MaxAmount; }
		}
	}

	// MCS switched a level to its outside flats for good on the first warp, so
	// walking back in stayed outside. Where the artefacts lead somewhere you can't
	// walk to from the start, that has them instead, along with anywhere green,
	// and the switch stays off
	void ZoneFlats()
	{
		MapHandler handler = MapHandler.Get();
		ParsedMap map = handler ? handler.curmap : null;
		String family = map ? AReyePGame.Family(map.extension) : "";
		if (family != "SR" && family != "EOD") { zoned = false; return; }
		if (family == "SR" && AReyePGame.SRFlatStyle() >= 2) { zoned = false; zonemap = 0; return; } // TextureSR's

		// Until the clock starts, the flats code draws for the next map
		if (level.time < 1) { return; }

		if (zonemap == map.mapnum)
		{
			// Changing the flats setting repaints the whole level
			if (!zoned || level.maptime % 35 || level.sectors[outsideprobe].GetTexture(Sector.ceiling) == outsideceiling) { return; }
			PaintOutside();
			return;
		}

		zonemap = map.mapnum;
		zoned = false;
		outside.Clear();

		String game = map.extension.MakeUpper();
		int mapslot = AReyePGame.SlotOf(map);
		int ceiling, floor, warpedceiling, warpedfloor;
		[ceiling, floor] = AReyePGame.Flats(game, mapslot, false);
		[warpedceiling, warpedfloor] = AReyePGame.Flats(game, mapslot, true);
		bool differs = ceiling != warpedceiling || floor != warpedfloor;

		// End of Destiny's are in the map's row 0, with its sky
		if (family == "EOD")
		{
			for (int c = 0; c < 8; c += 2) { differs = differs || (c < 4 ? map.planes[0][c / 2] != map.planes[0][c / 2 + 2] : map.planes[0][c / 2 + 2] != map.planes[0][c / 2 + 4]); }
		}
		if (!differs) { return; }

		Array<int> open;
		Array<bool> warpedto;
		if (!OutsideTiles(map, family, open, warpedto)) { return; }

		for (int s = 0; s < level.sectors.Size(); s++)
		{
			Sector sec = level.sectors[s];
			if (abs(sec.centerspot.x) > 4096 || abs(sec.centerspot.y) > 4096) { continue; }

			Vector2 pos = ParsedMap.CoordsToGrid(sec.centerspot);
			int i = int(pos.y) * map.width + int(pos.x);
			if (i >= 0 && i < open.Size() && warpedto[i]) { outside.Push(s); }
		}
		if (!outside.Size()) { return; }

		// One the flats code repaints: it passes over a closed pushwall's
		outsideprobe = -1;
		for (int s = 0; s < outside.Size() && outsideprobe < 0; s++)
		{
			Sector sec = level.sectors[outside[s]];
			if (sec.CenterFloor() != sec.CenterCeiling() && map.ActorAt(ParsedMap.CoordsToGrid(sec.centerspot)) != 0x62) { outsideprobe = outside[s]; }
		}
		if (outsideprobe < 0) { return; }

		let flats = ReplacementHandler(StaticEventHandler.Find("ReplacementHandler"));
		if (!flats) { return; }

		// (its own cvar isn't set up in a session that started with a load)
		int style = CVar.GetCVar("g_useflats", players[consoleplayer]).GetInt();

		zoned = true;
		warped = true;
		flats.CheckFlats(style);
		outsidefloor = level.sectors[outsideprobe].GetTexture(Sector.floor);
		outsideceiling = level.sectors[outsideprobe].GetTexture(Sector.ceiling);
		warped = false;
		flats.CheckFlats(style);
		PaintOutside();
	}

	void TextureSR()
	{
		MapHandler handler = MapHandler.Get();
		ParsedMap map = handler ? handler.curmap : null;
		int style = map ? AReyePGame.SRFlatStyle() : 0;
		if (!map || AReyePGame.Family(map.extension) != "SR" || style < 2 || level.time < 1) { texmap = 0; return; }

		if (texmap != map.mapnum || texstyle != style)
		{
			texstyle = style;
			texmap = map.mapnum;
			PlanTextures(map);
			PaintTextures();
			return;
		}

		// The flats code repaints the whole level when its setting changes or a warp
		// switches SR's colours
		if (texprobe >= 0 && level.sectors[texprobe].GetTexture(Sector.floor) != texfloor[texprobe]) { PaintTextures(); }
	}

	void PaintTextures()
	{
		bool sky = false;
		for (int s = 0; s < texfloor.Size(); s++)
		{
			if (!texfloor[s].IsValid()) { continue; }

			level.sectors[s].SetTexture(Sector.floor, texfloor[s]);
			level.sectors[s].SetAngle(Sector.floor, texangle[s]);
			if (texstyle < 3) { continue; }
			level.sectors[s].SetTexture(Sector.ceiling, texceiling[s]);
			level.sectors[s].SetAngle(Sector.ceiling, texangle[s]);
			sky = sky || texceiling[s] == skyflatnum;
		}

		if (sky) { AReyePExtension.StarSky(); }
	}

	// Rooms: open tiles between doors and secret walls, each with the floor and
	// ceiling of the wall around it most (-1 for an elevator's)
	void PlanRooms(ParsedMap map, Array<int> open, out Array<int> room, out Array<int> floorpage, out Array<int> ceilingpage, out Array<bool> outdoorroom)
	{
		int size = map.width * map.height;
		Array<int> votes;
		room.Clear();
		floorpage.Clear();
		ceilingpage.Clear();
		outdoorroom.Clear();
		room.Reserve(size);
		votes.Reserve(90);
		for (int i = 0; i < size; i++) { room[i] = -1; }

		for (int i = 0; i < size; i++)
		{
			if (room[i] >= 0 || !open[i] || IsDoorway(map, i)) { continue; }

			int id = floorpage.Size();
			for (int v = 0; v < votes.Size(); v++) { votes[v] = 0; }
			bool elevator = false;

			Array<int> flood;
			flood.Push(i);
			room[i] = id;
			while (flood.Size())
			{
				int t = flood[flood.Size() - 1];
				flood.Pop();

				for (int d = 0; d < 4; d++)
				{
					int nx = t % map.width + (d == 0 ? 1 : d == 1 ? -1 : 0);
					int ny = t / map.width + (d == 2 ? 1 : d == 3 ? -1 : 0);
					if (nx < 0 || ny < 0 || nx >= map.width || ny >= map.height) { continue; }

					int n = ny * map.width + nx;
					int code = map.planes[0][n];
					if (!open[n] || IsDoorway(map, n))
					{
						if (code >= 1 && code < votes.Size()) { votes[code]++; }
						elevator = elevator || code == ELEVATORTILE;
						continue;
					}
					if (room[n] >= 0) { continue; }

					room[n] = id;
					flood.Push(n);
				}
			}

			int best = 0;
			for (int v = 1; v < votes.Size(); v++) { if (votes[v] > votes[best]) { best = v; } }

			elevator = elevator || best == ELEVATORCODE || best == ELEVATORCODE2; // a start elevator has no switch
			outdoorroom.Push(best >= HEDGEFIRST && best <= HEDGELAST); // walled in hedges and plants
			floorpage.Push(elevator ? -1 : best ? SRFlatTable.floors[best] : 205);
			ceilingpage.Push(elevator ? -1 : best ? SRFlatTable.ceilings[best] : 210);
		}

	}

	void PlanTextures(ParsedMap map)
	{
		int size = map.width * map.height;
		texfloor.Clear();
		texceiling.Clear();
		texfloor.Reserve(level.sectors.Size());
		texceiling.Reserve(level.sectors.Size());
		texangle.Clear();
		for (int s = 0; s < level.sectors.Size(); s++) { texangle.Push(0); } // (Reserve leaves doubles unset)
		texprobe = -1;

		Array<int> open;
		Array<bool> outdoors;
		// Where an artefact takes you is outside only where SR colours it as sky;
		// Admin Blues' and Torture Room's, say, are more of the building
		if (!OutsideTiles(map, "SR", open, outdoors, WarpsOutside(map)))
		{
			outdoors.Clear();
			for (int i = 0; i < size; i++) { outdoors.Push(false); }
		}

		Array<int> room, floorpage, ceilingpage;
		Array<bool> outdoorroom;
		PlanRooms(map, open, room, floorpage, ceilingpage, outdoorroom);

		// Level 18's Spear takes you straight into Afterlife, in the rooms you were
		// in (the Spear's and the one before): wherever the two maps match, level 18
		// takes Afterlife's floors and ceilings, so nothing changes as you cross over
		bool afterlife = AReyePGame.SlotOf(map) == AFTERLIFESLOT;
		bool spearlevel = AReyePGame.SlotOf(map) == AFTERLIFESLOT - 3;
		Array<int> sharedfloor, sharedceiling; // pages; -1 the elevator's, -2 none, -3 black
		if (spearlevel)
		{
			MapHandler handler = MapHandler.Get();
			ParsedMap after = handler ? handler.parsedmaps.GetMapDataByNumber(map.mapnum + 3, map.datafile.path) : null;
			Array<int> afteropen, afterroom, afterfloor, afterceiling;
			Array<bool> afteroutside, afteroutdoorroom;
			if (after && after.width == map.width && after.height == map.height)
			{
				if (!OutsideTiles(after, "SR", afteropen, afteroutside, WarpsOutside(after))) { afteroutside.Clear(); }
				PlanRooms(after, afteropen, afterroom, afterfloor, afterceiling, afteroutdoorroom);
			}
			for (int i = 0; i < size; i++)
			{
				int r = afterroom.Size() ? afterroom[i] : -1;
				bool same = r >= 0 && open[i] && map.planes[0][i] == after.planes[0][i];
				bool outside = same && ((afteroutside.Size() && afteroutside[i]) || afteroutdoorroom[r]);
				sharedfloor.Push(!same ? -2 : outside ? COBBLES : afterfloor[r]);
				sharedceiling.Push(!same ? -2 : outside ? -3 : afterceiling[r]);
			}
		}

		TextureID earth = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", EARTH), TexMan.Type_Any);
		TextureID skyblue = TexMan.CheckForTexture("85", TexMan.Type_Any);
		bool ramparts = AReyePGame.SlotOf(map) == RAMPARTS;
		bool dungeon = AReyePGame.SlotOf(map) == GREATESCAPE;
		TextureID black = TexMan.CheckForTexture("00", TexMan.Type_Any);
		TextureID cobbles = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", COBBLES), TexMan.Type_Any);
		TextureID threshold = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", THRESHOLD), TexMan.Type_Any);
		TextureID steel = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", ELEVATORFLAT), TexMan.Type_Any);
		for (int s = 0; s < level.sectors.Size(); s++)
		{
			Sector sec = level.sectors[s];
			// (closed ones too: a pushwall's opens later)
			if (abs(sec.centerspot.x) > 4096 || abs(sec.centerspot.y) > 4096) { continue; }

			Vector2 pos = ParsedMap.CoordsToGrid(sec.centerspot);
			int i = int(pos.y) * map.width + int(pos.x);
			if (i < 0 || i >= size) { continue; }

			if (spearlevel && sharedfloor[i] > -2 && !(room[i] >= 0 && floorpage[room[i]] < 0)) // (its own elevators stay elevators)
			{
				texfloor[s] = sharedfloor[i] < 0 ? steel : TexMan.CheckForTexture(String.Format("EoD/Wall%04i", sharedfloor[i]), TexMan.Type_Any);
				texceiling[s] = sharedceiling[i] == -3 ? black : sharedceiling[i] < 0 ? steel : TexMan.CheckForTexture(String.Format("EoD/Wall%04i", sharedceiling[i]), TexMan.Type_Any);
			}
			else if (outdoors[i] || (room[i] >= 0 && outdoorroom[room[i]]))
			{
				// Past Afterlife's artefacts is no sky, only the dark over cobbles
				texfloor[s] = afterlife ? cobbles : earth;
				texceiling[s] = afterlife ? black : skyflatnum;
			}
			else if (room[i] >= 0 && floorpage[room[i]] < 0)
			{
				texfloor[s] = steel;
				texceiling[s] = steel;
			}
			else if (room[i] >= 0)
			{
				texfloor[s] = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", floorpage[room[i]]), TexMan.Type_Any);
				texceiling[s] = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", ceilingpage[room[i]]), TexMan.Type_Any);
			}
			else if (open[i] && map.planes[1][i] != 0x62)
			{
				texfloor[s] = threshold;
				texceiling[s] = threshold;

				// Its slabs run along the door: across a north-south passage
				int x = i % map.width, y = i / map.width;
				bool eastwest = (x > 0 && open[i - 1]) || (x < map.width - 1 && open[i + 1]);
				texangle[s] = eastwest ? 0 : 90;
			}
			else
			{
				// Anything else (a pushwall's tile) as the area beside it
				for (int d = 0; d < 4 && !texfloor[s].IsValid(); d++)
				{
					int nx = int(pos.x) + (d == 0 ? 1 : d == 1 ? -1 : 0);
					int ny = int(pos.y) + (d == 2 ? 1 : d == 3 ? -1 : 0);
					if (nx < 0 || ny < 0 || nx >= map.width || ny >= map.height) { continue; }
					int n = ny * map.width + nx;
					if (outdoors[n] || (room[n] >= 0 && outdoorroom[room[n]])) { texfloor[s] = earth; texceiling[s] = skyflatnum; }
					else if (room[n] >= 0 && floorpage[room[n]] >= 0)
					{
						texfloor[s] = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", floorpage[room[n]]), TexMan.Type_Any);
						texceiling[s] = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", ceilingpage[room[n]]), TexMan.Type_Any);
					}
				}
				if (!texfloor[s].IsValid()) { continue; }
			}

			// The dungeon: cobbles underfoot in every room
			if (dungeon && room[i] >= 0 && floorpage[room[i]] >= 0) { texfloor[s] = cobbles; }

			// The ramparts: castle stone underfoot, and on top (past the artefacts,
			// which SR colours blue) the open sky, as their walls' tops are
			if (ramparts && texfloor[s].IsValid() && (outdoors[i] || (room[i] >= 0 && outdoorroom[room[i]])))
			{
				if (room[i] >= 0 && floorpage[room[i]] >= 0) { texfloor[s] = TexMan.CheckForTexture(String.Format("EoD/Wall%04i", floorpage[room[i]]), TexMan.Type_Any); }
				texceiling[s] = skyblue;
			}

			if (texprobe < 0 && sec.CenterFloor() != sec.CenterCeiling() && map.ActorAt(pos) != 0x62) { texprobe = s; }
		}
	}

	// SR colours the area past a map's artefacts as a sky, black or Ramparts'
	// blue (0x85); where it only changes one indoor colour for another, as on
	// Torture Room, it's more of the building
	static bool WarpsOutside(ParsedMap map)
	{
		String game = map.extension.MakeUpper();
		int slot = AReyePGame.SlotOf(map);
		int ceiling, floor, warpedceiling, warpedfloor;
		[ceiling, floor] = AReyePGame.Flats(game, slot, false);
		[warpedceiling, warpedfloor] = AReyePGame.Flats(game, slot, true);
		return warpedceiling != ceiling && (warpedceiling == 0x00 || warpedceiling == 0x85);
	}

	static bool IsDoorway(ParsedMap map, int i)
	{
		TileInfo tile;
		int t;
		[t, tile] = map.TileAt((i % map.width, i / map.width));
		return (tile && tile.flags & TileInfo.TILE_DOOR) || map.planes[1][i] == 0x62;
	}

	// The outside of a map: where an artefact lands you, if you can't walk there
	// from the start, and anywhere green (SR's trees and shrubs) up to its doors
	bool OutsideTiles(ParsedMap map, String family, out Array<int> open, out Array<bool> warpedto, bool warpsoutside = true)
	{
		Array<bool> reached;
		open.Clear();
		open.Reserve(map.width * map.height);
		reached.Reserve(map.width * map.height);

		int start = -1;
		for (int i = 0; i < open.Size(); i++)
		{
			TileInfo tile;
			int t;
			[t, tile] = map.TileAt((i % map.width, i / map.width));
			int a = map.planes[1][i];
			open[i] = (tile && tile.flags & (TileInfo.TILE_FLOOR | TileInfo.TILE_DOOR)) || a == 0x62;
			reached[i] = false;
			if (a >= 0x13 && a <= 0x16) { start = i; }
		}
		if (start < 0) { return false; }

		FloodTiles(map, start, open, reached);

		warpedto.Clear();
		warpedto.Reserve(open.Size());
		for (int i = 0; i < open.Size(); i++) { warpedto[i] = false; }
		for (int i = 0; i < open.Size(); i++)
		{
			int a = map.planes[1][i];
			if (warpsoutside && (a == 101 || a == 103) && !reached[i] && !warpedto[i]) { FloodTiles(map, i, open, warpedto); }
		}

		// Anywhere with trees or shrubs is outside too, up to its doors and secret
		// walls. Hanging vines mean a ceiling: there, only the plants' own tiles are,
		// which on SR2's Black Forest is a strip beyond a room's walls
		Array<int> nodoors;
		nodoors.Copy(open);
		for (int i = 0; i < nodoors.Size(); i++)
		{
			TileInfo tile;
			int t;
			[t, tile] = map.TileAt((i % map.width, i / map.width));
			if ((tile && tile.flags & TileInfo.TILE_DOOR) || map.planes[1][i] == 0x62) { nodoors[i] = false; }
		}

		// Hiroshima (level 10 of both mapsets) is all indoors: its bonsai are pot plants
		bool indoorplants = AReyePGame.SlotOf(map) == HIROSHIMA;

		Array<bool> area;
		area.Reserve(open.Size());
		for (int i = 0; i < open.Size(); i++)
		{
			int a = map.planes[1][i];
			bool greenery = family == "SR" && !indoorplants && (a == 64 || a == 65 || a == 68 || a == 69 || a == 71);
			if (!greenery || !nodoors[i] || warpedto[i]) { continue; }

			for (int n = 0; n < area.Size(); n++) { area[n] = false; }
			FloodTiles(map, i, nodoors, area);

			bool ceiling = false;
			for (int n = 0; n < area.Size() && !ceiling; n++) { ceiling = area[n] && map.planes[1][n] == 70; }

			if (ceiling) { warpedto[i] = true; continue; }

			for (int n = 0; n < area.Size(); n++) { warpedto[n] = warpedto[n] || area[n]; }
		}

		return true;
	}

	void FloodTiles(ParsedMap map, int start, Array<int> open, out Array<bool> reached)
	{
		Array<int> flood;
		flood.Push(start);
		reached[start] = true;
		while (flood.Size())
		{
			int i = flood[flood.Size() - 1];
			flood.Pop();

			int x = i % map.width;
			int y = i / map.width;
			for (int d = 0; d < 4; d++)
			{
				int nx = x + (d == 0 ? 1 : d == 1 ? -1 : 0);
				int ny = y + (d == 2 ? 1 : d == 3 ? -1 : 0);
				if (nx < 0 || ny < 0 || nx >= map.width || ny >= map.height) { continue; }

				int n = ny * map.width + nx;
				if (!open[n] || reached[n]) { continue; }

				reached[n] = true;
				flood.Push(n);
			}
		}
	}

	bool IsOutside(Sector sec)
	{
		return outside.Find(sec.Index()) < outside.Size();
	}

	void PaintOutside()
	{
		for (int s = 0; s < outside.Size(); s++)
		{
			Sector sec = level.sectors[outside[s]];
			sec.SetTexture(Sector.floor, outsidefloor);
			sec.SetTexture(Sector.ceiling, outsideceiling);
		}
	}

	// The bronze key is the stock silver key's class, whose lock draws blue on the
	// automap: SR's and EoD's doors take a lock of their own (LockDefs)
	void MarkBronzeDoors()
	{
		if (!AReyePGame.IsMCS(AReyePGame.CurrentFamily())) { return; }

		for (int l = 0; l < level.lines.Size(); l++)
		{
			if (level.lines[l].locknumber == 61) { level.lines[l].locknumber = 64; }
		}
	}

	// Level sounds from MCS's PlayLoop: the Afterlife plays one of seven sounds
	// (DS:0x10e0) every 1800 tics at a spot 0-6 tiles east/south of the player
	// (PlaySoundLocGlobal); Ramparts plays sound 87 every 12600 tics; Funny
	// Dunnies one of seven toilet sounds (DS:0x10f0) every 2100 tics
	void Ambience()
	{
		static const int afterlife[] = { 98, 99, 100, 94, 95, 96, 97 };
		static const int toilet[] = { 88, 89, 90, 91, 92, 93, 57 };
		static const int periods[] = { 1800, 12600, 2100 };

		ambienttimer += 2; // the periods are 70 Hz tics
		if (ambienttimer <= periods[slot - 20]) { return; }
		ambienttimer = 0;

		if (slot == 20)
		{
			PlayerPawn mo = players[consoleplayer].mo;
			if (!mo) { return; }

			Vector3 spot = mo.pos + (Random[SRAmbient](0, 6) * 64, -Random[SRAmbient](0, 6) * 64, 32);
			Actor emitter = Actor.Spawn("SRSoundSpot", spot);
			if (emitter) { emitter.A_StartSound(String.Format("sr/sound%i", afterlife[Random[SRAmbient](0, 6)]), CHAN_VOICE); }
			return;
		}

		int snd = slot == 21 ? 87 : toilet[Random[SRAmbient](0, 6)];
		S_StartSound(String.Format("sr/sound%i", snd), CHAN_AUTO, CHANF_UI | CHANF_NOPAUSE);
	}

	// Black Forest thunderstorm: three free-running timers (3360, 2130 and 2100
	// tics) each fire a lightning flash; the 2100 one adds thunder and a second
	// flash. The flash is Wolf's bonus "white shift": 18 tics stepping from 15%
	// to 5% toward (64, 62, 0) in the 6-bit palette, i.e. a warm white.
	void Storm()
	{
		static const int periods[] = { 3360, 2130, 2100 };

		for (int t = 0; t < 3; t++)
		{
			stormtimer[t] += 2; // the periods are 70 Hz tics
			if (stormtimer[t] <= periods[t]) { continue; }

			stormtimer[t] = 0;
			if (t == 2) { S_StartSound("sr/thunder", CHAN_AUTO, CHANF_UI | CHANF_NOPAUSE); }

			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p] && players[p].mo) { players[p].mo.A_SetBlend(0xFFF800, 0.15, 9); } // Wolf's bonus flash: 18 70 Hz tics
			}
		}
	}
}

// Invisible point a level sound plays from; removes itself once it's done
class SRSoundSpot : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
	}

	States
	{
		Spawn:
			TNT1 A 175;
			Stop;
	}
}
