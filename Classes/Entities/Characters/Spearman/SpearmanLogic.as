// Spearman logic

#include "ThrowCommon.as"
#include "SpearmanCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as"
#include "Help.as";
#include "Requirements.as"


//attacks limited to the one time per-actor before reset.

void spearman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool spearman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 spearman_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void spearman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void spearman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.set_u8("specialhit", 0);
}

void onInit(CBlob@ this)
{
	SpearmanInfo sman;

	sman.state = SpearmanStates::normal;
	sman.spearTimer = 0;
	sman.doubleslash = false;
	sman.tileDestructionLimiter = 0;
	sman.spear_type = SpearType::normal;
	sman.throwing = false;

	this.set("spearmanInfo", @sman);
	
	SpearmanState@[] states;
	states.push_back(NormalState());
	states.push_back(SpearDrawnState());
	states.push_back(CutState(SpearmanStates::spear_cut_up));
	states.push_back(CutState(SpearmanStates::spear_cut_mid));
	states.push_back(CutState(SpearmanStates::spear_cut_mid_down));
	states.push_back(CutState(SpearmanStates::spear_cut_mid));
	states.push_back(CutState(SpearmanStates::spear_cut_down));
	states.push_back(SlashState(SpearmanStates::spear_power));
	states.push_back(SlashState(SpearmanStates::spear_power_super));
	states.push_back(ThrowState(SpearmanStates::spear_throw));
	states.push_back(ThrowState(SpearmanStates::spear_throw_super));
	states.push_back(ResheathState(SpearmanStates::resheathing_cut, SpearmanVars::resheath_cut_time));
	states.push_back(ResheathState(SpearmanStates::resheathing_slash, SpearmanVars::resheath_slash_time));
	states.push_back(ResheathState(SpearmanStates::resheathing_throw, SpearmanVars::resheath_throw_time));

	this.set("spearmanStates", @states);
	this.set_s32("currentSpearmanState", 0);
	
	this.set_f32("gib health", -1.5f);
	spearman_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	this.addCommandID("pickup spear");

	//add a command ID for each spear type
	for (uint i = 0; i < spearTypeNames.length; i++)
	{
		this.addCommandID("pick " + spearTypeNames[i]);
	}

	this.set_u8("specialhit", 0);

	//centered on spear select
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on inventory
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));
	AddIconToken("$Help_SpearJab$", "LWBHelpIcons.png", Vec2f(16, 16), 5);
	AddIconToken("$Help_SpearThrow$", "LWBHelpIcons.png", Vec2f(16, 16), 6);
	AddIconToken("$Help_SpearPower$", "LWBHelpIcons.png", Vec2f(16, 16), 7);
	AddIconToken("$Help_Spear1$", "LWBHelpIcons.png", Vec2f(8, 16), 16);
	AddIconToken("$Help_Spear2$", "LWBHelpIcons.png", Vec2f(8, 16), 17);

	SetHelp(this, "help self action", "spearman", getTranslatedString("$Help_SpearJab$Jab        $LMB$"), "", 4);
	SetHelp(this, "help self action2", "spearman", getTranslatedString("$Help_SpearThrow$Throw    $RMB$"), "", 4);

	const string texName = "Entities/Characters/Spearman/SpearmanIcons.png";
	AddIconToken("$Spear$", texName, Vec2f(16, 32), 0);
	AddIconToken("$FireSpear$", texName, Vec2f(16, 32), 1);
	AddIconToken("$PoisonSpear$", texName, Vec2f(16, 32), 2);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 4, Vec2f(16, 16));
	}
}


