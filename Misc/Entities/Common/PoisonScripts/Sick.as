// low moving speed while poisoned
#include "PoisonCommon.as";
#include "RunnerCommon.as";

void onInit(CMovement@ this)
{
	this.getCurrentScript().tickIfTag = poisoning_tag;
	this.getCurrentScript().removeIfTag = "dead";
}

void onTick(CBlob@ this)
{
	if(this.hasTag(poisoning_tag))
	{
		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor *= 0.5f;
			moveVars.jumpFactor *= 0.5f;
		}
	}
}