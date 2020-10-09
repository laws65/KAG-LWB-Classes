// Assassin logic

#include "AssassinCommon.as"
#include "ThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "MakeDustParticle.as";
#include "Requirements.as"

const int STAB_DELAY = 10;
const int STAB_TIME = 22;

void onInit(CBlob@ this)
{
	AssassinInfo assa;
	this.set("assassinInfo", @assa);

	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	this.addCommandID(grapple_sync_cmd);
	this.addCommandID("smokeball");
	this.addCommandID("knife");

	AddIconToken("$AssassinGrapple$", "LWBHelpIcons.png", Vec2f(16, 16), 9);

	SetHelp(this, "help self action", "assassin", getTranslatedString("$Daggar$Stab        $LMB$"), "", 3);
	SetHelp(this, "help self hide", "assassin", getTranslatedString("Hide    $KEY_S$"), "", 1);
	SetHelp(this, "help self action2", "assassin", getTranslatedString("$AssassinGrapple$ Grappling hook    $RMB$"), "", 3);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 5, Vec2f(16, 16));
	}
}

void ManageGrapple(CBlob@ this, AssassinInfo@ assa)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);
	if (right_click)
	{
		if (canSend(this) && !isKnifeAnim(this.getSprite())) //otherwise grapple
		{
			assa.grappling = true;
			assa.grapple_id = 0xffff;
			assa.grapple_pos = pos;

			assa.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				assa.grapple_vel = direction * assassin_grapple_throw_speed;
			}
			else
			{
				assa.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}
	}

	if (assa.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this))
			{
				assa.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 assassin_grapple_range = assassin_grapple_length * assa.grapple_ratio;
			const f32 assassin_grapple_force_limit = this.getMass() * assassin_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (assa.grapple_ratio > 0.2f)
				assa.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = assa.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - assassin_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * assassin_grapple_stiffness);
					force *= Maths::Min(assassin_grapple_force_limit, Maths::Max(0.0f, offdist + assassin_grapple_slack) * assassin_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (assa.grapple_pos.x < 0 ||
			        assa.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > assassin_grapple_length * 3.0f)
			{
				if (canSend(this))
				{
					assa.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (assa.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(assa.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				assa.grapple_vel = (assa.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = assa.grapple_pos + assa.grapple_vel;
				next -= offset;

				Vec2f dir = next - assa.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						assa.grapple_pos += dir * step;
					}
					else
					{
						assa.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, assa, map, dist);
				}

			}
			else //stuck -> pull towards pos
			{

				//wallrun/jump reset to make getting over things easier
				//at the top of grapple
				if (this.isOnWall()) //on wall
				{
					//close to the grapple point
					//not too far above
					//and moving downwards
					Vec2f dif = pos - assa.grapple_pos;
					if (this.getVelocity().y > 0 &&
					        dif.y > -10.0f &&
					        dif.Length() < 24.0f)
					{
						//need move vars
						RunnerMoveVars@ moveVars;
						if (this.get("moveVars", @moveVars))
						{
							moveVars.walljumped_side = Walljump::NONE;
							moveVars.wallrun_start = pos.y;
							moveVars.wallrun_current = pos.y;
						}
					}
				}

				CBlob@ b = null;
				if (assa.grapple_id != 0)
				{
					@b = getBlobByNetworkID(assa.grapple_id);
					if (b is null)
					{
						assa.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					assa.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this))
						{
							assa.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, assa, map))
				{
					if (canSend(this))
					{
						assa.grappling = false;
						SyncGrapple(this);
					}
				}

				this.AddForce(force);
				Vec2f target = (this.getPosition() + offset);
				if (!map.rayCastSolid(this.getPosition(), target) &&
					(this.getVelocity().Length() > 2 || !this.isOnMap()))
				{
					this.setPosition(target);
				}

				if (b !is null)
					b.AddForce(-force * (b.getMass() / this.getMass()));

			}
		}

	}
}

void onTick(CBlob@ this)
{
	AssassinInfo@ assa;
	if (!this.get("assassinInfo", @assa))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		assa.grappling = false;
		this.getSprite().SetEmitSoundPaused(true);
		return;
	}

	ManageGrapple(this, assa);

	if (isKnifeAnim(this.getSprite()))
	{
		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.5f;
			moveVars.jumpFactor = 0.5f;
		}
		this.Tag("prevent crouch");
	}


	if(this.isMyPlayer())
	{
		// void ManageKnife(CBlob@ this)
		CSprite@ sprite = this.getSprite();
		if(isKnifeAnim(sprite) && sprite.isFrameIndex(1) && !(sprite.getFrameIndex() < 0))// like builder's pickaxe
		{
			this.SendCommand(this.getCommandID("knife"));
		}

		//void SmokeBall(CBlob@ this)
		// space

		if (this.isKeyJustPressed(key_action3))
		{
			if (hasItem(this, "mat_smokeball"))
			{
				this.SendCommand(this.getCommandID("smokeball"));
			}
			else
			{
				client_SendThrowOrActivateCommand(this);
			}
		}
	}
}


