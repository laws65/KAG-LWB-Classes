#define SERVER_ONLY

#include "CratePickupCommon.as"

void onInit(CBlob@ this)
{
	this.getCurrentScript().removeIfTag = "dead";
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null || blob.getShape().vellen > 1.0f)
	{
		return;
	}

	string blobName = blob.getName();

	if (blobName == "mat_spears")
	{
		u32 spears_count = this.getBlobCount("mat_spears");
		u32 blob_quantity = blob.getQuantity();
		if (spears_count + blob_quantity <= 20)
		{
			this.server_PutInInventory(blob);
		}
		else if (spears_count < 20) //merge into current arrow stacks
		{
			this.getSprite().PlaySound("/PutInInventory.ogg");

			u32 pickup_amount = Maths::Min(blob_quantity, 20 - spears_count);
			if (blob_quantity - pickup_amount > 0)
				blob.server_SetQuantity(blob_quantity - pickup_amount);
			else
				blob.server_Die();

			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount() && pickup_amount > 0; i++)
			{
				CBlob@ spears = inv.getItem(i);
				if (spears !is null && spears.getName() == blobName)
				{
					u32 spear_amount = spears.getQuantity();
					u32 spear_maximum = spears.getMaxQuantity();
					if (spear_amount + pickup_amount < spear_maximum)
					{
						spears.server_SetQuantity(spear_amount + pickup_amount);
					}
					else
					{
						pickup_amount -= spear_maximum - spear_amount;
						spears.server_SetQuantity(spear_maximum);
					}
				}
			}
		}
	}
	if (blobName == "mat_firespears" || blobName == "mat_poisonspears")
	{
		if (this.server_PutInInventory(blob))
		{
			return;
		}
	}

	CBlob@ carryblob = this.getCarriedBlob();
	if (carryblob !is null && carryblob.getName() == "crate")
	{
		if (crateTake(carryblob, blob))
		{
			return;
		}
	}
}
