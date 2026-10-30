// End of Destiny's own enemies, from MCS's code (editor's SPEAR.EXE, unpacked):
// SpawnBoss (image 0x1ad63) gives each its class, first state and hit points,
// FirstSighting (0x156a6) its chase speed and sight sound, KillActor (0x14bcd)
// its points, drops and death state. State tics there are 70 Hz, halved here.
// Hit points, points and speeds live in AReyePGame (Games.zs).

// --- Flames and Frosty (MCS's T_Ghosts movers) ---

// They drift straight at you and hurt while within a tile of you: MoveObj
// (image 0x14af8) does TakeDamage(1) with the "take damage" sound each time
// they try to step closer, which is every frame (two a game tic at 70 fps)
class EoDGhostMover : ClassicBoss
{
	Default
	{
		-ClassicBase.OptionalRotations
		-COUNTKILL // in the kill total but never counted as killed in MCS's code
		+NOBLOOD
		Painchance 0;
		SeeSound "";
		DeathSound "eod/deathscream6";
	}

	States
	{
		SpriteList:
			D083 A 0; // flames
			D089 A 0; // ghost flame
			D104 A 0; // snowman
			D098 A 0; // toilet clone
			D090 A 0; // Ultra Clone
			D099 A 0; // Robot
			D091 A 0; // Heinrich
			Stop;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || health <= 0 || !target || !target.player || target.health <= 0 || level.isFrozen()) { return; }
		if (!InStateSequence(CurState, ResolveState("Chase"))) { return; }
		if (abs(target.pos.x - pos.x) >= 64 || abs(target.pos.y - pos.y) >= 64) { return; }

		target.DamageMobj(self, self, 2, 'WolfNazi');
		target.A_StartSound("eod/takedamage", CHAN_BODY, CHANF_NOSTOP);
	}
}

// 105 Spectre flame (flame with eyes): you can walk through it. Shot down it
// falls to embers, which relight when nothing stands on them (A_FlameRelight)
class EoDSpectreFlame : EoDGhostMover
{
	Default
	{
		//$Category End of Destiny/Enemies
		//$Title Spectre Flame
		-SOLID
		+BRIGHT
		SeeSound "eod/sound27";
		DeathSound "eod/sound62";
		ClassicBase.BaseSprite "D083"; // FLAME1-4, FLAME_DIE1-4
	}

	States
	{
		Spawn.Stand:
			"####" ABCD 5 {
				if (bDormant || bDeafandBlind || GetAge() < 2 || GameHandler.CheckFizzle()) { return; }
				A_Look();
			}
			Loop;
		Chase:
			"####" AAAAABBBBBCCCCCDDDDD 1 A_NaziChase(null, null);
			Loop;
		Death:
			"####" EFGH 5;
		Embers:
			"####" G 5 A_FlameRelight();
			"####" H 5;
			Loop;
	}

	// Every second ember frame counts up a level-wide counter; past a random
	// 10-19 it resets and the flame relights unless the player or anything
	// shootable is on it (image 0x1ac27). Its hit points stay spent, so the
	// next hit puts it out again.
	void A_FlameRelight()
	{
		EoDLevelRules rules = EoDLevelRules(EventHandler.Find("EoDLevelRules"));
		if (!rules || ++rules.flamecount <= Random[EoDFlame](10, 19)) { return; }
		rules.flamecount = 0;

		BlockThingsIterator it = BlockThingsIterator.Create(self, 64);
		while (it.Next())
		{
			Actor mo = it.thing;
			if (mo == self || !(mo.player || mo.bShootable) || mo.health <= 0) { continue; }
			if (abs(mo.pos.x - pos.x) < 64 && abs(mo.pos.y - pos.y) < 64) { return; }
		}

		health = 1;
		bShootable = true;
		bCorpse = false;
		A_SetSize(-1, Default.Height);
		A_StartSound(SeeSound, CHAN_VOICE);
		SetStateLabel("Chase");
	}
}

// 224 Ghost flame (no eyes). No map places one. MCS gives it Frosty's class,
// so shooting one runs the snowman's melt; here it simply goes out.
class EoDGhostFlame : EoDGhostMover
{
	Default
	{
		//$Category End of Destiny/Enemies
		//$Title Ghost Flame
		+BRIGHT
		ClassicBase.BaseSprite "D089"; // STAT_FLAME1-4
	}

