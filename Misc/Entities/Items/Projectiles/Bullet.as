#include "Hitters.as";
#include "ShieldCommon.as";
#include "TeamStructureNear.as";
#include "MakeDustParticle.as";
#include "ParticleSparks.as";
#include "KnockedCommon.as";

const f32 BULLET_PUSH_FORCE = 6.0f; // make it double?
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates

//Bullet logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	shape.SetGravityScale(0.0f);
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // weh ave our own map collision
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	// 20 seconds of floating around - gets cut down for fire bullet
	// in BulletHitMap
	this.server_SetTimeToDie(20);
	// like fire arrow, half radius
	this.SetLight(true);
	this.SetLightColor(SColor(255, 250, 215, 178));
	this.SetLightRadius(10.0f);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	f32 angle;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		//prevent leaving the map
		Vec2f pos = this.getPosition();
		if (
			pos.x < 0.1f ||
			pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
		) {
			this.server_Die();
			return;
		}

		angle = (this.getVelocity()).Angle();
		Pierce(this);   //map
		this.setAngleDegrees(-angle);
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialBulletHit(blob) &&
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
			dmg = getBulletDamage(this, vellen);
		}

		// this isnt synced cause we want instant collision for bullet even if it was wrong
		dmg = BulletHitBlob(this, point1, initVelocity, dmg, blob, Hitters::bullet);

		if (dmg > 0.0f)
		{
			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, Hitters::bullet);
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
	if (specialBulletHit(blob))
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

bool specialBulletHit(CBlob@ blob)
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
	CShape@ shape = this.getShape();

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		BulletHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::bullet);
	}
	else if(shape.vellen < 10.0f)
	{
		this.server_Die();
	}
}

f32 BulletHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialBulletHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (BULLET_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			force *= 1.3f;

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
				this.getSprite().PlaySound("ArrowHitFlesh.ogg");
			}
			else
			{
				this.getSprite().PlaySound("BulletImpact.ogg");	
			}
		}
		//if(!hitBlob.hasTag("wooden") || hitBlob.hasTag("vehicle") || hitBlob.hasTag("barricade"))
		//{
		this.server_Die();
		//}
	}

	return damage;
}

void BulletHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData)
{
	MakeDustParticle(worldPoint, "/DustSmall.png");
	CMap@ map = this.getMap();
	f32 vellen = velocity.Length();
	TileType tile = map.getTile(worldPoint).type;
	if (map.isTileCastle(tile) || map.isTileStone(tile) || map.isTileBedrock(tile))
	{
		sparks (worldPoint, -velocity.Angle(), Maths::Max(vellen*0.05f, damage));
		this.getSprite().PlaySound("BulletRicochet.ogg");
		if(!map.isTileBedrock(tile))
		{
			map.server_DestroyTile(worldPoint, 0.1f, this);
			map.server_DestroyTile(worldPoint, 0.1f, this);
		}
	}
	else
	{
		this.getSprite().PlaySound("BulletImpact.ogg");
		if (map.isTileWood(tile))
			map.server_DestroyTile(worldPoint, 0.1f, this);
	}
	this.Tag("collided");
	//kill any grain plants we shot the base of
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::bullet);
				break;
			}
		}
	}
	this.server_Die();
}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (!getNet().isServer())
	{
		return;
	}

	// merge bullet into mat_bullets

	for (int i = 0; i < inventoryBlob.getInventory().getItemsCount(); i++)
	{
		CBlob @blob = inventoryBlob.getInventory().getItem(i);

		if (blob !is this && blob.getName() == "mat_bullets")
		{
			blob.server_SetQuantity(blob.getQuantity() + 1);
			this.server_Die();
			return;
		}
	}

	// mat_bullets not found
	// make bullet into mat_bullets
	CBlob @mat = server_CreateBlob("mat_bullets");

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
		return 0.0f; //no cut bullets
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (this !is hitBlob && customData == Hitters::bullet)
	{
		// affect players velocity

		const f32 scale = specialBulletHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > 17.59f)
		{
			f32 force = (BULLET_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			force *= 1.3f;

			hitBlob.AddForce(velocity * force);

			// stun if shot real close
			if (
				speed > 17.59 * 0.845f &&
				hitBlob.hasTag("player")
			) {
				setKnocked(hitBlob, 20, true);
				Sound::Play("/Stun", hitBlob.getPosition(), 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			}
		}
	}
}


f32 getBulletDamage(CBlob@ this, f32 vellen = -1.0f)
{
	return 1.5f;
}