// Musketman logic

#include "MusketmanCommon.as"
#include "ThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "PlacementCommon.as";

void onInit(CBlob@ this)
{
	MusketmanInfo musman;
	this.set("musketmanInfo", @musman);

	this.set_s8("charge_time", 0);
	this.set_u8("charge_state", MusketmanParams::not_aiming);
	this.set_bool("has_bullet", false);
	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	//centered on bullets
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().SetEmitSound("musketman_bow_pull.ogg");
	this.addCommandID("shoot bullet");
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	AddIconToken("$Shovel$", "LWBHelpIcons.png", Vec2f(16, 16), 12);
	AddIconToken("$Help_Bullet$", "LWBHelpIcons.png", Vec2f(8, 16), 23);

	SetHelp(this, "help self hide", "musketman", getTranslatedString("Hide    $KEY_S$"), "", 1);
	SetHelp(this, "help self action2", "musketman", getTranslatedString("$Shovel$ Dig    $RMB$"), "", 3);

	//add a command ID for each bullet type

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 3, Vec2f(16, 16));
	}
}

void ManageBow(CBlob@ this, MusketmanInfo@ musman, RunnerMoveVars@ moveVars)
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
	bool hasbullet = musman.has_bullet;
	s8 charge_time = musman.charge_time;
	u8 charge_state = musman.charge_state;
	const bool pressed_action2 = this.isKeyPressed(key_action2);
	Vec2f pos = this.getPosition();
	bool isNotBuilding = true;

	CBlob@ carryBlob = this.getCarriedBlob();
	if (carryBlob !is null)
	{
		// check if this isn't what we wanted to create
		if (carryBlob.getName() == "barricade")// TODO:use hasTag("temp blob")
		{
			isNotBuilding = false;
		}
	}

	// cancel charging
	if (this.isKeyJustPressed(key_action2) && charge_state != MusketmanParams::not_aiming && charge_state != MusketmanParams::digging)
	{
		charge_state = MusketmanParams::not_aiming;
		musman.charge_time = 0;
		sprite.SetEmitSoundPaused(true);
		sprite.PlaySound("PopIn.ogg");
	}

	if (responsible)
	{
		if (hasbullet != this.get_bool("has_bullet"))
		{
			this.set_bool("has_bullet", hasbullet);
			this.Sync("has_bullet", isServer());
		}
	}

	if (charge_state == MusketmanParams::digging)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.jumpFactor *= 0.5f;
		moveVars.canVault = false;
		musman.dig_delay--;
		if(musman.dig_delay == 0)
		{
			charge_state = MusketmanParams::not_aiming;
			if(this.isKeyPressed(key_action1))
			{
				charge_state = MusketmanParams::readying;
				hasbullet = hasBullets(this);

				if (responsible)
				{
					this.set_bool("has_bullet", hasbullet);
					this.Sync("has_bullet", isServer());
				}

				charge_time = 0;

				if (!hasbullet)
				{
					charge_state = MusketmanParams::no_bullets;

					if (ismyplayer)   // playing annoying no ammo sound
					{
						this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
					}

				}
				else
				{
					sprite.PlaySound("musketman_arrow_draw_end.ogg");
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
	else if (this.isKeyPressed(key_action1) && isNotBuilding)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.jumpFactor *= 0.5f;
		moveVars.canVault = false;

		const bool just_action1 = this.isKeyJustPressed(key_action1);

		//	printf("charge_state " + charge_state );

		if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_action2) &&
		        charge_state == MusketmanParams::not_aiming)
		{
			charge_state = MusketmanParams::readying;
			hasbullet = hasBullets(this);

			if (responsible)
			{
				this.set_bool("has_bullet", hasbullet);
				this.Sync("has_bullet", isServer());
			}

			charge_time = 0;

			if (!hasbullet)
			{
				charge_state = MusketmanParams::no_bullets;

				if (ismyplayer && !this.wasKeyPressed(key_action1))   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}

			}
			else
			{
				sprite.PlaySound("musketman_arrow_draw_end.ogg");
				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(false);

				if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
				{
					sprite.SetEmitSoundVolume(0.5f);
				}
			}
		}
		else if (charge_state == MusketmanParams::readying)
		{
			charge_time++;
			if (charge_time >= MusketmanParams::shoot_period)
			{
				sprite.PlaySound("musketman_charged.ogg");
				charge_state = MusketmanParams::charging;
				sprite.SetEmitSoundPaused(true);
			}
		}
		else if (charge_state == MusketmanParams::charging)
		{
			charge_time++;

			if (charge_time >= MusketmanParams::shoot_period + MusketmanParams::charge_limit)
			{
				charge_state = MusketmanParams::discharging;
				charge_time = MusketmanParams::shoot_period;
			}
		}
		else if (charge_state == MusketmanParams::discharging)
		{
			if (charge_time >= 0)
			{
				charge_time--;
			}
			if (charge_time >= 0)//twice
			{
				charge_time--;
			}
			if (charge_time == 0)
			{
				charge_state = MusketmanParams::readying;
				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(false);

				if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
				{
					sprite.SetEmitSoundVolume(0.5f);
				}
			}
		}
		else if (charge_state == MusketmanParams::no_bullets)
		{
			if (charge_time < 7) charge_time++;

		}
	}
	else
	{
		if (charge_state == MusketmanParams::charging)
		{
			ClientFire(this, hasbullet);
		}
		charge_state = MusketmanParams::not_aiming;    //set to not aiming either way
		charge_time = 0;

		sprite.SetEmitSoundPaused(true);
		if(pressed_action2)
		{
			charge_state = MusketmanParams::digging;
			musman.dig_delay = 30;
			DoDig(this);
		}
	}

	// my player!

	if (responsible)
	{
		// set cursor

		if (ismyplayer && !getHUD().hasButtons())
		{
			int frame = 0;
			//	print("musketman.charge_time " + musketman.charge_time + " / " + MusketmanParams::shoot_period );
			if (musman.charge_state == MusketmanParams::readying || musman.charge_state == MusketmanParams::charging || musman.charge_state == MusketmanParams::discharging)
			{
				if (musman.charge_time < MusketmanParams::shoot_period)
				{
					//charging shot
					frame = 2 + int((float(musman.charge_time) / float(MusketmanParams::shoot_period) * 8)) * 2;
				}
				else
				{
					//charging legolas
					frame = 1;// + int((float(musman.charge_time - MusketmanParams::shoot_period) / MusketmanParams::charge_limit) * 9) * 2;
				}
			}
			getHUD().SetCursorFrame(frame);
		}

		// activate/throw

		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	musman.charge_time = charge_time;
	musman.charge_state = charge_state;
	musman.has_bullet = hasbullet;

}

