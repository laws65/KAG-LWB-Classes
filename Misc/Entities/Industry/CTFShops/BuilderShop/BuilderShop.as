// BuilderShop.as

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "GenericButtonCommon.as"

void onInit(CBlob@ this)
{
	InitCosts(); //read from cfg

	AddIconToken("$_buildershop_filled_bucket$", "Bucket.png", Vec2f(16, 16), 1);

	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	// SHOP
	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(6, 4));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	{
		ShopItem@ s = addShopItem(this, "Wood", "$mat_wood$", "mat_wood", Descriptions::wood, true);//"It's used for building bridges, shops, and more."
		AddRequirement(s.requirements, "coin", "", "Coins", 50);
	}
	{
		ShopItem@ s = addShopItem(this, "Stone", "$mat_stone$", "mat_stone", Descriptions::stone, true);//"It's used for building defence, trap, and more."
		AddRequirement(s.requirements, "coin", "", "Coins", 100);
	}
	{
		ShopItem@ s = addShopItem(this, "Gold", "$mat_gold$", "mat_gold", "Raw gold material.", true);//"It's used for building advance shops."
		AddRequirement(s.requirements, "coin", "", "Coins", 500);
	}
	{
		ShopItem@ s = addShopItem(this, "Lantern", "$lantern$", "lantern", Descriptions::lantern, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::lantern_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Bucket", "$_buildershop_filled_bucket$", "filled_bucket", Descriptions::filled_bucket, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::bucket_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Sponge", "$sponge$", "sponge", Descriptions::sponge, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::sponge);
	}
	{
		ShopItem@ s = addShopItem(this, "Boulder", "$boulder$", "boulder", Descriptions::boulder, false);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::boulder_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Trampoline", "$trampoline$", "trampoline", Descriptions::trampoline, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::trampoline_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Drill", "$drill$", "drill", Descriptions::drill + "\n\nRock Thrower can use this too.", false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::drill_stone);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::drill);
	}
	{
		ShopItem@ s = addShopItem(this, "Saw", "$saw$", "saw", Descriptions::saw, false);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::saw_wood);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::saw_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate (wood)", "$crate$", "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::crate_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate (coins)", "$crate$", "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::crate);
	}
	{
		ShopItem@ s = addShopItem(this, "Med Kit", "$mat_medkits$", "mat_medkits", "Med kit for Medic. Can be used 10 times.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 20);
	}
	{
		ShopItem@ s = addShopItem(this, "Water in a Jar", "$mat_waterjar$", "mat_waterjar", "Water for Medic Spray.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 30);
	}
	{
		ShopItem@ s = addShopItem(this, "Poison in a Jar", "$mat_poisonjar$", "mat_poisonjar", "Poison for Medic Spray.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 40);
	}
	{
		ShopItem@ s = addShopItem(this, "Acid in a Jar", "$mat_acidjar$", "mat_acidjar", "Acid for Medic Spray.\nCan damage blocks and enemies.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", 50);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;
	this.set_Vec2f("shop offset", Vec2f(6, 0));
	this.set_bool("shop available", this.isOverlapping(caller));
}

// fill bucket on collision
void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		if (blob.getName() == "bucket")
		{
			blob.set_u8("filled", 3);
			blob.set_u8("water_delay", 30);
			blob.getSprite().SetAnimation("full");
		}
		else
		{
			CBlob@ b = blob.getCarriedBlob();
			if (b !is null)
			{
				if (b.getName() == "bucket")
				{
					b.set_u8("filled", 3);
					b.set_u8("water_delay", 30);
					b.getSprite().SetAnimation("full");
				}
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item"))
	{
		this.getSprite().PlaySound("/ChaChing.ogg");

		if (!getNet().isServer()) return; /////////////////////// server only past here

		u16 caller, item;
		if (!params.saferead_netid(caller) || !params.saferead_netid(item))
		{
			return;
		}
		string name = params.read_string();
		{
			CBlob@ callerBlob = getBlobByNetworkID(caller);
			if (callerBlob is null)
			{
				return;
			}

			if (name == "filled_bucket")
			{
				CBlob@ b = server_CreateBlobNoInit("bucket");
				b.setPosition(callerBlob.getPosition());
				b.server_setTeamNum(callerBlob.getTeamNum());
				b.Tag("_start_filled");
				b.Init();
				callerBlob.server_Pickup(b);
			}
		}
	}
}
