// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_mintFor_mintReservesFor_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function test721TiersHook_mintReservesFor_mintReservedNft() public {
        uint256 initialSupply = 200; // The number of NFTs available for each tier.
        uint256 totalMinted = 120; // The number of NFTs already minted for each tier (out of `initialSupply`).
        uint256 reservedMinted = 1; // The number of reserve NFTs already minted (out of `totalMinted`).
        uint256 reserveFrequency = 4000; // The frequency at which NFTs are reserved (4000/10000 = 40%).
        uint256 numberOfTiers = 3; // The number of tiers to set up.

        // With 120 total NFTs minted and 1 being a reserve mint, 119 are non-reserved.
        // With a 40% reserve frequency, 47 should be reserved.
        // Accounting for the 1 already minted, there should be 46 pending reserve mints.

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        // Initialize `numberOfTiers` tiers.
        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        // Iterate through the tiers, minting the pending reserves,
        // and ensuring that the correct number of NFTs have been minted.
        for (uint256 tier = 1; tier <= numberOfTiers; tier++) {
            uint256 mintable = hook.test_store().numberOfPendingReservesFor(address(hook), tier);

            // Mint the reserve NFTs for the tier.
            for (uint256 token = 1; token <= mintable; token++) {
                vm.expectEmit(true, true, true, true, address(hook));
                emit MintReservedNft(_generateTokenId(tier, totalMinted + token), tier, reserveBeneficiary, owner);
            }

            vm.prank(owner);
            hook.mintPendingReservesFor(tier, mintable);

            // Assert that the reserve beneficiary has the correct number of NFTs.
            assertEq(hook.balanceOf(reserveBeneficiary), mintable * tier);
        }
    }

    function test721TiersHook_mintReservesFor_mintMultipleReservedToken() public {
        uint256 initialSupply = 200; // The number of NFTs available for each tier.
        uint256 totalMinted = 120; // The number of NFTs already minted for each tier (out of `initialSupply`).
        uint256 reservedMinted = 1; // The number of reserve NFTs already minted (out of `totalMinted`).
        uint256 reserveFrequency = 4000; // The frequency at which NFTs are reserved (4000/10000 = 40%).
        uint256 numberOfTiers = 3; // The number of tiers to set up.

        // With 120 total NFTs minted and 1 being a reserve mint, 119 are non-reserved.
        // With a 40% reserve frequency, 47 should be reserved.
        // Accounting for the 1 already minted, there should be 46 pending reserve mints.

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        // Initialize `numberOfTiers` tiers.
        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );

            // Set the number of reserve NFTs already minted for the tier.
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        uint256 totalMintable; // Keep a running counter of how many reserve NFTs should be mintable.

        JB721TiersMintReservesConfig[] memory reservesToMint = new JB721TiersMintReservesConfig[](numberOfTiers);

        // Iterate through the tiers, calculating how many reserve NFTs should be mintable.
        for (uint256 tier = 1; tier <= numberOfTiers; tier++) {
            uint256 mintable = hook.test_store().numberOfPendingReservesFor(address(hook), tier);
            reservesToMint[tier - 1] = JB721TiersMintReservesConfig({tierId: tier, count: mintable});
            totalMintable += mintable;
            for (uint256 token = 1; token <= mintable; token++) {
                uint256 tokenNonce = totalMinted + token; // Avoid stack too deep
                vm.expectEmit(true, true, true, true, address(hook));
                emit MintReservedNft(_generateTokenId(tier, tokenNonce), tier, reserveBeneficiary, owner);
            }
        }

        // Mint the pending reserve NFTs.
        vm.prank(owner);
        hook.mintPendingReservesFor(reservesToMint);

        // Assert that the reserve beneficiary has the correct number of NFTs.
        assertEq(hook.balanceOf(reserveBeneficiary), totalMintable);
    }

    function test721TiersHook_mintReservesFor_revertIfReservedMintingIsPausedInRuleset() public {
        uint256 initialSupply = 200; // The number of NFTs available for each tier.
        uint256 totalMinted = 120; // The number of NFTs already minted for each tier (out of `initialSupply`).
        uint256 reservedMinted = 1; // The number of reserve NFTs already minted (out of `totalMinted`).
        uint256 reserveFrequency = 4000; // The frequency at which NFTs are reserved (4000/10000 = 40%).
        uint256 numberOfTiers = 3; // The number of tiers to set up.

        // Set up the ruleset to pause reserved minting.
        // This is done with the `JBRulesetMetadata.metadata` field: the second bit is the `mintPendingReservesPaused`
        // bit.
        // See `JB721TiersRulesetMetadataResolver`.
        mockAndExpect(
            mockJBRulesets,
            abi.encodeCall(IJBRulesets.currentOf, projectId),
            abi.encode(
                JBRuleset({
                    cycleNumber: 1,
                    id: block.timestamp,
                    basedOnId: 0,
                    start: block.timestamp,
                    duration: 600,
                    weight: 10e18,
                    decayRate: 0,
                    approvalHook: IJBRulesetApprovalHook(address(0)),
                    metadata: JBRulesetMetadataResolver.packRulesetMetadata(
                        JBRulesetMetadata({
                            reservedRate: 5000, //50%
                            redemptionRate: 5000, //50%
                            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                            pausePay: false,
                            pauseCreditTransfers: false,
                            allowOwnerMinting: true,
                            allowTerminalMigration: false,
                            allowSetTerminals: false,
                            allowControllerMigration: false,
                            allowSetController: false,
                            holdFees: false,
                            useTotalSurplusForRedemptions: false,
                            useDataHookForPay: true,
                            useDataHookForRedeem: true,
                            dataHook: address(0),
                            metadata: 2 // == 010_2
                        })
                        )
                })
            )
        );

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        // Iterate through the tiers, attempting to mint the pending reserves.
        // Ensure that the correct error is thrown.
        for (uint256 tier = 1; tier <= numberOfTiers; tier++) {
            uint256 mintable = hook.test_store().numberOfPendingReservesFor(address(hook), tier);
            vm.prank(owner);
            vm.expectRevert(JB721TiersHook.MINT_RESERVE_NFTS_PAUSED.selector);
            hook.mintPendingReservesFor(tier, mintable);
        }
    }

    function test721TiersHook_mintReservesFor_revertIfNotEnoughPendingReserves() public {
        uint256 initialSupply = 200; // The number of NFTs available for each tier.
        uint256 totalMinted = 120; // The number of NFTs already minted for each tier (out of `initialSupply`).
        uint256 reservedMinted = 1; // The number of reserve NFTs already minted (out of `totalMinted`).
        uint256 reserveFrequency = 4000; // The frequency at which NFTs are reserved (4000/10000 = 40%).

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Initialize `numberOfTiers` tiers.
        for (uint256 i; i < 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        // Iterate through the tiers, attempting to mint more pending reserves than what is available.
        for (uint256 i = 1; i <= 10; i++) {
            // Get the number that we could mint successfully.
            uint256 amount = hook.test_store().numberOfPendingReservesFor(address(hook), i);
            // Increase it by 1 to cause an error, then attempt to mint.
            amount++;
            // Ensure that the correct error is thrown.
            vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
            vm.prank(owner);
            hook.mintPendingReservesFor(i, amount);
        }
    }

    function test721TiersHook_useDefaultReservedBeneficiary() public {
        // TODO: Looks unfinished
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reserveFrequency = 9;

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        for (uint256 i; i < 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );
        }
    }

    function test721TiersHook_noReserveFrequencyIfNoBeneficiarySet() public {
        uint256 initialSupply = 200; // The number of NFTs available for each tier.
        uint256 totalMinted = 120; // The number of NFTs already minted for each tier (out of `initialSupply`).
        uint256 reservedMinted = 10; // The number of reserve NFTs already minted (out of `totalMinted`).
        uint256 reserveFrequency = 9; // The frequency at which NFTs are reserved. For every 9 NFTs minted, 1 is
            // reserved.

        reserveBeneficiary = address(0);
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Initialize `numberOfTiers` tiers, and set the number of reserve NFTs already minted for each tier.
        // Although the `reserveFrequency` is set, it should be ignored since there is no reserve beneficiary.
        for (uint256 i; i < 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        // Fetch the stored tiers.
        JB721Tier[] memory storedTiers = hook.test_store().tiersOf(address(hook), new uint256[](0), false, 0, 10);

        // Make sure the reserve frequency is 0 for all tiers.
        for (uint256 i; i < 10; i++) {
            assertEq(storedTiers[i].reserveFrequency, 0, "Reserve frequency should be zero (no beneficiary set).");
        }
        // Make sure there are no pending reserves for all tiers.
        for (uint256 i; i < 10; i++) {
            assertEq(
                hook.test_store().numberOfPendingReservesFor(address(hook), i + 1),
                0,
                "There should not be any pending reserves (no beneficiary set)."
            );
        }
    }

    function test721TiersHook_mintFor_mintArrayOfTiers() public {
        uint256 numberOfTiers = 3;

        defaultTierConfig.allowOwnerMint = true;
        defaultTierConfig.reserveFrequency = 0;
        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        // Mint 6 NFTs, 2 from each tier.
        uint16[] memory tiersToMint = new uint16[](numberOfTiers * 2);
        for (uint256 i; i < numberOfTiers; i++) {
            tiersToMint[i] = uint16(i) + 1;
            tiersToMint[tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

        vm.prank(owner);
        hook.mintFor(tiersToMint, beneficiary);

        // Assert the balance of the beneficiary after minting.
        assertEq(hook.balanceOf(beneficiary), 6);

        // Assert the ownership of each NFT.
        assertEq(hook.ownerOf(_generateTokenId(1, 1)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 2)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 1)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 2)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(3, 1)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(3, 2)), beneficiary);
    }

    function test721TiersHook_mintFor_revertIfManualMintNotAllowed() public {
        uint256 numberOfTiers = 10;

        uint16[] memory tiersToMint = new uint16[](numberOfTiers * 2);
        for (uint256 i; i < numberOfTiers; i++) {
            tiersToMint[i] = uint16(i) + 1;
            tiersToMint[tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

        // Set the `allowOwnerMint` flag to false and initialize the hook.
        defaultTierConfig.allowOwnerMint = false;
        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        vm.prank(owner);

        // Expect the function call to revert with the specified error message.
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.CANT_MINT_MANUALLY.selector));

        // Call the `mintFor` function to trigger the revert.
        hook.mintFor(tiersToMint, beneficiary);
    }
}