void onTick(CBlob@ this)
{
	MusketmanInfo@ musman;
	if (!this.get("musketmanInfo", @musman))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		musman.charge_state = 0;
		musman.charge_time = 0;
		this.getSprite().SetEmitSoundPaused(true);
		getHUD().SetCursorFrame(0);
		return;
	}

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	ManageBow(this, musman, moveVars);
}

void DoDig(CBlob@ this)
{

	if (!getNet().isServer())
	{
		return;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f vec;
	this.getAimDirection(vec);
	Vec2f thinghy(1, 0);
	f32 aimangle = -(vec.Angle());
	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}
	thinghy.RotateBy(aimangle);
	vel.Normalize();
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
	
	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, 30.0f, radius + 16.0f, this, @hitInfos))
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
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();

				if (!canHit(this, b))
				{
					// no TK
					if (large)
						dontHitMore = true;

					continue;
				}

				if (!dontHitMore)
				{
					Vec2f velocity = b.getPosition() - pos;
					this.server_Hit(b, hi.hitpos, velocity, 0.25f, Hitters::shovel, true);  // server_Hit() is server-side only

					// end hitting if we hit something solid, don't if its flesh
					if (large)
					{
						dontHitMore = true;
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap)
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile) && !map.isTileThickStone(hi.tile);
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


							bool canhit = map.getSectorAtPosition(tpos, "no build") is null;

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
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this, const bool hasbullet)
{
	//time to fire!
	if (hasbullet && canSend(this))  // client-logic
	{
		ShootBullet(this, this.getPosition() + Vec2f(0.0f, -2.0f), this.getAimPos() + Vec2f(0.0f, -2.0f), MusketmanParams::shoot_max_vel);
	}
}

