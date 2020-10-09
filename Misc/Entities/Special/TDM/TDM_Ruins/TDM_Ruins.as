// TDM Ruins logic
// added new classes.
#include "ClassSelectMenu.as"
#include "StandardRespawnCommand.as"
#include "StandardControlsCommon.as"
#include "RespawnCommandCommon.as"
#include "GenericButtonCommon.as"

void onInit(CBlob@ this)
{
	this.CreateRespawnPoint("ruins", Vec2f(0.0f, 16.0f));
	AddIconToken("$knight_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 12);
	AddIconToken("$archer_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 16);
	AddIconToken("$rockthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 0);
	AddIconToken("$medic_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 1);
	AddIconToken("$spearman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 2);
	AddIconToken("$assassin_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 3);
	AddIconToken("$crossbowman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 4);
	AddIconToken("$musketman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 5);
	AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);
	//TDM classes
	addPlayerClass(this, "Rock Thrower", "$rockthrower_class_icon$", "rockthrower", "Basic Tactics.");
	addPlayerClass(this, "Medic", "$medic_class_icon$", "medic", "Medicine of War.");
	addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", "Hack and Slash.");
	addPlayerClass(this, "Spearman", "$spearman_class_icon$", "spearman", "Omnipotent Weapon.");
	addPlayerClass(this, "Assassin", "$assassin_class_icon$", "assassin", "Nothing can Escape.");
	addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", "The Ranged Advantage.");
	addPlayerClass(this, "Crossbowman", "$crossbowman_class_icon$", "crossbowman", "Heavy Mechanical Weapon.");
	addPlayerClass(this, "Musketman", "$musketman_class_icon$", "musketman", "New Era of War.");
	this.getShape().SetStatic(true);
	this.getShape().getConsts().mapCollisions = false;
	this.addCommandID("class menu");
	this.Tag("all_classes_loaded");

	this.Tag("change class drop inventory");

	this.getSprite().SetZ(-50.0f);   // push to background
}

void onTick(CBlob@ this)
{
	if (enable_quickswap)
	{
		//quick switch class
		CBlob@ blob = getLocalPlayerBlob();
		if (blob !is null && blob.isMyPlayer())
		{
			if (
				isInRadius(this, blob) && //blob close enough to ruins
				blob.isKeyJustReleased(key_use) && //just released e
				isTap(blob, 7) && //tapped e
				blob.getTickSinceCreated() > 1 //prevents infinite loop of swapping class
			) {
				CycleClass(this, blob);
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("class menu"))
	{
		u16 callerID = params.read_u16();
		CBlob@ caller = getBlobByNetworkID(callerID);

		if (caller !is null && caller.isMyPlayer())
		{
			BuildRespawnMenuFor(this, caller);
		}
	}
	else
	{
		onRespawnCommand(this, cmd, params);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (canChangeClass(this, caller))
	{
		if (isInRadius(this, caller))
		{
			BuildRespawnMenuFor(this, caller);
		}
		else
		{
			CBitStream params;
			params.write_u16(caller.getNetworkID());
			caller.CreateGenericButton("$change_class$", Vec2f(0, 6), this, this.getCommandID("class menu"), getTranslatedString("Change class"), params);
		}
	}

	// warning: if we don't have this button just spawn menu here we run into that infinite menus game freeze bug
}

bool isInRadius(CBlob@ this, CBlob @caller)
{
	return (this.getPosition() - caller.getPosition()).Length() < this.getRadius();
}