void RunStateMachine(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
{
	SpearmanState@[]@ states;
	if (!this.get("spearmanStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentSpearmanState");

	if (getNet().isClient())
	{
		if (this.exists("serverSpearmanState"))
		{
			s32 serverStateIndex = this.get_s32("serverSpearmanState");
			this.set_s32("serverSpearmanState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				SpearmanState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= SpearmanStates::spear_cut_mid && net_state <= SpearmanStates::spear_power_super)
					{
						if (sman.state != SpearmanStates::spear_drawn && sman.state != SpearmanStates::resheathing_cut && sman.state != SpearmanStates::resheathing_slash && sman.state != SpearmanStates::resheathing_throw)
						{
							sman.state = net_state;
							serverState.StateEntered(this, sman, serverState.getStateValue());
							this.set_s32("currentSpearmanState", serverStateIndex);
							currentStateIndex = serverStateIndex;
						}

					}
				}
				else
				{
					sman.state = net_state;
					serverState.StateEntered(this, sman, serverState.getStateValue());
					this.set_s32("currentSpearmanState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = sman.state;
	SpearmanState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, sman, moveVars);

	if (state != sman.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == sman.state)
			{
				s32 nextStateIndex = i;
				SpearmanState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, sman, nextState.getStateValue());
				nextState.StateEntered(this, sman, currentState.getStateValue());
				this.set_s32("currentSpearmanState", nextStateIndex);
				if (getNet().isServer() && sman.state >= SpearmanStates::spear_drawn && sman.state <= SpearmanStates::spear_throw_super)
				{
					this.set_s32("serverSpearmanState", nextStateIndex);
					this.Sync("serverSpearmanState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, sman, moveVars);

				}
				break;
			}
		}
	}
}

void onTick(CBlob@ this)
{
	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//spearman logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		sman.state = 0;
		sman.spearTimer = 0;
		sman.doubleslash = false;
		sman.throwing = false;
		hud.SetCursorFrame(0);
		this.set_s32("currentSpearmanState", 0);
		return;
	}


	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	bool spearState = isSpearState(sman.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	if (getNet().isClient() && !this.isInInventory() && myplayer)  //Spearman charge cursor
	{
		SpearCursorUpdate(this, sman);
	}

	//with the code about menus and myplayer you can slash-cancel;
	//we'll see if spearmans dmging stuff while in menus is a real issue and go from there
	if (knocked)// || myplayer && getHUD().hasMenus())
	{
		sman.state = SpearmanStates::normal; //cancel any attacks or shielding
		sman.spearTimer = 0;
		sman.doubleslash = false;
		sman.throwing = false;// for cursor
		this.set_s32("currentSpearmanState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
	{
		RunStateMachine(this, sman, moveVars);

	}

	if (myplayer)
	{
		if (sman.fletch_cooldown > 0)
		{
			sman.fletch_cooldown--;
		}

		// space

		CControls@ controls = getControls();
		if (this.isKeyPressed(key_action3) && controls.ActionKeyPressed(AK_BUILD_MODIFIER))
		{
			// pickup from ground

			if (sman.fletch_cooldown == 0)
			{
				if (getPickupSpear(this) !is null)   // pickup spear from ground
				{
					this.SendCommand(this.getCommandID("pickup spear"));
					sman.fletch_cooldown = PICKUP_COOLDOWN;
				}
			}
		}
		else if (this.isKeyJustPressed(key_action3))
			client_SendThrowOrActivateCommand(this);

		// help

		if (this.isKeyJustPressed(key_action1) && getGameTime() > 150)
		{
			SetHelp(this, "help self action", "spearman", getTranslatedString("$Help_SpearPower$ Slash!    $KEY_HOLD$$LMB$"), "", 13);
		}
		else if (this.isKeyJustPressed(key_action2) && getGameTime() > 150)
		{
			SetHelp(this, "help self action", "spearman", getTranslatedString("$Help_SpearThrow$ Throw!    $KEY_HOLD$$RMB$"), "", 13);
		}
	}

	if (!spearState && getNet().isServer())
	{
		spearman_clear_actor_limits(this);
	}

}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

class NormalState : SpearmanState
{
	u8 getStateValue() { return SpearmanStates::normal; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		sman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action1))
		{
			sman.state = SpearmanStates::spear_drawn;
			sman.throwing = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			sman.state = SpearmanStates::spear_drawn;
			sman.throwing = true;
			return true;
		}

		return false;
	}
}


s32 getSpearTimerDelta(SpearmanInfo@ sman)
{
	s32 delta = sman.spearTimer;
	if (sman.spearTimer < 128)
	{
		sman.spearTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	bool strong = (sman.spearTimer > SpearmanVars::slash_charge_level2);
	moveVars.jumpFactor *= (strong ? 0.6f : 0.8f);
	moveVars.walkFactor *= (strong ? 0.8f : 0.9f);

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class SpearDrawnState : SpearmanState
{
	u8 getStateValue() { return SpearmanStates::spear_drawn; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		sman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (sman.spearTimer == SpearmanVars::slash_charge_level2)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed", 1);
			}
			else if (sman.spearTimer == SpearmanVars::slash_charge)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
			}
		}

		if (sman.spearTimer >= SpearmanVars::slash_charge_limit)
		{
			Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 15);
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
		}

		AttackMovement(this, sman, moveVars);
		s32 delta = getSpearTimerDelta(sman);

		if ((!this.isKeyPressed(key_action1) && !sman.throwing) || // releaced LMB on melee charge
			(!this.isKeyPressed(key_action2) && sman.throwing)) // releaced RMB on throw charge
		{
			if (delta < SpearmanVars::slash_charge)
			{
				Vec2f vec;
				const int direction = this.getAimDirection(vec);

				if (direction == -1)
				{
					sman.state = SpearmanStates::spear_cut_up;
				}
				else if (direction == 0)
				{
					Vec2f aimpos = this.getAimPos();
					Vec2f pos = this.getPosition();
					if (aimpos.y < pos.y)
					{
						sman.state = SpearmanStates::spear_cut_mid;
					}
					else
					{
						sman.state = SpearmanStates::spear_cut_mid_down;
					}
				}
				else
				{
					sman.state = SpearmanStates::spear_cut_down;
				}
			}
			else if (delta < SpearmanVars::slash_charge_level2)
			{
				sman.state = sman.throwing ? SpearmanStates::spear_throw : SpearmanStates::spear_power;
			}
			else if(delta < SpearmanVars::slash_charge_limit)
			{
				sman.state = sman.throwing ? SpearmanStates::spear_throw_super : SpearmanStates::spear_power_super;
			}
		}

		return false;
	}
}

class CutState : SpearmanState
{
	u8 state;
	CutState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		sman.spearTimer = 0;
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
			return false;

		}

		this.Tag("prevent crouch");

		AttackMovement(this, sman, moveVars);
		s32 delta = getSpearTimerDelta(sman);

		if (delta == DELTA_BEGIN_ATTACK)
		{
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
		{
			f32 attackarc = 90.0f;
			f32 attackAngle = getCutAngle(this, sman.state);

			if (sman.state == SpearmanStates::spear_cut_down)
			{
				attackarc *= 0.9f;
			}

			DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::spear, delta, sman);
		}
		else if (delta >= 9)
		{
			sman.state = SpearmanStates::resheathing_cut;
		}

		return false;

	}
}

