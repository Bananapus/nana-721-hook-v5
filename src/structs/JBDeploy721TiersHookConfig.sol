// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBRulesets} from "@bananapus/core/src/interfaces/IJBRulesets.sol";
import {IJB721TokenUriResolver} from "../interfaces/IJB721TokenUriResolver.sol";
import {IJB721TiersHookStore} from "../interfaces/IJB721TiersHookStore.sol";
import {JB721InitTiersConfig} from "./JB721InitTiersConfig.sol";
import {JB721TiersHookFlags} from "./JB721TiersHookFlags.sol";

/// @custom:member name The NFT collection's name.
/// @custom:member symbol The NFT collection's symbol.
/// @custom:member rulesets The contract storing and managing project rulesets.
/// @custom:member baseUri The URI to use as a base for full NFT URIs.
/// @custom:member tokenUriResolver The contract responsible for resolving the URI for each NFT.
/// @custom:member contractUri The URI where this contract's metadata can be found.
/// @custom:member tiersConfig The NFT tiers and pricing config to launch the hook with.
/// @custom:member reserveBeneficiary The default reserved beneficiary for all tiers.
/// @custom:member store The contract to store and manage this hook's data.
/// @custom:member flags A set of boolean options to configure the hook with.
struct JBDeploy721TiersHookConfig {
    string name;
    string symbol;
    IJBRulesets rulesets;
    string baseUri;
    IJB721TokenUriResolver tokenUriResolver;
    string contractUri;
    JB721InitTiersConfig tiersConfig;
    address reserveBeneficiary;
    IJB721TiersHookStore store;
    JB721TiersHookFlags flags;
}
