// Knight logic

#include "ThrowCommon.as"
#include "CrossbowmanCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as"
#include "Help.as";
#include "Requirements.as"


const int FLETCH_COOLDOWN = 45;
const int PICKUP_COOLDOWN = 15;
const int fletch_num_arrows = 1;

//attacks limited to the one time per-actor before reset.

void crossbowman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool crossbowman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 crossbowman_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void crossbowman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void crossbowman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.Untag("fletched_this_attack");
}

void onInit(CBlob@ this)
{
	AddIconToken("$PoisonArrow$", "ArcherIcons.png", Vec2f(16, 32), 4);
	CrossbowmanInfo cbman;

	cbman.state = CrossbowmanVars::not_aiming;
	cbman.swordTimer = 0;
	cbman.tileDestructionLimiter = 0;

	this.set("crossbowmanInfo", @cbman);

	this.set_f32("gib health", -1.5f);
	crossbowman_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	this.set_s8("charge_time", 0);
	this.set_u8("charge_state", CrossbowmanVars::not_aiming);
	this.set_bool("has_arrow", false);
	this.getSprite().SetEmitSound("Entities/Characters/Archer/BowPull.ogg");
	this.addCommandID("shoot arrow");
	this.addCommandID("pickup arrow");
	for (uint i = 0; i < arrowTypeNames.length; i++)
	{
		this.addCommandID("pick " + arrowTypeNames[i]);
	}

	//centered on bomb select
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on inventory
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));
	AddIconToken("$Help_Bayonet$", "LWBHelpIcons.png", Vec2f(16, 16), 10);
	AddIconToken("Help_Arrow3$", "LWBHelpIcons.png", Vec2f(8, 16), 22);

	SetHelp(this, "help self action2", "crossbowman", getTranslatedString("$Help_Bayonet$Bayonet/Fletch    $RMB$"), "", 4);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 2, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//knight logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		cbman.state = 0;
		cbman.swordTimer = 0;
		cbman.charge_time = 0;
		hud.SetCursorFrame(0);
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool swordState = isSwordState(cbman.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	// cancel charging
	if (this.isKeyJustPressed(key_action2) && cbman.state != CrossbowmanVars::not_aiming && !swordState)
	{
		CSprite@ sprite = this.getSprite();
		cbman.state = CrossbowmanVars::not_aiming;
		cbman.charge_time = 0;
		sprite.SetEmitSoundPaused(true);
		sprite.PlaySound("PopIn.ogg");
	}

	if (knocked)
	{
		cbman.state = CrossbowmanVars::not_aiming; //cancel any attacks or shielding
		cbman.swordTimer = 0;
		cbman.charge_time = 0;
		this.getSprite().SetEmitSoundPaused(true);
		getHUD().SetCursorFrame(0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
	{
		//are we responsible for this actor?
		bool ismyplayer = this.isMyPlayer();
		bool responsible = ismyplayer;
		if (isServer() && !ismyplayer)
		{
			CPlayer@ p = this.getPlayer();
			if (p !is null)
			{
				responsible = p.isBot();
			}
		}
		//
		CSprite@ sprite = this.getSprite();
		bool hasarrow = cbman.has_arrow;
		bool hasnormal = hasArrows(this, ArrowType::normal);
		s8 charge_time = cbman.charge_time;
		u8 state = cbman.state;
		if (responsible)
		{
			if ((getGameTime() + this.getNetworkID()) % 10 == 0)
			{
				hasarrow = hasArrows(this);

				if (!hasarrow && hasnormal)
				{
					// set back to default
					cbman.arrow_type = ArrowType::normal;
					hasarrow = hasnormal;
				}
			}

			if (hasarrow != this.get_bool("has_arrow"))
			{
				this.set_bool("has_arrow", hasarrow);
				this.Sync("has_arrow", isServer());
			}
		}

		if (state == CrossbowmanVars::legolas_charging) // fast arrows
		{
			if (!hasarrow)
			{
				state = CrossbowmanVars::not_aiming;
				charge_time = 0;
			}
			else
			{
				state = CrossbowmanVars::legolas_ready;
			}
		}
		//charged - no else (we want to check the very same tick)
		
		if (swordState)
		{
			if (moveVars.wallsliding)
			{
				state = CrossbowmanVars::not_aiming;
				cbman.swordTimer = 0;
			}
			else
			{
				this.Tag("prevent crouch");
	
				AttackMovement(this, cbman, moveVars);
				s32 delta = getSwordTimerDelta(cbman);
	
				if (delta == DELTA_BEGIN_ATTACK)
				{
					Sound::Play("/SwordSlash", this.getPosition());
				}
				else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
				{
					f32 attackarc = 90.0f;
					f32 attackAngle = getCutAngle(this, cbman.state);
	
					if (state == CrossbowmanVars::sword_cut_down)
					{
						attackarc *= 0.9f;
					}
	
					DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::bayonet, delta, cbman);
				}
				else if (delta >= 18)
				{
					state = CrossbowmanVars::not_aiming;
					if (pressed_a1)
					{
						moveVars.walkFactor *= 0.75f;
						moveVars.canVault = false;

						state = CrossbowmanVars::readying;
						hasarrow = hasArrows(this);

						if (!hasarrow && hasnormal)
						{
							cbman.arrow_type = ArrowType::normal;
							hasarrow = hasnormal;

						}

						if (responsible)
						{
							this.set_bool("has_arrow", hasarrow);
							this.Sync("has_arrow", isServer());
						}

						charge_time = 0;

						if (!hasarrow)
						{
							state = CrossbowmanVars::no_arrows;

							if (ismyplayer)   // playing annoying no ammo sound
							{
								this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
							}

						}
						else
						{
							if (ismyplayer)
							{
								if (pressed_a1)
								{
									const u8 type = cbman.arrow_type;

									if (type == ArrowType::fire)
									{
										sprite.PlaySound("SparkleShort.ogg");
									}
								}
							}

							sprite.RewindEmitSound();
							sprite.SetEmitSoundPaused(false);

							if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
							{
								sprite.SetEmitSoundVolume(0.5f);
							}
						}
					}
				}
			}
		}
		//charged - no else (we want to check the very same tick)
		else if (state == CrossbowmanVars::legolas_ready) // fast arrows
		{
			moveVars.walkFactor *= 0.75f;

			cbman.legolas_time--;
			if (!hasarrow || cbman.legolas_time == 0)
			{
				bool pressed = this.isKeyPressed(key_action1);
				state = pressed ? CrossbowmanVars::readying : CrossbowmanVars::not_aiming;
				charge_time = 0;
				//didn't fire
				if (cbman.legolas_arrows == CrossbowmanVars::legolas_arrows_count)
				{
					Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
					setKnocked(this, 15);
				}
				else if (pressed)
				{
					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);
				}
			}
			else if (this.isKeyJustPressed(key_action1) ||
			         (cbman.legolas_arrows == CrossbowmanVars::legolas_arrows_count &&
			          !pressed_a1 &&
			          this.wasKeyPressed(key_action1)))
			{
				ClientFire(this, charge_time, hasarrow, cbman.legolas_arrows == CrossbowmanVars::legolas_arrows_count ? cbman.arrow_type : 0, true);
				state = CrossbowmanVars::legolas_charging;
				charge_time = CrossbowmanVars::shoot_period - CrossbowmanVars::legolas_charge_time;
				Sound::Play("FastBowPull.ogg", pos);
				cbman.legolas_arrows--;

				if (cbman.legolas_arrows == 0)
				{
					state = CrossbowmanVars::readying;// it's readying, not not_aiming. old archer, too.
					charge_time = 5;

					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);
				}
			}

		}
		else if (pressed_a1)
		{
			moveVars.walkFactor *= 0.75f;
			moveVars.canVault = false;

			const bool just_action1 = this.isKeyJustPressed(key_action1);

			//	printf("state " + state );

			if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_a2) &&
			        (state == CrossbowmanVars::not_aiming || state == CrossbowmanVars::fired))
			{
				state = CrossbowmanVars::readying;
				hasarrow = hasArrows(this);

				if (!hasarrow && hasnormal)
				{
					cbman.arrow_type = ArrowType::normal;
					hasarrow = hasnormal;

				}

				if (responsible)
				{
					this.set_bool("has_arrow", hasarrow);
					this.Sync("has_arrow", isServer());
				}

				charge_time = 0;

				if (!hasarrow)
				{
					state = CrossbowmanVars::no_arrows;

					if (ismyplayer && !this.wasKeyPressed(key_action1))   // playing annoying no ammo sound
					{
						this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
					}

				}
				else
				{
					if (ismyplayer)
					{
						if (just_action1)
						{
							const u8 type = cbman.arrow_type;

							if (type == ArrowType::fire)
							{
								sprite.PlaySound("SparkleShort.ogg");
							}
						}
					}

					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);

					if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
					{
						sprite.SetEmitSoundVolume(0.5f);
					}
				}
			}
			else if (state == CrossbowmanVars::readying)
			{
				charge_time++;

				if (charge_time > CrossbowmanVars::ready_time)
				{
					charge_time = 1;
					state = CrossbowmanVars::charging;
				}
			}
			else if (state == CrossbowmanVars::charging)
			{
				charge_time++;

				if (charge_time >= CrossbowmanVars::legolas_period)
				{
					// Legolas state

					Sound::Play("AnimeSword.ogg", pos, ismyplayer ? 1.3f : 0.7f);
					Sound::Play("FastBowPull.ogg", pos);
					state = CrossbowmanVars::legolas_charging;
					charge_time = CrossbowmanVars::shoot_period - CrossbowmanVars::legolas_charge_time;

					cbman.legolas_arrows = CrossbowmanVars::legolas_arrows_count;
					cbman.legolas_time = CrossbowmanVars::legolas_time;
				}

				if (charge_time >= CrossbowmanVars::shoot_period)
				{
					sprite.SetEmitSoundPaused(true);
				}
			}
			else if (state == CrossbowmanVars::no_arrows)
			{
				if (charge_time < CrossbowmanVars::ready_time)
				{
					charge_time++;
				}
			}
		}
		else
		{
			if (state > CrossbowmanVars::readying)
			{
				if (state < CrossbowmanVars::fired)
				{
					ClientFire(this, charge_time, hasarrow, cbman.arrow_type, false);

					charge_time = CrossbowmanVars::fired_time;
					state = CrossbowmanVars::fired;
				}
				else //fired..
				{
					charge_time--;

					if (charge_time <= 0)
					{
						state = CrossbowmanVars::not_aiming;
						charge_time = 0;
					}
				}
			}
			else
			{
				state = CrossbowmanVars::not_aiming;    //set to not aiming either way
				charge_time = 0;
			}

			sprite.SetEmitSoundPaused(true);
			if (pressed_a2 && !moveVars.wallsliding)
			{
				crossbowman_clear_actor_limits(this);
				cbman.swordTimer = 0;
				Vec2f vec;
				const int direction = this.getAimDirection(vec);

				if (direction == -1)
				{
					state = CrossbowmanVars::sword_cut_up;
				}
				else if (direction == 0)
				{
					Vec2f aimpos = this.getAimPos();
					Vec2f pos = this.getPosition();
					if (aimpos.y < pos.y)
					{
						state = CrossbowmanVars::sword_cut_mid;
					}
					else
					{
						state = CrossbowmanVars::sword_cut_mid_down;
					}
				}
				else
				{
					state = CrossbowmanVars::sword_cut_down;
				}
			}
		}

		// my player!

		if (responsible)
		{
			// set cursor

			if (ismyplayer && !getHUD().hasButtons())
			{
				int frame = 0;
				//	print("archer.charge_time " + archer.charge_time + " / " + CrossbowmanVars::shoot_period );
				if (cbman.state == CrossbowmanVars::readying)
				{
					//readying shot
					frame = 2 + int((float(cbman.charge_time) / float(CrossbowmanVars::shoot_period + CrossbowmanVars::ready_time)) * 8) * 2.0f;
				}
				else if (cbman.state == CrossbowmanVars::charging)
				{
					if (cbman.charge_time < CrossbowmanVars::shoot_period)
					{
						//charging shot
						frame = 2 + int((float(CrossbowmanVars::ready_time + cbman.charge_time) / float(CrossbowmanVars::shoot_period + CrossbowmanVars::ready_time)) * 8) * 2;
					}
					else
					{
						//charging legolas
						frame = 1 + int((float(cbman.charge_time - CrossbowmanVars::shoot_period) / (CrossbowmanVars::legolas_period - CrossbowmanVars::shoot_period)) * 9) * 2;
					}
				}
				else if (cbman.state == CrossbowmanVars::legolas_ready)
				{
					//legolas ready
					frame = 19;
				}
				else if (cbman.state == CrossbowmanVars::legolas_charging)
				{
					//in between shooting multiple legolas shots
					frame = 1;
				}
				getHUD().SetCursorFrame(frame);
			}

			// activate/throw

			if (this.isKeyJustPressed(key_action3))
			{
				client_SendThrowOrActivateCommand(this);
			}

			// pick up arrow

			if (cbman.fletch_cooldown > 0)
			{
				cbman.fletch_cooldown--;
			}

			// pickup from ground

			if (cbman.fletch_cooldown == 0 && pressed_a2)
			{
				if (getPickupArrow(this) !is null)   // pickup arrow from ground
				{
					this.SendCommand(this.getCommandID("pickup arrow"));
					cbman.fletch_cooldown = PICKUP_COOLDOWN;
				}
			}
		}

		cbman.charge_time = charge_time;
		cbman.state = state;
		cbman.has_arrow = hasarrow;
	}

	if (!swordState && getNet().isServer())
	{
		crossbowman_clear_actor_limits(this);
	}

}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

