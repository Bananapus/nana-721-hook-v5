// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract Test721TiersHook_redeem_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function test721TiersHook_beforeRedeemContext_returnsCorrectAmount() public {
        uint256 weight;
        uint256 totalWeight;
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set up 10 tiers, with half of the supply minted for each one.
        for (uint256 i = 1; i <= 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i,
                JBStored721Tier({
                    price: uint104(i * 10),
                    remainingSupply: uint32(10 * i - 5 * i),
                    initialSupply: uint32(10 * i),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(0),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, false)
                })
            );
            totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem as if the beneficiary has 1 NFT from each of the first five tiers.
        uint256[] memory tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            uint256 tokenId = _generateTokenId(i + 1, 1);
            hook.ForTest_setOwnerOf(tokenId, beneficiary);
            tokenList[i] = tokenId;
            weight += (i + 1) * 10;
        }

        // Build the metadata with the tiers to redeem.
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(tokenList);

        // Pass the hook ID.
        bytes4[] memory ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        bytes memory hookMetadata = metadataHelper.createMetadata(ids, data);
        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory returnedHook) = hook.beforeRedeemRecordedWith(
            JBBeforeRedeemRecordedContext({
                terminal: address(0),
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                redeemCount: 0,
                totalSupply: 0,
                surplus: SURPLUS,
                reclaimAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                useTotalSurplus: true,
                redemptionRate: REDEMPTION_RATE,
                metadata: hookMetadata
            })
        );

        // Calculate what portion of the surplus should accessible (pro rata relative to weight of NFTs held).
        uint256 base = mulDiv(SURPLUS, weight, totalWeight);
        uint256 claimableSurplus = mulDiv(
            base,
            REDEMPTION_RATE + mulDiv(weight, MAX_RESERVED_RATE() - REDEMPTION_RATE, totalWeight),
            MAX_RESERVED_RATE()
        );
        assertEq(reclaimAmount, claimableSurplus);
        assertEq(address(returnedHook[0].hook), address(hook));
    }

    function test721TiersHook_beforeRedeemContext_returnsZeroAmountIfReserveFrequencyIsZero() public {
        uint256 surplus = 10e18;
        uint256 redemptionRate = 0;
        uint256 weight;
        uint256 totalWeight;

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set up 10 tiers, with half of the supply minted for each one.
        for (uint256 i = 1; i <= 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i,
                JBStored721Tier({
                    price: uint104(i * 10),
                    remainingSupply: uint32(10 * i - 5 * i),
                    initialSupply: uint32(10 * i),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(0),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, false)
                })
            );
            totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem as if the beneficiary has 1 NFT from each of the first five tiers.
        uint256[] memory tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            hook.ForTest_setOwnerOf(i + 1, beneficiary);
            tokenList[i] = i + 1;
            weight += (i + 1) * (i + 1) * 10;
        }

        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory returnedHook) = hook.beforeRedeemRecordedWith(
            JBBeforeRedeemRecordedContext({
                terminal: address(0),
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                redeemCount: 0,
                totalSupply: 0,
                surplus: surplus,
                reclaimAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                useTotalSurplus: true,
                redemptionRate: redemptionRate,
                metadata: abi.encode(bytes32(0), type(IJB721Hook).interfaceId, tokenList)
            })
        );

        assertEq(reclaimAmount, 0);
        assertEq(address(returnedHook[0].hook), address(hook));
    }

    function test721TiersHook_beforeRedeemContext_returnsPartOfOverflowOwnedIfRedemptionRateIsMaximum() public {
        uint256 weight;
        uint256 totalWeight;

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set up 10 tiers, with half of the supply minted for each one.
        for (uint256 i = 1; i <= 10; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i,
                JBStored721Tier({
                    price: uint104(i * 10),
                    remainingSupply: uint32(10 * i - 5 * i),
                    initialSupply: uint32(10 * i),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(0),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, false)
                })
            );
            totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem as if the beneficiary has 1 NFT from each of the first five tiers.
        uint256[] memory tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            hook.ForTest_setOwnerOf(_generateTokenId(i + 1, 1), beneficiary);
            tokenList[i] = _generateTokenId(i + 1, 1);
            weight += (i + 1) * 10;
        }

        // Build the metadata with the tiers to redeem.
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(tokenList);

        // Pass the hook ID.
        bytes4[] memory ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        bytes memory hookMetadata = metadataHelper.createMetadata(ids, data);

        JBBeforeRedeemRecordedContext memory beforeRedeemContext = JBBeforeRedeemRecordedContext({
            terminal: address(0),
            holder: beneficiary,
            projectId: projectId,
            rulesetId: 0,
            redeemCount: 0,
            totalSupply: 0,
            surplus: SURPLUS,
            reclaimAmount: JBTokenAmount({
                token: address(0),
                value: 0,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            }),
            useTotalSurplus: true,
            redemptionRate: REDEMPTION_RATE,
            metadata: hookMetadata
        });

        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory returnedHook) =
            hook.beforeRedeemRecordedWith(beforeRedeemContext);

        // Calculate what portion of the surplus should accessible (pro rata relative to weight of NFTs held).
        uint256 base = mulDiv(SURPLUS, weight, totalWeight);
        assertEq(reclaimAmount, base);
        assertEq(address(returnedHook[0].hook), address(hook));
    }

    function test721TiersHook_beforeRedeemContext_revertIfNonZeroTokenCount(uint256 tokenCount) public {
        vm.assume(tokenCount > 0);

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.UNEXPECTED_TOKEN_REDEEMED.selector));

        hook.beforeRedeemRecordedWith(
            JBBeforeRedeemRecordedContext({
                terminal: address(0),
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                redeemCount: tokenCount,
                totalSupply: 0,
                surplus: 100,
                reclaimAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                useTotalSurplus: true,
                redemptionRate: 100,
                metadata: new bytes(0)
            })
        );
    }

    function test721TiersHook_afterRedeemRecordedWith_burnRedeemedNft(uint256 numberOfNfts) public {
        ForTest_JB721TiersHook hook = _initializeForTestHook(5);

        // Has to all fit in tier 1 (excluding reserve mints).
        numberOfNfts = bound(numberOfNfts, 1, 90);

        // Mock the directory call.
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256[] memory tokenList = new uint256[](numberOfNfts);

        bytes memory hookMetadata;
        bytes[] memory data;
        bytes4[] memory ids;

        for (uint256 i; i < numberOfNfts; i++) {
            uint16[] memory tierIdsToMint = new uint16[](1);
            tierIdsToMint[0] = 1;

            // Build the metadata using the tiers to mint and the overspending flag.
            data = new bytes[](1);
            data[0] = abi.encode(false, tierIdsToMint);

            // Pass the hook ID.
            ids = new bytes4[](1);
            ids[0] = bytes4(bytes20(address(hook)));

            // Generate the metadata.
            hookMetadata = metadataHelper.createMetadata(ids, data);

            // Mint the NFTs. Otherwise, the voting balance is not incremented, which leads to an underflow upon redemption.
            vm.prank(mockTerminalAddress);
            JBAfterPayRecordedContext memory afterPayContext = JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 10, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                // Forward to the hook.
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: hookMetadata
            });

            hook.afterPayRecordedWith(afterPayContext);

            tokenList[i] = _generateTokenId(1, i + 1);

            // Assert that a new NFT was minted.
            assertEq(hook.balanceOf(beneficiary), i + 1);
        }

        // Build the metadata with the tiers to redeem.
        data = new bytes[](1);
        data[0] = abi.encode(tokenList);

        // Pass the hook ID.
        ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        hookMetadata = metadataHelper.createMetadata(ids, data);

        vm.prank(mockTerminalAddress);
        hook.afterRedeemRecordedWith(
            JBAfterRedeemRecordedContext({
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 1,
                redeemCount: 0,
                reclaimedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                forwardedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }), // 0, forwarded to the hook.
                redemptionRate: 5000,
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: hookMetadata
            })
        );

        // Balance should be 0 again
        assertEq(hook.balanceOf(beneficiary), 0);

        // Burn should be counted (`numberOfNfts` in first tier)
        assertEq(hook.test_store().numberOfBurnedFor(address(hook), 1), numberOfNfts);
    }

    function test721TiersHook_afterRedeemRecordedWith_revertIfNotCorrectProjectId(uint8 wrongProjectId) public {
        vm.assume(wrongProjectId != projectId);

        uint256[] memory tokenList = new uint256[](1);
        tokenList[0] = 1;

        // Mock the directory call.
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.INVALID_REDEEM.selector));

        vm.prank(mockTerminalAddress);
        hook.afterRedeemRecordedWith(
            JBAfterRedeemRecordedContext({
                holder: beneficiary,
                projectId: wrongProjectId,
                rulesetId: 1,
                redeemCount: 0,
                reclaimedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                forwardedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }), // 0, forwarded to the hook.
                redemptionRate: 5000,
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: abi.encode(type(IJB721TiersHook).interfaceId, tokenList)
            })
        );
    }

    function test721TiersHook_afterRedeemRecordedWith_revertIfCallerIsNotATerminalOfTheProject() public {
        uint256[] memory tokenList = new uint256[](1);
        tokenList[0] = 1;

        // Mock the directory call.
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.INVALID_REDEEM.selector));

        vm.prank(mockTerminalAddress);
        hook.afterRedeemRecordedWith(
            JBAfterRedeemRecordedContext({
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 1,
                redeemCount: 0,
                reclaimedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                forwardedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }), // 0, forwarded to the hook.
                redemptionRate: 5000,
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: abi.encode(type(IJB721TiersHook).interfaceId, tokenList)
            })
        );
    }

    function test721TiersHook_afterRedeemRecordedWith_revertIfWrongHolder(address wrongHolder, uint8 tokenId) public {
        vm.assume(beneficiary != wrongHolder);
        vm.assume(tokenId != 0);

        ForTest_JB721TiersHook hook = _initializeForTestHook(1);

        hook.ForTest_setOwnerOf(tokenId, beneficiary);

        uint256[] memory tokenList = new uint256[](1);
        tokenList[0] = tokenId;

        // Build the metadata with the tiers to redeem.
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(tokenList);

        // Pass the hook ID.
        bytes4[] memory ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        bytes memory hookMetadata = metadataHelper.createMetadata(ids, data);

        // Mock the directory call.
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.UNAUTHORIZED_TOKEN.selector, tokenId));

        vm.prank(mockTerminalAddress);
        hook.afterRedeemRecordedWith(
            JBAfterRedeemRecordedContext({
                holder: wrongHolder,
                projectId: projectId,
                rulesetId: 1,
                redeemCount: 0,
                reclaimedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                forwardedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }), // 0
                redemptionRate: 5000,
                // fwd to hook
                beneficiary: payable(wrongHolder),
                hookMetadata: bytes(""),
                redeemerMetadata: hookMetadata
            })
        );
    }
}
