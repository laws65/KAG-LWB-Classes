
#include "Hitters.as";
#include "ShieldCommon.as";
#include "TeamStructureNear.as";

const f32 rockFastSpeed = 6.5f;

const f32 ROCK_PUSH_FORCE = 6.0f;
//arrow is 6.0f
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates


//Rock logic

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

	// 20 seconds of floating around
	this.server_SetTimeToDie(20);

	CSprite@ sprite = this.getSprite();
	//set a random frame
	Animation@ anim = sprite.addAnimation("rock", 0, false);
	anim.AddFrame(XORRandom(4));
	sprite.SetAnimation(anim);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	//I may make
	// if (this.hasTag("shotgunned"))
	//{
		//if (this.getTickSinceCreated() > 20)
		//{
			//this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		//}
	//}

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
	Pierce(this);

	if (shape.vellen > 0.0001f)
	{
		if (shape.vellen > 13.5f)
			shape.SetGravityScale(0.1f);
		else
			shape.SetGravityScale(Maths::Min(1.0f, 1.0f / (shape.vellen * 0.1f)));
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialRockHit(blob) &&
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
			dmg = getRockDamage(this, vellen);
		}

		// this isnt synced cause we want instant collision for arrow even if it was wrong
		dmg = RockHitBlob(this, point1, initVelocity, dmg, blob, Hitters::thrownrock);

		if (dmg > 0.0f)
		{
			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, Hitters::thrownrock);
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

	//anything to always hit
	if (specialRockHit(blob))
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
			//they're 
			this.hasTag("collided") ||
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

bool specialRockHit(CBlob@ blob)
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
		RockHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::thrownrock);
	}
}

f32 RockHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialRockHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (ROCK_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			//if (this.hasTag("bow arrow"))
			//{
				force *= 1.3f;
			//}

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
				if (velocity.Length() > rockFastSpeed)
				{
					this.getSprite().PlaySound("BodyGibFall2.ogg");
				}
				else
				{
					this.getSprite().PlaySound("BodyGibFall1.ogg");
				}
			}
			else
			{
				if (velocity.Length() > rockFastSpeed)
				{
					this.getSprite().PlaySound("rock_hit?.ogg");
				}
				else
				{
					this.getSprite().PlaySound("Rubble2.ogg");
				}
			}
		}

		this.server_Die();
	}

	return damage;
}

void RockHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData)
{
	if (velocity.Length() > rockFastSpeed)
	{
		this.getSprite().PlaySound("rock_hit?.ogg");
	}
	else
	{
		this.getSprite().PlaySound("Rubble2.ogg");
	}

	CMap@ map = this.getMap();
	if(map.isTileWood(map.getTile(worldPoint).type) && getRockDamage(this) == 0.5f)
	{
		map.server_DestroyTile(worldPoint, 0.1f, this);
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
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::arrow);
				break;
			}
		}
	}
	this.server_Die();
	this.Tag("collided");
}

void onDie(CBlob@ this)
{
	if (getNet().isClient())
	{
		Vec2f pos = this.getOldPosition();
		if (pos.x >= 1 && pos.y >= 1)
		{
			makeGibParticle(
				"ThrowingRocksGib.png", pos, getRandomVelocity(this.getOldVelocity().Angle(), this.getVelocity().Length() / 2 , 10),
				XORRandom(2), XORRandom(2),
				Vec2f(8, 8), 2.0f, 20, "Rubble1.ogg"
			);
			makeGibParticle(
				"ThrowingRocksGib.png", pos, getRandomVelocity(this.getOldVelocity().Angle(), this.getVelocity().Length() / 2 , 10),
				XORRandom(2), XORRandom(2),
				Vec2f(8, 8), 2.0f, 20, "Rubble1.ogg"
			);
		}
	}

}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (!getNet().isServer())
	{
		return;
	}

	// merge arrow into mat_arrows

	for (int i = 0; i < inventoryBlob.getInventory().getItemsCount(); i++)
	{
		CBlob @blob = inventoryBlob.getInventory().getItem(i);

		if (blob !is this && blob.getName() == "mat_stone")
		{
			blob.server_SetQuantity(blob.getQuantity() + 1);
			this.server_Die();
			return;
		}
	}

	// mat_arrows not found
	// make arrow into mat_arrows
	CBlob @mat = server_CreateBlob("mat_stone");

	if (mat !is null)
	{
		inventoryBlob.server_PutInInventory(mat);
		mat.server_SetQuantity(1);
		this.server_Die();
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::sword || customData == Hitters::spear || customData == Hitters::bayonet)
	{
		return 0.0f; //no cut arrows
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::thrownrock)
	{
		// affect players velocity
		const f32 scale = specialRockHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > 5.0f)//10.0f, shoot vel / 0.5f
		{
			f32 force = (ROCK_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale * 1.3f;// like bow arrow

			hitBlob.AddForce(velocity * force);
		}
	}
}


f32 getRockDamage(CBlob@ this, f32 vellen = -1.0f)
{
	if (vellen < 0) //grab it - otherwise use cached
	{
		CShape@ shape = this.getShape();
		if (shape is null)
			vellen = this.getOldVelocity().Length();
		else
			vellen = this.getShape().getVars().oldvel.Length();
	}

	if (vellen >= rockFastSpeed)
	{
		return 0.5f;
	}

	return 0.25f;
}
