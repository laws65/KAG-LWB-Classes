// Workbench
// added new items and water source.

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"

void onInit(CBlob@ this)
{
	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	this.Tag("can settle"); //for DieOnCollapse to prevent 2 second life :)

	InitWorkshop(this);
}


void InitWorkshop(CBlob@ this)
{
	InitCosts(); //read from cfg
	
	AddIconToken("$_buildershop_filled_bucket$", "Bucket.png", Vec2f(16, 16), 1);

	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(5, 5));

	{
		ShopItem@ s = addShopItem(this, "Lantern", "$lantern$", "lantern", Descriptions::lantern, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::lantern_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Bucket", "$_buildershop_filled_bucket$", "filled_bucket", Descriptions::filled_bucket, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::bucket_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Sponge", "$sponge$", "sponge", Descriptions::sponge, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::sponge_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Trampoline", "$trampoline$", "trampoline", Descriptions::trampoline, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::trampoline_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate", "$crate$", "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::crate_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Drill", "$drill$", "drill", Descriptions::drill, false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", WARCosts::drill_stone);
		AddRequirement(s.requirements, "tech", "drill", "Drill Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Saw", "$saw$", "saw", Descriptions::saw, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::saw_wood);
		AddRequirement(s.requirements, "tech", "saw", "Saw Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Dinghy", "$dinghy$", "dinghy", Descriptions::dinghy, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::dinghy_wood);
		AddRequirement(s.requirements, "tech", "dinghy", "Dinghy Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Boulder", "$boulder$", "boulder", Descriptions::boulder, false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", WARCosts::boulder_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Mounted Bow", "$mounted_bow$", "mounted_bow", Descriptions::mounted_bow, false, true);
		s.crate_icon = 6;
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 100);
		AddRequirement(s.requirements, "tech", "mounted_bow", "Camping Technology");
	}
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
	bool isServer = getNet().isServer();

	if (cmd == this.getCommandID("shop buy"))
	{
		// is this need?
		/*u16 callerID;
		if (!params.saferead_u16(callerID))
			return;
		bool spawnToInventory = params.read_bool();
		bool spawnInCrate = params.read_bool();
		bool producing = params.read_bool();
		string blobName = params.read_string();
		u8 s_index = params.read_u8();*/

		// check spam
		//if (blobName != "factory" && isSpammed( blobName, this.getPosition(), 12 ))
		//{
		//}
		//else
		{
			this.getSprite().PlaySound("/ConstructShort");
		}

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

//sprite - planks layer

void onInit(CSprite@ this)
{
	this.SetZ(50); //foreground

	CBlob@ blob = this.getBlob();
	CSpriteLayer@ planks = this.addSpriteLayer("planks", this.getFilename() , 16, 16, blob.getTeamNum(), blob.getSkinNum());

	if (planks !is null)
	{
		Animation@ anim = planks.addAnimation("default", 0, false);
		anim.AddFrame(6);
		planks.SetOffset(Vec2f(3.0f, -7.0f));
		planks.SetRelativeZ(-100);
	}
}
