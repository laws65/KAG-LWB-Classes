// Draw a flame sprite layer

#include "PoisonParticle.as";
#include "PoisonCommon.as";

void onInit(CSprite@ this)
{
	//init flame layer
	CSpriteLayer@ poison = this.addSpriteLayer("poison_animation", "Poisoned.png", 16, 16, -1, -1);

	if (poison !is null)
	{
		/*
		{
			Animation@ anim = fire.addAnimation("bigfire", 3, true);
			anim.AddFrame(1);
			anim.AddFrame(2);
			anim.AddFrame(3);
		}
		*/
		{
			Animation@ anim = poison.addAnimation("smallpoison", 12, true);
			anim.AddFrame(0);
			anim.AddFrame(1);
			anim.AddFrame(2);
		}
		poison.SetVisible(false);
		poison.SetRelativeZ(10);
	}
	this.getCurrentScript().tickFrequency = 24;
}

void onTick(CSprite@ this)
{
	this.getCurrentScript().tickFrequency = 24; // opt
	CBlob@ blob = this.getBlob();
	CSpriteLayer@ poison = this.getSpriteLayer("poison_animation");
	if (poison !is null)
	{
		//if we're burning
		if (blob.hasTag(poisoning_tag))
		{
			this.getCurrentScript().tickFrequency = 12;

			poison.SetVisible(true);

			//TODO: draw the fire layer with varying sizes based on var - may need sync spam :/
			//fire.SetAnimation( "bigfire" );
			poison.SetAnimation("smallpoison");

			/*
			//set the "on fire" animation if it exists (eg wave arms around)
			if (this.getAnimation("on_fire") !is null)
			{
				this.SetAnimation("on_fire");
			}
			*/
		}
		else
		{
			if (poison.isVisible() && !blob.hasTag("dead"))
			{
				this.PlaySound("/Gurgle1.ogg");
			}
			poison.SetVisible(false);
		}
	}
}
