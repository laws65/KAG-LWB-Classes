//common crossbowman header
#include "RunnerCommon.as";

namespace ArrowType
{
	enum type
	{
		normal,
		fire,
		poison,
		count
	};
}

namespace CrossbowmanVars
{
	const ::s32 resheath_cut_time = 2;

	const ::s32 ready_time = 11;

	const ::s32 shoot_period = 30;
	const ::s32 shoot_period_1 = CrossbowmanVars::shoot_period / 3;
	const ::s32 shoot_period_2 = 2 * CrossbowmanVars::shoot_period / 3;
	const ::s32 legolas_period = CrossbowmanVars::shoot_period * 4;

	const ::s32 fired_time = 7;
	const ::f32 shoot_max_vel = 17.59f;

	const ::s32 legolas_charge_time = 5;
	const ::s32 legolas_arrows_count = 3;
	//const ::s32 legolas_arrows_volley = 3;
	//const ::s32 legolas_arrows_deviation = 5;
	const ::s32 legolas_time = 60;

	enum States
	{
		not_aiming = 0,
		readying,
		charging,
		fired,
		no_arrows,
		legolas_ready,
		legolas_charging,
		sword_cut_mid,
		sword_cut_mid_down,
		sword_cut_up,
		sword_cut_down
	}
}

shared class CrossbowmanInfo
{
	u8 swordTimer;
	u8 tileDestructionLimiter;
	u8 state;

	s8 charge_time;
	bool has_arrow;
	u8 stab_delay;
	u8 fletch_cooldown;
	u8 arrow_type;

	u8 legolas_arrows;
	u8 legolas_time;

	CrossbowmanInfo()
	{
		charge_time = 0;
		has_arrow = false;
		fletch_cooldown = 0;
		arrow_type = ArrowType::normal;
	}
};

// if you use other mod too, please check ArcherCommon.as in other mod
// and put actual number in this
u8 getActualArrowNumber(u8 type)
{
	switch(type)
	{
		case ArrowType::normal: return 0;
		case ArrowType::fire: return 2;
		case ArrowType::poison: return 4;
	}
	return 0;
}

//checking state stuff

bool isSwordState(u8 state)
{
	return (state >= CrossbowmanVars::sword_cut_mid && state <= CrossbowmanVars::sword_cut_down);
}

//checking angle stuff

f32 getCutAngle(CBlob@ this, u8 state)
{
	f32 attackAngle = (this.isFacingLeft() ? 180.0f : 0.0f);

	if (state == CrossbowmanVars::sword_cut_mid)
	{
		attackAngle += (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == CrossbowmanVars::sword_cut_mid_down)
	{
		attackAngle -= (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == CrossbowmanVars::sword_cut_up)
	{
		attackAngle += (this.isFacingLeft() ? 80.0f : -80.0f);
	}
	else if (state == CrossbowmanVars::sword_cut_down)
	{
		attackAngle -= (this.isFacingLeft() ? 80.0f : -80.0f);
	}

	return attackAngle;
}

f32 getCutAngle(CBlob@ this)
{
	Vec2f aimpos = this.getMovement().getVars().aimpos;
	int tempState;
	Vec2f vec;
	int direction = this.getAimDirection(vec);

	if (direction == -1)
	{
		tempState = CrossbowmanVars::sword_cut_up;
	}
	else if (direction == 0)
	{
		if (aimpos.y < this.getPosition().y)
		{
			tempState = CrossbowmanVars::sword_cut_mid;
		}
		else
		{
			tempState = CrossbowmanVars::sword_cut_mid_down;
		}
	}
	else
	{
		tempState = CrossbowmanVars::sword_cut_down;
	}

	return getCutAngle(this, tempState);
}


const string[] arrowTypeNames = { "mat_arrows",
                                  "mat_firearrows",
								  "mat_poisonarrows"
                                };

const string[] arrowNames = { "Regular arrows",
                              "Fire arrows",
							  "Poison arrows"
                            };

const string[] arrowIcons = { "$Arrow$",
                              "$FireArrow$",
							  "$PoisonArrow$"
                            };

bool hasArrows(CBlob@ this)
{
	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return false;
	}
	if (cbman.arrow_type >= 0 && cbman.arrow_type < arrowTypeNames.length)
	{
		return this.getBlobCount(arrowTypeNames[cbman.arrow_type]) > 0;
	}
	return false;
}

bool hasArrows(CBlob@ this, u8 arrowType)
{
	return this.getBlobCount(arrowTypeNames[arrowType]) > 0;
}

bool hasAnyArrows(CBlob@ this)
{
	for (uint i = 0; i < ArrowType::count; i++)
	{
		if (hasArrows(this, i))
		{
			return true;
		}
	}
	return false;
}

void SetArrowType(CBlob@ this, const u8 type)
{
	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return;
	}
	cbman.arrow_type = type;
}

u8 getArrowType(CBlob@ this)
{
	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return 0;
	}
	return cbman.arrow_type;
}

//shared attacking/bashing constants (should be in CrossbowmanVars but used all over)

const int DELTA_BEGIN_ATTACK = 2;
const int DELTA_END_ATTACK = 5;
const f32 DEFAULT_ATTACK_DISTANCE = 16.0f;
const f32 MAX_ATTACK_DISTANCE = 18.0f;