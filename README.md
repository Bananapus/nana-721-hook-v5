# Bananapus NFT Hook

Juicebox projects can use a 721 tiers hook to sell tiered NFTs (ERC-721s) with different prices and artwork. When the project is paid, the hook may mint NFTs to the payer, depending on the hook's setup, the amount paid, and information specified by the payer. The project's owner can enable NFT redemptions through this hook, allowing holders to burn their NFTs to reclaim funds from the project (in proportion to the NFT's price).

_If you're having trouble understanding this contract, take a look at the [core protocol contracts](https://github.com/Bananapus/nana-core) and the [documentation](https://docs.juicebox.money/) first. If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS)._

## Install

For `npm` projects (recommended):

```bash
npm install @bananapus/721-hook
```

For `forge` projects (not recommended):

```bash
forge install Bananapus/nana-721-hook
```

Add `@bananapus/721-hook/=lib/nana-721-hook/` to `remappings.txt`. You'll also need to install `nana-721-hook`'s dependencies and add similar remappings for them.

## Develop

`nana-721-hook` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm install && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

## Scripts

For convenience, several utility commands are available in `package.json`.

| Command                           | Description                            |
| --------------------------------- | -------------------------------------- |
| `npm test`                        | Run local tests.                       |
| `npm run coverage:lcov`           | Generate an LCOV test coverage report. |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet             |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet     |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet             |
| `npm run deploy:optimism-testnet` | Deploy to Optimism testnet             |

## Hooks

This contract is a *data hook*, a *pay hook*, and a *redeem hook*. Data hooks receive information about a payment or a redemption, and put together a payload for the pay/redeem hook to execute.

Juicebox projects can specify a data hook in their `JBRulesetMetadata`. When someone attempts to pay or redeem from the project, the project's terminal records the payment in the terminal store, passing information about the payment/redemption to the data hook in the process. The data hook responds with a list of payloads – each payload specifies the address of a pay/redeem hook, as well as some custom data and an amount of funds to send to that pay/redeem hook.

Each pay/redeem hook can then execute custom behavior based on the custom data (and funds) they receive.

## Mechanism

A project using a 721 tiers hook can specify any number of NFT tiers.

- NFT tiers can be removed by the project owner as long as they are not locked.
- NFT tiers can be added by the project owner as long as they respect the hook's `flags`. The flags specify if newly added tiers can have votes (voting units), if new tiers can have non-zero reserve frequencies, if new tiers can allow on-demand minting by the project's owner, and if the tier can be removed.

Each tier has the following optional properties:

- A price.
- A supply (the maximum number of NFTs which can be minted from the tier).
- A token URI (artwork and metadata), which can be overridden by a URI resolver. The URI resolver can return unique values for each NFT in the tier.
- A category, so tiers can be organized and accessed for different purposes.
- A reserve frequency (optional). With a reserve frequency of 5, an extra NFT will be minted to a pre-specified beneficiary address for every 5 NFTs purchased and minted from the tier.
- A number of votes each NFT should represent on-chain (optional).
- A flag to specify whether the NFTs in the tier can always be transferred, or if transfers can be paused depending on the project's ruleset.
- A flag to specify whether the contract's owner can mint NFTs from the tier on-demand.
- A set of flags which restrict tiers added in the future (the votes/reserved frequency/on-demand minting/can be removed flags noted above).

Additional notes:

- A payer can specify any number of tiers to mint as long as the total price does not exceed the amount being paid. If tiers aren't specified, their payment mints the most expensive tier possible, unless they specify that the hook should not mint any NFTs.
- If the payment and a tier's price are specified in different currencies, the `JBPrices` contract is used to normalize the values.
- If some of a payment does not go towards purchasing an NFT, those extra funds will be stored as "NFT credits" which can be used for future purchases. Optionally, the hook can disallow credits and reject payments with leftover funds.
- If enabled by the project owner, holders can burn their NFTs to reclaim funds from the project. These redemptions are proportional to the NFTs price, relative to the combined price of all the NFTs.
- NFT redemptions can be enabled by setting `useDataHookForRedeem` to `true` in the project's `JBRulesetMetadata`. If NFT redemptions are enabled, project token redemptions are disabled.
- The hook's deployer can choose if the NFTs should support on-chain voting (as `ERC721Votes`). This increases the gas fees to interact with the NFTs, and should be disabled if not needed.

## Architecture

To use a 721 tiers hook, a Juicebox project should be created by a `JB721TiersHookProjectDeployer` instead of a `JBController`. The deployer will create a `JB721TiersHook` (through an associated `JB721TiersHookDeployer`) and add it to the project's first ruleset. New rulesets can be queued through the `JB721TiersHookProjectDeployer` if the project's owner gives it the `QUEUE_RULESETS` permission (`JBPermissions` ID `2`).

All `JB721TiersHook`s store their data in the `JB721TiersHookStore` contract.