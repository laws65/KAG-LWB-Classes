// Spearman animations

#include "SpearmanCommon.as";
#include "FireParticle.as"
#include "PoisonParticle.as"
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"

const string shiny_layer = "shiny bit";

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
	int armour = PLAYER_ARMOUR_STANDARD;

	CPlayer@ p = this.getBlob().getPlayer();
	if (p !is null)
	{
		armour = p.getArmourSet();
		if (armour == PLAYER_ARMOUR_STANDARD)
		{
			Accolades@ acc = getPlayerAccolades(p.getUsername());
			if (acc.hasCape())
			{
				armour = PLAYER_ARMOUR_CAPE;
			}
		}
	}

	switch (armour)
	{
	case PLAYER_ARMOUR_STANDARD:
		ensureCorrectRunnerTexture(this, "spearman", "Spearman");
		break;
	case PLAYER_ARMOUR_CAPE:
		ensureCorrectRunnerTexture(this, "spearman_cape", "SpearmanCape");
		break;
	case PLAYER_ARMOUR_GOLD:
		ensureCorrectRunnerTexture(this, "spearman_gold", "SpearmanGold");
		break;
	}

	string texname = getRunnerTextureName(this);

	// add blade
	this.RemoveSpriteLayer("chop");
	CSpriteLayer@ chop = this.addTexturedSpriteLayer("chop", this.getTextureName(), 32, 32);

	if (chop !is null)
	{
		Animation@ anim = chop.addAnimation("default", 0, true);
		anim.AddFrame(35);
		anim.AddFrame(43);
		anim.AddFrame(63);
		chop.SetVisible(false);
		chop.SetRelativeZ(1000.0f);
	}

	// add shiny
	this.RemoveSpriteLayer(shiny_layer);
	CSpriteLayer@ shiny = this.addSpriteLayer(shiny_layer, "AnimeShiny.png", 16, 16);

	if (shiny !is null)
	{
		Animation@ anim = shiny.addAnimation("default", 2, true);
		int[] frames = {0, 1, 2, 3};
		anim.AddFrames(frames);
		shiny.SetVisible(false);
		shiny.SetRelativeZ(1.0f);
	}

	//quiver, likes archer
	this.RemoveSpriteLayer("quiver");
	CSpriteLayer@ quiver = this.addTexturedSpriteLayer("quiver", texname , 32, 8);

	if (quiver !is null)
	{
		Animation@ anim = quiver.addAnimation("default", 0, false);
		anim.AddFrame(33);
		quiver.SetOffset(Vec2f(0.0f, -2.0f));
		quiver.SetRelativeZ(-0.1f);
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f aimpos;

	SpearmanInfo@ sman;
	if (!blob.get("spearmanInfo", @sman))
	{
		return;
	}

	bool knocked = isKnocked(blob);

	bool spearState = isSpearState(sman.state);

	bool pressed_a1 = blob.isKeyPressed(key_action1);
	bool pressed_a2 = blob.isKeyPressed(key_action2);

	bool walking = (blob.isKeyPressed(key_left) || blob.isKeyPressed(key_right));

	aimpos = blob.getAimPos();
	bool inair = (!blob.isOnGround() && !blob.isOnLadder());

	Vec2f vel = blob.getVelocity();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.RemoveSpriteLayer(shiny_layer);
			this.SetAnimation("dead");
		}

		doEffectUpdate(this, blob, false, sman, false);

		Vec2f oldvel = blob.getOldVelocity();

		//TODO: trigger frame one the first time we server_Die()()
		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(1);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(3);
		}
		else
		{
			this.SetFrameIndex(2);
		}

		CSpriteLayer@ chop = this.getSpriteLayer("chop");

		if (chop !is null)
		{
			chop.SetVisible(false);
		}

		return;
	}

	// get the angle of aiming with mouse
	Vec2f vec;
	int direction = blob.getAimDirection(vec);

	// set facing
	bool facingLeft = this.isFacingLeft();
	// animations
	bool ended = this.isAnimationEnded();
	bool wantsChopLayer = false;
	s32 chopframe = 0;
	f32 chopAngle = 0.0f;

	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);

	bool shinydot = false;

	if (knocked)
	{
		if (inair)
		{
			this.SetAnimation("knocked_air");
		}
		else
		{
			this.SetAnimation("knocked");
		}
	}
	else if (blob.hasTag("seated"))
	{
		this.SetAnimation("crouch");
	}
	else if(sman.state == SpearmanStates::resheathing_throw)
	{
		this.SetAnimation("resheath_throw");
	}
	else if(sman.state == SpearmanStates::resheathing_cut || sman.state == SpearmanStates::resheathing_slash)
	{
		this.SetAnimation("draw_spear");
	}
	else if (sman.state == SpearmanStates::spear_drawn)
	{
		if (sman.spearTimer < SpearmanVars::slash_charge)
		{
			this.SetAnimation("draw_spear");
		}
		else if (sman.spearTimer < SpearmanVars::slash_charge_level2)
		{
			this.SetAnimation(sman.throwing ? "throw_ready" : "strike_power_ready");
			this.animation.frame = 0;
		}
		else if (sman.spearTimer < SpearmanVars::slash_charge_limit)
		{
			this.SetAnimation(sman.throwing ? "throw_ready" : "strike_power_ready");
			this.animation.frame = 1;
			shinydot = true;
		}
		else
		{
			this.SetAnimation("draw_spear");
		}
	}
	else if (sman.state == SpearmanStates::spear_cut_mid)
	{
		this.SetAnimation("strike_mid");
	}
	else if (sman.state == SpearmanStates::spear_cut_mid_down)
	{
		this.SetAnimation("strike_mid_down");
	}
	else if (sman.state == SpearmanStates::spear_cut_up)
	{
		this.SetAnimation("strike_up");
	}
	else if (sman.state == SpearmanStates::spear_cut_down)
	{
		this.SetAnimation("strike_down");
	}
	else if (sman.state == SpearmanStates::spear_power || sman.state == SpearmanStates::spear_power_super)
	{
		if((this.isAnimation("strike_mid") ||
			this.isAnimation("strike_mid_down") ||
			this.isAnimation("strike_up") ||
			this.isAnimation("strike_down"))
			 && sman.spearTimer != 0)
			this.SetAnimation(this.animation.name);// keep showing this animation
		else
		{
			if (direction == -1)
			{
				this.SetAnimation("strike_up");
			}
			else if (direction == 0)
			{
				if (aimpos.y < pos.y)
				{
					this.SetAnimation("strike_mid");
				}
				else
				{
					this.SetAnimation("strike_mid_down");
				}
			}
			else
			{
				this.SetAnimation("strike_down");
			}
		}

		if (sman.spearTimer <= 1)
			this.animation.SetFrameIndex(0);
		if (sman.spearTimer < 3)
			this.animation.timer = 0;

		u8 mintime = 6;
		u8 maxtime = 8;
		if (sman.spearTimer >= mintime && sman.spearTimer <= maxtime)
		{
			wantsChopLayer = true;
			chopframe = sman.spearTimer - mintime;
			chopAngle = -vec.Angle();
		}
	}
	else if (sman.state == SpearmanStates::spear_throw || sman.state == SpearmanStates::spear_throw_super)
	{
		this.SetAnimation("throw");

		if (sman.spearTimer <= 1)
			this.animation.SetFrameIndex(0);
	}
	else if (inair)
	{
		RunnerMoveVars@ moveVars;
		if (!blob.get("moveVars", @moveVars))
		{
			return;
		}
		f32 vy = vel.y;
		if (vy < -0.0f && moveVars.walljumped)
		{
			this.SetAnimation("run");
		}
		else
		{
			this.SetAnimation("fall");
			this.animation.timer = 0;

			if (vy < -1.5)
			{
				this.animation.frame = 0;
			}
			else if (vy > 1.5)
			{
				this.animation.frame = 2;
			}
			else
			{
				this.animation.frame = 1;
			}
		}
	}
	else if (walking ||
	         (blob.isOnLadder() && (blob.isKeyPressed(key_up) || blob.isKeyPressed(key_down))))
	{
		this.SetAnimation("run");
	}
	else
	{
		defaultIdleAnim(this, blob, direction);
	}

	CSpriteLayer@ chop = this.getSpriteLayer("chop");

	if (chop !is null)
	{
		chop.SetVisible(wantsChopLayer);
		if (wantsChopLayer)
		{
			f32 choplength = 10.0f;// double

			chop.animation.frame = chopframe;
			Vec2f offset = Vec2f(choplength, 0.0f);
			offset.RotateBy(chopAngle, Vec2f_zero);
			if (!this.isFacingLeft())
				offset.x *= -1.0f;
			offset.y += this.getOffset().y * 0.5f;

			chop.SetOffset(offset);
			chop.ResetTransform();
			if (this.isFacingLeft())
				chop.RotateBy(180.0f + chopAngle, Vec2f());
			else
				chop.RotateBy(chopAngle, Vec2f());
		}
	}

	doEffectUpdate(this, blob, hasAnySpears(blob), sman, shinydot);

	//set the head anim
	if (knocked)
	{
		blob.Tag("dead head");
	}
	else if (blob.isKeyPressed(key_action1) || blob.isKeyPressed(key_action2))
	{
		blob.Tag("attack head");
		blob.Untag("dead head");
	}
	else
	{
		blob.Untag("attack head");
		blob.Untag("dead head");
	}

}

