#include "Hitters.as";
#include "ShieldCommon.as";
#include "FireParticle.as"
#include "PoisonParticle.as"
#include "SpearmanCommon.as";
#include "TeamStructureNear.as";
#include "KnockedCommon.as"

const f32 spearMediumSpeed = 6.5f;
const f32 spearFastSpeed = 8.5f;

const f32 SPEAR_PUSH_FORCE = 6.0f;
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates

const s32 FIRE_IGNITE_TIME = 5;


//Spear logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // weh ave our own map collision
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	if (!this.exists("spear type"))
	{
		this.set_u8("spear type", SpearType::normal);
	}

	// 20 seconds of floating around - gets cut down for fire spear
	// in SpearHitMap
	this.server_SetTimeToDie(20);

	const u8 spearType = this.get_u8("spear type");

	CSprite@ sprite = this.getSprite();
	//set a random frame
	{
		Animation@ anim = sprite.addAnimation("spear", 0, false);
		anim.AddFrame(0);
		sprite.SetAnimation(anim);
	}

	{
		Animation@ anim = sprite.addAnimation("fire spear", 0, false);
		anim.AddFrame(2);
		if (spearType == SpearType::fire)
			sprite.SetAnimation(anim);
	}

	{
		Animation@ anim = sprite.addAnimation("poison spear", 0, false);
		anim.AddFrame(1);
		if (spearType == SpearType::poison)
			sprite.SetAnimation(anim);
	}
}

void turnOffFire(CBlob@ this)
{
	this.SetLight(false);
	this.set_u8("spear type", SpearType::normal);
	this.Untag("fire source");
	this.getSprite().SetAnimation("spear");
	this.getSprite().PlaySound("/ExtinguishFire.ogg");
}

