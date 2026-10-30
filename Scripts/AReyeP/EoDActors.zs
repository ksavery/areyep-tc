// End of Destiny actors that aren't plain statics (those are generated into
// EoDStatics.zs). Behaviour follows AReyeP's "Map creation notes.txt" for the
// editor's version and eod4sdl's GetBonus (wl_agent.cpp). Sprites: D### names
// from tools/eod_sprites.py.

// --- Items EoD added over SR ---

// Stealth rifle: silent single shots on its own ammo (eod4sdl: GiveAmmo(2, 4) per clip)
class EoDRifleAmmo : Ammo
{
	Default
	{
		//$Category End of Destiny/Ammo
		//$Title Rifle Ammo
		Inventory.Amount 4;
		Inventory.MaxAmount 50;
		Inventory.PickupMessage "";
		Inventory.PickupSound "pickups/ammo";
		Ammo.BackpackAmount 4;
		Ammo.BackpackMaxAmount 100;
	}

	States
	{
		Spawn:
			D072 A -1; // SPR_STAT_RIFLEAMMO
			Stop;
	}
}

class EoDRifle : WolfPistol
{
	Default
	{
		//$Category End of Destiny/Weapons
		//$Title Stealth Rifle
		Tag "Stealth Rifle";
		AttackSound "eod/silenced";
		+Weapon.NOALERT // a silenced shot wakes no one
		Weapon.AmmoType "EoDRifleAmmo";
		Weapon.AmmoGive 4;
		Weapon.SlotNumber 6;
		Inventory.PickupSound "pickups/mgun";
		-Weapon.WIMPY_WEAPON
		Inventory.PickupMessage "You picked up a stealth rifle"; // MCS's message (EoD shows it, SR prints none)
	}

	States
	{
		Spawn:
			D066 A -1; // SPR_STAT_RIFLE
			Stop;
		Ready:
			D044 A 1 A_WeaponReady(); // SPR_RIFLEREADY
			Loop;
		Select:
			D044 A 1 A_Raise();
			Loop;
		Deselect:
			D044 A 1 A_Lower();
			Loop;
		Fire:
			D044 B 3;
			D044 C 3 Bright;
			D044 D 3 A_RifleShot();
			D044 E 3;
			D044 A 0 A_Refire();
			Goto Ready;
	}
}

// One silenced round: the first enemy in the sights within 20 tiles dies outright,
// in one piece; bosses shrug it off (eod4sdl GunAttack, wp_rifle)
extend class EoDRifle
{
	action void A_RifleShot()
	{
		if (!invoker.DepleteAmmo(false, true)) { return; }
		A_StartSound("eod/silenced", CHAN_WEAPON);

		Actor tgt = AimTarget();
		if (!tgt || !tgt.bShootable || tgt.health <= 0 || tgt is "ClassicBoss") { return; }

		Vector2 d = tgt.pos.xy - pos.xy;
		if (max(abs(d.x), abs(d.y)) / 64 >= 21) { return; }

		tgt.DamageMobj(invoker, self, tgt.health, 'Stealth', DMG_FORCED | DMG_NO_ARMOR);
	}
}

class EoDRocketBox : WolfRocketCrate
{
	Default
	{
		Inventory.Amount 2; // eod4sdl GiveAmmo(3, 2)
	}

	States
	{
		Spawn:
			D073 A -1; // SPR_STAT_LAUNCHERAMMOBOX
			Stop;
	}
}

class EoDRocketLauncher : WolfRocketLauncher
{
	Default
	{
		Weapon.WeaponScaleX 1.0;
		Weapon.WeaponScaleY 1.0;
		Weapon.YAdjust 0;
		Inventory.PickupMessage "You picked up a rocket launcher"; // MCS's message (EoD shows it, SR prints none)
	}

