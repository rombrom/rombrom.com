---
tags: ["post", "svelte", "context", "stores", "dev"]
layout: post
title: SvelteKit Contexts and Stores
excerpt: |
  A deep-ish dive into Svelte's context API and why it's not, and shouldn't
  be, reactive.
---

We've launched [coin.fun](https://www.coin.fun/) on Solana Mainnet a few weeks
ago. Despite my earlier conclusion that "Web3 tooling isn't ready for frameworks
beyond React", we stubbornly built coin.fun in
[SvelteKit](https://kit.svelte.dev/). The <abbr title="too long; didn't
  read">tl;dr</abbr> is that developing in [Svelte](https://svelte.dev/) has been
a joy, but there were some framework-specific things that raised some confusion.
One of these being context and stores.

Contexts and stores, on their face, seem pretty straightforward. Context in
Svelte, just like context in React, is a method to share data in a component
tree. Svelte stores are the primary mechanism to share reactive state across
many components.

Okay, cool.

Wait. They sound pretty similar.

I guess, in short, they're both concerned with sharing things across component
trees. Key difference being that stores are concerned with _reactive state_,
whereas context can be used to share _anything_: static values, functions,
reactive state, anything.

Unfortunately, the [Svelte](https://svelte.dev/docs/svelte#setcontext) and
[SvelteKit
docs](https://kit.svelte.dev/docs/state-management#using-stores-with-context)
fall a bit short when it comes to the intricacies of context. I guess it's more
of a lack of idiomatic patterns than necessarily omission of critical concepts.
Let's just say some things are left to imagination.

The docs on context do mention a few times that `getContext` and `setContext`
"must be called during component instantiation." Furthermore, SvelteKit offers a
little insight how context can be utilized to _isolate store instances per
client_[^isolate-stores].

Anyway. Lets engage in the pleasure of finding things out.

## Context Playground

There's a small [context playground I created in the Svelte
REPL](https://svelte.dev/repl/f2aed192063c4ca0a6a77e9a22a66944?version=4.2.19). It's no
SvelteKit so we can't check some SSR-specific things—like how SvelteKit reuses
component instances across navigations—but that's something we can sort of
emulate.

I encourage you to play around a bit.

<figure>
  <iframe src="https://svelte.dev/repl/f2aed192063c4ca0a6a77e9a22a66944?version=4.2.19"></iframe>
  <figcaption>Poor-man's context playground.</figcaption>
</figure>

The playground here forgoes idiomatic usage of context. Especially the use of
reactive `getContext` and `setContext` calls is something which would make Rich
shudder, I imagine. It's a good showcase of context anti-patterns—I will circle
back to this later—and that's why it's educational.

### Setup

The playground has three sets of fields.

1. A context key, which you can change to check how dynamic keys work.
2. Two context values, as a reactive binding or a store value.
3. Toggles for triggering render and mounts of children.

The component utilizes `<svelte:self />` to recursively render itself, which
allows you to check behavior of components consuming a context set by a parent.

### Observations

Now, when playing with just the two values we can set things look fine and
dandy. We can see that our value binding updates, and our store binding updates
values in nested components consuming context.

It appears "component instantiation" is a bit of a "loose" concept though. I
cheekily added some `getContext()` calls inside the HTML template (don't do this
btw). So if you toggle the `context` flag, observe how the values are updated
when the `#if` block (re)renders it's contents. It makes sense though, because
the template is just as much instantiated as the code in our `<script>`.

The nested component carrying over the same context key behaves as expected as
well. The `getContext()` calls inside our nested component carry over the store
value but do not carry over the input value. And, just as with toggling the
`context` flag, toggling the `nested` flag on our root will instantiate the
child component and thus propagate the bound input value.

If we add another nested component (toggle `nested` on in the first child), you
would notice that our values appeared to have stopped propagating. This is not a
bug but 💯 expected because of how Svelte context works. Svelte's `setContext()`
attaches a key/value context to the component tree. As we are calling
`setContext()` in every component instance, the grandchild will inherit the
context set by the first child, which is `undefined`. Note that calling order
is of importance as well. Because we call `getContext()` before `setContext()`,
we grab the first context instance we find when walking up the component tree;
not the instance attached to the current component.

However…

Things change when we take the context `key` into account. Notice how, in the
playground, I'm calling `$: setContext(key)` reactively (also: don't do this),
meaning it's called on to changes to `key`. Also note we're grabbing context
reactively on changes to `key` with `$: ctxReactive = getContext(key)` (again:
doing this is not advisable). Anyway.

Here we discover why setting and getting context reactively is a bad idea. When
you play around with changing context key on both the root element and the
child, you'll see that the `const getContext()` exhibits the most consistent
and, in my view most expected, behavior. Now, this is probably because the
playground is deliberate exceptionally bad implementation of utilizing context,
but it perfectly shows why you'd want to approach setting and getting context as
something static.

### A digression into React

Now, Svelte's context model is quite a bit different than that of React. React
is pretty explicit in how it deals with context. You need a `Provider` component
which explicitly wraps a component sub-tree. Components in that sub-tree can
consume the `Provider`'s value. This value is inherently reactive in React
because it's just a prop on `Provider`. Also, if the provider value is a struct,
you can easily hook up parts into React's reactivity by utilizing `useState()`
or `useReducer()`.

In Svelte context, through `setContext()` is directly bound to the current
component sub-tree. When you `getContext()` before setting it, you can get
access to the parent's context. The context value also isn't something
inherently reactive as opposed to React's model.

Although you could hook up getting/setting context up to Svelte's reactivity, by
making `key` reactive, the API clearly isn't built for this scenario. An obvious
hint here, is that Svelte throws whenever you call `getContext()` or
`setContext()` in an event handler. Now, I'm not sure whether allowing calls in
reactive statements is an oversight or possibly difficult to detect or a valid
use-case for very specific scenarios, but generally it looks like doing this is
a recipe for subtle bugs.

## SvelteKit stores in context

So far I've mainly written about what _not_ to do. So what's the proper way
here?

If you need to pass reactive variables you will need to wrap a store inside a
context. This way both the root and descendants of a sub-tree can consume and/or
update the store's value contained within the context.

A helpful pattern I've been applying here is making sure stores have some sort
of initializer method. This method we can hook up to Svelte's reactivity system
so it may propagate changes to descendants of the tree which consume its
context. The basic patter is like so:

```svelte
<script>
  import { setContext } from 'svelte';
  import { writable } from 'svelte/store';

  export let someValue;
  const store = writable(someValue);
  setContext('key', store);

  // Make sure store updates when `someValue` changes.
  $: $store = someValue;
</script>
```

This example is a bit contrived though. In coin.fun we have some pretty gnarly
stores keeping track of signed in users, onchain operations, and other more
complex data. In some cases we also need to set up listeners to websocket
events, or kick off a `fetch()`. And in many cases we need multiple descendant
components of a sub-tree consume these stores. We roughly apply the following
pattern in a file (or files, depending on complexity):

```js
// store.js
import { setContext } from "svelte";
import { writable } from "svelte/store";

const KEY = "myContext";

function createStore(initialValue) {
  const { set, subscribe } = writable(initialValue);

  function init(nextValue) {
    // Here you could place some initialization logic.
    // Afterwards, update the store with `nextValue`.
    set(nextValue);
  }

  return {
    init,
    subscribe,
  };
}

export function getValueContext() {
  // If you're antsy about children being able to initialize
  // store values, you can do something like the following to
  // omit the `init()` method:
  //
  //   const { init: _, ...store } = getContext(KEY);
  //   return store;
  //
  return getContext(KEY);
}

export function setValueContext(initialValue) {
  const store = createStore(initialValue);
  setContext(KEY, store);
  return store;
}
```

This can then be set and consumed in a parent, a route file for example, like so:

```svelte
<!-- +page.svelte -->
<script>
import { setValueContext } from './store.js';

export let data; // page data as received from load()

// For initial, full-page loads we create the store and set an
// initial value.
const store = setValueContext(data.value);
// Because SvelteKit reuses components and does not re-mount
// we can update the corresponding store reactively whenever
// `data.value` changes due to navigation.
$: store.init(data.value);
</script>
```

Having an `init()` method also helps if you need/want to be explicit in
initializing the store value on certain lifecycle events, like `onMount()`,
`afterNavigate()`, etc.

### Svelte's Magic

Building [coin.fun](https://www.coin.fun/) in SvelteKit was an absolute joy. We
did struggle a tiny bit learning the intricacies of Svelte. Reactivity in Svelte
4 is pretty magical at times, and can definitely bite you if you're dealing with
a lot of reactive variables dependent on each other. The context playground
being a good case-in-point, as we're definitely doing some naughty things there
which anyone unfamiliar with the behavior could try. One of the things in Svelte
5 I'm looking forward to is it requiring you to be a lot more explicit when it
comes to reactivity.

I hope this post provides some insights in how to apply context in Svelte and
SvelteKit. Most of all, I hope it at least explains a little bit how context
behaves with store-in-context scenarios, and why you'd want to adhere to Svelte
and SvelteKit's documentation.

🖖

---

**Let me know if this blows.** [Reply on X](https://x.com/rombromz/status/1830925277255348651).

[^isolate-stores]:
    The [SvelteKit docs on state
    management](https://kit.svelte.dev/docs/state-management#avoid-shared-state-on-the-server)
    are very adamant about not relying on global, ex. module-scoped, state because
    this could leak state to other clients. They mention:

    "You might wonder how we're able to use `$page.data` and other [app
    stores](https://kit.svelte.dev/docs/modules#$app-stores) if we can't use our own
    stores. The answer is that app stores on the server use Svelte's [context
    API](https://learn.svelte.dev/tutorial/context-api) — the store is attached to
    the component tree with `setContext`, and when you subscribe you retrieve it
    with `getContext`."

    Well, what I'm wondering still is how they're doing this _and_ making
    `$page` available through a module import because it feels a lot less cumbersome
    than importing and calling a `getContext` before being able to consume the
    store.