void turnOnFire(CBlob@ this)
{
	this.SetLight(true);
	this.set_u8("spear type", SpearType::fire);
	this.Tag("fire source");
	this.getSprite().SetAnimation("fire spear");
	this.getSprite().PlaySound("/FireFwoosh.ogg");
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	const u8 spearType = this.get_u8("spear type");

	f32 angle;
	bool processSticking = true;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		//prevent leaving the map
		{
			Vec2f pos = this.getPosition();
			if (
				pos.x < 0.1f ||
				pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
			) {
				this.server_Die();
				return;
			}
		}

		angle = (this.getVelocity()).Angle();
		Pierce(this);   //map
		this.setAngleDegrees(-angle);

		if (shape.vellen > 0.0001f)
		{
			if (shape.vellen > 13.5f)
				shape.SetGravityScale(0.1f);
			else
				shape.SetGravityScale(Maths::Min(1.0f, 1.0f / (shape.vellen * 0.1f)));

			processSticking = false;
		}

		// ignite spear
		if (spearType == SpearType::normal && this.isInFlames())
		{
			turnOnFire(this);
		}
	}

	// sticking
	if (processSticking)
	{
		//no collision
		shape.getConsts().collidable = false;

		if (!this.hasTag("_collisions"))
		{
			this.Tag("_collisions");
			// make everyone recheck their collisions with me
			const uint count = this.getTouchingCount();
			for (uint step = 0; step < count; ++step)
			{
				CBlob@ _blob = this.getTouchingByIndex(step);
				_blob.getShape().checkCollisionsAgain = true;
			}
		}

		angle = Maths::get360DegreesFrom256(this.get_u8("angle"));
		this.setVelocity(Vec2f(0, 0));
		this.setPosition(this.get_Vec2f("lock"));
		shape.SetStatic(true);
	}

	// poison spear
	if (spearType == SpearType::poison)
	{
		const s32 gametime = getGameTime();

		if (gametime % 12 == 0)
		{
			Vec2f offset = Vec2f(this.getWidth(), 0.0f);
			offset.RotateBy(-angle);
			makePoisonParticle(this.getPosition() + offset);
		}
	}

	// fire spear
	if (spearType == SpearType::fire)
	{
		const s32 gametime = getGameTime();

		if (gametime % 6 == 0)
		{
			this.getSprite().SetAnimation("fire");
			this.Tag("fire source");

			Vec2f offset = Vec2f(this.getWidth(), 0.0f);
			offset.RotateBy(-angle);
			makeFireParticle(this.getPosition() + offset, 4);

			if (!this.isInWater())
			{
				this.SetLight(true);
				this.SetLightColor(SColor(255, 250, 215, 178));
				this.SetLightRadius(20.5f);
			}
			else
			{
				turnOffFire(this);
			}
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		const u8 spearType = this.get_u8("spear type");

		if (spearType == SpearType::normal)
		{
			if (
				blob.getName() == "fireplace" &&
				blob.getSprite().isAnimation("fire") &&
				this.getTickSinceCreated() > 1 //forces player to shoot through fire
			) {
				turnOnFire(this);
			}
		}

		if (
			!solid && !blob.hasTag("flesh") &&
			!specialSpearHit(blob) &&
			(blob.getName() != "mounted_bow" || this.getTeamNum() != blob.getTeamNum())
		) {
			return;
		}

		Vec2f initVelocity = this.getOldVelocity();
		f32 vellen = initVelocity.Length();
		if (vellen < 0.1f)
		{
			return;
		}

		f32 dmg = 0.0f;
		if (blob.getTeamNum() != this.getTeamNum())
		{
			dmg = getSpearDamage(this, vellen);
		}
		// this isnt synced cause we want instant collision for spear even if it was wrong
		dmg = SpearHitBlob(this, point1, initVelocity, dmg, blob, Hitters::thrownspear, spearType);

		if (dmg > 0.0f)
		{
			//determine the hit type
			const u8 hit_type =
				(spearType == SpearType::fire) ? Hitters::fire :
				(spearType == SpearType::poison) ? Hitters::poisoning :
				Hitters::thrownspear;

			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, hit_type);
			this.Tag("collided");
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	//don't collide with other projectiles
	if (blob.hasTag("projectile"))
	{
		return false;
	}

	//collide so normal spears can be ignited
	if (blob.getName() == "fireplace")
	{
		return true;
	}

	//anything to always hit
	if (specialSpearHit(blob))
	{
		return true;
	}

	//definitely collide with non-team blobs
	bool check = this.getTeamNum() != blob.getTeamNum();
	//maybe collide with team structures
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		if (
			//we've collided
			this.getShape().isStatic() ||
			this.hasTag("collided") ||
			//or they're dead
			blob.hasTag("dead") ||
			//or they ignore us
			blob.hasTag("ignore_arrow")
		) {
			return false;
		}
		else
		{
			return true;
		}
	}

	return false;
}

bool specialSpearHit(CBlob@ blob)
{
	string bname = blob.getName();
	return (bname == "fishy" && blob.hasTag("dead") || bname == "food"
		|| bname == "steak" || bname == "grain"/* || bname == "heart"*/); //no egg because logic
}

void Pierce(CBlob @this, CBlob@ blob = null)
{
	Vec2f end;
	CMap@ map = this.getMap();
	Vec2f position = blob is null ? this.getPosition() : blob.getPosition();

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		SpearHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::thrownspear);
	}
}

