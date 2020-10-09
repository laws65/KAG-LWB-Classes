//Assassin Include
const f32 assassin_grapple_length = 72.0f;
const f32 assassin_grapple_slack = 16.0f;
const f32 assassin_grapple_throw_speed = 20.0f;

const f32 assassin_grapple_force = 2.0f;
const f32 assassin_grapple_accel_limit = 1.5f;
const f32 assassin_grapple_stiffness = 0.1f;

shared class AssassinInfo
{
	//u8 stab_delay;
	u8 tileDestructionLimiter;
	//bool dontHitMore;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	bool use_left;
	AssassinInfo()
	{
		//stab_delay = 0;
		tileDestructionLimiter = 0;
		grappling = false;
		use_left = false;
	}
};

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	AssassinInfo@ assa;
	if (!this.get("assassinInfo", @assa)) { return; }

	CBitStream bt;
	bt.write_bool(assa.grappling);

	if (assa.grappling)
	{
		bt.write_u16(assa.grapple_id);
		bt.write_u8(u8(assa.grapple_ratio * 250));
		bt.write_Vec2f(assa.grapple_pos);
		bt.write_Vec2f(assa.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	AssassinInfo@ assa;
	if (!this.get("assassinInfo", @assa)) { return; }

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
		assa.grappling = grappling;
		if (assa.grappling)
		{
			assa.grapple_id = grapple_id;
			assa.grapple_ratio = grapple_ratio;
			assa.grapple_pos = grapple_pos;
			assa.grapple_vel = grapple_vel;
		}
	}
}

bool isKnifeAnim(CSprite@ this)
{
	return this.isAnimation("stab_up") ||
	this.isAnimation("stab_up_left") ||
	this.isAnimation("stab_mid") ||
	this.isAnimation("stab_mid_left") ||
	this.isAnimation("stab_down") ||
	this.isAnimation("stab_down_left");
}