	States
	{
		Spawn:
			D067 A -1; // SPR_STAT_LAUNCHER
			Stop;
		Ready:
			D045 A 1 A_WeaponReady(); // SPR_LAUNCHERREADY
			Loop;
		Select:
			D045 A 1 A_Raise();
			Loop;
		Deselect:
			D045 A 1 A_Lower();
			Loop;
		Fire:
			D045 B 3;
		Hold:
			D045 C 3 Bright A_FireProjectile("WolfRocketPlayer", 0, 1, 0, -8);
			D045 D 3;
			D045 E 3;
			D045 A 20 A_ReFire;
			Goto Ready;
	}
}

// The Spear of Destiny as a weapon (Hell on Earth): throws spears, never runs
// out, 100 damage a hit, then a second's reload (eod4sdl SpearAttack, RELOADDELAY)
class EoDSpear : ClassicWeapon
{
	Default
	{
		Tag "Spear of Destiny";
		AttackSound "dk/attack";
		Weapon.SelectionOrder 0;
		Weapon.SlotNumber 7;
		Weapon.AmmoUse 0;
		+Weapon.CHEATNOTWEAPON
		+Weapon.NOAUTOFIRE
	}

	States
	{
		Spawn:
			SOFD A -1;
			Stop;
		Ready:
			D092 A 1 A_WeaponReady(); // SPR_SPEARREADY
			Loop;
		Select:
			D092 A 1 A_Raise();
			Loop;
		Deselect:
			D092 A 1 A_Lower();
			Loop;
		Fire:
			D092 B 3;
			D092 C 3 Bright A_FireProjectile("EoDSpearProjectile");
			D092 D 3;
			D092 E 3;
			D092 A 35;
			Goto Ready;
	}
}

class EoDSpearProjectile : WolfProjectile
{
	Default
	{
		Speed 20; // 0x2600 per 70 Hz tic
		Damage 100;
		DamageFunction (100);
		DamageType "Spear";
		SeeSound "dk/attack";
		RenderStyle "Normal";
		+BRIGHT
	}

	States
	{
		Spawn:
			R105 A 3 Bright; // SPR_SPEARPROJ_1-8 as rotations
			Loop;
		Death:
			D106 EFG 4 Bright; // SPR_SPEARPROJ_EXP1-3
			Stop;
	}
}

class EoDBackpack : WolfBackpack
{
	Default
	{
		Inventory.PickupMessage "You picked up a backpack"; // MCS's message
	}

	override bool TryPickup(in out Actor toucher)
	{
		if (!Super.TryPickup(toucher)) { return false; }

		// eod4sdl: 40 primary, 20 secondary, 4 rifle, 2 rockets
		toucher.A_GiveInventory("WolfClip", 40);
		toucher.A_GiveInventory("SRAmmo2", 20);
		toucher.A_GiveInventory("EoDRifleAmmo", 4);
		toucher.A_GiveInventory("WolfRocketPickup", 2);
		return true;
	}
}

// Save artefact: an extra life, up to nine
class EoDSaveArtefact : CustomInventory
{
	Default
	{
		//$Category End of Destiny/Artefacts
		//$Title Save Artefact
		+Inventory.AUTOACTIVATE
		Inventory.MaxAmount 0;
		Inventory.PickupSound "pickups/life";
		Inventory.PickupMessage "";
	}

	States
	{
		Spawn:
			D079 ABCD 8 Bright; // SPR_STAT_SAVEGAME1-4
			Loop;
		Pickup:
			TNT1 A 0 {
				if (LifeHandler.CheckLives(self) >= 9) { return false; }
				LifeHandler.GiveLife(self);
				return true;
			}
			Stop;
	}
}

// Fury artefact: berserk knife for a while (the TC's berserk)
class EoDFury : WolfBerserk
{
	Default
	{
		Inventory.PickupMessage "Knife Fury!"; // MCS's message
	}

	States
	{
		Spawn:
			D080 ABCD 8 Bright; // SPR_STAT_FURY1-4
			Loop;
	}
}

