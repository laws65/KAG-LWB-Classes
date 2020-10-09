//spawning a generic fire particle

void makePoisonParticle(Vec2f pos, int bigBubble = 0)
{
	string texture;

	switch (XORRandom(XORRandom(bigBubble) == 0 ? 4 : 2))
	{
		case 0: texture = "PoisonSmallBubble1.png"; break;

		case 1: texture = "PoisonSmallBubble2.png"; break;

		case 2:
		case 3: texture = "PoisonBubble.png"; break;
	}

	ParticleAnimated(texture, pos, Vec2f(0, 0), 0.0f, 1.0f, 10, -0.01, true);
}