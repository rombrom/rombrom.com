---
hidden: true
tags: post
layout: post
title: 'Endgame Front End Deep Dive: Layers and Data'
excerpt: |
  tbd
---

It's strange. When we think about code it oftentimes evokes a sense of rigidness. A rule-bound universe where processes, inputs, outputs, are predictable things. The same input produces the same output. Paradoxically, the act of coding is anything but rigid. It's an extremely creative and relatively unbounded process. I think the architecture and module structure of a codebase is where this paradox causes the most clashes. This is evidenced partly by how many opinions and articles about code organization float around on the net. Another thing I noticed, as a person who frequents (web) dev related Subreddits, is how often questions on folder structure pop up.

I think I understand the perceived importance of structuring upfront. As humans we like patterns, structure and the clarity these things provide. "If I think really really hard about how my project needs to be structured up front, I'll win back velocity once I'll actually start coding because I won't have to think about where to place things."

Structuring a project upfront is a fantastically useless navel-gazing distraction. It distracts you from the actual work with its feigned importance. It's a very inconspicuous form premature optimization and, quite frankly, busywork. What's more, structuring upfront runs directly counter to coding's actual craft and distances you from the material and landscape. The map is not the territory.

Just get started. Refactor early. Refactor often.

## Three-Tiered Onions

Oooh, onions! We're definitely cookin'.

There's no shortage of metaphors when it comes to coding. One of the most long-lived ones is the tiered "onion" architecture. Like an onion, it has a core being enveloped by other layers with differing responsibilities. The three tier architecture being a prime example. It separates presentation, application (logic) and data into separate layers. Data placed firmly at the core, enveloped by the application layer, enveloped by the presentation layer.

