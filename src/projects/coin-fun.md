---
layout: project
title: Coin.fun
excerpt: The Community-Owned Memecoin Printer
---

Coin.fun was 021's take on a memecoin launcher. In the true spirit of Web3, we
wanted to make it community-owned. All transaction fees would be injected back
into the community.

The mascot and brand was designed by the talented Leonor Meirelles. User interface by yours truly.

<figure>
  <img alt="" src="/coin-fun/home.png" />
  <figcaption>Zoom in! It's hard to see in the preview but we had a very cool scanline effect going on.</figcaption>
</figure>

One of our goals was making launching coins faster than on Pump.fun. I think
we did a pretty good job:

<video controls src="/coin-fun/launch.webm" /></video>

People could trade using their own wallets, but we allowed people to sign up
with email, making placing trades frictionless:

<video controls src="/coin-fun/video.webm" /></video>

We had a questing system and daily spinner built, leveraging `pg_cron` for
kicking off tweet indexing jobs. The questing system allowed us to write
arbitrary quest completion and validation logic.

![Coin.fun Quests Page](/coin-fun/tweets.png)

I also liked the 404 page. We made a lot of memes for this project.

![Coin.fun 404 Page](/coin-fun/404.png)
