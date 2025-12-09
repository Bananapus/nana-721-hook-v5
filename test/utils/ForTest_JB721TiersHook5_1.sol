// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../../src/interfaces/IJB721TiersHook5_1.sol";

import "../../src/JB721TiersHook5_1.sol";
import "../../src/JB721TiersHookStore.sol";

import "../../src/structs/JBBitmapWord.sol";

import "@bananapus/core-v5/src/structs/JBRulesetMetadata.sol";
import "@bananapus/core-v5/src/interfaces/IJBPermissioned.sol";
import {MetadataResolverHelper} from "@bananapus/core-v5/test/helpers/MetadataResolverHelper.sol";

import "@bananapus/core-v5/src/libraries/JBConstants.sol";

import "./UnitTestSetup.sol"; // Only used to get the `PAY_HOOK_ID` and `CASH_OUT_HOOK_ID` constants.
import "./ForTest_JB721TiersHook.sol"; // Import the shared interface

// A customized 721 tiers hook for testing purposes (5_1 version).
contract ForTest_JB721TiersHook5_1 is JB721TiersHook5_1 {
    IJB721TiersHookStore_ForTest public test_store;
    MetadataResolverHelper metadataHelper;

    uint256 constant SURPLUS = 10e18;
    uint256 constant CASH_OUT_TAX_RATE = JBConstants.MAX_CASH_OUT_TAX_RATE; // 40%
    address _trustedForwarder = address(123_456);

    constructor(
        uint256 projectId,
        IJBDirectory directory,
        string memory name,
        string memory symbol,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721TierConfig[] memory tiers,
        IJB721TiersHookStore store,
        JB721TiersHookFlags memory flags
    )
        // The directory is also `IJBPermissioned`.
        JB721TiersHook5_1(directory, IJBPermissioned(address(directory)).PERMISSIONS(), store, _trustedForwarder)
    {
        // Disable the safety check to not allow initializing the original contract
        JB721TiersHook5_1.initialize(
            projectId,
            name,
            symbol,
            baseUri,
            tokenUriResolver,
            contractUri,
            JB721InitTiersConfig({
                tiers: tiers,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            flags
        );
        test_store = IJB721TiersHookStore_ForTest(address(store));

        metadataHelper = new MetadataResolverHelper();
    }

    function ForTest_setOwnerOf(uint256 tokenId, address owner) public {
        _owners[tokenId] = owner;
    }

    function burn(uint256[] memory tokenIds) public {
        for (uint256 i; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
        STORE.recordBurn(tokenIds);
    }
}