// Portable medkit: carried and used later (+25%)
class EoDPortableMedkit : CustomInventory
{
	Default
	{
		//$Category End of Destiny/Health
		//$Title Portable Medkit
		+Inventory.INVBAR
		Inventory.MaxAmount 3;
		Inventory.InterHubAmount 3;
		Inventory.PickupSound "pickups/medkit";
		Inventory.PickupMessage "You picked up a portable medkit"; // MCS's message (EoD shows it, SR prints none)
		Inventory.Icon "HLTHE0";
	}

	States
	{
		Spawn:
			D097 A -1; // SPR_STAT_PORTMED
			Stop;
		Use:
			TNT1 A 0 {
				if (health >= 100) { return false; }
				A_GiveInventory("Health", 25);
				return true;
			}
			Fail;
	}
}

// --- Map systems from AReyeP's notes ---

// Blocking code: invisible; stops enemies, lets the player through. The tile's
// edges become monster-blocking lines, so pushwalls (which AReyeP's notes say to
// guard with these) still slide through.
class EoDBlockingCode : Actor
{
	Default
	{
		//$Category End of Destiny/Triggers
		//$Title Blocking Code
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		Sector sec = level.PointInSector(pos.xy);
		for (int l = 0; l < sec.lines.Size(); l++) { sec.lines[l].flags |= Line.ML_BLOCKMONSTERS; }

		Destroy();
	}
}

// Invisible floor triggers the player "picks up" by walking over them
class EoDTrigger : SRFloorHazard
{
	override bool Affects(Actor mo) { return mo.player && mo.health > 0; }

	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
	}
}

// Secrets count only when these are crossed (pushing a pushwall doesn't)
class EoDSecretTrigger : EoDTrigger
{
	bool issuper;

	Property IsSuper:issuper;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		level.total_secrets++;
	}

	override void Trigger(Actor mo)
	{
		level.found_secrets++;
		console.MidPrint(SmallFont, issuper ? "You found a super secret area" : "You found a secret area"); // MCS's words; the status bar shows them his way
		S_StartSound("misc/secret", CHAN_AUTO, CHANF_UI);
		Destroy();
	}
}

class EoDSuperSecretTrigger : EoDSecretTrigger
{
	Default
	{
		EoDSecretTrigger.IsSuper true;
	}
}

// EndLevel trigger: crossing it ends the level
class EoDEndLevelTrigger : EoDTrigger
{
	override void Trigger(Actor mo)
	{
		spent = true;
		level.ExitLevel(0, false);
	}
}

// Spawn triggers and targets: crossing a trigger warps one active enemy of its
// type onto every target of the same channel. Channels: officer 1/2, SS 1/2,
// guard 1/2 (map codes 512-517 triggers, 518-523 targets).
class EoDSpawnTarget : Actor
{
	int channel;

	Property Channel:channel;

	Default
	{
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

class EoDSpawnTrigger : EoDTrigger
{
	int channel;

	Property Channel:channel;

	static const Class<Actor> enemies[] = { "Officer", "Officer", "SS", "SS", "Guard", "Guard" };

	override void Trigger(Actor mo)
	{
		ThinkerIterator it = ThinkerIterator.Create("EoDSpawnTarget");
		EoDSpawnTarget t;
		while (t = EoDSpawnTarget(it.Next()))
		{
			if (t.channel != channel) { continue; }

			Actor enemy = Spawn(enemies[channel], t.pos, ALLOW_REPLACE);
			if (!enemy) { continue; }

			Spawn("WolfTeleportIn", t.pos, ALLOW_REPLACE);
			enemy.angle = enemy.AngleTo(mo);
			enemy.target = mo;
			enemy.SetState(enemy.SeeState);
		}

		Destroy();
	}
}

class EoDSpawnTriggerOfficer1 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 0; } }
class EoDSpawnTriggerOfficer2 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 1; } }
class EoDSpawnTriggerSS1 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 2; } }
class EoDSpawnTriggerSS2 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 3; } }
class EoDSpawnTriggerGuard1 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 4; } }
class EoDSpawnTriggerGuard2 : EoDSpawnTrigger { Default { EoDSpawnTrigger.Channel 5; } }
class EoDSpawnTargetOfficer1 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 0; } }
class EoDSpawnTargetOfficer2 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 1; } }
class EoDSpawnTargetSS1 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 2; } }
class EoDSpawnTargetSS2 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 3; } }
class EoDSpawnTargetGuard1 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 4; } }
class EoDSpawnTargetGuard2 : EoDSpawnTarget { Default { EoDSpawnTarget.Channel 5; } }