s32 getSwordTimerDelta(CrossbowmanInfo@ cbman)
{
	s32 delta = cbman.swordTimer;
	if (cbman.swordTimer < 128)
	{
		cbman.swordTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, CrossbowmanInfo@ cbman, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	moveVars.jumpFactor *= 0.8f;
	moveVars.walkFactor *= 0.9f;

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this, const s8 charge_time, const bool hasarrow, const u8 arrow_type, const bool legolas)
{
	//time to fire!
	if (hasarrow && canSend(this))  // client-logic
	{
		f32 arrowspeed;

		if (charge_time < CrossbowmanVars::ready_time / 2 + CrossbowmanVars::shoot_period_1)
		{
			arrowspeed = CrossbowmanVars::shoot_max_vel * (1.0f / 3.0f);
		}
		else if (charge_time < CrossbowmanVars::ready_time / 2 + CrossbowmanVars::shoot_period_2)
		{
			arrowspeed = CrossbowmanVars::shoot_max_vel * (4.0f / 5.0f);
		}
		else
		{
			arrowspeed = CrossbowmanVars::shoot_max_vel;
		}

		ShootArrow(this, this.getPosition() + Vec2f(0.0f, -2.0f), this.getAimPos() + Vec2f(0.0f, -2.0f), arrowspeed, arrow_type, legolas);
	}
}

void ShootArrow( CBlob @this, Vec2f arrowPos, Vec2f aimpos, f32 arrowspeed, const u8 arrow_type, const bool legolas = true )
{
    if (canSend(this))
	{ // player or bot
		f32 randomInn = 0.0f;
		if(legolas)
		{
			randomInn = -4.0f + (( f32(XORRandom(2048)) / 2048.0f) * 8.0f);
		}

		Vec2f arrowVel = (aimpos- arrowPos).RotateBy(randomInn,Vec2f(0,0));
		arrowVel.Normalize();
		arrowVel *= arrowspeed;
		//print("arrowspeed " + arrowspeed);
		CBitStream params;
		params.write_Vec2f( arrowPos );
		params.write_Vec2f( arrowVel );
		params.write_u8( arrow_type );

		this.SendCommand( this.getCommandID("shoot arrow"), params );
	}
}


CBlob@ getPickupArrow(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "arrow")
			{
				return b;
			}
		}
	}
	return null;
}