f32 SpearHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData, const u8 spearType)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialSpearHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (SPEAR_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale * 1.3f;
			/*if (this.hasTag("bow spear"))
			{
				force *= 1.3f;
			}*/

			hitBlob.AddForce(velocity * force);

			//die
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}

		// check if shielded
		const bool hitShield = (hitBlob.hasTag("shielded") && blockAttack(hitBlob, velocity, 0.0f));

		// play sound
		if (!hitShield)
		{
			if (hitBlob.hasTag("flesh"))
			{
				if (velocity.Length() > spearFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitFleshFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitFlesh.ogg");
				}
			}
			else
			{
				if (velocity.Length() > spearFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitGround.ogg");
				}
			}
		}
		else if (spearType != SpearType::normal)
		{
			damage = 0.0f;
		}

		if (spearType == SpearType::fire)
		{
			this.server_SetTimeToDie(0.5f);

			if (hitBlob.getName() == "keg" && !hitBlob.hasTag("exploding"))
			{
				hitBlob.SendCommand(hitBlob.getCommandID("activate"));
			}

			this.set_Vec2f("override fire pos", hitBlob.getPosition());
		}
		else
		{
			//stick into "map" blobs
			if (hitBlob.getShape().isStatic())
			{
				SpearHitMap(this, worldPoint, velocity, damage, Hitters::thrownspear);
			}
			//die otherwise
			else
			{
				//add spear layer disabled
				/*
				CSprite@ sprite = hitBlob.getSprite();
				if (sprite !is null && !hitShield && spearType != SpearType::bomb)
				{
					AddSpearLayer(this, hitBlob, sprite, worldPoint, velocity);
				}*/
				this.server_Die();
			}
		}
	}

	return damage;
}

void SpearHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData)
{
	if (velocity.Length() > spearFastSpeed)
	{
		this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
	}
	else
	{
		this.getSprite().PlaySound("ArrowHitGround.ogg");
	}

	f32 radius = this.getRadius();

	f32 angle = velocity.Angle();

	this.set_u8("angle", Maths::get256DegreesFrom360(angle));

	Vec2f norm = velocity;
	norm.Normalize();
	norm *= (1.5f * radius);
	Vec2f lock = worldPoint - norm;
	this.set_Vec2f("lock", lock);

	this.Sync("lock", true);
	this.Sync("angle", true);

	this.setVelocity(Vec2f(0, 0));
	this.setPosition(lock);
	//this.getShape().server_SetActive( false );

	this.Tag("collided");

	const u8 spearType = this.get_u8("spear type");
	if (spearType == SpearType::fire)
	{
		this.server_SetTimeToDie(FIRE_IGNITE_TIME);
	}

	//kill any grain plants we shot the base of
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::thrownspear);
				break;
			}
		}
	}
}

void FireUp(CBlob@ this)
{
	CMap@ map = getMap();
	if (map is null) return;

	Vec2f pos = this.getPosition();
	Vec2f head = Vec2f(map.tilesize * 0.8f, 0.0f);
	f32 angle = this.getAngleDegrees();
	head.RotateBy(angle);
	Vec2f burnpos = pos + head;

	if (this.exists("override fire pos"))
	{
		MakeFireCross(this, this.get_Vec2f("override fire pos"));
	}
	else if (isFlammableAt(burnpos))
	{
		MakeFireCross(this, burnpos);
	}
	else if (isFlammableAt(pos))
	{
		MakeFireCross(this, pos);
	}
}

void MakeFireCross(CBlob@ this, Vec2f burnpos)
{
	/*
	fire starting pattern
	X -> fire | O -> not fire

	[O] [X] [O]
	[X] [X] [X]
	[O] [X] [O]
	*/

	CMap@ map = getMap();

	const float ts = map.tilesize;

	//align to grid
	burnpos = Vec2f(
		(Maths::Floor(burnpos.x / ts) + 0.5f) * ts,
		(Maths::Floor(burnpos.y / ts) + 0.5f) * ts
	);

	Vec2f[] positions = {
		burnpos, // center
		burnpos - Vec2f(ts, 0.0f), // left
		burnpos + Vec2f(ts, 0.0f), // right
		burnpos - Vec2f(0.0f, ts), // up
		burnpos + Vec2f(0.0f, ts) // down
	};

	for (int i = 0; i < positions.length; i++)
	{
		Vec2f pos = positions[i];
		//set map on fire
		map.server_setFireWorldspace(pos, true);

		//set blob on fire
		CBlob@ b = map.getBlobAtPosition(pos);
		//skip self or nothing there
		if (b is null || b is this) continue;

		//only hit static blobs
		CShape@ s = b.getShape();
		if (s !is null && s.isStatic())
		{
			this.server_Hit(b, this.getPosition(), this.getVelocity(), 0.5f, Hitters::fire);
		}
	}
}