	States
	{
		Spawn.Stand:
			"####" A 5 {
				if (bDormant || bDeafandBlind || GetAge() < 2 || GameHandler.CheckFizzle()) { return; }
				A_Look();
			}
			Loop;
		Chase:
			"####" AAAAABBBBBCCCCCDDDDD 1 A_NaziChase(null, null);
			Loop;
		Death:
			D083 I 5 { A_Scream(); EoDSnowman.DropTreasure(self); }
			D083 JKL 5;
			Stop;
	}
}

// 262 Frosty the Snowman. One in eight just stands there jiggling: SpawnBoss
// starts it in its walk without the chase speed FirstSighting would give.
// Melted, it lies 1024 tics; then, if nobody is on it, it rebuilds itself
// as a new snowman half the time and stays melted for good otherwise.
class EoDSnowman : EoDGhostMover
{
	Default
	{
		//$Category End of Destiny/Enemies
		//$Title Frosty the Snowman
		ClassicBase.BaseSprite "D104"; // SNOWMAN_W1-2, DIE1-3, DEAD
	}

	States
	{
		Spawn.Stand:
			"####" A 5 {
				if (bDormant || bDeafandBlind || GetAge() < 2 || GameHandler.CheckFizzle()) { return; }
				A_Look();
			}
			Loop;
		Spawn.Idle:
			"####" AB 5;
			Loop;
		Chase:
			"####" AAAAABBBBB 1 A_NaziChase(null, null);
			Loop;
		Death:
			"####" C 5 { A_Scream(); DropTreasure(self); }
			"####" DE 5;
		Melted:
			"####" F 512;
			"####" F 0 A_Rebuild();
			Loop;
		Rebuild:
			"####" FEDC 5;
			"####" A 8;
			"####" A 0 {
				let frosty = EoDSnowman(Spawn("EoDSnowman", pos));
				if (frosty) { frosty.angle = angle; }
			}
			Stop;
		Gone:
			"####" F -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (Random[EoDSnowman](0, 255) > 0xDF) { SetStateLabel("Spawn.Idle"); }
	}

	void A_Rebuild()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, 64);
		while (it.Next())
		{
			Actor mo = it.thing;
			if (mo == self || !(mo.player || mo.bShootable) || mo.health <= 0) { continue; }
			if (abs(mo.pos.x - pos.x) < 64 && abs(mo.pos.y - pos.y) < 64) { return; }
		}

		if (Random[EoDSnowman](0, 255) >= 0x80) { SetStateLabel("Rebuild"); }
		else { SetStateLabel("Gone"); }
	}

	// One time in four a treasure, each picked by its own roll (KillActor)
	static void DropTreasure(Actor mo)
	{
		if (Random[EoDTreasure](0, 255) >= 0x40) { return; }

		Class<Actor> treasure = "Crown";
		if (Random[EoDTreasure](0, 255) < 0x65) { treasure = "JeweledCross"; }
		else if (Random[EoDTreasure](0, 255) >= 0x65 && Random[EoDTreasure](0, 255) < 0xB5) { treasure = "Chalice"; }
		else if (Random[EoDTreasure](0, 255) >= 0x76 && Random[EoDTreasure](0, 255) < 0xE7) { treasure = "Chest"; }

		Actor item = mo.Spawn(treasure, mo.pos, ALLOW_REPLACE);
		if (item) { item.bDropped = true; }
	}
}

// 267 Clone on the toilet: a mutant sitting down until he sees you
class EoDToiletClone : Mutant
{
	Default
	{
		//$Category End of Destiny/Enemies
		//$Title Clone on Toilet
		-ClassicNazi.Patrolling
		DropItem "None"; // KillActor skips the clip for a mutant on code 267
	}

	// MCS's ScanInfoPlane also spawns the toilet he sits on; his stays non-solid
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		Actor toilet = Spawn("EoDObjToilet", pos);
		if (toilet) { toilet.bSolid = false; }
	}

	States
	{
		Spawn.Stand:
			D098 A 5 {
				if (bDormant || bDeafandBlind || GetAge() < 2 || GameHandler.CheckFizzle()) { return; }
				A_Look;
			}
			Loop;
		See:
			"####" A 1 {
				sprite = GetSpriteIndex(Name(basesprite)); // stand up
				ActivatePeers();
				SetStateLabel("Chase");
			}
			Stop;
		Pain:
		Pain.Alt:
			"####" A 0 { sprite = GetSpriteIndex(Name(basesprite)); }
			Goto Super::Pain;
	}
}

