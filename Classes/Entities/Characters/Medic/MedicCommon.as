//Medic Include


//TODO: move vars into archer params namespace
const f32 medic_grapple_length = 72.0f;
const f32 medic_grapple_slack = 16.0f;
const f32 medic_grapple_throw_speed = 20.0f;

const f32 medic_grapple_force = 2.0f;
const f32 medic_grapple_accel_limit = 1.5f;
const f32 medic_grapple_stiffness = 0.1f;
//preparation
const u8 healPrep = 60;
const u8 sprayPrep = 60;

namespace SprayType
{
	enum type
	{
		water = 0,
		poison,
		acid,
		count
	};
}

shared class MedicInfo
{
	//u8 jar_type; in MedicLogic.as, likes Knight bombs

	u16 healTimer;
	u16 sprayTimer;

	u8 sprayType;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	MedicInfo()
	{
		healTimer = 0;
		sprayTimer = 0;
		grappling = false;
		sprayType = SprayType::count;//hack
	}
};

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	MedicInfo@ medic;
	if (!this.get("medicInfo", @medic)) { return; }

	CBitStream bt;
	bt.write_bool(medic.grappling);

	if (medic.grappling)
	{
		bt.write_u16(medic.grapple_id);
		bt.write_u8(u8(medic.grapple_ratio * 250));
		bt.write_Vec2f(medic.grapple_pos);
		bt.write_Vec2f(medic.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	MedicInfo@ medic;
	if (!this.get("medicInfo", @medic)) { return; }

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	grappling = bt.read_bool();

	if (grappling)
	{
		grapple_id = bt.read_u16();
		u8 temp = bt.read_u8();
		grapple_ratio = temp / 250.0f;
		grapple_pos = bt.read_Vec2f();
		grapple_vel = bt.read_Vec2f();
	}

	if (apply)
	{
		medic.grappling = grappling;
		if (medic.grappling)
		{
			medic.grapple_id = grapple_id;
			medic.grapple_ratio = grapple_ratio;
			medic.grapple_pos = grapple_pos;
			medic.grapple_vel = grapple_vel;
		}
	}
}

const string[] sprayTypeNames = { "mat_waterjar",
                                  "mat_poisonjar",
                                  "mat_acidjar"
                                };

const string[] sprayNames = { "Water spray",
                              "Poison spray",
                              "Acid spray"
                            };

const string[] sprayIcons = { "$WaterJar$",
                              "$PoisonJar$",
                              "$AcidJar$"
                            };