Vec2f getSlashDirection(CBlob@ this)
{
	Vec2f vel = this.getVelocity();
	Vec2f aiming_direction = vel;
	aiming_direction.y *= 2;
	aiming_direction.Normalize();

	return aiming_direction;
}

class SlashState : SpearmanState
{
	u8 state;
	SlashState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		sman.spearTimer = 0;
		sman.slash_direction = getSlashDirection(this);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
			return false;

		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (sman.state == SpearmanStates::spear_power_super && this.get_u8("animeSpearPlayed") == 0)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
				this.set_u8("spearSheathPlayed", 1);

			}
			else if (sman.state == SpearmanStates::spear_power && this.get_u8("spearSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, sman, moveVars);
		s32 delta = getSpearTimerDelta(sman);

		if (sman.state == SpearmanStates::spear_power_super
			&& this.isKeyJustPressed(key_action1))
		{
			sman.doubleslash = true;
		}

		if (delta == 2)
		{
			Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < 10)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, 2.0f, -(vec.Angle()), 60.0f, Hitters::spear, delta, sman);//half arc
		}
		else if (delta >= SpearmanVars::slash_time
			|| (sman.doubleslash && delta >= SpearmanVars::double_slash_time))
		{
			if (sman.doubleslash)
			{
				sman.doubleslash = false;
				sman.state = SpearmanStates::spear_power;
			}
			else
			{
				sman.state = SpearmanStates::resheathing_slash;
			}
		}

		Vec2f vel = this.getVelocity();
		if ((sman.state == SpearmanStates::spear_power ||
				sman.state == SpearmanStates::spear_power_super) &&
				delta < SpearmanVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < SpearmanVars::slash_move_max_speed &&
					vel.y > -SpearmanVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  sman.slash_direction * this.getMass() * 0.6f;//from 0.5f
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ThrowState : SpearmanState
{
	u8 state;
	ThrowState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		sman.spearTimer = 0;
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
			return false;
		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (sman.state == SpearmanStates::spear_throw_super && this.get_u8("animeSpearPlayed") == 0)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
				this.set_u8("spearSheathPlayed", 1);

			}
			else if (sman.state == SpearmanStates::spear_throw && this.get_u8("spearSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, sman, moveVars);
		s32 delta = getSpearTimerDelta(sman);

		if (sman.state == SpearmanStates::spear_throw_super
			&& this.isKeyJustPressed(key_action2))
		{
			sman.doubleslash = true;
		}

		if (delta == 2)
		{
			if(hasSpears(this, sman.spear_type))
			{
				Sound::Play("/ArgLong", this.getPosition());
				Sound::Play("/SwordSlash", this.getPosition());
				if(sman.spear_type == SpearType::fire)
					Sound::Play("/SparkleShort.ogg", this.getPosition());
			}
			else if(this.isMyPlayer())
			{
				Sound::Play("/NoAmmo");
			}
		}
		else if (delta == DELTA_BEGIN_ATTACK + 1)
		{
			DoThrow(this, sman);
			sman.fletch_cooldown = FLETCH_COOLDOWN; // just don't allow shoot + make spear
		}
		else if ((delta >= SpearmanVars::slash_time
		    || (sman.doubleslash && delta >= SpearmanVars::double_slash_time)) && !(delta < 10))
		{
			if (sman.doubleslash)
			{
				sman.doubleslash = false;
				sman.state = SpearmanStates::spear_throw;
			}
			else
			{
				sman.state = SpearmanStates::resheathing_throw;
			}
		}

		return false;

	}
}

class ResheathState : SpearmanState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ sman, u8 previous_state)
	{
		sman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ sman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
			return false;

		}
		else if (this.isKeyPressed(key_action1))
		{
			sman.state = SpearmanStates::spear_drawn;
			sman.throwing = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			sman.state = SpearmanStates::spear_drawn;
			sman.throwing = true;
			return true;
		}

		AttackMovement(this, sman, moveVars);
		s32 delta = getSpearTimerDelta(sman);

		if (delta > time)
		{
			sman.state = SpearmanStates::normal;
			sman.throwing = false;
		}

		return false;
	}
}