// --- Bosses (single view, like Wolf's) ---

// Their rockets: MCS's rocketobj (T_Projectile, image 0x19a34), launched with the
// rocket launcher's sound, bursting with the explosion sample. No splash: a
// direct hit does 30-61 to the player; enemies in its way are hit too, the
// small ones killed outright, the rest taking 100, except those that fire
// rockets themselves, which it passes.
class EoDRocket : WolfRocketSOD
{
	Default
	{
		SeeSound "eod/rlaunch";
		DeathSound "eod/landmine";
		DamageFunction (30 + (GameHandler.WolfRandom() >> 3));
	}

	States
	{
		Death:
			ROCP A 3 Bright;
			ROCP BC 3 Bright
			{
				if (!g_noblood) { A_FadeOut(0.33); }
				lightradius /= alpha;
			}
			Stop;
	}

	override int SpecialMissileHit(Actor victim)
	{
		if (victim.player || !victim.bShootable || victim == target) { return -1; }
		if (victim is "EoDUltraClone" && !(victim is "EoDRobot")) { return 1; }
		if (victim is "EoDTurret" || victim is "BarnacleWilhelm") { return 1; }

		if (victim is "Guard" || victim is "Officer" || victim is "SS" || victim is "Mutant" || victim is "Dog")
		{
			victim.DamageMobj(self, target, victim.health + 1000, 'Explosion', DMG_FORCED);
		}
		else { victim.DamageMobj(self, target, 100, 'MCSRocket'); } // no boss damage factor

		return 0;
	}
}

// 264 Ultra Clone: Dr. Schabbs' chase (keeps his distance, dodges), then a
// rocket 4 degrees right of you and, 20 tics on, one 4 degrees left
class EoDUltraClone : ClassicBoss
{
	Default
	{
		//$Category End of Destiny/Bosses
		//$Title Ultra Clone
		+ClassicBase.RUN
		Speed 4;
		SeeSound "";
		DeathSound "eod/clonebossdeath";
		-ClassicBase.OptionalRotations
		ClassicBase.BaseSprite "D090";
		ClassicBoss.Projectile "EoDRocket";
	}

	States
	{
		Chase:
			"####" AAAAA 1 A_NaziChase(chance:16);
			"####" A 1;
			"####" BBBB 1 A_NaziChase(chance:16);
			"####" CCCCC 1 A_NaziChase(chance:16);
			"####" CC 1;
			"####" DDDD 1 A_NaziChase(chance:16);
			Loop;
		Missile:
			"####" E 15 A_FaceTarget();
			"####" G 5;
			"####" E 5 A_BossRocket(-4);
			"####" F 5;
			"####" E 10 A_BossRocket(4);
			Goto Chase;
		Death:
			"####" A 35 A_BossDeath1();
			"####" HIJ 5;
			"####" K 5 A_WolfBossDeath();
		Dead:
			"####" L -1;
			Stop;
	}

	// Aimed at the player when it leaves (image 0x1a9f1)
	void A_BossRocket(double offset = 0)
	{
		A_FaceTarget();
		A_SpawnProjectile(projectile, 32, 0, offset, CMF_AIMDIRECTION);
	}

	// KillActor: the gold key on the first seven maps only
	virtual void A_BossDeath1()
	{
		A_Scream();
		if (AReyePGame.CurrentSlot() <= 6) { A_SpawnItemEx("YellowKey"); }
	}
}

// 178 Robot: Hans's chase, then four bursts of the gatling
class EoDRobot : EoDUltraClone
{
	Default
	{
		//$Title Robot
		-ClassicBase.RUN
		SeeSound "eod/robotsight";
		AttackSound "eod/gatling";
		DeathSound "eod/robotdeath";
		BloodColor "00 00 00";
		ClassicBase.BaseSprite "D099";
	}

