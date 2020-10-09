// ArcherShop.as

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "CheckSpam.as"
#include "Costs.as"
#include "GenericButtonCommon.as"

void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	//INIT COSTS
	InitCosts();

	// SHOP
	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(4, 2));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	{
		ShopItem@ s = addShopItem(this, "Arrows", "$mat_arrows$", "mat_arrows", Descriptions::arrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::arrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Water Arrows", "$mat_waterarrows$", "mat_waterarrows", Descriptions::waterarrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::waterarrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Fire Arrows", "$mat_firearrows$", "mat_firearrows", Descriptions::firearrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::firearrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Bomb Arrows", "$mat_bombarrows$", "mat_bombarrows", Descriptions::bombarrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::bombarrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Poison Arrows", "$mat_poisonarrows$", "mat_poisonarrows", "Poison arrows for Archer and Crossbowman.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 25);
	}
	{
		ShopItem@ s = addShopItem(this, "Bullets", "$mat_bullets$", "mat_bullets", "Lead ball and gunpowder in a paper for Musketman.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 15);
	}
	{
		ShopItem@ s = addShopItem(this, "Barricade Frames", "$mat_barricades$", "mat_barricades", "Ballicade frames for Musketman.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 30);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;
	this.set_Vec2f("shop offset", Vec2f(6, 0));
	this.set_bool("shop available", this.isOverlapping(caller));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item"))
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
	}
}