bool isFlammableAt(Vec2f worldPos)
{
	CMap@ map = getMap();
	//check for flammable tile
	Tile tile = map.getTile(worldPos);
	if ((tile.flags & Tile::FLAMMABLE) != 0)
	{
		return true;
	}
	//check for flammable blob
	CBlob@ b = map.getBlobAtPosition(worldPos);
	if (b !is null && b.isFlammable())
	{
		return true;
	}
	//nothing flammable here!
	return false;
}

//random object used for gib spawning
Random _gib_r(0xa7c3a);
void onDie(CBlob@ this)
{
	if (getNet().isClient())
	{
		Vec2f pos = this.getPosition();
		if (pos.x >= 1 && pos.y >= 1)
		{
			Vec2f vel = this.getVelocity();
			makeGibParticle(
				"GenericGibs.png", pos, vel,
				1, _gib_r.NextRanged(4) + 4,
				Vec2f(8, 8), 2.0f, 20, "/thud",
				this.getTeamNum()
			);
		}
	}

	const u8 spearType = this.get_u8("spear type");

	if (spearType == SpearType::fire && isServer())
	{
		FireUp(this);
	}
}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (!getNet().isServer())
	{
		return;
	}

	// merge spear into mat_spears

	for (int i = 0; i < inventoryBlob.getInventory().getItemsCount(); i++)
	{
		CBlob @blob = inventoryBlob.getInventory().getItem(i);

		if (blob !is this && blob.getName() == "mat_spears")
		{
			blob.server_SetQuantity(blob.getQuantity() + 1);
			this.server_Die();
			return;
		}
	}

	// mat_spears not found
	// make spear into mat_spears
	CBlob @mat = server_CreateBlob("mat_spears");

	if (mat !is null)
	{
		inventoryBlob.server_PutInInventory(mat);
		mat.server_SetQuantity(1);
		this.server_Die();
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	const u8 spearType = this.get_u8("spear type");

	if (customData == Hitters::water || customData == Hitters::water_stun) //splash
	{
		if (spearType == SpearType::fire)
		{
			turnOffFire(this);
		}
	}

	if (customData == Hitters::sword || customData == Hitters::spear || customData == Hitters::bayonet)
	{
		return 0.0f; //no cut spears
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	const u8 spearType = this.get_u8("spear type");
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::thrownspear)
	{
		// affect players velocity

		const f32 scale = specialSpearHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > SpearmanVars::shoot_max_vel * 0.5f)
		{
			f32 force = (SPEAR_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			force *= 1.3f;

			hitBlob.AddForce(velocity * force);

			// stun if shot real close
			if (
				this.getTickSinceCreated() <= 4 &&
				speed > SpearmanVars::shoot_max_vel * 0.845f &&
				hitBlob.hasTag("player")
			) {
				setKnocked(hitBlob, 20, true);
				Sound::Play("/Stun", hitBlob.getPosition(), 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			}
		}
	}
}


f32 getSpearDamage(CBlob@ this, f32 vellen = -1.0f)
{
	if (vellen < 0) //grab it - otherwise use cached
	{
		CShape@ shape = this.getShape();
		if (shape is null)
			vellen = this.getOldVelocity().Length();
		else
			vellen = this.getShape().getVars().oldvel.Length();
	}

	if (vellen >= spearFastSpeed)
	{
		return 1.5f;
	}
	else if (vellen >= spearMediumSpeed)
	{
		return 1.0f;
	}

	return 0.5f;
}