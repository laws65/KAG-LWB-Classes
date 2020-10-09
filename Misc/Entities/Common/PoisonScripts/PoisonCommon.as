
#include "Hitters.as"

const string poison_duration = "poison duration";
const string poison_hitter = "poison hitter";

const string poison_timer = "poison timer";

const string poisoning_tag = "poisoned";

const int poison_wait_ticks = 4;

/**
 * Start this's fire and sync everything important
 */
void server_setPoisonOn(CBlob@ this)
{
	if (!getNet().isServer())
		return;
	this.Tag(poisoning_tag);
	this.Sync(poisoning_tag, true);

	this.set_s16(poison_timer, this.get_s16(poison_duration) / poison_wait_ticks);
	this.Sync(poison_timer, true);
}

/**
 * Put out this's fire and sync everything important
 */
void server_setPoisonOff(CBlob@ this)
{
	if (!getNet().isServer())
		return;
	this.Untag(poisoning_tag);
	this.Sync(poisoning_tag, true);

	this.set_s16(poison_timer, 0);
	this.Sync(poison_timer, true);
}

/**
 * Hitters that should start something burning when hit
 */
bool isPoisoningHitter(u8 hitter)
{
	return hitter == Hitters::poisoning;
}
