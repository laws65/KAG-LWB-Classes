// Archer animations
#include "RunnerTextures.as"

void onInit(CSprite@ this)
{
	LoadSprites(this);
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	CPlayer@ player = blob.getPlayer();
	blob.set_string("clanFlag", "none");

	if(player !is null)
	{
		string clantag = player.getClantag();
		if(clantag == "[JP]" || clantag == "JP") blob.set_string("clanFlag", "JapaneseFlag.png");
		else
		{
			string playerName = player.getUsername();
			if(playerName == "kinokino7[Zipangu]" || playerName == "taroimop") blob.set_string("clanFlag", "JapaneseFlag.png");
			else return;
		}
	}
	else return;

	this.RemoveSpriteLayer("flag");
	CSpriteLayer@ flag = this.addSpriteLayer("flag", blob.get_string("clanFlag"), 32, 32);

	if (flag !is null)
	{
		Animation@ anim = flag.addAnimation("default", 0, false);
		anim.AddFrame(0);
		flag.SetOffset(Vec2f(0.0f, 0.0f));
		flag.SetRelativeZ(-0.5f);
	}
}

void onTick(CSprite@ this)
{

	CBlob@ blob = this.getBlob();
	if(blob.get_string("clanFlag") == "none") return;
	CSpriteLayer@ quiverLayer = this.getSpriteLayer("flag");

	if (quiverLayer !is null)
	{
		if (not this.isVisible()) {
			quiverLayer.SetVisible(false);
			return;
		}
		quiverLayer.SetVisible(true);

		bool down = (
			((blob.getName() == "archer" ||blob.getName() == "musketman" || blob.getName() == "assassin") && this.isAnimation("crouch")) || 
			this.isAnimation("dead"));
		quiverLayer.SetVisible(true);
		f32 quiverangle = down ? 90.0f : 0.0f;

		if (this.isFacingLeft())
		{
			quiverangle *= -1.0f;
		}

		//face the same way (force)
		quiverLayer.SetIgnoreParentFacing(true);
		quiverLayer.SetFacingLeft(this.isFacingLeft());

		int layer = 0;
		Vec2f head_offset = getHeadOffset(blob, -1, layer);

		bool easy = false;
		Vec2f off;
		if (layer != 0)
		{
			easy = true;
			off.Set(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
			off += this.getOffset();
			off += Vec2f(-head_offset.x, head_offset.y);


			f32 y = (down ? 0.0f : -3.0f);
			f32 x = (down ? -2.0f : 5.0f);
			off += Vec2f(x, y);
		}

		if (easy)
		{
			quiverLayer.SetOffset(off);
		}

		quiverLayer.ResetTransform();
		quiverLayer.RotateBy(quiverangle, Vec2f(0.0f, 0.0f));
	}
}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	if(blob.get_string("clanFlag") == "none") return;
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle(blob.get_string("clanFlag"), pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(32, 32), 2.0f, 20, "/BodyGibFall", team);
}
