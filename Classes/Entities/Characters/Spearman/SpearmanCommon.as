//common spearman header
#include "RunnerCommon.as";

namespace SpearmanStates
{
	enum States
	{
		normal = 0,
		spear_drawn,
		spear_cut_mid,
		spear_cut_mid_down,
		spear_cut_up,
		spear_cut_down,
		spear_power,
		spear_power_super,
		spear_throw,
		spear_throw_super,
		resheathing_cut,
		resheathing_slash,
		resheathing_throw
	}
}

namespace SpearmanVars
{
	const ::s32 resheath_cut_time = 2;
	const ::s32 resheath_slash_time = 2;
	const ::s32 resheath_throw_time = 2;

	const ::s32 slash_charge = 15;
	const ::s32 slash_charge_level2 = 38;
	const ::s32 slash_charge_limit = slash_charge_level2 + slash_charge + 10;
	const ::s32 slash_move_time = 4;
	const ::s32 slash_time = 13;
	const ::s32 double_slash_time = 8;

	const ::f32 slash_move_max_speed = 7.0f;// double

	const ::f32 shoot_max_vel = 10.0f;
}

shared class SpearmanInfo
{
	u8 spearTimer;
	bool doubleslash;
	u8 tileDestructionLimiter;

	bool throwing;

	u8 state;
	Vec2f slash_direction;

	u8 spear_type;
	u8 fletch_cooldown;
};

shared class SpearmanState
{
	SpearmanState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state) {}
	// set knight.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, SpearmanInfo@ sman, u8 next_state) {}
}

namespace SpearType
{
	enum type
	{
		normal,
		fire,
		poison,
		count
	};
}

const string[] spearNames = { "Spear",
                             "Fire Spear",
                             "Poison Spear"
                           };

const string[] spearIcons = { "$Spear$",
                             "$FireSpear$",
                             "$PoisonSpear$"
                           };

const string[] spearTypeNames = { "mat_spears",
                                 "mat_firespears",
                                 "mat_poisonspears"
                               };


//checking state stuff

bool isSpearState(u8 state)
{
	return (state >= SpearmanStates::spear_drawn && state <= SpearmanStates::resheathing_throw);
}

bool inMiddleOfAttack(u8 state)
{
	return (state > SpearmanStates::spear_drawn && state <= SpearmanStates::spear_throw_super);
}

//checking angle stuff

f32 getCutAngle(CBlob@ this, u8 state)
{
	f32 attackAngle = (this.isFacingLeft() ? 180.0f : 0.0f);

	if (state == SpearmanStates::spear_cut_mid)
	{
		attackAngle += (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == SpearmanStates::spear_cut_mid_down)
	{
		attackAngle -= (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == SpearmanStates::spear_cut_up)
	{
		attackAngle += (this.isFacingLeft() ? 80.0f : -80.0f);
	}
	else if (state == SpearmanStates::spear_cut_down)
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
		tempState = SpearmanStates::spear_cut_up;
	}
	else if (direction == 0)
	{
		if (aimpos.y < this.getPosition().y)
		{
			tempState = SpearmanStates::spear_cut_mid;
		}
		else
		{
			tempState = SpearmanStates::spear_cut_mid_down;
		}
	}
	else
	{
		tempState = SpearmanStates::spear_cut_down;
	}

	return getCutAngle(this, tempState);
}

bool hasSpears(CBlob@ this)
{
	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return false;
	}
	if (sman.spear_type >= 0 && sman.spear_type < spearTypeNames.length)
	{
		return this.getBlobCount(spearTypeNames[sman.spear_type]) > 0;
	}
	return false;
}

bool hasSpears(CBlob@ this, u8 spearType)
{
	return this.getBlobCount(spearTypeNames[spearType]) > 0;
}

bool hasAnySpears(CBlob@ this)
{
	for (uint i = 0; i < SpearType::count; i++)
	{
		if (hasSpears(this, i))
		{
			return true;
		}
	}
	return false;
}

void SetSpearType(CBlob@ this, const u8 type)
{
	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return;
	}
	sman.spear_type = type;
}

u8 getSpearType(CBlob@ this)
{
	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return 0;
	}
	return sman.spear_type;
}


//shared attacking/bashing constants (should be in SpearmanVars but used all over)

const int DELTA_BEGIN_ATTACK = 2;
const int DELTA_END_ATTACK = 5;
const f32 DEFAULT_ATTACK_DISTANCE = 20.0f;// from 16.0f
const f32 MAX_ATTACK_DISTANCE = 24.0f;// from 18.0f

const int FLETCH_COOLDOWN = 45;
const int PICKUP_COOLDOWN = 15;
const int fletch_num_spears = 1;