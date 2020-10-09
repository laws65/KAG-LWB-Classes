// BuilderCommon.as

#include "BuildBlock.as";
#include "PlacementCommon.as";
#include "CheckSpam.as";
#include "GameplayEvents.as";
#include "Requirements.as";

const f32 allow_overlap = 2.0f;

namespace Action
{
	enum type
	{
		nothing = 0,
		throw,
		ladder,
		count
	};
}

shared class RockthrowerInfo
{
	u8 action;
	u16 boulderTimer;

	RockthrowerInfo()
	{
		action = Action::nothing;
		boulderTimer = 0;
	}
};

void SetActionType(CBlob@ this, const u8 type)
{
	RockthrowerInfo@ rter;
	if (!this.get("rockthorwerInfo", @rter))
	{
		return;
	}
	rter.action = type;
}

u8 getActionType(CBlob@ this)
{
	RockthrowerInfo@ rter;
	if (!this.get("rockthrowerInfo", @rter))
	{
		return 0;
	}
	return rter.action;
}

// for animation
bool isShootTime(CBlob@ this)
{
	RockthrowerInfo@ rter;
	if (!this.get("rockthrowerInfo", @rter))
	{
		return false;
	}
	return rter.action == Action::throw;
}

bool isBuildTime(CBlob@ this)
{
	RockthrowerInfo@ rter;
	if (!this.get("rockthrowerInfo", @rter))
	{
		return false;
	}
	return rter.action == Action::ladder;
}

bool hasStones(CBlob@ this)
{
	return this.getBlobCount("mat_stone") > 0;
}

bool hasBoulderStones(CBlob@ this)
{
	return this.getBlobCount("mat_stone") >= 35;
}


shared class HitData
{
	u16 blobID;
	Vec2f tilepos;
};

Vec2f getBuildingOffsetPos(CBlob@ blob, CMap@ map, Vec2f required_tile_space)
{
	Vec2f halfSize = required_tile_space * 0.5f;

	Vec2f pos = blob.getPosition();
	pos.x = int(pos.x / map.tilesize);
	pos.x *= map.tilesize;
	pos.x += map.tilesize * 0.5f;

	pos.y -= required_tile_space.y * map.tilesize * 0.5f - map.tilesize;
	pos.y = int(pos.y / map.tilesize);
	pos.y *= map.tilesize;
	pos.y += map.tilesize * 0.5f;

	Vec2f offsetPos = pos - Vec2f(halfSize.x , halfSize.y) * map.tilesize;
	Vec2f alignedWorldPos = map.getAlignedWorldPos(offsetPos);
	return alignedWorldPos;
}

CBlob@ server_BuildBlob(CBlob@ this, BuildBlock[]@ blocks, uint index)
{
	if (index >= blocks.length)
	{
		return null;
	}

	this.set_u32("cant build time", 0);

	CInventory@ inv = this.getInventory();
	BuildBlock@ b = @blocks[index];

	this.set_TileType("buildtile", 0);

	CBlob@ anotherBlob = inv.getItem(b.name);
	if (getNet().isServer() && anotherBlob !is null)
	{
		this.server_Pickup(anotherBlob);
		this.set_u8("buildblob", 255);
		return null;
	}

	Vec2f pos = this.getPosition();

	this.set_u8("buildblob", index);

	if (getNet().isServer())
	{
		CBlob@ blockBlob = server_CreateBlob(b.name, this.getTeamNum(), Vec2f(0,0));
		if (blockBlob !is null)
		{
			CShape@ shape = blockBlob.getShape();
			shape.SetStatic(false);
			shape.server_SetActive(true);
			blockBlob.setPosition(pos);

			this.server_Pickup(blockBlob);

			blockBlob.Tag("temp blob");
			return blockBlob;
		}
	}

	return null;
}

bool canBuild(CBlob@ this, BuildBlock[]@ blocks, uint index)
{
	if (index >= blocks.length)
	{
		return false;
	}

	BuildBlock@ block = @blocks[index];

	BlockCursor @bc;
	this.get("blockCursor", @bc);
	if (bc is null)
	{
		return false;
	}

	bc.missing.Clear();
	bc.hasReqs = hasRequirements(this.getInventory(), block.reqs, bc.missing, not block.buildOnGround);

	return bc.hasReqs;
}

void ClearCarriedBlock(CBlob@ this)
{
	// clear variables
	this.set_u8("buildblob", 255);

	// remove carried block, if any
	CBlob@ carried = this.getCarriedBlob();
	if (carried !is null && carried.hasTag("temp blob"))
	{
		carried.Untag("temp blob");
		carried.server_Die();
	}
}
