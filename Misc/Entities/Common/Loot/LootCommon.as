// LootCommon.as
// added new classes' loot

const string LOOT = "loot_table";
const string DROP = "loot_dropped";
const string PURSE = "coins_carried";

const string TDM = "Team Deathmatch";
const string CTF = "CTF";

enum                Index
{
	MAT_ARROWS = 0,
	MAT_WATERARROWS,
	MAT_FIREARROWS,
	MAT_BOMBARROWS,
	MAT_WOOD,
	MAT_STONE,
	MAT_GOLD,
	DRILL,
	MAT_BOMBS,
	MAT_WATERBOMBS,
	MINE,
	KEG,
	HEART,
	FOOD,
	MAT_POISONARROWS,
	MAT_MEDKITS,
	MAT_WATERJAR,
	MAT_POISONJAR,
	MAT_ACIDJAR,
	MAT_SPEARS,
	MAT_FIRESPEARS,
	MAT_POISONSPEARS,
	MAT_SMOKEBALL,
	MAT_BULLETS,
	MAT_BARRICADES
};

const string[]      NAME =
{
	"mat_arrows",
	"mat_waterarrows",
	"mat_firearrows",
	"mat_bombarrows",
	"mat_wood",
	"mat_stone",
	"mat_gold",
	"drill",
	"mat_bombs",
	"mat_waterbombs",
	"mine",
	"keg",
	"heart",
	"food",
	"mat_poisonarrows",
	"mat_medkits",
	"mat_waterjar",
	"mat_poisonjar",
	"mat_acidjar",
	"mat_spears",
	"mat_firespears",
	"mat_poisonspears",
	"mat_smokeball",
	"mat_bullets",
	"mat_barricades"
};

const u8[]          WEIGHT =
{
	5,                      // mat_arrows
	45,                     // mat_waterarrows
	30,                     // mat_firearrows
	20,                     // mat_bombarrows
	40,                     // mat_wood
	25,                     // mat_stone
	10,                     // mat_gold
	25,                     // drill
	55,                     // mat_bombs
	25,                     // mat_waterbombs
	15,                     // mine
	5,                      // keg
	100,                    // heart
	20,                     // food
	50,                     // mat_poisonarrows
	5,                      // mat_medkits
	40,                     // mat_waterjar
	30,                     // mat_poisonjar
	25,                     // mat_acidjar
	10,                    // mat_spears
	30,                    // mat_firespears
	60,                    // mat_poisonspears
	100,                    // mat_smokeball
	75,                     // mat_bullets
	25                      // mat_barricades
};

// pre-set 'CLASS' arrays
// ━━━━━━━━━━━━━━━━━
const u8[]          INDEX_ARCHER =
{
	MAT_ARROWS,
	MAT_WATERARROWS,
	MAT_FIREARROWS,
	MAT_BOMBARROWS,
	MAT_POISONARROWS
};

const u8[]          INDEX_BUILDER =
{
	MAT_WOOD,
	MAT_STONE,
	MAT_GOLD,
	DRILL
};

const u8[]          INDEX_KNIGHT =
{
	MAT_BOMBS,
	MAT_WATERBOMBS,
	MINE,
	KEG
};

const u8[]          INDEX_ROCKTHROWER =
{
	MAT_WOOD,
	MAT_STONE,
	DRILL
};

const u8[]          INDEX_MEDIC =
{
	MAT_MEDKITS,
	MAT_WATERJAR,
	MAT_POISONJAR,
	MAT_ACIDJAR
};

const u8[]          INDEX_CROSSBOWMAN=
{
	MAT_ARROWS,
	MAT_FIREARROWS,
	MAT_POISONARROWS
};

const u8[]          INDEX_MUSKETMAN =
{
	MAT_BULLETS,
	MAT_BARRICADES
};

const u8[]          INDEX_SPEARMAN =
{
	MAT_SPEARS,
	MAT_FIRESPEARS,
	MAT_POISONSPEARS
};

const u8[]          INDEX_ASSASSIN =
{
	MAT_SMOKEBALL
};

// pre-set 'GAMEMODE' arrays
// ━━━━━━━━━━━━━━━━━
const u8[]          INDEX_CTF =
{
	MAT_ARROWS,
	MAT_WATERARROWS,
	MAT_FIREARROWS,
	MAT_BOMBARROWS,
	MAT_WOOD,
	MAT_STONE,
	MAT_GOLD,
	DRILL,
	MAT_BOMBS,
	MAT_WATERBOMBS,
	MINE,
	KEG,
	HEART,
	FOOD,
	MAT_POISONARROWS,
	MAT_MEDKITS,
	MAT_WATERJAR,
	MAT_POISONJAR,
	MAT_ACIDJAR,
	MAT_SPEARS,
	MAT_FIRESPEARS,
	MAT_POISONSPEARS,
	MAT_SMOKEBALL,
	MAT_BULLETS,
	MAT_BARRICADES
};

