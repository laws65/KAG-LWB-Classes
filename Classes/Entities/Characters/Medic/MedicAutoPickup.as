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

	if (blobName == "mat_medkits")// likes archer arrow
	{
		u32 kits_count = this.getBlobCount("mat_medkits");
		u32 blob_quantity = blob.getQuantity();
		if (kits_count + blob_quantity <= 20)
		{
			this.server_PutInInventory(blob);
		}
		else if (kits_count < 20) //merge into current kit stacks
		{
			this.getSprite().PlaySound("/PutInInventory.ogg");

			u32 pickup_amount = Maths::Min(blob_quantity, 20 - kits_count);
			if (blob_quantity - pickup_amount > 0)
				blob.server_SetQuantity(blob_quantity - pickup_amount);
			else
				blob.server_Die();

			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount() && pickup_amount > 0; i++)
			{
				CBlob@ kits = inv.getItem(i);
				if (kits !is null && kits.getName() == blobName)
				{
					u32 kit_amount = kits.getQuantity();
					u32 kit_maximum = kits.getMaxQuantity();
					if (kit_amount + pickup_amount < kit_maximum)
					{
						kits.server_SetQuantity(kit_amount + pickup_amount);
					}
					else
					{
						pickup_amount -= kit_maximum - kit_amount;
						kits.server_SetQuantity(kit_maximum);
					}
				}
			}
		}
	}
	if (blobName == "mat_waterjar" || (blobName == "mat_poisonjar") || blobName == "mat_acidjar")
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