// Teleport artefacts with EoD's animated art; 160 is an invisible one on channel 1
class EoDTeleportArtefact : SRTeleportArtefact
{
	States
	{
		Spawn:
			D058 BCDE 6 Bright; // SPR_STAT_TELE1-4
			Loop;
	}
}

class EoDTeleportArtefact2 : EoDTeleportArtefact
{
	Default
	{
		SRTeleportArtefact.Channel 2;
	}
}

class EoDInvisibleTeleport : SRTeleportArtefact
{
	States
	{
		Spawn:
			TNT1 A -1;
			Stop;
	}
}

// Red exploding drum in EoD art
// 32 hit points. On code 104 it leaves a fire burning; otherwise poison one time
// in three when shot, one in five when set off by another blast (KillActor)
class EoDExplodingDrum : MCSDrum
{
	Default
	{
		Health 32;
		DeathSound "eod/barrelexp";
	}

	States
	{
		Spawn:
			D035 A -1; // SPR_STAT_REDBARREL
			Stop;
		Chained:
			D035 A 9;
		Death:
			D036 A 6 Bright { // SPR_BARRELEXP1-3
				A_Scream();
				Game.AttachLight(self, 48.0, "Yellow", (0, 0, 24));
			}
			D036 BC 6 Bright;
			D037 A -1 A_RemoveLight("Light"); // SPR_BARRELDEAD
			Stop;
	}

	override void LeaveBehind(bool chained)
	{
		if (MapHandler.ActorAt(pos.xy) == 104) { Spawn("EoDObjStationaryFlame", pos); }
		else if (chained ? Random[MCS](0, 255) < 0x30 : Random[MCS](0, 255) >= 0xAA) { DropHere("EoDObjToxicPuddle"); }
	}
}

// 226 Blinking light (the red ceiling light): lit 300 tics, then a flicker,
// picked at the end of each lit spell (image 0x1a024, states 0x2024-0x2054):
// lit 5/dark 3 one time in four, else dark 3 by a fresh 3-in-8 roll, else
// dark 3/lit 5/dark 3
class EoDBlinkingLight : EoDObjBlueCeilingLight
{
	States
	{
		Spawn:
			E001 Q 150 Bright;
			E001 Q 0 Bright {
				if (Random[EoDBlink](0, 255) >= 0xC0) { return ResolveState("LitDark"); }
				if (Random[EoDBlink](0, 255) >= 0xA0) { return ResolveState("Dark"); }
				return ResolveState(null);
			}
			D030 A 2;
		LitDark:
			E001 Q 2 Bright;
		Dark:
			D030 A 2;
			Goto Spawn;
	}
}

// Things that answer the use key (eod4sdl Cmd_Use object checks)
extend class EoDObjSuitOfArmor
{
	override bool Used(Actor user)
	{
		A_StartSound("eod/yourang", CHAN_VOICE); // "You rang?"
		return true;
	}
}

extend class EoDObjToilet
{
	override bool Used(Actor user)
	{
		A_StartSound("eod/toilet", CHAN_VOICE);
		return true;
	}
}

extend class EoDObjRadioOnTable
{
	override bool Used(Actor user)
	{
		A_StartSound("eod/radiocast", CHAN_VOICE);
		return true;
	}
}

class EoDBreakableColumn : SRBreakableColumn
{
	Default
	{
		DeathSound "eod/columnbreak";
	}

	States
	{
		Spawn:
			E000 J -1; // the regular column
			Stop;
		Death:
			D043 A 6 { A_Scream(); A_UnSetSolid(); } // SPR_COLUMNBREAK1-4
			D043 BC 6;
			D043 D -1;
			Stop;
	}
}
