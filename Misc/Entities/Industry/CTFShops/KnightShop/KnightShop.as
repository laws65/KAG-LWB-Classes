// Knight Workshop

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
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
	this.set_Vec2f("shop menu size", Vec2f(4, 3));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	{
		ShopItem@ s = addShopItem(this, "Bomb", "$bomb$", "mat_bombs", Descriptions::bomb, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::bomb);
	}
	{
		ShopItem@ s = addShopItem(this, "Water Bomb", "$waterbomb$", "mat_waterbombs", Descriptions::waterbomb, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::waterbomb);
	}
	{
		ShopItem@ s = addShopItem(this, "Mine", "$mine$", "mine", Descriptions::mine, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::mine);
	}
	{
		ShopItem@ s = addShopItem(this, "Keg", "$keg$", "keg", Descriptions::keg, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::keg);
	}
	//new items
	{
		ShopItem@ s = addShopItem(this, "Spears", "$mat_spears$", "mat_spears", "Spare Spears for Spearman. Throw them to enemies.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 15);
	}
	{
		ShopItem@ s = addShopItem(this, "Fire Spear", "$mat_firespears$", "mat_firespears", "Fire Spear for Spearman. Make spear attacking or thrown spear ignitable once.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 40);
	}
	{
		ShopItem@ s = addShopItem(this, "Poison Spears", "$mat_poisonspears$", "mat_poisonspears", "Poison Spears for Spearman. Make spear attacking or thrown spear poisonable twice.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 25);
	}
	{
		ShopItem@ s = addShopItem(this, "Smoke Ball", "$mat_smokeball$", "mat_smokeball", "Smoke Ball for Assassin. Can stun nearly enemies.", true);
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