bool checkGrappleStep(CBlob@ this, AssassinInfo@ assa, CMap@ map, const f32 dist)
{
	if (map.getSectorAtPosition(assa.grapple_pos, "barrier") !is null)  //red barrier
	{
		if (canSend(this))
		{
			assa.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(assa, map, dist))
	{
		assa.grapple_id = 0;

		assa.grapple_ratio = Maths::Max(0.2, Maths::Min(assa.grapple_ratio, dist / assassin_grapple_length));

		assa.grapple_pos.y = Maths::Max(0.0, assa.grapple_pos.y);

		if (canSend(this)) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(assa.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (assa.grapple_ratio > 0.5f)
					return false;

				if (canSend(this))
				{
					assa.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				assa.grapple_ratio = Maths::Max(0.2, Maths::Min(assa.grapple_ratio, b.getDistanceTo(this) / assassin_grapple_length));

				assa.grapple_id = b.getNetworkID();
				if (canSend(this))
				{
					SyncGrapple(this);
				}

				return true;
			}
		}
	}

	return false;
}

bool grappleHitMap(AssassinInfo@ assa, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(assa.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(assa.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(assa.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(assa.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(assa.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, AssassinInfo@ assa, CMap@ map)
{
	return !grappleHitMap(assa, map) || this.isKeyPressed(key_use);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}
void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(grapple_sync_cmd))
	{
		HandleGrapple(this, params, !canSend(this));
	}
	else if (cmd == this.getCommandID("smokeball"))
	{
		Vec2f pos = this.getPosition();
		MakeDustParticle(pos, "LargeSmoke.png");
		this.getSprite().PlaySound("FireFwoosh.ogg", 1.0f, 1.0f);
		if (!getNet().isServer() || !hasItem(this, "mat_smokeball"))
			return;
		TakeItem(this, "mat_smokeball");
		CMap@ map = this.getMap();
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromArc(pos, 0.0f, 360.0f, this.getRadius() + 30.0f, this, @hitInfos))
		{
			//HitInfo objects are sorted, first come closest hits
			for (uint i = 0; i < hitInfos.length; i++)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;
				if (b !is null) // blob
				{
					if (canHit(this, b) && isKnockable(b))
					{
						setKnocked(b, 30);
					}
				}
			}
		}
	}
	else if (cmd == this.getCommandID("knife"))
	{
		if (!getNet().isServer())
		{
			return;
		}

		AssassinInfo@ assa;
		if (!this.get("assassinInfo", @assa))
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
		//get the actual aim angle
		f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
		bool notAddTimer = true;

		CBlob@ secondBestHittable;// player is first
		uint id = 0;
		bool foundSecondBest = false;

		// this gathers HitInfo objects which contain blob or tile hit information
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromArc(pos, aimangle, 90.0f, radius + 10.0f, this, @hitInfos))
		{
			//HitInfo objects are sorted, first come closest hits
			for (uint i = 0; i < hitInfos.length; i++)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;
				if (b !is null) // blob
				{
					if (b.hasTag("ignore sword")) continue;

					if (!canHit(this, b))
					{
						// no TK
						//big things block attacks
						if (b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable())
							break;// if you found second best hittable, you'll hit by after command
					}
					else // can hit!
					{
						if (b.hasTag("player") && !b.hasTag("dead"))// it is best hittable, not need to compare
						{
							Vec2f velocity = b.getPosition() - pos;
							// lesser knock back
							this.server_Hit(b, hi.hitpos, velocity, b.hasTag("flesh") ? 1.0f : 0.5f, Hitters::stab, true);  // server_Hit() is server-side only
							return;
						}
						else if (b.hasTag("vehicle") || (b.hasTag("flesh") && !b.hasTag("dead")) || b.getName() == "mine")// found better hittable
						{
							@secondBestHittable = b;
							id = i;
							foundSecondBest = true;
						}
						else if (secondBestHittable is null)// is not exist
						{
							@secondBestHittable = b;
							id = i;
						}
						//big things block attacks
						if (b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable())
							break;// if you found second best hittable, you'll hit by after command
					}
				}
				else if (secondBestHittable is null) // hitmap
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

							bool canhit = true;
							if(notAddTimer)
							{
								assa.tileDestructionLimiter++;
								notAddTimer = false;
							}
							canhit = ((assa.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;
							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								assa.tileDestructionLimiter = 0;// reset
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
								return;
							}
						}
					}
				}
			}
			if (secondBestHittable !is null)// hit nothing but found second best
			{
				Vec2f velocity = secondBestHittable.getPosition() - pos;
				this.server_Hit(secondBestHittable, hitInfos[id].hitpos, velocity, secondBestHittable.hasTag("flesh") ? 1.0f : 0.5f, Hitters::stab, true);  // server_Hit() is server-side only
			}
		}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (customData == Hitters::stab)
	{
		if (damage > 0.0f && hitBlob.hasTag("flesh"))
		{
			this.getSprite().PlaySound("KnifeStab.ogg");
			if (isKnockable(hitBlob)) setKnocked(hitBlob, 20, true);
		}

		if (blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 20, true);
		}
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

//ball management

bool hasItem(CBlob@ this, const string &in name)
{
	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Smoke Balls", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		return hasRequirements(inv, reqs, missing);
	}
	else
	{
		warn("our inventory was null! AssassinLogic.as");
	}

	return false;
}

void TakeItem(CBlob@ this, const string &in name)
{
	CBlob@ carried = this.getCarriedBlob();
	if (carried !is null)
	{
		if (carried.getName() == name)
		{
			carried.server_Die();
			return;
		}
	}

	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Smoke Balls", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		if (hasRequirements(inv, reqs, missing))
		{
			server_TakeRequirements(inv, reqs);
		}
		else
		{
			warn("took a ball even though we dont have one! AssassinLogic.as");
		}
	}
	else
	{
		warn("our inventory was null! AssassinLogic.as");
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	if (blob.getName() == "mat_smokeball")
		SetHelp(this, "help inventory", "assassin", "$mat_smokeball$ Stun nearby enemies $KEY_SPACE$", "", 3);
}
