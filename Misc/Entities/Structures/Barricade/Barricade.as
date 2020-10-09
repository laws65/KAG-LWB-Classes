// ballicade logic

#include "FireCommon.as"

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;
	this.getShape().getConsts().waterPasses = true;

	this.set_s16(burn_duration , 300);
	//transfer fire to underlying tiles
	this.Tag(spread_fire_tag);

	// this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().tickFrequency = 0;

	//block knight sword
	this.Tag("blocks sword");
	this.Tag("barricade");//block spear and bullets
	this.Tag("place norotate");

	this.set_TileType("background tile", CMap::tile_wood_back);
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_ladder.ogg");
	this.getSprite().SetZ(-40);
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return this.getTeamNum() != blob.getTeamNum();
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}