const u8[]          INDEX_TDM =
{
	MAT_ARROWS,
	MAT_WATERARROWS,
	MAT_FIREARROWS,
	MAT_BOMBARROWS,
	MAT_WOOD,// for rockthrower
	MAT_STONE,//
	DRILL,//
	MAT_BOMBS,
	MAT_WATERBOMBS,
	MINE,
	KEG,
	HEART,
	FOOD,
	MAT_POISONARROWS,
	MAT_MEDKITS,
	MAT_WATERJAR,
	MAT_POISONJAR,
	MAT_ACIDJAR,
	MAT_SPEARS,
	MAT_FIRESPEARS,
	MAT_POISONSPEARS,
	MAT_SMOKEBALL,
	MAT_BULLETS,
	MAT_BARRICADES
};

// add a single piece of 'LOOT'
// ━━━━━━━━━━━━━━━━━
// addLoot(this, "mat_bombs");
void addLoot(CBlob@ this, const string &in NAME)
{
	if (!this.exists(LOOT))
	{
		string[] loot_table;
		this.set(LOOT, loot_table);
	}
	this.push(LOOT, NAME);
}

// add multiple pieces of 'LOOT'
// ━━━━━━━━━━━━━━━━━
// const u8[] INDEX = {0, 1, 2, 3};
// addLoot(this, INDEX);
// or
// addLoot(this, INDEX_ARCHER);
void addLoot(CBlob@ this, const u8[]&in INDEX)
{
	for(u8 i = 0; i < INDEX.length; i++)
	{
		addLoot(this, NAME[INDEX[i]]);
	}
}

// add 'count' pieces of 'LOOT' based on 'INDEX'
// ━━━━━━━━━━━━━━━━━
// const u8[] INDEX = {0, 1, 2, 3};
// addLoot(this, INDEX, 1, 0);
// or
// addLoot(this, INDEX_ARCHER, 1, 0);
void addLoot(CBlob@ this, const u8[]&in INDEX, u8 &in count, const u8 &in NONE)
{
	while(count > 0)
	{
		--count;
		const u16 RANDOM = XORRandom(getSumOfWeight(INDEX) + NONE);
		u16 total = 0;
		for(u8 i = 0; i < INDEX.length; i++)
		{
			total += WEIGHT[INDEX[i]];
			if (total > RANDOM)
			{
				addLoot(this, NAME[INDEX[i]]);
				break;
			}
		}
	}
}

// create coins from 'PURSE' and LOOT' from this
// ━━━━━━━━━━━━━━━━━
// createLoot(this, this.getPosition(), this.getTeamNum());
void server_CreateLoot(CBlob@ this, const Vec2f &in POSITION, const u8 &in TEAM)
{
	if (this.exists(DROP))
	{
		return;
	}

	if (this.exists(PURSE))
	{
		server_DropCoins(POSITION, this.get_u16(PURSE));
	}

	string[]@ loot;
	if (this.get(LOOT, @loot))
	{
		for(u8 i = 0; i < loot.length; i++)
		{
			CBlob@ item = server_CreateBlob(loot[i], TEAM, POSITION);
			if (item !is null)
			{
				const f32 ANGLE = XORRandom(300) * 0.1f - 15;
				Vec2f force = Vec2f(0, -1);
				force.RotateBy(ANGLE);
				force *= item.getMass() * 3.6f;
				item.AddForce(force);
			}
		}
	}
	this.Tag(DROP);
	this.Sync(DROP, true);
}

// add 'COUNT' coins to 'PURSE'
// ━━━━━━━━━━━━━━━━━
// addCoin(this, 100);
void addCoin(CBlob@ this, const u16 &in COUNT)
{
	if (!this.exists(PURSE))
	{
		this.set_u16(PURSE, COUNT);
		return;
	}
	this.set_u16(PURSE, this.get_u16(PURSE) + COUNT);
}

// get the 'sum' of 'WEIGHT'
// ━━━━━━━━━━━━━━━━━
// u16 sum = getSumOfWeight(WEIGHT);
u16 getSumOfWeight(const u8[]&in INDEX)
{
	u16 sum = 0;
	for(u8 i = 0; i < INDEX.length; i++)
	{
		sum += WEIGHT[INDEX[i]];
	}
	return sum;
}