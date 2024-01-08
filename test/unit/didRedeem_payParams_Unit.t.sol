// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_redemption_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function test721TiersHook_redeemParams_returnsCorrectAmount() public {
        uint256 _weight;
        uint256 _totalWeight;
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set 10 tiers, with half supply minted for each
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
            _totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem based on holding 1 NFT in each of the 5 first tiers
        uint256[] memory _tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            uint256 tokenId = _generateTokenId(i + 1, 1);
            hook.ForTest_setOwnerOf(tokenId, beneficiary);
            _tokenList[i] = tokenId;
            _weight += (i + 1) * 10;
        }

        //Build the metadata with the tiers to redee
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(_tokenList);

        // Pass the hook ID.
        bytes4[] memory ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        bytes memory hookMetadata = metadataHelper.createMetadata(ids, data);
        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory _returnedDelegate) = hook.beforeRedeemRecordedWith(
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

        // Portion of the surplus accessible (pro rata weight held)
        uint256 _base = mulDiv(SURPLUS, _weight, _totalWeight);
        uint256 _claimableOverflow = mulDiv(
            _base,
            REDEMPTION_RATE + mulDiv(_weight, MAX_RESERVED_RATE() - REDEMPTION_RATE, _totalWeight),
            MAX_RESERVED_RATE()
        );
        assertEq(reclaimAmount, _claimableOverflow);
        assertEq(address(_returnedDelegate[0].hook), address(hook));
    }

    function test721TiersHook_redeemParams_returnsZeroAmountIfreserveFrequencyIsZero() public {
        uint256 _surplus = 10e18;
        uint256 _redemptionRate = 0;
        uint256 _weight;
        uint256 _totalWeight;

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set 10 tiers, with half supply minted for each
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
            _totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem based on holding 1 NFT in each of the 5 first tiers
        uint256[] memory _tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            hook.ForTest_setOwnerOf(i + 1, beneficiary);
            _tokenList[i] = i + 1;
            _weight += (i + 1) * (i + 1) * 10;
        }

        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory _returnedDelegate) = hook.beforeRedeemRecordedWith(
            JBBeforeRedeemRecordedContext({
                terminal: address(0),
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                redeemCount: 0,
                totalSupply: 0,
                surplus: _surplus,
                reclaimAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                useTotalSurplus: true,
                redemptionRate: _redemptionRate,
                metadata: abi.encode(bytes32(0), type(IJB721Hook).interfaceId, _tokenList)
            })
        );

        assertEq(reclaimAmount, 0);
        assertEq(address(_returnedDelegate[0].hook), address(hook));
    }

    function test721TiersHook_redeemParams_returnsPartOfOverflowOwnedIfRedemptionRateIsMaximum() public {
        uint256 _weight;
        uint256 _totalWeight;

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Set 10 tiers, with half supply minted for each
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
            _totalWeight += (10 * i - 5 * i) * i * 10;
        }

        // Redeem based on holding 1 NFT in each of the 5 first tiers
        uint256[] memory _tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            hook.ForTest_setOwnerOf(_generateTokenId(i + 1, 1), beneficiary);
            _tokenList[i] = _generateTokenId(i + 1, 1);
            _weight += (i + 1) * 10;
        }

        //Build the metadata with the tiers to redee
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(_tokenList);

        // Pass the hook ID.
        bytes4[] memory ids = new bytes4[](1);
        ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata.
        bytes memory hookMetadata = metadataHelper.createMetadata(ids, data);

        JBBeforeRedeemRecordedContext memory _redeemParams = JBBeforeRedeemRecordedContext({
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

        (uint256 reclaimAmount, JBRedeemHookSpecification[] memory _returnedDelegate) =
            hook.beforeRedeemRecordedWith(_redeemParams);

        // Portion of the surplus accessible (pro rata weight held)
        uint256 _base = mulDiv(SURPLUS, _weight, _totalWeight);
        assertEq(reclaimAmount, _base);
        assertEq(address(_returnedDelegate[0].hook), address(hook));
    }

    function test721TiersHook_redeemParams_revertIfNonZeroTokenCount(uint256 _tokenCount) public {
        vm.assume(_tokenCount > 0);

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.UNEXPECTED_TOKEN_REDEEMED.selector));

        hook.beforeRedeemRecordedWith(
            JBBeforeRedeemRecordedContext({
                terminal: address(0),
                holder: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                redeemCount: _tokenCount,
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

    function test721TiersHook_afterRedeemRecordedWith_burnRedeemedNFT(uint256 _numberOfNFT) public {
        ForTest_JB721TiersHook hook = _initializeForTestHook(5);

        // Has to all fit in tier 1 minus reserved
        _numberOfNFT = bound(_numberOfNFT, 1, 90);

        // Mock the directory call.
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256[] memory _tokenList = new uint256[](_numberOfNFT);

        bytes memory hookMetadata;
        bytes[] memory data;
        bytes4[] memory ids;

        for (uint256 i; i < _numberOfNFT; i++) {
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

            // We mint the NFTs otherwise the voting balance does not get incremented
            // which leads to underflow on redeem
            vm.prank(mockTerminalAddress);
            JBAfterPayRecordedContext memory _payData = JBAfterPayRecordedContext({
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

            hook.afterPayRecordedWith(_payData);

            _tokenList[i] = _generateTokenId(1, i + 1);

            // Assert that a new NFT was minted
            assertEq(hook.balanceOf(beneficiary), i + 1);
        }

        // Build the metadata with the tiers to redeem
        data = new bytes[](1);
        data[0] = abi.encode(_tokenList);

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
                }), // 0
                redemptionRate: 5000,
                // fwd to hook
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: hookMetadata
            })
        );

        // Balance should be 0 again
        assertEq(hook.balanceOf(beneficiary), 0);

        // Burn should be counted (_numberOfNft in first tier)
        assertEq(hook.test_store().numberOfBurnedFor(address(hook), 1), _numberOfNFT);
    }

    function test721TiersHook_afterRedeemRecordedWith_revertIfNotCorrectProjectId(uint8 _wrongProjectId) public {
        vm.assume(_wrongProjectId != projectId);

        uint256[] memory _tokenList = new uint256[](1);
        _tokenList[0] = 1;

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
                projectId: _wrongProjectId,
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
                }), //sv
                redemptionRate: 5000,
                // 0 fwd to hook
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: abi.encode(type(IJB721TiersHook).interfaceId, _tokenList)
            })
        );
    }

    function test721TiersHook_afterRedeemRecordedWith_revertIfCallerIsNotATerminalOfTheProject() public {
        uint256[] memory _tokenList = new uint256[](1);
        _tokenList[0] = 1;

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
                }), // 0
                redemptionRate: 5000,
                beneficiary: payable(beneficiary),
                hookMetadata: bytes(""),
                redeemerMetadata: abi.encode(type(IJB721TiersHook).interfaceId, _tokenList)
            })
        );
    }

    function test721TiersHook_afterRedeemRecordedWith_RevertIfWrongHolder(address _wrongHolder, uint8 tokenId) public {
        vm.assume(beneficiary != _wrongHolder);
        vm.assume(tokenId != 0);

        ForTest_JB721TiersHook hook = _initializeForTestHook(1);

        hook.ForTest_setOwnerOf(tokenId, beneficiary);

        uint256[] memory _tokenList = new uint256[](1);
        _tokenList[0] = tokenId;

        //Build the metadata with the tiers to redee
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(_tokenList);

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
                holder: _wrongHolder,
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
                beneficiary: payable(_wrongHolder),
                hookMetadata: bytes(""),
                redeemerMetadata: hookMetadata
            })
        );
    }
}