CBlob@ getPickupSpear(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "spear")
			{
				return b;
			}
		}
	}
	return null;
}

bool canPickSpriteSpear(CBlob@ this, bool takeout)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			{
				CSprite@ sprite = b.getSprite();
				if (sprite.getSpriteLayer("spear") !is null)
				{
					if (takeout)
						sprite.RemoveSpriteLayer("spear");
					return true;
				}
			}
		}
	}
	return false;
}

void SpearCursorUpdate(CBlob@ this, SpearmanInfo@ sman)
{
		if (sman.spearTimer >= SpearmanVars::slash_charge_level2 || sman.doubleslash || sman.state == SpearmanStates::spear_power_super || sman.state == SpearmanStates::spear_throw_super)
		{
			getHUD().SetCursorFrame(19);
		}
		else if (sman.spearTimer >= SpearmanVars::slash_charge)
		{
			int frame = 1 + int((float(sman.spearTimer - SpearmanVars::slash_charge) / (SpearmanVars::slash_charge_level2 - SpearmanVars::slash_charge)) * 9) * 2;
			getHUD().SetCursorFrame(frame);
		}
		// the yellow circle stays for the duration of a slash, helpful for newplayers (note: you cant attack while its yellow)
		else if (sman.state == SpearmanStates::normal || sman.state == SpearmanStates::resheathing_cut || sman.state == SpearmanStates::resheathing_slash || sman.state == SpearmanStates::resheathing_throw) // disappear after slash is done
		// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
		// else if (spearman.spearTimer == 0) (disappear right after mouse release)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (sman.spearTimer < SpearmanVars::slash_charge && sman.state == SpearmanStates::spear_drawn)
		{
			int frame = 2 + int((float(sman.spearTimer) / SpearmanVars::slash_charge) * 8) * 2;
			if (sman.spearTimer <= SpearmanVars::resheath_cut_time) //prevent from appearing when jabbing/jab spamming
			{
				getHUD().SetCursorFrame(0);
			}
			else
			{
				getHUD().SetCursorFrame(frame);
			}
		}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("pickup spear"))
	{
		CBlob@ spear = getPickupSpear(this);
		bool spriteSpear = canPickSpriteSpear(this, false); // unnecessary

		if (spear !is null || spriteSpear)
		{

			if (getNet().isServer())
			{
				CBlob@ mat_spears = server_CreateBlobNoInit('mat_spears');

				if (mat_spears !is null)
				{
					mat_spears.Tag('custom quantity');
					mat_spears.Init();

					mat_spears.server_SetQuantity(1); // unnecessary

					if (not this.server_PutInInventory(mat_spears))
					{
						mat_spears.setPosition(this.getPosition());
					}

					if (spear !is null)
					{
						spear.server_Die();
					}
					else
					{
						canPickSpriteSpear(this, true);
					}
				}
			}

			this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
		}
	}
	else if (cmd == this.getCommandID("cycle"))  //from standardcontrols
	{
		// cycle spears
		SpearmanInfo@ sman;
		if (!this.get("spearmanInfo", @sman))
		{
			return;
		}
		u8 type = sman.spear_type;

		int count = 0;
		while (count < spearTypeNames.length)
		{
			type++;
			count++;
			if (type >= spearTypeNames.length)
			{
				type = 0;
			}
			if (this.getBlobCount(spearTypeNames[type]) > 0 || type == SpearType::normal)
			{
				sman.spear_type = type;
				if (this.isMyPlayer())
				{
					Sound::Play("/CycleInventory.ogg");
				}
				break;
			}
		}
	}
	else
	{
		SpearmanInfo@ sman;
		if (!this.get("spearmanInfo", @sman))
		{
			return;
		}
		for (uint i = 0; i < spearTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + spearTypeNames[i]))
			{
				sman.spear_type = i;
				break;
			}
		}
	}
}

