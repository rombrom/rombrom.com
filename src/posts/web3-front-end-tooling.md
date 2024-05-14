---
tags: ["post", "thread", "021.gg", "front end"]
layout: post
title: A Small Thread on Web3 Front End Tooling
excerpt: |
  Web3 front end tools. A React monoculture. It does not spark joy.
---

Originally published as a [Xitter thread](https://twitter.com/rombromz/status/1790389272320647286).

---

At 021.gg we were looking at stacks to drastically increase iteration speed. We don't want to waste time fighting frameworks or performing cumbersome rituals.

We want something simple and monolithic to launch projects fast.

We fell in love with [Svelte](https://svelte.dev/). I used it in the past (when [SvelteKit](https://kit.svelte.dev/) was called Sapper) and it's an absolute joy to write in. The reactivity system is way simpler than that of [React](https://react.dev/), handling state requires a lot less boilerplate, the runtime is tiny.

During our exploration things looked very optimistic. [Wevm](https://wevm.dev/) provides a [@wagmi/core](https://wagmi.sh/core) package which is trivial to wire up with Svelte's stores. It sparked joy.

Wagmi allows us to onboard web3-natives, i.e. people with crypto wallets, easily.

Still, we think a key success factor for any project, as for web3 in general, is onboarding the non-natives. We were very enticed by [fantasy.top](https://fantasy.top/)'s approach, using [privy.io](https://www.privy.io/) for onboarding both native and non-native web3 users.

There was an issue however.

The only SDK Privy currently provides a React SDK. What's more, it's tuned heavily to favor [Next.js](https://nextjs.org/) projects. Using a Svelte stack is nigh impossible. The same is the case for [dynamic.xyz](https://www.dynamic.xyz/), another auth/custodial wallet provider, which also targets React.

Now, there's a [`svelte-preprocessor-react`](https://github.com/bfanger/svelte-preprocess-react) package which enables you to utilize React components and APIs inside Svelte (🤮). Using Privy
is a non-option, because:

1. Largest client bundle became 2MB+
2. You cannot use SSR at all
3. Some auth providers don't work still.

Since Dynamic.xyz's SDK is also React, this is probably a no-go as well.

The last option we found is [Web3Auth](https://web3auth.io/), who provide a framework-agnostic SDK. The implementation is definitely more cumbersome, but we got it working in Svelte after wrestling with [Vite](https://vitejs.dev/) polyfills.

All this is leaving a very bad and especially bland taste in my mouth.

It's bland, because the experience shows Web3 tooling is becoming a monoculture. Which is probably related to React's (and Next.js') hegemony.

A lot of front end developers have developed React brain.

There's a paradox here as well, I think. We say key success lies with onboarding the Web3 non-natives, but at the same time we're hardly putting effort in onboarding non-React brained developers.

In the current state, Web3 tooling isn't ready for frameworks beyond React.

I do see some projects working towards this. Wevm's Wagmi has a very solid architecture: a core API which enables you to write very straightforward framework-specific wrappers. They shipped React first and are now working on Vue. `@wagmi/svelte` coming up.

Anyway.

For us product builders it's sensible to take the path of least resistance. You want to ship.

But it's very sad that the path of least resistance doesn't coincide with the path of most fun. Because combined, they will let you ship fastest.

Let the ecosystem grow beyond React.

---

**Got something to say?** [Reply on X](https://twitter.com/rombromz/status/1790389272320647286).

*[SSR]: Server Side Rendering
