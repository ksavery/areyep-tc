version "5.0.0"

// AReyeP & MCS's Spear Resurrection and End of Destiny, a mod for the Wolf3D TC.
// It hooks into the TC through GameExtension (AReyePExtension).
#include "Scripts/AReyeP/Games.zs"				// AReyeP game registry (extensions, families, map numbering)
#include "Scripts/AReyeP/Extension.zs"			// The TC's hooks: screens, rules and status bars per game
#include "Scripts/AReyeP/DevProbe.zs"			// Dev-only state logging for headless runs
#include "Scripts/AReyeP/SRActors.zs"			// Spear Resurrection actors
#include "Scripts/AReyeP/EoDActors.zs"			// End of Destiny actors
#include "Scripts/AReyeP/EoDSwitches.zs"		// End of Destiny switches, fire walls, remote pushwalls
#include "Scripts/AReyeP/EoDEnemies.zs"			// End of Destiny enemies and bosses
#include "Scripts/AReyeP/MCSRules.zs"			// MCS engine rules SR and EoD share (pickups, blasts, drums)
#include "Scripts/AReyeP/MCSCheats.zs"			// AReyeP and MCS's cheat keys
#include "Scripts/AReyeP/EoDLevels.zs"			// End of Destiny per-level rules
#include "Scripts/AReyeP/EoDWeather.zs"			// End of Destiny snow, outdoors only
#include "Scripts/AReyeP/EoDMenus.zs"			// End of Destiny story screens and ending
#include "Scripts/AReyeP/EoDStatics.zs"			// End of Destiny statics (generated)