/////////////////////////////////////////////////

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, SpearmanInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	const bool jab = isJab(damage);

	u8 attackType = info.spear_type;
	if(!hasSpears(this, attackType))
		attackType = 0;
	if(this.get_u8("specialhit") != 0)
		attackType = this.get_u8("specialhit");
	switch(attackType)
	{
		case SpearType::fire: type = Hitters::fire; break;
		case SpearType::poison: type = Hitters::poisoning; break;
		default: type = Hitters::spear;
	}
	bool usedSpecialSpear = false;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		for (uint i = 0; i < hitInfos.length; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b !is null && !dontHitMore) // blob
			{
				if (b.hasTag("ignore sword")) continue;

				//big things block attacks, except not stone things
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();// && (b.hasTag("stone") || b.hasTag("barricade"));

				if (!canHit(this, b))
				{
					// no TK
					if (large)
						dontHitMore = true;

					continue;
				}

				if (spearman_has_hit_actor(this, b))
				{
					if (large)
						dontHitMore = true;

					continue;
				}

				spearman_add_actor_limit(this, b);
				if (!dontHitMore)
				{
					Vec2f velocity = b.getPosition() - pos;
					this.server_Hit(b, hi.hitpos, velocity, damage, type, true);  // server_Hit() is server-side only
					usedSpecialSpear = true;

					// end hitting if we hit something solid, don't if its flesh
					if (large)
					{
						dontHitMore = true;
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap && (deltaInt == DELTA_BEGIN_ATTACK + 1))
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile);
					bool gold = map.isTileGold(hi.tile);
					bool wood = map.isTileWood(hi.tile);
					if (ground || wood || dirt_stone || gold)
					{
						Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
						Vec2f offset = (tpos - blobPos);
						f32 tileangle = offset.Angle();
						f32 dif = Maths::Abs(exact_aimangle - tileangle);
						if (dif > 180)
							dif -= 360;
						if (dif < -180)
							dif += 360;

						dif = Maths::Abs(dif);
						//print("dif: "+dif);

						if (dif < 20.0f)
						{
							//detect corner

							int check_x = -(offset.x > 0 ? -1 : 1);
							int check_y = -(offset.y > 0 ? -1 : 1);
							if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
							        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
								continue;


							bool canhit = true; //default true if not jab
							//dont dig through no build zones
							canhit = map.getSectorAtPosition(tpos, "no build") is null;// check before checking jab, for fire spear

							if(wood && type == Hitters::fire)
							{
								map.server_setFireWorldspace(hi.hitpos, true);
								usedSpecialSpear = true;
							}

							if (jab) //fake damage
							{
								info.tileDestructionLimiter++;
								canhit = canhit && ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);
							}
							else //reset fake dmg for next time
							{
								info.tileDestructionLimiter = 0;
							}

							dontHitMoreMap = true;

							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								if (gold)
								{
									// Note: 0.1f damage doesn't harvest anything I guess
									// This puts it in inventory - include MaterialCommon
									//Material::fromTile(this, hi.tile, 1.f);

									CBlob@ ore = server_CreateBlobNoInit("mat_gold");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
	     								ore.Init();
	     								ore.setPosition(pos);
	     								ore.server_SetQuantity(4);
	     							}
								}
							}
						}
					}
				}
		}
	}

	// destroy grass

	if (((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
	        (deltaInt == DELTA_BEGIN_ATTACK + 1)) // hit only once
	{
		f32 tilesize = map.tilesize;
		int steps = Maths::Ceil(2 * radius / tilesize);
		int sign = this.isFacingLeft() ? -1 : 1;

		for (int y = 0; y < steps; y++)
			for (int x = 0; x < steps; x++)
			{
				Vec2f tilepos = blobPos + Vec2f(x * tilesize * sign, y * tilesize);
				TileType tile = map.getTile(tilepos).type;

				if (map.isTileGrass(tile))
				{
					map.server_DestroyTile(tilepos, damage, this);
					if(type == Hitters::fire)
					{
						map.server_setFireWorldspace(tilepos, true);
						usedSpecialSpear = true;
					}

					if (damage <= 1.0f)
					{
						break;
					}
				}
			}
	}

	if(!(type == Hitters::spear) && usedSpecialSpear && this.get_u8("specialhit") == 0)
	{
		this.TakeBlob(spearTypeNames[info.spear_type], 1);
		this.set_u8("specialhit", info.spear_type);
		if(this.getBlobCount(spearTypeNames[info.spear_type]) == 0)
			this.SendCommand(this.getCommandID("pick mat_spears"));
	}
}

void DoThrow(CBlob@ this, SpearmanInfo info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (!hasSpears(this, info.spear_type))
	{
		return;
	}

	CBlob@ spear = server_CreateBlobNoInit("spear");
	if (spear !is null)
	{
		// fire spear?
		spear.set_u8("spear type", info.spear_type);
		spear.SetDamageOwnerPlayer(this.getPlayer());
		spear.Init();

		Vec2f spearPos = this.getPosition() + Vec2f(0.0f, -2.0f);
		Vec2f spearVel = (this.getAimPos() + Vec2f(0.0f, -2.0f) - spearPos);
		spearVel.Normalize();
		spearVel *= SpearmanVars::shoot_max_vel;

		spear.IgnoreCollisionWhileOverlapped(this);
		spear.server_setTeamNum(this.getTeamNum());
		spear.setPosition(spearPos);
		spear.setVelocity(spearVel);
		this.TakeBlob(spearTypeNames[info.spear_type], 1);
	}
	if(this.getBlobCount(spearTypeNames[info.spear_type]) == 0)
		this.SendCommand(this.getCommandID("pick mat_spears"));
	//return spear;
}

//a little push forward

void pushForward(CBlob@ this, f32 normalForce, f32 pushingForce, f32 verticalForce)
{
	f32 facing_sign = this.isFacingLeft() ? -1.0f : 1.0f ;
	bool pushing_in_facing_direction =
	    (facing_sign < 0.0f && this.isKeyPressed(key_left)) ||
	    (facing_sign > 0.0f && this.isKeyPressed(key_right));
	f32 force = normalForce;

	if (pushing_in_facing_direction)
	{
		force = pushingForce;
	}

	this.AddForce(Vec2f(force * facing_sign , verticalForce));
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return;
	}

	if ((customData == Hitters::spear || customData == Hitters::poisoning || customData == Hitters::fire) &&
	        ( //is a jab - note we dont have the dmg in here at the moment :/
	            sman.state == SpearmanStates::spear_cut_mid ||
	            sman.state == SpearmanStates::spear_cut_mid_down ||
	            sman.state == SpearmanStates::spear_cut_up ||
	            sman.state == SpearmanStates::spear_cut_down
	        )
	        && blockAttack(hitBlob, velocity, 0.0f))
	{
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		setKnocked(this, 30, true);
	}
	if (customData == Hitters::fire && hitBlob.getName() == "keg" && !hitBlob.hasTag("exploding"))
	{
		hitBlob.SendCommand(hitBlob.getCommandID("activate"));
	}
}