void doEffectUpdate(CSprite@ this, CBlob@ blob, bool has_spears, SpearmanInfo@ sman, bool shinydot)
{
	CSpriteLayer@ quiverLayer = this.getSpriteLayer("quiver");

	if (quiverLayer !is null)
	{
		if (not this.isVisible()) {
			quiverLayer.SetVisible(false);
			return;
		}
		quiverLayer.SetVisible(true);
		f32 quiverangle = 45.0f;

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
		Vec2f quiverOff;
		if (layer != 0)
		{
			easy = true;
			off.Set(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
			off += this.getOffset();
			off += Vec2f(-head_offset.x, head_offset.y);

			quiverOff = off;
			quiverOff += Vec2f(3.0f, 3.0f);
		}

		if (easy)
		{
			quiverLayer.SetOffset(quiverOff);
		}

		quiverLayer.ResetTransform();
		quiverLayer.RotateBy(quiverangle, Vec2f(0.0f, 0.0f));

		if (has_spears)
		{
			quiverLayer.SetVisible(true);
		}
		else
		{
			quiverLayer.SetVisible(false);
		}

		Vec2f effectPos = blob.getPositionWithOffset(off);
		Vec2f posOff;
		bool noOffset = false;
		switch(this.getFrame())
		{
			case 0:
			case 2:
			case 4:
			posOff = Vec2f(-5.0f, -8.0f); break;
			case 1:
			posOff = Vec2f(-4.0f, -9.0f); break;
			case 3:
			posOff = Vec2f(-6.0f, -8.0f); break;
			case 5:
			posOff = Vec2f(-5.0f, -9.0f); break;
			case 6:
			posOff = Vec2f(-6.0f, -9.0f); break;
			case 7:
			posOff = Vec2f(-7.0f, -9.0f); break;
			case 8:
			posOff = Vec2f(9.0f, 9.0f); break;
			case 22:
			posOff = Vec2f(6.0f, -1.0f); break;
			case 23:
			posOff = Vec2f(7.0f, -7.0f); break;
			case 29:
			posOff = Vec2f(15.0f, 8.0f); break;
			case 30:
			posOff = Vec2f(9.0f, 7.0f); break;
			case 31:
			posOff = Vec2f(12.0f, 0.0f); break;
			case 36:
			posOff = Vec2f(0.0f, -5.0f); break;
			case 37:
			posOff = Vec2f(-3.0f, -8.0f); break;
			case 40:
			posOff = Vec2f(11.0f, 11.0f); break;
			case 41:
			posOff = Vec2f(9.0f, -2.0f); break;
			case 46:
			posOff = Vec2f(2.0f, 12.0f); break;
			case 47:
			posOff = Vec2f(1.0f, 13.0f); break;
			case 48:
			posOff = Vec2f(10.0f, 11.0f); break;
			case 53:
			posOff = Vec2f(7.0f, -10.0f); break;
			case 54:
			posOff = Vec2f(12.0f, 4.0f); break;
			case 55:
			posOff = Vec2f(8.0f, 12.0f); break;
			case 62:
			posOff = Vec2f(14.0f, 6.0f); break;
			default: noOffset = true;
		}
		if(noOffset) return;
		posOff.x += 0.5f;

		//set the shiny dot on the spear

		CSpriteLayer@ shiny = this.getSpriteLayer(shiny_layer);

		if (shiny !is null)
		{
			shiny.SetVisible(shinydot);
			if (shinydot)
			{
				Vec2f shinyOff = off + posOff;
				shinyOff.x *= -1;
				shinyOff.x += 4;
				shiny.RotateBy(10, Vec2f());
				shiny.SetOffset(shinyOff);
			}
		}

		if (this.isFacingLeft())
		{
			posOff.x *= -1.0f;
		}

		effectPos += posOff;

		if(sman.spear_type == SpearType::fire && getGameTime() % 6 == 0)
			makeFireParticle(effectPos, 4);
		if(sman.spear_type == SpearType::poison && getGameTime() % 12 == 0)
			makePoisonParticle(effectPos);

	}
}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("Entities/Characters/Spearman/SpearmanGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Spearman/SpearmanGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Spearman/SpearmanGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Spearman/SpearmanGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}


// render cursors

void DrawCursorAt(Vec2f position, string& in filename)
{
	position = getMap().getAlignedWorldPos(position);
	if (position == Vec2f_zero) return;
	position = getDriver().getScreenPosFromWorldPos(position - Vec2f(1, 1));
	GUI::DrawIcon(filename, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
}

const string cursorTexture = "Entities/Characters/Sprites/TileCursor.png";

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (!blob.isMyPlayer())
	{
		return;
	}
	if (getHUD().hasButtons())
	{
		return;
	}

	// draw tile cursor

	if (blob.isKeyPressed(key_action1))
	{
		CMap@ map = blob.getMap();
		Vec2f position = blob.getPosition();
		Vec2f cursor_position = blob.getAimPos();
		Vec2f surface_position;
		map.rayCastSolid(position, cursor_position, surface_position);
		Vec2f vector = surface_position - position;
		f32 distance = vector.getLength();
		Tile tile = map.getTile(surface_position);

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 20.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}
