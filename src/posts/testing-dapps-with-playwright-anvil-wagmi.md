---
hidden: true
tags: ['post', 'endgame', '021.gg', 'project', 'testing']
layout: post
title: 'End-to-End Testing Blockchain Applications: Episode 2'
excerpt: |
  Testing
---

More shop talk today. We're going to have some fun with End-to-End (E2E) testing blockchain applications.

What I'm _not_ going to write about is testing philosophy. The discourse on why, what and how to test is saturated enough. I'll just leave it at the following. I like tests. They provide confidence my code is working as intended. I like tests with a high ROI better than tests with a low ROI. In some cases TDD helps in designing an API. In most cases E2E is all you need.

In all cases one test is infinitely better than no test.

### Table of contents

This article has become so big I'm required to add a table of contents. Also, if you just want to see the code, there's an [example repostory on GitHub](https://github.com/rombrom/blockchain-web-app-e2e-testing-remix-wagmi) you can check out.

- [Setting up for success](#setting-up-for-success)
  - [Setting up Playwright](#setting-up-playwright)
  - [Running a testnet node](#running-a-testnet-node)
  - [Setting up Wagmi](#setting-up-wagmi)
  - [How to mock a wallet](#how-to-mock-a-wallet)
- [Setting up for failure](#setting-up-for-failure)
  - [It swaps the config](#it-swaps-the-config)
  - [It hooks up a fixture](#it-hooks-up-a-fixture)
  - [It travels through time](#it-travels-through-time)
- [In closing](#in-closing)

## Setting up for success

A long while back (over a year ago—84 years in web3 time), I [wrote a piece](https://medium.com/renftlabs/end-to-end-testing-dapps-with-playwright-rainbowkit-wagmi-and-anvil-90d1d143512c) on how we approached E2E testing for our v2 protocol application. The basic initial setup is still the same:

1. Playwright as the test runner.
2. Foundry's Anvil for running a testnet node.
3. Wagmi & Viem to connect wallets and interface with the blockchain.
4. Leverage Wagmi's [mock connector](https://wagmi.sh/react/api/connectors/mock) to set up a testing wallet.

The previous article provided a get-running-quick tutorial. This one will be more in-depth.

### Setting up Playwright

Lets get this show on the road. The following will create a Remix starter repository:

```sh
npx create-remix@latest --yes blockchain-web-app-e2e-testing-remix-wagmi \
  && cd blockchain-web-app-e2e-testing-remix-wagmi
```

Make sure to install Viem, Wagmi and Tanstack Query as dependencies. We also need to install Playwright as a development dependency. And install Playwright's browsers.

```sh
npm install --save-exact @tanstack/react-query viem wagmi
npm install --save-dev @playwright/test
npx playwright install
```

Grab the [example configuration from playwright.dev](https://playwright.dev/docs/test-configuration#basic-configuration) and save it to the file `playwright.config.ts`. There is one tiny change we might want to make, which is the `fullyParallel` flag.

```ts
  ...
  // Run all tests in parallel.
  fullyParallel: true, // [!code --]
  fullyParallel: false, // [!code ++]
  ...
```

The reason we probably want to switch this off is because, if `fullyParallel` is enabled, Playwright—assuming there are workers available—will not only execute separate test suites in parallel _but also execute each test in a test suite in parallel._ When testing against a blockchain there's often a linearity to the tests, requiring you to execute things serially as opposed to fully parallel.

We will get back to this at the end of the article.

Lets add our first test in `tests/smoke.spec.ts`:

```ts
// tests/smoke.spec.ts
import { expect, test } from '@playwright/test';

test('load the homepage', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle('New Remix App');
});
```

Update `scripts` in `package.json` to execute Playwright:

```json
// package.json
    "start": "remix-serve ./build/server/index.js",
    "test": "playwright test", // [!code ++]
    "typecheck": "tsc
```

And run it:

```sh
npm run build
npm run test
```

Okay. One more thing. Notice the `webServer.reuseExistingServer` option in `playwright.config.ts`. This tells Playwright, if an existing process exposed on `webServer.url` returns a valid response, it won't execute `webServer.command`. This allows us to run tests against our development server. Unfortunately, Vite uses `:5173`^[I just recently found out that `5173` isn't random. It's leetspeak for SITE.] as the port when executing it in development mode. Lets fix this by pinning the development server to `host: '0.0.0.0'` and `port: 3000`.^[Using `host: '0.0.0.0'` binds the development server to be exposed on the local machine.]

```ts
// vite.config.ts
export default defineConfig({
  plugins: [remix(), tsconfigPaths()],
  server: { host: '0.0.0.0', port: 3000 }, // [!code ++]
});
```

Alright, sparky! We can now run the test against the dev server. Get that running with `npm run dev`.

### Running a testnet node

We need a local RPC node. Why do we need a local RPC node? Because testing on a live chain is anything but idempotent. With a local testnet node you can spin up a fresh blockchain state each run. It also enables you to snapshot and/or revert/restore the chain state. Moreover, it allows you to fork an EVM-compatible chain at a certain block number. All this tooling is essential for any serious testing of blockchain applications.

And, it will save you a whole load of gas.

We prefer Foundry's Anvil, but if you're familiar with Hardhat or Truffle the same principles and processes should apply, roughly. I'll refer to the [Foundry installation instructions](https://book.getfoundry.sh/getting-started/installation) to get it set up.

After installing Foundry, open a new terminal and execute `anvil`. This will boot up your testnet node to develop against.

### Setting up Wagmi

Lets set up Wagmi. Create `app/wagmi.ts` and paste in the following:

```ts
// app/wagmi.ts
import { createClient, http } from "viem";
import { createConfig } from "wagmi";
import { injected } from "wagmi/connectors";
import { foundry, mainnet } from "wagmi/chains";

const chains = [mainnet, foundry] as const;

export const config = createConfig({
  chains,
  client: ({ chain }) => createClient({ chain, transport: http() }),
  connectors: [injected()],
  ssr: true, // you want this to avoid hydration errors.
});
```

The next step is setting up our Remix application to make use of our Wagmi configuration. Note that we're putting the `QueryClient` in a `useState` because we need this to be unique for every visitor. If you'd use a non-`useState` initialized `QueryClient` the client would be shared by all visitors on the server-side parts of Remix. Anyway. We're going to do the same for the Wagmi configuration because we want to change this on-the-fly later.

```tsx
// app/root.tsx
import { QueryClientProvider, QueryClient } from "@tanstack/react-query"; // [!code ++]
import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "@remix-run/react";
import { useState } from "react"; // [!code ++]
import { WagmiProvider } from "wagmi"; // [!code ++]

import { config } from "~/wagmi"; // [!code ++]

export function Layout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(new QueryClient()); // [!code ++]
  const [wagmiConfig] = useState(config); // [!code ++]
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        <QueryClientProvider client={queryClient}> // [!code ++]
          <WagmiProvider config={wagmiConfig}>{children}</WagmiProvider> // [!code ++]
        </QueryClientProvider> // [!code ++]
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}
```

The last thing we want to do here is actually implement some blockchain interfacing so we can connect a wallet to the application and switch chains (if required). Lets change the `app/_index.tsx` completely so we can:

1. Connect a wallet
2. Display the address connected
3. Switch chains

As we're changing the complete file, I'm adding the complete implementation below:

```tsx{% raw %}
// app/_index.tsx
import type { MetaFunction } from "@remix-run/node";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";

export const meta: MetaFunction = () => {
  return [
    { title: "New Remix App" },
    { name: "description", content: "Welcome to Remix!" },
  ];
};

export default function Index() {
  const { address, chain, isConnected } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { chains, switchChainAsync } = useSwitchChain();
  return (
    <div style={{ fontFamily: "system-ui, sans-serif", lineHeight: "1.8" }}>
      <div style={{ padding: 16, border: "solid 1px" }}>
        <p>Connected: {address ?? "no"}</p>

        <p style={{ display: "flex", gap: 8 }}>
          Chain:
          {chains.map((c) => (
            <button
              key={c.id}
              onClick={() => void switchChainAsync({ chainId: c.id })}
              type="button"
            >
              {c === chain && "✅"} {c.name} ({c.id})
            </button>
          ))}
        </p>

        <p style={{ display: "flex", gap: 8 }}>
          {isConnected ? (
            <button onClick={() => disconnect()} type="button">
              Disconnect
            </button>
          ) : (
            connectors.map((connector) => (
              <button
                key={connector.id}
                onClick={() => void connectAsync({ connector })}
                type="button"
              >
                {connector.name}
              </button>
            ))
          )}
        </p>
      </div>
    </div>
  );
}
{% endraw %}```

Time to see what we have so far. Make sure you have the Remix dev server (`npm run dev`) and anvil (`anvil`) running. Lets see if we can connect a browser extension wallet like MetaMask. Note that in the demo below I imported the first available anvil testing account into MetaMask. Whenever you boot up `anvil`, by default it provides you with 10 testing accounts and their corresponding private keys.

<video controls src="/wagmi-demo-pt1.webm" /></video>

### How to mock a wallet

Finally we're getting to the meat. When attempting to conjure up a test for connecting a wallet we get stuck. There's no easy way to add wallet functionality to Playwright. There are projects like Synpress and Dappeteer (deprecated at the time of writing) which wrap MetaMask. Personally I'm not a fan of this approach as it's locking you into testing on a specific wallet. Any fundamental changes to MetaMask will require changes in your tests. Any fundamental breakages in MetaMask will break your tests. Icky.

The way we like to solve this is making use of Wagmi's mock connector. The mock connector offers a fantastic low-level abstraction for connecting a wallet to a blockchain application. You can integrate it in your application to test wallet connections and interactions. It even allows you to test non-happy paths by passing error cases to it's `features` option. This allows you to test errors when switching chains, connecting wallets, or signing messages or transactions.

We need to initialize the mock connector. There are several ways to do this. The simplest would be to add it to our list of `connectors` in `app/wagmi.ts`. The mock connector requires one argument with a list of accounts it's able to use. Lets limit this to the first two test accounts provided by anvil:

```ts
// app/wagmi.ts
import { createClient, http } from "viem";
import { createConfig } from "wagmi";
import { injected } from "wagmi/connectors"; // [!code --]
import { injected, mock } from "wagmi/connectors"; // [!code ++]
import { foundry, mainnet } from "wagmi/chains";

const chains = [mainnet, foundry] as const;

export const config = createConfig({
  chains,
  client: ({ chain }) => createClient({ chain, transport: http() }),
  connectors: [injected()], // [!code --]
  connectors: [ // [!code ++]
    injected(), // [!code ++]
    mock({ // [!code ++]
      accounts: [ // [!code ++]
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // [!code ++]
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // [!code ++]
      ], // [!code ++]
    }), // [!code ++]
  ], // [!code ++]
  ssr: true,
});
```

Yep. That adds it to our list of connectors:

![Mock Connector Option](/wagmi-demo-pt2.png)

And it allows us to connect with it. Woo!

![Mock Connector Connected](/wagmi-demo-pt3.png)

Lets add a test where we connect the first account from the mock connector.

```ts
// tests/smoke.spec.ts
import { expect, test } from "@playwright/test";

test("load the homepage", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("New Remix App");
});

test("connect wallet", async ({ page }) => { // [!code ++]
  await page.goto("/"); // [!code ++]
  await page.getByRole("button", { name: "Mock Connector" }).click(); // [!code ++]
  await expect( // [!code ++]
    page.getByText("Connected: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266") // [!code ++]
  ).toBeVisible(); // [!code ++]
}); // [!code ++]
```

When we run `npm test`, we should be green:

```
> test
> playwright test


Running 2 tests using 2 workers
  2 passed (1.1s)
```

Yep.

The catch here is that the mock connector is initialized for everyone—regardless of environment. We could add some logic which initializes the mock connector only on development environments by checking Vite's `import.meta.env.DEV`. This is what we did for our v2 protocol application.

It works great, but there's an opportunity here to make the mock connector useful for more than just testing.

## Setting up for failure

You could say that the web is quite a volatile environment. Users have different systems, different configurations, different browsers, plugins, etc. I would argue web3 is an even more volatile environment. On top of different systems and configurations, there's a wide variety of wallet providers and an even bigger variety of tokens held in these wallets.

One of the most powerful abilities you can give yourself and your team is being able to browse an application as any user. For Endgame we set up the mock connector in a way to allow us to do precisely this.

We expose an interface which swaps our production configuration with a configuration leveraging the mock connector, initializing it on an arbitrary account. What's more, through this interface we could pass options into the mock connector's `features` configuration to test specific scenarios.

The goals here are:

1. Set up a function accepting a private key/address and mock connector `features`.
2. Expose this to the browser in some way. The path of least resistance (and least intrusion into the UI) is slapping it onto `window`.
3. Set up a Playwright fixture which initializes mock connector configuration in test environments.

### It swaps the config

The trick here is realizing that the Wagmi configuration can live inside React too. Remember how we wrapped it in a `useState()` earlier?

```tsx
  const [wagmiConfig] = useState(config); // [!code ++]
```

What we need is a factory function which creates a new Wagmi configuration for us. The resulting configuration can be passed to a `setWagmiConfig()` state dispatcher. Because it's part of React state, any update to this state makes parts of the application dependent on the configuration rerender automagically.

The configuration factory will need to mirror most of our general configuration. The key thing to set up is the account it will be initialized for.

```tsx
// app/wagmi.ts
import { createClient, http } from "viem"; // [!code --]
import { createClient, http, isAddress } from "viem"; // [!code ++]
import { privateKeyToAccount } from "viem/accounts"; // [!code ++]
import { createConfig } from "wagmi";
import { injected, mock } from "wagmi/connectors"; // [!code --]
import { injected, mock, type MockParameters } from "wagmi/connectors"; // [!code ++]
import { foundry, mainnet } from "wagmi/chains";

const chains = [mainnet, foundry] as const;

export const config = createConfig({
  chains,
  client: ({ chain }) => createClient({ chain, transport: http() }),
  connectors: [injected()],
  ssr: true,
});

export function createMockConfig( // [!code ++]
  addressOrPkey: `0x${string}`, // [!code ++]
  features?: MockParameters["features"] // [!code ++]
) { // [!code ++]
  const account = isAddress(addressOrPkey) // [!code ++]
    ? addressOrPkey // [!code ++]
    : privateKeyToAccount(addressOrPkey); // [!code ++]
  const address = typeof account === "string" ? account : account.address; // [!code ++]
  return createConfig({ // [!code ++]
    connectors: [mock({ accounts: [address], features })], // [!code ++]
    chains, // [!code ++]
    client: ({ chain }) => createClient({ account, transport: http(), chain }), // [!code ++]
    ssr: true, // [!code ++]
  }); // [!code ++]
} // [!code ++]
```

That's the first part. The `createMockConfig()` function is set up to accept a private key or an address and the mock connector `features` configuration. By allowing any account address to be passed we can impersonate any account.^[Unfortunately I haven't got _real_ impersonation on a forked chain working through this method. If any of you have this figured out, please [give me a shout on X](https://x.com/rombromz)]

Next part is hooking this up to `WagmiProvider` initialization and slapping this helper onto the global `window` interface.

```tsx
// app/root.tsx
import { QueryClientProvider, QueryClient } from "@tanstack/react-query";
import {
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "@remix-run/react";
import { useState } from "react"; // [!code --]
import { useCallback, useState } from "react"; // [!code ++]
import { WagmiProvider } from "wagmi";

import { config } from "~/wagmi"; // [!code --]
import { config, createMockConfig } from "~/wagmi"; // [!code ++]

declare global { // [!code ++]
  interface Window { // [!code ++]
    _setupAccount: typeof createMockConfig; // [!code ++]
  } // [!code ++]
} // [!code ++]

export function Layout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(new QueryClient());
  const [wagmiConfig] = useState(config); // [!code --]
  const [wagmiConfig, setWagmiConfig] = useState(config); // [!code ++]

  const _setupAccount = useCallback( // [!code ++]
    (...args: Parameters<Window["_setupAccount"]>) => { // [!code ++]
      const config = createMockConfig(...args); // [!code ++]
      setWagmiConfig(config); // [!code ++]
    }, // [!code ++]
    [] // [!code ++]
  ); // [!code ++]

  if (typeof window !== "undefined") window._setupAccount = _setupAccount; // [!code ++]

  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        <QueryClientProvider client={queryClient}>
          <WagmiProvider config={wagmiConfig}>{children}</WagmiProvider>
        </QueryClientProvider>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}
```

Lets test it out.

<video controls src="/wagmi-demo-pt4.webm" /></video>

Yep. We can now browse our app pretending to be Vitalik.

### It hooks up a fixture

Fixtures are one of the core concepts to grok in Playwright. They're a very powerful tool, allowing you to abstract a lot of setup and application-specific initializations and interactions into a very simple interface.

> Test fixtures are used to establish the environment for each test, giving the test everything it needs and nothing else. [...] With fixtures, you can group tests based on their meaning, instead of their common setup.^[[Playwright's documentation on fixtures](https://playwright.dev/docs/test-fixtures)]

When testing blockchain applications there are a few things which are _very_ useful to have set up in fixtures:

- A Viem test client, extended with public- and wallet client actions.
- A date mocking mechanism so we can pretend it's earlier or later.
- An account connection fixture so we don't have to repeat this for each test.

The key thing here, is that you want to grab `test` from `@playwright/test` and re-export it with your fixtures attached. Instead of importing Playwright's `test`, you would import your own, extended with any fixtures you require.

Let's set up our first fixture. This one will concern itself with abstracting connecting a wallet through our mock connector. I'll provide some other useful fixtures in the next chapter.

Lets create two files: `tests/fixtures/wallet.ts` and `tests/fixtures/index.ts`. The former will house our application-specific wallet connection initialization. The latter we'll use as an entrypoint which re-exports anything from `@playwright/test` plus our extended `test` function.

```ts
// tests/fixtures/wallet.ts
import { type Page } from "@playwright/test";
import { type Address, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { test as base } from "@playwright/test";
import { type MockParameters } from "wagmi/connectors";

// It helps if we give accounts names, as it makes discerning
// different accounts more clear. It's easier to talk about
// Alice and Bob in tests than "wallet starting with 0xf39...".
// NOTE: These private keys are provided by `anvil`.
const ACCOUNT_PKEYS = {
  alice: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  bob: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
} as const;

// A fixture doesn't need to be a class. It could just as well
// be a POJO, function, scalar, etc. In our case a class keeps
// things nice and organized.
export class WalletFixture {
  address?: Address;
  #page: Page;

  // The only thing we require for setting up a wallet connection
  // through the mock connector is the page to look up locators.
  constructor({ page }: { page: Page }) {
    this.#page = page;
  }

  // You can make this as contrived or expansive as required for
  // your use-case. For Endgame, we actually derive accounts from
  // an `ANVIL_MNEMONIC` env and viem's `mnemonicToAccount()`.
  async connect(
    name: keyof typeof ACCOUNT_PKEYS,
    features?: MockParameters['features']
  ) {
    const pkey = ACCOUNT_PKEYS[name];
    const account = privateKeyToAccount(pkey);

    this.address = account.address;

    await this.#setup(pkey, features);
    await this.#login();
  }

  // Any application-specific rituals to get a wallet connected
  // can be put here. In our demo app we click a button.
  async #login() {
    await this.#page.getByRole("button", { name: "Mock Connector" }).click();
  }

  // Remember how we slapped our mock configuration helper onto
  // `window._setupAccount`? Here's how to use it in Playwright:
  async #setup(...args: [Hex, MockParameters["features"]]) {
    // We let Playwright wait for the function to be non-nullable
    // on the `window` global. This ensures we can use it.
    await this.#page.waitForFunction(() => window._setupAccount);
    // `page.evaluate()` is a _very_ powerful method which allows
    // you to evaluate a script inside the browser page context.
    // In this example, we evaluate `window._setupAccount()`
    // with arguments passed from inside Playwright tests.
    await this.#page.evaluate((args) => window._setupAccount(...args), args);
  }
}

// Lastly, we export a `test` with the `WalletFixture` attached.
export const test = base.extend<{ wallet: WalletFixture }>({
  async wallet({ page }, use) {
    await use(new WalletFixture({ page }));
  },
});
```

The second file we'll create is `tests/fixtures/index.ts` which will be a central module making fixtures and any other Playwright exports available to our tests:

```ts
// tests/fixtures/index.ts
import { mergeTests } from "@playwright/test";

import { test as walletTest } from "./wallet";

// Re-export anything from Playwright.
export * from "@playwright/test";
// Export our test function, extended with fixtures.
// It'll become useful when we have more fixtures to attach.
export const test = mergeTests(walletTest);
```

Now we can update our `tests/smoke.spec.ts` file to make use of this fixture:

```ts
// tests/smoke.spec.ts
import { expect, test } from "@playwright/test"; // [!code --]
import { expect, test } from "./fixtures"; // [!code ++]
import { UserRejectedRequestError } from "viem"; // [!code ++]

test("load the homepage", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("New Remix App");
});

test("connect wallet", async ({ page }) => { // [!code --]
test("connect wallet", async ({ page, wallet }) => { // [!code ++]
  await page.goto("/");
  await page.getByRole("button", { name: "Mock Connector" }).click(); // [!code --]
  await expect( // [!code --]
    page.getByText("Connected: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266") // [!code --]
  ).toBeVisible(); // [!code --]
  await wallet.connect("alice"); // [!code ++]
  await expect(page.getByText(`Connected: ${wallet.address}`)).toBeVisible(); // [!code ++]
});

test("throw when wallet connect failure", async ({ page, wallet }) => {// [!code ++]
  await page.goto("/"); // [!code ++]
  await Promise.all([ // [!code ++]
    page.waitForEvent( // [!code ++]
      "pageerror", // [!code ++]
      (error) => error.name === "UserRejectedRequestError" // [!code ++]
    ), // [!code ++]
    wallet.connect("alice", { // [!code ++]
      connectError: new UserRejectedRequestError( // [!code ++]
        new Error("Connection failure.") // [!code ++]
      ), // [!code ++]
    }), // [!code ++]
  ]); // [!code ++]
}); // [!code ++]
```

Make sure you have the Remix dev server and anvil node running. Then, `npm test` 🤞

```
> test
> playwright test


Running 3 tests using 3 workers
  3 passed (1.5s)
```

Amazing.

### It travels through time

With Endgame parts of our core functionality depend on time elapsed. Primarily, any rental has a rent duration which, well, dictates the amount of seconds a rental will be considered being actively rented. In order to test the temporal aspects of the protocol we need to travel forwards in time. This way, when a rental has "expired", we can test functionality related to stopping rentals.

A good practice when dealing with time-sensitive protocols is to make your application depend on block time primarily. However, in many cases there's no escaping relying on a browser's `new Date()`. This kind of sucks, because we need to synchronize multiple time sources to reflect the same time.

In this bonus round we'll implement a few Playwright fixtures which enables us to 1) mock the browser's Date initializer and 2) synchronize our test RPC node so that the latest block timestamp reflects the same time.

First, lets add something to our UI so we can verify.

```tsx{% raw %}
// app/_index.tsx
import type { MetaFunction } from "@remix-run/node";
import { useAccount, useConnect, useDisconnect useSwitchChain } from "wagmi"; // [!code --]
import { // [!code ++]
  useAccount, // [!code ++]
  useConnect, // [!code ++]
  useDisconnect, // [!code ++]
  useBlock, // [!code ++]
  useSwitchChain, // [!code ++]
} from "wagmi"; // [!code ++]

export const meta: MetaFunction = () => {
  return [
    { title: "New Remix App" },
    { name: "description", content: "Welcome to Remix!" },
  ];
};

export default function Index() {
  const { address, chain, isConnected } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { chains, switchChainAsync } = useSwitchChain();

  const { data: block } = useBlock(); // [!code ++]
  const blockTime = new Date(Number(block?.timestamp) * 1000).toUTCString(); // [!code ++]
  const browserTime = new Date().toUTCString(); // [!code ++]

  return (
    <div style={{ fontFamily: "system-ui, sans-serif", lineHeight: "1.8" }}>
      <div style={{ padding: 16, marginBottom: 16, border: "solid 1px" }}> // [!code ++]
        <p>Block time: {blockTime}</p> // [!code ++]
        <p>Browser time: {browserTime}</p> // [!code ++]
      </div> // [!code ++]

      <div style={{ padding: 16, border: "solid 1px" }}>
        <p>Connected: {address ?? "no"}</p>

        <p style={{ display: "flex", gap: 8 }}>
          Chain:
          {chains.map((c) => (
            <button
              key={c.id}
              onClick={() => void switchChainAsync({ chainId: c.id })}
              type="button"
            >
              {c === chain && "✅"} {c.name} ({c.id})
            </button>
          ))}
        </p>

        <p style={{ display: "flex", gap: 8 }}>
          {isConnected ? (
            <button onClick={() => disconnect()} type="button">
              Disconnect
            </button>
          ) : (
            connectors.map((connector) => (
              <button
                key={connector.id}
                onClick={() => void connectAsync({ connector })}
                type="button"
              >
                {connector.name}
              </button>
            ))
          )}
        </p>
      </div>
    </div>
  );
}
{% endraw %}```

The result will look something like the screenshot below. When you boot up a new `anvil` instance these times will roughly correlate, but after a little while—refresh the page or force a rerender—these times will diverge more and more. Also note that `blockTime` relates to the currently selected chain. Switching between Ethereum and Foundry will reflect the latest block time on these respective chains.

![Block time and Browser time](/wagmi-demo-pt5.png)

It's high time (ha!) to add some tooling to sync these up. We will create two more fixtures. One responsible for interfacing with `anvil` and another responsible for patching the `Date` constructor browser-side.

First up the `anvil` fixture:

```ts
// tests/fixtures/anvil.ts
import { test as base } from "@playwright/test";
import { createTestClient, http, publicActions, walletActions } from "viem";
import { foundry } from "viem/chains";

const anvil = createTestClient({
  chain: foundry,
  mode: "anvil",
  transport: http(),
})
  .extend(publicActions)
  .extend(walletActions)
  // `client.extend()` is a very low-barrier utility, allowing you
  // to write custom methods for a viem client easily. It receives
  // a callback with the `client` as argument, returning an object
  // with any properties or methods you want to tack on.
  // We return an object with an `async syncDate(date)` method.
  .extend((client) => ({
    async syncDate(date: Date) {
      await client.setNextBlockTimestamp({
        // NOTE: JavaScript Date.getTime returns milliseconds.
        timestamp: BigInt(Math.round(date.getTime() / 1000)),
      });
      // We need to mine a block to commit its next timestamp.
      return client.mine({ blocks: 1 });
    },
  }));

export const test = base.extend<{ anvil: typeof anvil }>({
  async anvil({}, use) {
    await use(anvil);
  },
});
```

Having an `anvil` fixture is generally useful as it allows you to query and interact with the test node inside of your tests. One way we used this is to create a snapshot before each test suite with `let id = await anvil.snapshot()` and restore it after with `await anvil.revert({ id })`.

I digress. Back to the future… err… dates.

We found the most pragmatic way to approach synchronizing date sources is to have the browser synchronize with block time. You could turn flip this approach but we found that having block time be leading yields less and more simple code in your fixture.

Next up, the date fixture which will make use of our anvil fixture so we can use the newly created `anvil` client to fetch the block time to synchronize with the browser when required. We will add two methods.

1. `addDays(n)` which will advance the current `date` `n` amount of days.
2. `set(date)` which will attempt to synchronize the block timestamp and browser `Date` constructor with the passed `date`.

Note the highlighted line which imports from our `./anvil` fixture.

```ts
// tests/fixtures/date.ts
import { test as base } from "./anvil"; // [!code highlight]

export const test = base.extend<{
  date: {
    addDays: (days: number) => Promise<Date>;
    set: (value: number | string | Date) => Promise<Date>;
  };
}>({
  async date({ anvil, page }, use) {
    // We want to keep around a cached reference to be used
    // by `addDays()` as opposed to getting the current date
    // anew each time we call `addDays()`.
    let date = new Date();

    async function addDays(days: number) {
      date = new Date(date.setDate(date.getDate() + days));
      await set(date);
    }

    async function set(value: number | string | Date) {
      date = new Date(value);

      // Attempt to synchronize our test node's block timestamp
      // with the provided `date`. We can't set dates in the past
      // or at the current time: it will throw a Timestamp error.
      try {
        await anvil.syncDate(date);
      } catch (error) {
        console.error(error);
      }

      // Construct our patch to `window.Date`. Yes. We're
      // patching a global. Unfortunately this will mean React
      // will throw hydration warnings, but it will allow us
      // to test with mocked dates regardless.
      const dateInit = date.valueOf();
      const datePatch = `
      Date = class extends Date {
        constructor(...args) {
          super(...args.length ? args : [${dateInit}]);
        }

        now() {
          return super.now() + (${dateInit} - super.now());
        }
      };
      `;

      // Firstly we'll attach it as a `<script>` to the page
      // in Playwright. Whenever you `goto()` or `reload()` in
      // Playwright, the Date patch will be applied.
      await page.addInitScript(datePatch);
      // Secondly, we evaluate the script directly within the
      // Playwright page context. Roughly this should allow us
      // to forgo any `goto()` or `reload()`—assuming any
      // component sensitive to `Date` is rerendered before
      // doing your test assertions.
      await page.evaluate((datePatch) => {
        // Look, mom! A valid use of `eval()`!
        // eslint-disable-next-line no-eval
        eval(datePatch);
      }, datePatch);

      return date;
    }

    await use({ addDays, set });
  },
});
```

One more thing…

We can update our `tests/fixtures/index.ts` file to chuck all our created fixtures onto a single `test()` function.

```ts
// tests/fixtures/index.ts
import { mergeTests } from "@playwright/test";

import { test as anvilTest } from "./anvil"; // [!code ++]
import { test as dateTest } from "./date"; // [!code ++]
import { test as walletTest } from "./wallet";

export * from "@playwright/test";
export const test = mergeTests(walletTest); // [!code --]
export const test = mergeTests(anvilTest, dateTest, walletTest); // [!code ++]

```

We're able to time travel now! Only forwards though.

Lets try it out and add a test.

```ts
// tests/smoke.spec.ts
import { expect, test } from "./fixtures";
import { UserRejectedRequestError } from "viem";

test("load the homepage", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("New Remix App");
});

test("connect wallet", async ({ page, wallet }) => {
  await page.goto("/");
  await wallet.connect("alice");
  await expect(page.getByText(`Connected: ${wallet.address}`)).toBeVisible();
});

test("throw when wallet connect failure", async ({ page, wallet }) => {
  await page.goto("/");
  const [error] = await Promise.all([
    page.waitForEvent("pageerror"),
    wallet.connect("alice", {
      connectError: new UserRejectedRequestError(
        new Error("Connection failure.")
      ),
    }),
  ]);
  expect(error.name).toBe("UserRejectedRequestError");
});

test("synchronize times", async ({ date, page }) => { // [!code ++]
  await date.set("2069-04-20"); // [!code ++]
  await page.goto("/"); // [!code ++]
  await page.getByRole("button", { name: /Foundry/ }).click(); // [!code ++]
  await expect(page.getByText(/Block time/)).toHaveText(/Sat, 20 Apr 2069/); // [!code ++]
  await expect(page.getByText(/Browser time/)).toHaveText(/Sat, 20 Apr 2069/); // [!code ++]
  await date.addDays(69420); // [!code ++]
  // Because our demo app doesn't rerender after patching the // [!code ++]
  // Date constructor we need a `goto()` or `reload()`. // [!code ++]
  await page.reload(); // [!code ++]
  await expect(page.getByText(/Block time/)).toHaveText(/Sun, 15 May 2259/); // [!code ++]
  await expect(page.getByText(/Browser time/)).toHaveText(/Sun, 15 May 2259/); // [!code ++]
}); // [!code ++]
```

When you run `npm test` again, we should get 4 passed tests now. Running this command a second time however makes the `"synchronize times"` test fail. If you read the code in our date fixture carefully you may know why: we can't set the time of our local testnet node to a date in the past. Only forwards.

The solution here is making a snapshot of our chain state before our tests fire and restore this snapshot after all tests are finished.

```ts
// tests/smoke.spec.ts
import { expect, test } from "./fixtures";
import { UserRejectedRequestError } from "viem";

let id: `0x${string}` | undefined; // [!code ++]

test.beforeAll(async ({ anvil }) => { // [!code ++]
  id = await anvil.snapshot(); // [!code ++]
}); // [!code ++]

test.afterAll(async ({ anvil }) => { // [!code ++]
  if (!id) return; // [!code ++]
  await anvil.revert({ id }); // [!code ++]
  id = undefined; // [!code ++]
}); // [!code ++]

test("load the homepage", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("New Remix App");
});

test("connect wallet", async ({ page, wallet }) => {
  await page.goto("/");
  await wallet.connect("alice");
  await expect(page.getByText(`Connected: ${wallet.address}`)).toBeVisible();
});

test("throw when wallet connect failure", async ({ page, wallet }) => {
  await page.goto("/");
  const [error] = await Promise.all([
    page.waitForEvent("pageerror"),
    wallet.connect("alice", {
      connectError: new UserRejectedRequestError(
        new Error("Connection failure.")
      ),
    }),
  ]);
  expect(error.name).toBe("UserRejectedRequestError");
});

test("synchronize times", async ({ date, page }) => {
  await date.set("2069-04-20");
  await page.goto("/");
  await page.getByRole("button", { name: /Foundry/ }).click();
  await expect(page.getByText(/Block time/)).toHaveText(/Sat, 20 Apr 2069/);
  await expect(page.getByText(/Browser time/)).toHaveText(/Sat, 20 Apr 2069/);
  await date.addDays(69420);
  await page.reload();
  await expect(page.getByText(/Block time/)).toHaveText(/Sun, 15 May 2259/);
  await expect(page.getByText(/Browser time/)).toHaveText(/Sun, 15 May 2259/);
});
```

Reboot your `anvil` node. Now you should be able to spam `npm test` as many times as you like—_assuming you set `fullyParallel: false` in you `playwright.config.ts`._

Time to add a cherry on top.

Maybe you caught the fact that the Playwright configuration has a [`webServer` option](https://playwright.dev/docs/test-webserver#multiple-web-servers). The cool thing about `webServer` is that it can be leveraged as a poor-man's service orchestration. `webServer` can be turned into an array of `webServer` entries, meaning we can add our `anvil` initialization here as well.

```ts
// playwright.config.ts
  webServer: { // [!code --]
    command: "npm run start", // [!code --]
    url: "http://127.0.0.1:3000", // [!code --]
    reuseExistingServer: !process.env.CI, // [!code --]
  }, // [!code --]
  webServer: [ // [!code ++]
    { // [!code ++]
      command: "anvil", // [!code ++]
      url: "http://127.0.0.1:8545", // [!code ++]
      reuseExistingServer: !process.env.CI, // [!code ++]
    }, // [!code ++]
    { // [!code ++]
      command: "npm run start", // [!code ++]
      url: "http://127.0.0.1:3000", // [!code ++]
      reuseExistingServer: !process.env.CI, // [!code ++]
    }, // [!code ++]
  ], // [!code ++]
```

Check it out.

<video controls src="/wagmi-demo-pt6.webm" /></video>

## In closing

Woah. This was quite the trip. I hope this walkthrough is helpful for some of you. It was definitely fun to write. I also hope the peak behind the curtain on how we approached testing challenges for Endgame is as enjoyable to read as it is to share.

Be sure to check out the example repository, which should be straightforward to get up and running. I think it's a decent web3 front end development springboard. The commits to the repository roughly corroborate to each of the sections in this walkthrough.

If you have any questions or remarks, be sure to [hit me up on X](https://x.com/rombromz).

*[E2E]: End-to-End
*[RPC]: Remote Procedure Call
*[ROI]: Return on Investment
*[TDD]: Test-Driven Development
*[UI]: User Interface