Let me cycle back to how [we swapped the engine at 2/3rd of the project](/posts/endgame-front-end-2024/#remix%3F). The primary reason we were confident about swapping Next.js with Remix is because we were quite diligent in keeping apart the architectural layers of our front end. These layers do not corroborate 1-on-1 to three tier architecture. We're dealing with a front end here and not a complete stack. Still, the principle of layering can be applied somewhat recursively to fit this slice of our stack.

Roughly speaking we discern the following:

1. Service layer, consisting of configuration, API interfacing, chain & wallet interfacing, and rental protocol interfacing.
2. User Interface and Browser/React utilities
3. Engine, providing SSR and route endpoints.

Now, these layers do not necessarily correlate with our module structure. Generally speaking though, each layer can consume any preceding layer. Notice how the engine is an outer layer. Our core user interface components are separate from it, as is our core logic and service interfacing. The engine mostly provides an harness to fit our core logic and UI onto. It provides ways to expose our user interface through routes and ways to optimize initial data fetching to get those fast initial renders.

There are some parts which remain somewhat tightly coupled, because they're pretty much dependent on engine specifics. This makes them inherently hard to decouple. Take cookies and sessions for example. Next.js and Remix both provide APIs to handle these. There's some overlap but consuming cookies (ha!) generally wasn't worth abstracting. In these cases we do try to keep data model and consumers of cookie data in our service and UI layers.

If there's anything to take away from this section, it's that having a clear idea about layering responsibilities will guide decisions on structure and organization.

### A practical example

So far I've been all talk. It's high time for some actual code. Lets implement the way we fetch data with Tanstack Query.

**Note:** there is a [demo repository](https://github.com/rombrom/remix-tanstack-query-hydration-demo) you can check out which contains all code below.

```sh
# Create a Remix project, install Tanstack Query
# and run dev server
npx create-remix@latest remix-tanstack-query
cd remix-tanstack-query
npm i --save-exact @tanstack/react-query
npm run dev
```

Lets do some scaffolding first. We need some fake data to fetch. We'll simulate this as well as possible network latency and error cases.

```ts
// File: app/getData.ts

export async function getData() {
  const num = Math.random();
  await new Promise((ok) => setTimeout(ok, 1000 * num));
  if (num > 0.5) throw new Error(`Bad number: ${num}`);
  return `Good number: ${num}`;
}
```

We also need to add a `<QueryClientProvider />` to our root layout.

```tsx
// File: app/root.tsx

import {
  QueryClient,
  QueryClientProvider
} from '@tanstack/react-query';
import { useState } from 'react';
// ...
export function Layout({ children }: { children: React.ReactNode }) {
  // The reason we want to initialze `QueryClient` in a state
  // is because we need the client to be unique for each user.
  const [queryClient] = useState(
    new QueryClient({
      defaultOptions: {
        // No retries in testing, else we'll never see errors.
        queries: { retry: false },
      },
    })
  );
  // ...

  return (
    // ...
        <QueryClientProvider client={queryClient}>
          {children}
        </QueryClientProvider>
    // ...
  );
}
// ...
```

Lastly, lets implement this in our `app/routes/_index.tsx` route.

```tsx
// File: app/routes/_index.tsx
// ...
import { useQuery } from '@tanstack/react-query';
import { getData } from '~/getData';
// ...
export default function Index() {
  const { data, error, isLoading } = useQuery({
    queryFn: () => getData(),
    queryKey: ['num'],
  });

  return (
    <div
      style={% raw %}{{
        color: isLoading ? 'blue' : error ? 'red' : 'green',
        fontFamily: 'system-ui, sans-serif',
        lineHeight: '1.8',
      }}{% endraw %}
    >
      <p>Data: {data}</p>
      <p>Error: {error?.message}</p>
    </div>
  );
}
```

Big whoop. This is Tanstack Query 101. Lets get that SSR going. Tanstack Query offers some flexibility here. The `initialState` parameter on `useQuery` and friends could be used but will lead to prop drilling. The most robust and portable method is leveraging its `HydrationBoundary` and `dehyrate()` APIs. You can implement these per route, but Remix allows you to write even less boilerplate.

When you visit a route on Remix, it will fetch data from all loaders in the route cascade. If you pair this with Remix's powerful [`useMatches`](https://remix.run/docs/en/main/hooks/use-matches){% footnote %}Not related to fire starting equipment.{% endfootnote %} hook, you can combine dehydrated data from all matching loaders without having to resort to nested `HydrationBoundary` components. The only requirement is introducing a convention on how (prefetched) loader data is returned. So lets agree here and now that any loader returning JSON which includes a `dehydratedState` property has state we want to accumulate.

```ts
// File: app/useMatches.ts

import { useMatches } from '@remix-run/react';
import type { DehydratedState } from '@tanstack/react-query';

export function useDehydratedState() {
  const matches = useMatches();
  return (
    matches
      // @ts-expect-error in all cases the following will resolve
      // to undefined if `dehydratedState` isn't available.
      .flatMap(({ data }) => (data?.dehydratedState as DehydratedState) ?? [])
      .reduce<DehydratedState>(
        (result, current) => ({
          queries: [...result.queries, ...current.queries],
          mutations: [...result.mutations, ...current.mutations],
        }),
        { queries: [], mutations: [] }
      )
  );
}
```

Now lets add the hydration setup to our root layout. Also note the addition of `staleTime` to our client side `QueryClient`. Our dehydrated client already fetched and without adding at least a bit of `staleTime`, our queries would be executed again on the client.

```tsx
// File: app/root.tsx

import {
  HydrationBoundary,
  QueryClient,
  QueryClientProvider
} from '@tanstack/react-query';
import { useState } from 'react';
import { useDehydratedState } from './useDehydratedState';
// ...
export function Layout({ children }: { children: React.ReactNode }) {
  // The reason we want to initialze `QueryClient` in a state
  // is because we need the client to be unique for each user.
  const [queryClient] = useState(
    new QueryClient({
      defaultOptions: {
        // No retries in testing, else we'll never see errors.
        queries: { retry: false },
        staleTime: 5000,
      },
    })
  );
  const dehydratedState = useDehydratedState();
  // ...

  return (
    // ...
        <HydrationBoundary state={dehydratedState}>
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        </HydrationBoundary>
    // ...
  );
}
// ...
```

And hook up a loader, making use of `dehydrate()`, to the index route.

```tsx
// File: app/routes/_index.tsx
import { json, type LoaderFunction, type MetaFunction } from '@remix-run/node';
import { QueryClient, dehydrate, useQuery } from '@tanstack/react-query';
import { getData } from '~/getData';

export const loader: LoaderFunction = async () => {
  const queryClient = new QueryClient();
  await queryClient.prefetchQuery({
    queryFn: () => getData(),
    queryKey: ['num'],
  });
  return json({ dehydratedState: dehydrate(queryClient) });
};
// ...
```

And fin.

This is basically the setup we use for anything data-fetching related. We have some modules exporting ready-to-use functions like `getData()` from our service layer. These are used in our UI components directly on `useQuery()`. Our engine also imports these so they can be hooked up easily to prefetching. This setup has been unchanged since we implemented it in Next.js. The prefetching logic, instead of being housed in a loader, was just part of a React Server Component. Moving over the logic to a loader was a breeze.

### You said onions?

Right.

The example we worked through is a simple one. Still, it informs us about layers. The way Tanstack Query integrates naturally separates data fetching from presentation and allows you separate prefetching into a separate layer as well. I guess you could add an extra abstraction which wraps setting up and dehydrating a client, but trust me when I say the ROI isn't great. You're not swapping engines every day.

The layers in the example aren't that clearly demarcated as there's some overlap in code location. The index route, for example, contains code concerning the UI layer and the prefetching layer. However, when this application grows you could very well imagine UI components being split off into `~/components`. At some point it might make sense to create a `~/loaders` module which houses recurring loader patterns. `getData()` could grow into a slew of modules housed in `~/api`. Who knows.

Layers aren't necessarily related to code location, folders and files. Moving the UI code into a separate component is trivial. So is moving or abstracting loader (pre)fetching. It's got more to do with what responsibility and/or domain the code envelops.

The key thing here recognizing these layers. And understanding—nay, grokking—that moving, abstracting, and refactoring code are inexpensive operations. Start inline and work your way outwards. The code will tell you when it needs changing.

## A digression on botany

When we started building Endgame we didn't start with any specific structure in mind. The first commit is literally the result from `npx create-next-app@latest` and we cruised on this structure for our initial scaffolding. We just wrote a lot of things inline. When we added WalletConnect support about 12 commits in, the `@/components` folder was added. It's a central place for UI components. Initially we had everything related to our WalletConnect integration housed in `@/components/wallet`. Much later we had split this up into `@/wallet` and `@/components/wallet`. The former being responsible for configuration and generic initialization, the latter specifically catered to UI. When we worked on getting GraphQL interfacing set up, we added `@/graphql`, housing code generation artifacts from GraphQL Codegen, our GraphQL client initialization and some utilities. We shoehorned our API interfacing layer into this module which we later extracted into `@/services/api`. We had a `@/config` folder which later turned into a simpler `@/config.ts` file.{% footnote %}We're leveraging TypeScript's [`paths`](https://www.typescriptlang.org/tsconfig/#paths) option as a poor-man's monorepo: `@/* › src/*`, `~/* › app/*`. Aside from freeing us from walking up paths, it's more subtle effect is that you tend to folders in `src/*` and `app/*` as proper, separate modules.{% endfootnote %}

Anyway. What I'm trying to get at is that we just started doing the work. It didn't make sense worrying about structure before we'd have a solid grasp of how the thing we were building could be best structured. We did, however, have a good sense on how to layer things.

Andy Hunt and David Thomas, authors of "The Pragmatic Programmer," quite aptly captured this aspect of the craft in their [garden metaphor](https://www.artima.com/articles/programming-is-gardening-not-engineering). They recognized the paradoxical sentiments around programming. One the one hand the discourse touts coding an engineering profession: plan, execute, deliver. All according to spec. On the other hand, the act of coding itself often yields new discoveries orthogonal to the initial plan.

> The garden doesn't quite come up the way you drew the picture. This plant gets a lot bigger than you thought it would. You've got to prune it. You've got to split it. You've got to move it around the garden. This big plant in the back died. You've got to dig it up and throw it into the compost pile.{% footnote %}See [Programming is Gardening, not Engineering: A Conversation with Andy Hunt and Dave Thomas, Part VII](https://www.artima.com/articles/programming-is-gardening-not-engineering). Quite some concepts from The Pragmatic Programmer make the rounds here.{% endfootnote %}

Coding is just as much a process of discovering the codified as it is codifying the discovered. One of the keys to becoming better is trying to make this feedback loop as tight as possible. Because many iterations through this loop will offset the practice more and more to codifying the discovered.
