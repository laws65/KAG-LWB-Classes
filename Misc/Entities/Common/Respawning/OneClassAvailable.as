// OneClassAvailable.as

#include "StandardRespawnCommand.as";
#include "GenericButtonCommon.as";

const string req_class = "required class";

void onInit(CBlob@ this)
{
	this.Tag("change class drop inventory");
	if (!this.exists("class offset"))
		this.set_Vec2f("class offset", Vec2f_zero);

	if (!this.exists("class button radius"))
	{
		CShape@ shape = this.getShape();
		if (shape !is null)
		{
			this.set_u8("class button radius", Maths::Max(this.getRadius(), (shape.getWidth() + shape.getHeight()) / 2));
		}
		else
		{
			this.set_u8("class button radius", 16);
		}
	}

	AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);

	if(this.getName() == "buildershop")
	{
		AddIconToken("$builder_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 8);
		AddIconToken("$rockthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 0);
		AddIconToken("$medic_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 1);
		addPlayerClass(this, "Builder", "$builder_class_icon$", "builder", "Build ALL the towers.");
		addPlayerClass(this, "Rock Thrower", "$rockthrower_class_icon$", "rockthrower", "Basic Tactics.");
		addPlayerClass(this, "Medic", "$medic_class_icon$", "medic", "Medicine of War.");
	}
	else if(this.getName() == "knightshop")
	{
		AddIconToken("$knight_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 12);
		AddIconToken("$spearman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 2);
		AddIconToken("$assassin_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 3);
		addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", "Hack and Slash.");
		addPlayerClass(this, "Spearman", "$spearman_class_icon$", "spearman", "Omnipotent Weapon.");
		addPlayerClass(this, "Assassin", "$assassin_class_icon$", "assassin", "Nothing can Escape.");
	}
	else if(this.getName() == "archershop")
	{
		AddIconToken("$archer_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 16);
		AddIconToken("$crossbowman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 4);
		AddIconToken("$musketman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 5);
		addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", "The Ranged Advantage.");
		addPlayerClass(this, "Crossbowman", "$crossbowman_class_icon$", "crossbowman", "Heavy Mechanical Weapon.");
		addPlayerClass(this, "Musketman", "$musketman_class_icon$", "musketman", "New Era of War.");
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller) || (!this.exists(req_class) && !isGenuineShop(this))) return;

	string cfg = this.get_string(req_class);
	if (canChangeClass(this, caller) && isGenuineShop(this))
	{
		CBitStream params;
		write_classchange(params, caller.getNetworkID(), cfg);

		CButton@ button = caller.CreateGenericButton(
		"$change_class$",                           // icon token
		this.get_Vec2f("class offset"),             // button offset
		this,                                       // button attachment
		SpawnCmd::buildMenu,                      // command id
		getTranslatedString("Swap Class"),                               // description
		params);                                    // bit stream

		button.enableRadius = this.get_u8("class button radius");
	}
	else if (canChangeClass(this, caller) && caller.getName() != cfg)// default, if this is other mod shop...
	{
		CBitStream params;
		write_classchange(params, caller.getNetworkID(), cfg);

		CButton@ button = caller.CreateGenericButton(
		"$change_class$",                           // icon token
		this.get_Vec2f("class offset"),             // button offset
		this,                                       // button attachment
		SpawnCmd::changeClass,                      // command id
		getTranslatedString("Swap Class"),                               // description
		params);                                    // bit stream

		button.enableRadius = this.get_u8("class button radius");
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);
}

bool isGenuineShop(CBlob@ this)
{
	string name = this.getName();
	return name == "buildershop" || name == "knightshop" || name == "archershop"; 
}