// spear pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	if (spearTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(spearTypeNames.length, 2), "Current spear");

	SpearmanInfo@ sman;
	if (!this.get("spearmanInfo", @sman))
	{
		return;
	}
	const u8 spearSel = sman.spear_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < spearTypeNames.length; i++)
		{
			string matname = spearTypeNames[i];
			CGridButton @button = menu.AddButton(spearIcons[i], getTranslatedString(spearNames[i]), this.getCommandID("pick " + matname));

			if (button !is null)
			{
				bool enabled = this.getBlobCount(spearTypeNames[i]) > 0 || i == SpearType::normal;// normal spear always selectable
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;

				//if (enabled && i == SpearType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}

				if (spearSel == i)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	string itemname = blob.getName();
	if (this.isMyPlayer())
	{
		for (uint j = 0; j < spearTypeNames.length; j++)
		{
			if (itemname == spearTypeNames[j])
			{
				if (j > 0 && this.getInventory().getItemsCount() > 1)
				{
					SetHelp(this, "help inventory", "spearman", "$Help_Spear1$$Swap$$Help_Spear2$         $KEY_TAP$$KEY_F$", "", 2);
				}
				break;
			}
		}
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @ap)
{
	if (!ap.socket) {
		SpearmanInfo@ sman;
		if (!this.get("spearmanInfo", @sman))
		{
			return;
		}

		sman.state = SpearmanStates::normal; //cancel any attacks or shielding
		sman.spearTimer = 0;
		sman.doubleslash = false;
	}
}

// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{

	if (b.hasTag("invincible"))
		return false;

	// Don't hit temp blobs and items carried by teammates.
	if (b.isAttached())
	{

		CBlob@ carrier = b.getCarriedBlob();

		if (carrier !is null)
			if (carrier.hasTag("player")
			        && (this.getTeamNum() == carrier.getTeamNum() || b.hasTag("temp blob")))
				return false;

	}

	if (b.hasTag("dead"))
		return true;

	return b.getTeamNum() != this.getTeamNum();

}
