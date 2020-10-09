
#include "MusketmanCommon.as";
#include "PlacementCommon.as";
#include "Help.as";
#include "BuildBlock.as"
#include "Requirements.as"
#include "KnockedCommon.as";

const Vec2f MENU_SIZE(2, 2);

void onInit(CInventory@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	if (!blob.exists("blocks"))
	{
		BuildBlock[][] blocks;
		BuildBlock[] page_0;
		blocks.push_back(page_0);
		{
			BuildBlock b(0, "barricade", "$barricade$", "Barricade");
			AddRequirement(b.reqs, "blob", "mat_barricades", "Frame");
			blocks[0].push_back(b);
		}
		blob.set("blocks", blocks);
	}

	if (!blob.exists("inventory offset"))
	{
		blob.set_Vec2f("inventory offset", Vec2f(0, 174));
	}

	blob.set_Vec2f("backpack position", Vec2f_zero);

	blob.set_u8("build page", 0);// for other scripts, no changing situation

	blob.set_u8("buildblob", 255);

	blob.set_u32("cant build time", 0);
	blob.set_u32("show build time", 0);

	blob.addCommandID("barricade");
	blob.addCommandID("stop_building");

	const string texName = "Entities/Characters/Rockthorwer/MusketmanIcons.png";
	AddIconToken("$MusketmanNothing$", texName, Vec2f(16, 32), 1);
	AddIconToken("$MusketmanBarricade$", texName, Vec2f(16, 32), 2);

	this.getCurrentScript().removeIfTag = "dead";
}

void onCreateInventoryMenu(CInventory@ this, CBlob@ forBlob, CGridMenu@ gridmenu)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);// yes as same as knight and archer

	CGridMenu@ menu = CreateGridMenu(pos, blob, MENU_SIZE, "Build Barricade");


	MusketmanInfo@ rter;
	if (!blob.get("musketmanInfo", @rter))
	{
		return;
	}

	if (menu !is null)
	{
		menu.deleteAfterClick = false;
		{
			CGridButton @button = menu.AddButton("$MusketmanNothing$", "Stop Building", blob.getCommandID("stop_building"));
			if (button !is null)
			{
				button.selectOneOnClick = true;
			}
		}
		{
			CGridButton @button = menu.AddButton("$MusketmanBarricade$", "Build Barricade", blob.getCommandID("barricade"));
			if (button !is null)
			{
				BuildBlock[][]@ blocks;
				if (blob.get("blocks", @blocks))
				{
					CBlob@ carryBlob = blob.getCarriedBlob();
					if (carryBlob !is null)
					{
						// check if this isn't what we wanted to create
						if (carryBlob.getName() == blocks[0][0].name)
						{
							button.SetSelected(1);
						}
					}
				}
				button.selectOneOnClick = true;
			}
		}
	}
}

void onCommand(CInventory@ this, u8 cmd, CBitStream@ params)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	BuildBlock[][]@ blocks;
	if (!blob.get("blocks", @blocks)) return;

	if (cmd == blob.getCommandID("stop_building"))
	{
		ClearCarriedBlock(blob);
	}
	else if (cmd == blob.getCommandID("barricade"))
	{
		ClearCarriedBlock(blob);
		processingTempBlob(blob, @blocks[0], 0);
	}
	else if (cmd == blob.getCommandID("cycle"))  //from standardcontrols
	{
		bool isBuilding = false;
		CBlob@ carryBlob = blob.getCarriedBlob();
		if (carryBlob !is null)
		{
			// check if this isn't what we wanted to create
			if (carryBlob.hasTag("temp blob"))
			{
				isBuilding = true;
			}
		}

		ClearCarriedBlock(blob);
		
		if(!isBuilding)
			processingTempBlob(blob, @blocks[0], 0);

		if (blob.isMyPlayer())
		{
			Sound::Play("/CycleInventory.ogg");
		}
	}
	/*CBlob@ carryBlob = blob.getCarriedBlob();
	if (carryBlob !is null)
	{
		// check if this isn't what we wanted to create
		if (carryBlob.hasTag("temp blob"))
		{
			printf("It's temp blob");
		}
		else
		{
			printf("It's not temp blob");
		}
	}*/
}

void processingTempBlob(CBlob@ blob, BuildBlock[]@ blocks, uint i)
{
	BuildBlock@ block = @blocks[i];

	bool canBuildBlock = canBuild(blob, @blocks, i) && !isKnocked(blob);
	if (!canBuildBlock)
	{
		if (blob.isMyPlayer())
		{
			blob.getSprite().PlaySound("/NoAmmo", 0.5);
		}

		return;
	}

	// put carried in inventory thing first
	
	if (getNet().isServer())
	{
		CBlob@ carryBlob = blob.getCarriedBlob();
		if (carryBlob !is null)
		{
			// check if this isn't what we wanted to create
			if (carryBlob.getName() == block.name)
			{
				return;
			}

			if (carryBlob.hasTag("temp blob"))
			{
				carryBlob.Untag("temp blob");
				carryBlob.server_Die();
			}
			else
			{
				// try put into inventory whatever was in hands
				// creates infinite mats duplicating if used on build block, not great :/
				if (!block.buildOnGround && !blob.server_PutInInventory(carryBlob))
				{
					carryBlob.server_DetachFromAll();
				}
			}
		}
		if (blob.isMyPlayer())
		{
			SetHelp(blob, "help self action", "musketman", getTranslatedString("$Build$Build/Place  $LMB$"), "", 3);
		}
	}
	
	server_BuildBlob(blob, @blocks, i);
}