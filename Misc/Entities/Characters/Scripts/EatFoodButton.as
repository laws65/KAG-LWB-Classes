#include "KnockedCommon.as"
#include "EatCommon.as";
// now everyone can use medkit, but low effective.

void onInit(CBlob@ this)
{
	this.set_s32("healTimer", getGameTime());
	this.getCurrentScript().removeIfTag = "dead";
	this.addCommandID("healSound");
}

void onTick(CBlob@ this)
{
	if (
		getNet().isServer() &&
		this.isKeyJustPressed(key_eat) &&
		!isKnocked(this) &&
		this.getHealth() < this.getInitialHealth()
	) {
		CBlob @carried = this.getCarriedBlob();
		if (carried !is null && (canEat(carried) || (carried.getName() == "mat_medkits"))) // consume what is held
		{
			if (canEat(carried))
			{
				Heal(this, carried);
			}
			else if(this.getBlobCount("mat_medkits") >= 2)
			{
				if((this.get_s32("healTimer") + 90) <= getGameTime())// 3sec cooldown
				{
					this.TakeBlob("mat_medkits", 2);
					this.server_Heal(0.5f);
					this.set_s32("healTimer", getGameTime());
					this.SendCommand(this.getCommandID("healSound"));
				}
			}
		}
		else // search in inventory
		{
			CInventory@ inv = this.getInventory();

			// build list of all eatables
			CBlob@[] eatables;
			for (int i = 0; i < inv.getItemsCount(); i++)
			{
				CBlob @blob = inv.getItem(i);
				if (canEat(blob))
				{
					eatables.insertLast(blob);
				}
			}

			if (eatables.length() == 0) // nothing to eat
			{
				return;
			}

			// find the most appropriate food to eat
			CBlob@ bestFood;
			u8 bestHeal = 0;
			for (int i = 0; i < eatables.length(); i++)
			{
				CBlob@ food = eatables[i];
				u8 heal = getHealingAmount(food);
				int missingHealth = int(Maths::Ceil(this.getInitialHealth() - this.getHealth()) * 4);

				if (heal < missingHealth && (bestFood is null || bestHeal < heal ) )
				{
					@bestFood = food;
					bestHeal = heal;
				}
				else if (heal >= missingHealth && (bestFood is null || bestHeal < missingHealth || bestHeal > heal))
				{
					@bestFood = food;
					bestHeal = heal;
				}
			}

			Heal(this, bestFood);
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("healSound"))
	{
		Sound::Play("/Heart.ogg", this.getPosition());
	}
}