void ShootBullet(CBlob @this, Vec2f bulletPos, Vec2f aimpos, f32 bulletspeed)
{
	if (canSend(this))
	{
		// player or bot
		Vec2f bulletVel = (aimpos - bulletPos);
		bulletVel.Normalize();
		bulletVel *= bulletspeed;
		//print("bulletspeed " + bulletspeed);
		CBitStream params;
		params.write_Vec2f(bulletPos);
		params.write_Vec2f(bulletVel);

		this.SendCommand(this.getCommandID("shoot bullet"), params);
	}
}

CBlob@ CreateBullet(CBlob@ this, Vec2f bulletPos, Vec2f bulletVel)
{
	CBlob@ bullet = server_CreateBlobNoInit("bullet");
	if (bullet !is null)
	{
		bullet.SetDamageOwnerPlayer(this.getPlayer());
		bullet.Init();

		bullet.IgnoreCollisionWhileOverlapped(this);
		bullet.server_setTeamNum(this.getTeamNum());
		bullet.setPosition(bulletPos);
		bullet.setVelocity(bulletVel);
	}
	return bullet;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shoot bullet"))
	{
		Vec2f bulletPos;
		if (!params.saferead_Vec2f(bulletPos)) return;
		Vec2f bulletVel;
		if (!params.saferead_Vec2f(bulletVel)) return;
		
		// return to normal bullet - server didnt have this synced
		if (!hasBullets(this))
		{
			return;
		}

		if (getNet().isServer())
		{
			CreateBullet(this, bulletPos, bulletVel);
		}

		this.getSprite().PlaySound("M16Fire.ogg");
		this.TakeBlob("mat_bullets", 1);
	}
}

// Blame Fuzzle.
// as same as knight
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

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	// ignore collision for built blob
	BuildBlock[][]@ blocks;
	if (!this.get("blocks", @blocks))
	{
		return;
	}

	for(u8 i = 0; i < blocks[0].length; i++)
	{
		BuildBlock@ block = blocks[0][i];
		if (block !is null && block.name == detached.getName())
		{
			this.IgnoreCollisionWhileOverlapped(null);
			detached.IgnoreCollisionWhileOverlapped(null);
		}
	}

	// BUILD BLOB
	// take requirements from blob that is built and play sound
	// put out another one of the same
	if (detached.hasTag("temp blob"))
	{
		if (!detached.hasTag("temp blob placed"))
		{
			detached.server_Die();
			return;
		}

		uint i = this.get_u8("buildblob");
		if (i >= 0 && i < blocks[0].length)
		{
			BuildBlock@ b = blocks[0][i];
			if (b.name == detached.getName())
			{
				this.set_u8("buildblob", 255);

				CInventory@ inv = this.getInventory();

				CBitStream missing;
				if (hasRequirements(inv, b.reqs, missing, not b.buildOnGround))
				{
					server_TakeRequirements(inv, b.reqs);
				}
				// take out another one if in inventory
				if (hasBarricades(this)) server_BuildBlob(this, blocks[0], i);// TODO: don't use hasBarricades()
			}
		}
	}
	else if (detached.getName() == "seed")
	{
		if (not detached.hasTag('temp blob placed')) return;

		CBlob@ anotherBlob = this.getInventory().getItem(detached.getName());
		if (anotherBlob !is null)
		{
			this.server_Pickup(anotherBlob);
		}
	}
}

// help
void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	string itemname = blob.getName();
	if (this.isMyPlayer())
	{
		if (itemname == "mat_bullets")
		{
			SetHelp(this, "help self action", "musketman", getTranslatedString("$Help_Bullet$Fire bullet   $KEY_HOLD$$LMB$"), "", 3);
		}
		else if (itemname == "mat_barricades")
		{
			SetHelp(this, "help inventory", "musketman", getTranslatedString("$Build$Select in inventory to build barricade"), "", 3);
		}
	}
}