bool canPickSpriteArrow(CBlob@ this, bool takeout)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			{
				CSprite@ sprite = b.getSprite();
				if (sprite.getSpriteLayer("arrow") !is null)
				{
					if (takeout)
						sprite.RemoveSpriteLayer("arrow");
					return true;
				}
			}
		}
	}
	return false;
}

CBlob@ CreateArrow(CBlob@ this, Vec2f arrowPos, Vec2f arrowVel, u8 arrowType)
{
	CBlob@ arrow = server_CreateBlobNoInit("arrow");
	if (arrow !is null)
	{
		// fire arrow?
		arrow.set_u8("arrow type", getActualArrowNumber(arrowType));
		arrow.SetDamageOwnerPlayer(this.getPlayer());
		arrow.Init();

		arrow.IgnoreCollisionWhileOverlapped(this);
		arrow.server_setTeamNum(this.getTeamNum());
		arrow.setPosition(arrowPos);
		arrow.setVelocity(arrowVel);
	}
	return arrow;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shoot arrow"))
	{
		Vec2f arrowPos;
		if (!params.saferead_Vec2f(arrowPos)) return;
		Vec2f arrowVel;
		if (!params.saferead_Vec2f(arrowVel)) return;
		u8 arrowType;
		if (!params.saferead_u8(arrowType)) return;

		if (arrowType >= arrowTypeNames.length) return;

		CrossbowmanInfo@ cbman;
		if (!this.get("crossbowmanInfo", @cbman))
		{
			return;
		}

		//cbman.arrow_type = arrowType;

		// return to normal arrow - server didnt have this synced
		if (!hasArrows(this, arrowType))
		{
			return;
		}

		if (getNet().isServer())
		{
			CreateArrow(this, arrowPos, arrowVel, arrowType);
			this.TakeBlob(arrowTypeNames[ arrowType ], 1);
		}

		this.getSprite().PlaySound("Entities/Characters/Archer/BowFire.ogg");

		cbman.fletch_cooldown = FLETCH_COOLDOWN; // just don't allow shoot + make arrow
	}
	else if (cmd == this.getCommandID("pickup arrow"))
	{
		CBlob@ arrow = getPickupArrow(this);
		bool spriteArrow = canPickSpriteArrow(this, false); // unnecessary

		if (arrow !is null || spriteArrow)
		{
			if (arrow !is null)
			{
				CrossbowmanInfo@ cbman;
				if (!this.get("crossbowmanInfo", @cbman))
				{
					return;
				}
				const u8 arrowType = cbman.arrow_type;
			}

			if (getNet().isServer())
			{
				CBlob@ mat_arrows = server_CreateBlobNoInit('mat_arrows');

				if (mat_arrows !is null)
				{
					mat_arrows.Tag('custom quantity');
					mat_arrows.Init();

					mat_arrows.server_SetQuantity(1); // unnecessary

					if (not this.server_PutInInventory(mat_arrows))
					{
						mat_arrows.setPosition(this.getPosition());
					}

					if (arrow !is null)
					{
						arrow.server_Die();
					}
					else
					{
						canPickSpriteArrow(this, true);
					}
				}
			}

			this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
		}
	}
	else if (cmd == this.getCommandID("cycle"))  //from standardcontrols
	{
		// cycle arrows
		CrossbowmanInfo@ cbman;
		if (!this.get("crossbowmanInfo", @cbman))
		{
			return;
		}
		u8 type = cbman.arrow_type;

		int count = 0;
		while (count < arrowTypeNames.length)
		{
			type++;
			count++;
			if (type >= arrowTypeNames.length)
			{
				type = 0;
			}
			if (this.getBlobCount(arrowTypeNames[type]) > 0)
			{
				cbman.arrow_type = type;
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
		CrossbowmanInfo@ cbman;
		if (!this.get("crossbowmanInfo", @cbman))
		{
			return;
		}
		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + arrowTypeNames[i]))
			{
				cbman.arrow_type = i;
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

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, CrossbowmanInfo@ info)
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

				//big things block attacks
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();

				if (!canHit(this, b))
				{
					// no TK
					if (large)
						dontHitMore = true;

					continue;
				}

				if (crossbowman_has_hit_actor(this, b))
				{
					if (large)
						dontHitMore = true;

					continue;
				}

				crossbowman_add_actor_limit(this, b);
				if (!dontHitMore)
				{
					Vec2f velocity = b.getPosition() - pos;
					this.server_Hit(b, hi.hitpos, velocity, damage, type, true);  // server_Hit() is server-side only

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

							info.tileDestructionLimiter++;
							canhit = ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);

							dontHitMoreMap = true;
							if (wood && !this.hasTag("fletched_this_attack"))
							{
								// Note: 0.1f damage doesn't harvest anything I guess
								// This puts it in inventory - include MaterialCommon
								//Material::fromTile(this, hi.tile, 1.f);

								CBlob@ ore = server_CreateBlobNoInit("mat_arrows");
								if (ore !is null)
								{
									ore.Tag('custom quantity');
	     							ore.Init();
	     							ore.setPosition(pos);
	     							ore.server_SetQuantity(1);
	     							this.Tag("fletched_this_attack");
	     						}
							}
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
								info.tileDestructionLimiter = 0;
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

					if (damage <= 1.0f)
					{
						return;
					}
				}
			}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return;
	}

	if (customData == Hitters::bayonet)
	{
		if(( //is a jab - note we dont have the dmg in here at the moment :/
		    cbman.state == CrossbowmanVars::sword_cut_mid ||
		    cbman.state == CrossbowmanVars::sword_cut_mid_down ||
		    cbman.state == CrossbowmanVars::sword_cut_up ||
		    cbman.state == CrossbowmanVars::sword_cut_down
		    )
		    && blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 30, true);
		}
		// fletch arrow
		if (!this.hasTag("fletched_this_attack") && (hitBlob.hasTag("tree") || hitBlob.hasTag("wooden")))	// make arrow from tree
		{
			if (getNet().isServer())
			{
				CBlob@ mat_arrows = server_CreateBlobNoInit('mat_arrows');
				if (mat_arrows !is null)
				{
					mat_arrows.Tag('custom quantity');
					mat_arrows.Init();

					mat_arrows.server_SetQuantity(fletch_num_arrows);

					if (not this.server_PutInInventory(mat_arrows))
					{
						mat_arrows.setPosition(this.getPosition());
					}
				}
			}
			this.Tag("fletched_this_attack");
			this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
		}
	}
}
// arrow pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	if (arrowTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(ArrowType::count, 2), getTranslatedString("Current arrow"));

	CrossbowmanInfo@ cbman;
	if (!this.get("crossbowmanInfo", @cbman))
	{
		return;
	}
	const u8 arrowSel = cbman.arrow_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			string matname = arrowTypeNames[i];
			CGridButton @button = menu.AddButton(arrowIcons[i], getTranslatedString(arrowNames[i]), this.getCommandID("pick " + matname));
		
			if (button !is null)
			{
				bool enabled = this.getBlobCount(arrowTypeNames[i]) > 0;
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;
		
				//if (enabled && i == ArrowType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}
		
				if (arrowSel == i)
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
		for (uint j = 0; j < arrowTypeNames.length; j++)
		{
			if (itemname == arrowTypeNames[j])
			{
				SetHelp(this, "help self action", "crossbowman", getTranslatedString("$arrow$Fire arrow   $KEY_HOLD$$LMB$"), "", 3);
				if (j > 0 && this.getInventory().getItemsCount() > 1)
				{
					SetHelp(this, "help inventory", "crossbowman", "$Help_Arrow1$$Swap$$Help_Arrow3$         $KEY_TAP$$KEY_F$", "", 2);
				}
				break;
			}
		}
	}

	CInventory@ inv = this.getInventory();
	if (inv.getItemsCount() == 0)
	{
		CrossbowmanInfo@ cbman;
		if (!this.get("crossbowmanInfo", @cbman))
		{
			return;
		}

		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			if (itemname == arrowTypeNames[i])
			{
				cbman.arrow_type = i;
			}
		}
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