	States
	{
		Chase:
			"####" AAAAA 1 A_NaziChase(null, "Missile");
			"####" A 1;
			"####" BBBB 1 A_NaziChase(null, "Missile");
			"####" CCCCC 1 A_NaziChase(null, "Missile");
			"####" CC 1;
			"####" DDDD 1 A_NaziChase(null, "Missile");
			Loop;
		Missile:
			"####" E 15 A_FaceTarget();
			"####" G 5;
			"####" E 5 A_NaziShoot();
			"####" F 5 A_NaziShoot();
			"####" E 5 A_NaziShoot();
			"####" E 5 A_NaziShoot();
			Goto Chase;
		Death:
			"####" A 35 A_Scream();
			"####" HIJ 8;
			"####" K 8 A_WolfBossDeath();
		Dead:
			"####" L -1;
			Stop;
	}
}

// 265 Heinrich Haufmann: Schabbs' chase, then a rocket and four Mk4 shots
class EoDHeinrich : EoDUltraClone
{
	Default
	{
		//$Title Heinrich Haufmann
		SeeSound "eod/heinrichsight";
		AttackSound "eod/mk4";
		DeathSound "eod/heinrichdeath";
		ClassicBase.BaseSprite "D091";
	}

	States
	{
		Missile:
			"####" E 15 A_FaceTarget();
			"####" F 5;
			"####" G 5 A_BossRocket();
			"####" H 5 A_NaziShoot();
			"####" G 5 A_NaziShoot();
			"####" H 5 A_NaziShoot();
			"####" A 0 A_NaziShoot();
			Goto Chase;
		Death:
			"####" A 35 A_BossDeath1();
			"####" A 5;
			"####" IJ 5;
			"####" K 5 A_WolfBossDeath();
		Dead:
			"####" N -1;
			Stop;
	}

	override void A_BossDeath1()
	{
		A_Scream();
		A_SpawnItemEx("YellowKey");
	}
}

// 106 Rocket turret. Once it has seen you it spins on the spot (its eight
// frames are a spin, not views), and each time round, if it can see you, it
// fires one rocket straight at you and pauses (image 0x1a964, states 0x2c74+)
class EoDTurret : ClassicBoss
{
	Default
	{
		//$Category End of Destiny/Enemies
		//$Title Rocket Turret
		+DONTTHRUST
		+NOBLOOD
		-ClassicBase.OptionalRotations
		Speed 0;
		Radius 24;
		SeeSound "";
		DeathSound "eod/landmine";
		ClassicBase.BaseSprite "D075";
		ClassicBoss.Projectile "EoDRocket";
	}

	States
	{
		Spawn.Stand:
			D075 A 5 {
				if (bDormant || bDeafandBlind || GetAge() < 2 || GameHandler.CheckFizzle()) { return; }
				A_Look();
			}
			Loop;
		Chase:
			D075 B 12;
			D075 C 13;
			D075 D 12;
			D075 E 13;
			D075 F 12;
			D075 G 13;
			D075 H 12;
		Check:
			D075 A 13;
			D075 A 0 A_TurretCheck();
			Loop;
		Missile:
			D075 A 5;
			D075 I 5 Bright;
			D075 A 50 A_TurretRocket();
			Goto Check;
		Death:
			D075 J 3 {
				A_StartSound("eod/barrelexp", CHAN_BODY);
				A_Scream();
			}
			D075 J 5;
			D075 K 5;
			D075 L 5;
		Dead:
			D075 M -1;
			Stop;
	}

	override void Die(Actor source, Actor inflictor, int dmgflags, Name meansofdeath)
	{
		Super.Die(source, inflictor, dmgflags, meansofdeath);
		bSolid = true; // the wreck stays in its tile
		A_SetSize(-1, Default.Height);
	}

	void A_TurretCheck()
	{
		Actor mo = target;
		if (!mo || mo.health <= 0) { mo = players[0].mo; }
		if (!mo || mo.health <= 0 || !CheckSight(mo)) { SetStateLabel("Chase"); return; }

		target = mo;
		SetStateLabel("Missile");
	}

	void A_TurretRocket()
	{
		if (!target) { return; }

		A_FaceTarget();
		A_SpawnProjectile(projectile, 32, 0, 0, CMF_AIMDIRECTION);
	}
}
