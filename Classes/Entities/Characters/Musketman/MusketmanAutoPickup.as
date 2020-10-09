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

	if (blobName == "mat_bullets")
	{
		u32 bullets_count = this.getBlobCount("mat_bullets");
		u32 blob_quantity = blob.getQuantity();
		if (bullets_count + blob_quantity <= 60)
		{
			this.server_PutInInventory(blob);
		}
		else if (bullets_count < 60) //merge into current bullet stacks
		{
			this.getSprite().PlaySound("/PutInInventory.ogg");

			u32 pickup_amount = Maths::Min(blob_quantity, 60 - bullets_count);
			if (blob_quantity - pickup_amount > 0)
				blob.server_SetQuantity(blob_quantity - pickup_amount);
			else
				blob.server_Die();

			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount() && pickup_amount > 0; i++)
			{
				CBlob@ bullets = inv.getItem(i);
				if (bullets !is null && bullets.getName() == blobName)
				{
					u32 bullet_amount = bullets.getQuantity();
					u32 bullet_maximum = bullets.getMaxQuantity();
					if (bullet_amount + pickup_amount < bullet_maximum)
					{
						bullets.server_SetQuantity(bullet_amount + pickup_amount);
					}
					else
					{
						pickup_amount -= bullet_maximum - bullet_amount;
						bullets.server_SetQuantity(bullet_maximum);
					}
				}
			}
		}
	}
	if (blobName == "mat_barricades")
	{
		if (this.server_PutInInventory(blob))
		{
			return;
		}
	}

	CBlob@ carryblob = this.getCarriedBlob(); // For crate detection
	if (carryblob !is null && carryblob.getName() == "crate")
	{
		if (crateTake(carryblob, blob))
		{
			return;
		}
	}
}
