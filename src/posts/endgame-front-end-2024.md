---
date: 2024-04-18T18:19:00
tags: post
layout: post
title: A Tour of an NFT Rentals Marketplace Front End at Cruising Altitude
---

Gm all! Now that we’ve released our [021 Endgame](https://endgame.021.gg/) rentals protocol into the wild we figured it was high time to get some word out concerning some of the choices and trade-offs we made while building it. This article will focus in on some of these choices and trade-offs we made for our front end tech stack. I’ll get right to the juice.

## The Gist

We use [Remix](https://remix.run/) as our front end framework. As it’s powered by [React](https://react.dev/) it offers us lots of goodies available in the React ecosystem. Things like [Tanstack Query](https://tanstack.com/query/latest) for handling any (asynchronous) state with [GraphQL Request](https://github.com/jasonkuhrt/graphql-request), [Wagmi](https://wagmi.sh/) and [Viem](https://viem.sh/) for handling any onchain/wallet interactions, [Radix Primitives](https://www.radix-ui.com/primitives) and [TailwindCSS](https://tailwindcss.com/) for anything UI related.

For testing our application we leverage [Storybook’s Test Runner](https://storybook.js.org/docs/writing-tests/test-runner) as a component testing framework and [Playwright](https://playwright.dev/) for the heavier end-to-end testing. Both are fantastic tools to keep core functionality in check.

Everything is written in TypeScript. Most of these choices were locked-in from the onset.

Now, if there’s any guiding principle in our development team, it would be: “be pragmatic”. This captures a slew of software development principles into one overarching creed. Think: YAGNI, KISS, “premature optimization is the root of all evil”, principle of least power, and probably some others. The thing with code, when you’ve worked with it long enough, is that at some point you discover the code itself has a voice. Code can’t be simply reduced to expressions, variables and operations cast from the void of the programmer’s mind. This stance will deafen you to this voice. Code whispers when you find yourself repeating things. Code speaks when you struggle to find elegance. Code shouts when you’re trying to bend an implementation to its breaking point.

Pragmatism appoints code itself a powerful advisor.

## Back End

Our back end exposes a GraphQL API to fetch and mutate data. As such we had a rich amount of choices for handling back end I/O but opted for simplicity first. We leverage GraphQL Request in tandem with Tanstack Query.

Tanstack Query especially exposes a delightful API to handle a wide variety of data fetching (while not being limited to only data fetching) scenarios. Things like TTL, invalidation, “infinite” (e.g. paginated) queries, loading and error states, mutations, etc. are all made available in a relatively light-weight package. GraphQL Request, in tandem with GraphQL Codegen, allows us to easily and flexibly define the data we need for certain views. We try to colocate GraphQL queries where it's sensible and leverage fragments to reduce duplication. GraphQL Codegen provides tooling like `FragmentType` and `useFragment()` to handle actual types and properties returned by queries—as opposed to using GraphQL schema types as props directly. For more info, read up on ["fragment masking"](https://the-guild.dev/blog/unleash-the-power-of-fragments-with-graphql-codegen).

One fantastic benefit of using Tanstack Query is that it allows you to introduce another layer of separation between the UI and framework (like Remix). Essentially, it theoretically allows us to eject from a server framework completely and still have fully functioning views. The server side prefetching is just extra. This approach proved immensely useful later.

## Chains, Wallets and Protocol

A few months after Wagmi was released we integrated it into our v2 front end to simplify a lot of logic concerning wallet sessions. Similarly, to simplify internals and interaction between our v2 front end and protocol, we added support for Viem in our v2 SDK. These libraries, in our opinion, are an absolute joy to work with and provide simple yet powerful foundations of interacting with chains and wallets. This experience made it an obvious choice for Endgame as well.

We leverage WalletConnect’s Web3 Modal for wallet connections. While Wagmi does provide the option to handle the injected connector alongside, we figured presenting a unified, familiar interface regardless of connector was easiest to maintain while providing a consistent UX.

For Endgame protocol I/O we wrote a small library wrapping parts of our back end I/O, Wagmi, and—since our protocol leverages Seaport—SeaportJS with Tanstack Query. The library exposes a set of React hooks which provide us data about chain configuration, permissions, rental status, and relevant rental and safe account actions. In honesty, SeaportJS we might eject from at some later point, as it provides a lot of tooling to interface with the Seaport protocol, whereas we just use a small subset. For velocity's sake though, having SeaportJS check and ask for approvals before initiating a rental transaction is pretty nice to have.

We found Wagmi’s MockConnector one of its biggest boons. It allows us to, well, mock a connected wallet. We have written a small harness around the MockConnector, allowing us to easily connect a test wallet for our end-to-end tests, or to mimic/impersonate any wallet for manual testing and debugging purposes. In the future we might write a more in-depth article on our approach here.

## Components and UI

The danger with picking a full-fledged, off-the-shelf component library is that, at some point, you will need to fight the framework or accept some nauseating compromise. Most of these libraries (e.g. Material UI, Ant Design, Bootstrap, Chakra) design their components and interfaces, understandably, for the most broad cases. Many of these libraries also ship their own way of extending or overwriting their themes. Some have strong opinions on which custom styling solution works best. Some even provide their own styling solutions. The key thing is, with any UI library, you often find yourself writing your own wrappers anyway.

A “headless UI” library like Radix Primitives enables a very flexible approach to reusable components. It provides accessible primitives with a lot of hooks (not the React ones) to handle custom behavior. Additionally, a headless UI library is agnostic as to the preferred styling solution. You can use plain ol' CSS, Styled Components, Emotion, stylex—pick your poison, amirite? We choose Tailwind.

I’ll be honest. I love CSS. When you grok the cascade it allows for a very powerful and extensible paradigm to style user interfaces with. Recent advancements in the CSS specifications (and browsers actually implementing these) can make CSS a very fun logic playground. I love shipping things more though.

TailwindCSS allows us to mark up and style components fast, while retaining the ability to use plain ol’ CSS when the use-case calls for it. A specific example here would be styling third-party components. Sure, you can leverage Tailwind’s selector engine to apply styles to any child element, but seeing as regular Tailwind is hardly a feast for the eyes, overloading a className to style elements of a third party component will positively make your eyes bleed. Eject to a CSS file.

## Remix?

Remember how we said it’s important to listen to code?

We actually started developing Endgame on top of Next.js. We use this framework for our v2 application and thereby accrued quite some experience with it. We knew Next.js has its faults and foot guns but an experienced programmer would agree reusing a stack you have experience in, for a comparable project, is a very sensible choice.

The tech landscape—especially the front end ecosystem—is ever shifting however, and while developing Endgame we found ourselves in the midst of Next.js releasing v13 (and later v14). The v13 release added the powerful App Router, leveraging React Server Components (RSC). Initial adoption took some getting used to and we had to restructure a few modules but things chugged along fine. Over the months we would grow increasingly disenchanted by Next.js’ offering however. Partly because RSC exposed, in our opinion, a very misguided approach: that it makes sense to shoehorn a client side UI library into—checks notes—a server-side templating language. Partly because we kept discovering Next.js has very strong opinions on how to handle some web platform core APIs. We had to write a quite some indirections to deal with these (looking at you, `useSearchParams()`). The code started shouting.

At this point, about 6 months in, we made the decision to migrate framework. We had been eying Remix for some time because of its sensible approach to expose Web APIs rather than abstract them. Moreover, much of our logic was required on the client anyway so the reduced bundle payloads were hardly worth the effort. The key thing to migrate over was routing. The rest pretty much worked out of the box because of our decoupled architecture. The core engine swap essentially took about 2-3 days. Rewriting some of the indirections took about the same time. Bells and whistles, another two days or so. The result, however, was code tranquility and a big boost to our velocity.

Remix offered us vastly more transparency and control over its layers.

## Endgame

We’re very excited to have launched Endgame and we’re grateful we can start to share our journey with everyone. It has taught us a lot. We hope to have given you an interesting cursory look at how we architected our front end. Now, each component in our architecture could merit its own article but we wanted to provide a comprehensive overview first. Stay tuned for some more in-depth content! Oh and be sure to [check out Endgame](https://endgame.021.gg). It's a labor of love.
