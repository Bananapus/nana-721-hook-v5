// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_getters_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function test721TiersHook_tiers_returnsAllTiers(uint256 numberOfTiers) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        (, JB721Tier[] memory _tiers) = _createTiers(defaultTierConfig, numberOfTiers);

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        assertTrue(_isIn(hook.test_store().tiersOf(address(hook), new uint256[](0), false, 0, numberOfTiers), _tiers));
        assertTrue(_isIn(_tiers, hook.test_store().tiersOf(address(hook), new uint256[](0), false, 0, numberOfTiers)));
    }

    function test721TiersHook_pricing_packingFunctionsAsExpected(
        uint32 _currency,
        uint8 _decimals,
        address _prices
    )
        public
    {
        JBDeploy721TiersHookConfig memory delegateData = JBDeploy721TiersHookConfig(
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({tiers: tiers, currency: _currency, decimals: _decimals, prices: IJBPrices(_prices)}),
            address(0),
            new JB721TiersHookStore(),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );

        JB721TiersHook hook = JB721TiersHook(address(jbHookDeployer.deployHookFor(projectId, delegateData)));

        (uint256 __currency, uint256 __decimals, IJBPrices __prices) = hook.pricingContext();
        assertEq(__currency, uint256(_currency));
        assertEq(__decimals, uint256(_decimals));
        assertEq(address(__prices), _prices);
    }

    function test721TiersHook_bools_packingFunctionsAsExpected(bool _a, bool _b, bool _c) public {
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        uint8 _packed = _ForTest_store.ForTest_packBools(_a, _b, _c);
        (bool __a, bool __b, bool __c) = _ForTest_store.ForTest_unpackBools(_packed);
        assertEq(_a, __a);
        assertEq(_b, __b);
        assertEq(_c, __c);
    }

    function test721TiersHook_tiers_returnsAllTiersWithResolver(uint256 numberOfTiers) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        // use non-null resolved uri
        defaultTierConfig.encodedIPFSUri = bytes32(hex"69");

        (, JB721Tier[] memory _tiers) = _createTiers(defaultTierConfig, numberOfTiers);

        mockTokenUriResolver = makeAddr("mockTokenUriResolver");
        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        for (uint256 i; i < numberOfTiers; i++) {
            // Mock the URI resolver call
            mockAndExpect(
                mockTokenUriResolver,
                abi.encodeWithSelector(
                    IJB721TokenUriResolver.tokenUriOf.selector, address(hook), _generateTokenId(i + 1, 0)
                ),
                abi.encode(string(abi.encodePacked("resolverURI", _generateTokenId(i + 1, 0))))
            );
        }

        assertTrue(_isIn(hook.test_store().tiersOf(address(hook), new uint256[](0), true, 0, 100), _tiers));
        assertTrue(_isIn(_tiers, hook.test_store().tiersOf(address(hook), new uint256[](0), true, 0, 100)));
    }

    function test721TiersHook_tiers_returnsAllTiersExcludingRemovedOnes(
        uint256 numberOfTiers,
        uint256 firstRemovedTier,
        uint256 secondRemovedTier
    )
        public
    {
        numberOfTiers = bound(numberOfTiers, 1, 30);
        firstRemovedTier = bound(firstRemovedTier, 1, numberOfTiers);
        secondRemovedTier = bound(secondRemovedTier, 1, numberOfTiers);
        vm.assume(firstRemovedTier != secondRemovedTier);

        (, JB721Tier[] memory _tiers) = _createTiers(defaultTierConfig, numberOfTiers);

        // Copy only the tiers we keep
        JB721Tier[] memory _nonRemovedTiers = new JB721Tier[](numberOfTiers - 2);
        uint256 j;
        for (uint256 i; i < numberOfTiers; i++) {
            if (i != firstRemovedTier - 1 && i != secondRemovedTier - 1) {
                _nonRemovedTiers[j] = _tiers[i];
                j++;
            }
        }

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        hook.test_store().ForTest_setIsTierRemoved(address(hook), firstRemovedTier);
        hook.test_store().ForTest_setIsTierRemoved(address(hook), secondRemovedTier);

        JB721Tier[] memory _storedTiers =
            hook.test_store().tiersOf(address(hook), new uint256[](0), false, 0, numberOfTiers);

        // Check: tier array returned is resized
        assertEq(_storedTiers.length, numberOfTiers - 2);

        // Check: all and only the non-removed tiers are in the tier array returned
        assertTrue(_isIn(_storedTiers, _nonRemovedTiers));
        assertTrue(_isIn(_nonRemovedTiers, _storedTiers));
    }

    function test721TiersHook_tier_returnsTheGivenTier(uint256 numberOfTiers, uint16 givenTier) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        (, JB721Tier[] memory _tiers) = _createTiers(defaultTierConfig, numberOfTiers);
        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        // Check: correct tier, if exist?
        if (givenTier <= numberOfTiers && givenTier != 0) {
            assertEq(hook.test_store().tierOf(address(hook), givenTier, false), _tiers[givenTier - 1]);
        } else {
            assertEq( // empty tier if not?
                hook.test_store().tierOf(address(hook), givenTier, false),
                JB721Tier({
                    id: givenTier,
                    price: 0,
                    remainingSupply: 0,
                    initialSupply: 0,
                    votingUnits: 0,
                    reserveFrequency: 0,
                    reserveBeneficiary: address(0),
                    encodedIPFSUri: bytes32(0),
                    category: uint24(100),
                    allowOwnerMint: false,
                    transfersPausable: false,
                    resolvedUri: ""
                })
            );
        }
    }

    function test721TiersHook_totalSupply_returnsTotalSupply(uint256 numberOfTiers) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setTier(
                address(hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(100 - (i + 1)),
                    initialSupply: uint32(100),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(0),
                    category: uint24(100),
                    packedBools: hook.test_store().ForTest_packBools(false, false, false)
                })
            );
        }
        assertEq(hook.test_store().totalSupplyOf(address(hook)), ((numberOfTiers * (numberOfTiers + 1)) / 2));
    }

    function test721TiersHook_balanceOf_returnsCompleteBalance(
        uint256 numberOfTiers,
        address holder
    )
        public
    {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setBalanceOf(address(hook), holder, i + 1, (i + 1) * 10);
        }
        assertEq(hook.balanceOf(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
    }

    function test721TiersHook_numberOfPendingReservesFor_returnsOutstandingReserved() public {
        // 120 are minted, 10 out of these are reserved, meaning 110 non-reserved are minted. The reserveFrequency is
        // 9 (1 reserved token for every 9 non-reserved minted) -> total reserved is 13 (  ceil(110 / 9)), still 3 to
        // mint
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 10;
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
                    packedBools: hook.test_store().ForTest_packBools(false, false, false)
                })
            );
            hook.test_store().ForTest_setReservesMintedFor(address(hook), i + 1, reservedMinted);
        }

        for (uint256 i; i < 10; i++) {
            assertEq(hook.test_store().numberOfPendingReservesFor(address(hook), i + 1), 3);
        }
    }

    function test721TiersHook_getvotingUnits_returnsTheTotalVotingUnits(
        uint256 numberOfTiers,
        uint256 votingUnits,
        uint256 balances
    )
        public
    {
        numberOfTiers = bound(numberOfTiers, 1, 30);
        votingUnits = bound(votingUnits, 1, type(uint32).max);
        balances = bound(balances, 1, type(uint32).max);

        defaultTierConfig.useVotingUnits = true;
        defaultTierConfig.votingUnits = uint32(votingUnits);
        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        // Set one tier voting unit to 0
        hook.test_store().ForTest_setTier(
            address(hook),
            1,
            JBStored721Tier({
                price: uint104(10),
                remainingSupply: uint32(10),
                initialSupply: uint32(20),
                votingUnits: uint16(0),
                reserveFrequency: uint16(100),
                category: uint24(100),
                packedBools: hook.test_store().ForTest_packBools(false, false, true)
            })
        );

        for (uint256 i; i < numberOfTiers; i++) {
            hook.test_store().ForTest_setBalanceOf(address(hook), beneficiary, i + 1, balances);
        }

        assertEq(
            hook.test_store().votingUnitsOf(address(hook), beneficiary),
            numberOfTiers * votingUnits * balances - (votingUnits * balances) // One tier has a 0 voting power
        );
    }

    function test721TiersHook_tierIdOfToken_returnsCorrectTierNumber(
        uint16 _tierId,
        uint16 _tokenNumber
    )
        public
    {
        vm.assume(_tierId > 0 && _tokenNumber > 0);
        uint256 tokenId = _generateTokenId(_tierId, _tokenNumber);
        assertEq(hook.STORE().tierOfTokenId(address(hook), tokenId, false).id, _tierId);
    }

    function test721TiersHook_tokenURI_returnsCorrectUriIfResolverUsed(uint256 tokenId) public {
        mockTokenUriResolver = makeAddr("mockTokenUriResolver");

        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        // Mock the URI resolver call
        mockAndExpect(
            mockTokenUriResolver,
            abi.encodeWithSelector(IJB721TokenUriResolver.tokenUriOf.selector, address(hook), tokenId),
            abi.encode("resolverURI")
        );

        hook.ForTest_setOwnerOf(tokenId, beneficiary);

        assertEq(hook.tokenURI(tokenId), "resolverURI");
    }

    function test721TiersHook_tokenURI_returnsCorrectUriIfNoResolverUsed() public {
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        for (uint256 i = 1; i <= 10; i++) {
            uint256 tokenId = _generateTokenId(i, 1);
            assertEq(hook.tokenURI(tokenId), string(abi.encodePacked(baseUri, theoreticHashes[i - 1])));
        }
    }

    function test721TiersHook_setEncodedIPFSUriOf_returnsCorrectUriIfEncodedAdded() public {
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        uint256 tokenId = _generateTokenId(1, 1);
        hook.ForTest_setOwnerOf(tokenId, address(123));

        vm.prank(owner);
        hook.setMetadata("", "", IJB721TokenUriResolver(address(0)), 1, tokenUris[1]);

        assertEq(hook.tokenURI(tokenId), string(abi.encodePacked(baseUri, theoreticHashes[1])));
    }

    function test721TiersHook_redemptionWeightOf_returnsCorrectWeightAsFloorsCumSum(
        uint256 numberOfTiers,
        uint256 firstTier,
        uint256 lastTier
    )
        public
    {
        numberOfTiers = bound(numberOfTiers, 0, 30);
        lastTier = bound(lastTier, 0, numberOfTiers);
        firstTier = bound(firstTier, 0, lastTier);

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        uint256 _maxNumberOfTiers = (numberOfTiers * (numberOfTiers + 1)) / 2; // "tier amount" of token mintable per
            // tier -> max == numberOfTiers!
        uint256[] memory _tierToGetWeightOf = new uint256[](_maxNumberOfTiers);
        uint256 _iterator;
        uint256 _theoreticalWeight;

        for (uint256 i; i < numberOfTiers; i++) {
            if (i >= firstTier && i < lastTier) {
                for (uint256 j; j <= i; j++) {
                    _tierToGetWeightOf[_iterator] = _generateTokenId(i + 1, j + 1); // "tier" tokens per tier
                    _iterator++;
                }
                _theoreticalWeight += (i + 1) * (i + 1) * 10; //floor is 10
            }
        }

        assertEq(hook.test_store().redemptionWeightOf(address(hook), _tierToGetWeightOf), _theoreticalWeight);
    }

    function test721TiersHook_totalRedemptionWeight_returnsCorrectTotalWeightAsFloorsCumSum(
        uint256 numberOfTiers
    )
        public
    {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        ForTest_JB721TiersHook hook = _initializeForTestHook(numberOfTiers);

        uint256 _theoreticalWeight;

        for (uint256 i = 1; i <= numberOfTiers; i++) {
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
            _theoreticalWeight += (10 * i - 5 * i) * i * 10;
        }
        assertEq(hook.test_store().totalRedemptionWeight(address(hook)), _theoreticalWeight);
    }

    function test721TiersHook_firstOwnerOf_shouldReturnCurrentOwnerIfFirstOwner(
        uint256 tokenId,
        address _owner
    )
        public
    {
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        hook.ForTest_setOwnerOf(tokenId, _owner);
        assertEq(hook.firstOwnerOf(tokenId), _owner);
    }

    function test721TiersHook_firstOwnerOf_shouldReturnFirstOwnerIfOwnerChanged(
        address _owner,
        address _previousOwner
    )
        public
    {
        vm.assume(_owner != _previousOwner);
        vm.assume(_owner != address(0));
        vm.assume(_previousOwner != address(0));

        defaultTierConfig.allowOwnerMint = true;
        defaultTierConfig.reserveFrequency = 0;
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);

        uint16[] memory _tiersToMint = new uint16[](1);
        _tiersToMint[0] = 1;

        uint256 tokenId = _generateTokenId(_tiersToMint[0], 1);

        vm.prank(owner);
        hook.mintFor(_tiersToMint, _previousOwner);

        assertEq(hook.firstOwnerOf(tokenId), _previousOwner);

        vm.prank(_previousOwner);
        IERC721(hook).transferFrom(_previousOwner, _owner, tokenId);

        assertEq(hook.firstOwnerOf(tokenId), _previousOwner);
    }

    function test721TiersHook_firstOwnerOf_shouldReturnAddressZeroIfNotMinted(uint256 tokenId) public {
        ForTest_JB721TiersHook hook = _initializeForTestHook(10);
        assertEq(hook.firstOwnerOf(tokenId), address(0));
    }

    function test721TiersHook_constructor_deployIfNoEmptyinitialSupply(uint256 nbTiers) public {
        nbTiers = bound(nbTiers, 0, 10);
        // Create new tiers array
        ForTest_JB721TiersHook hook = _initializeForTestHook(nbTiers);
        (, JB721Tier[] memory _tiers) = _createTiers(defaultTierConfig, nbTiers);

        // Check: hook has correct parameters?
        assertEq(hook.projectId(), projectId);
        assertEq(address(hook.DIRECTORY()), mockJBDirectory);
        assertEq(hook.name(), name);
        assertEq(hook.symbol(), symbol);
        assertEq(address(hook.STORE().tokenUriResolverOf(address(hook))), mockTokenUriResolver);
        assertEq(hook.contractURI(), contractUri);
        assertEq(hook.owner(), owner);
        assertTrue(_isIn(hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, nbTiers), _tiers)); // Order
            // is not insured
        assertTrue(_isIn(_tiers, hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, nbTiers)));
    }

    function test721TiersHook_constructor_revertDeploymentIfOneEmptyinitialSupply(
        uint256 nbTiers,
        uint256 errorIndex
    )
        public
    {
        nbTiers = bound(nbTiers, 1, 20);
        errorIndex = bound(errorIndex, 0, nbTiers - 1);
        // Create new tiers array
        JB721TierConfig[] memory _tiers = new JB721TierConfig[](nbTiers);
        for (uint256 i; i < nbTiers; i++) {
            _tiers[i] = JB721TierConfig({
                price: uint104(i * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
        }
        _tiers[errorIndex].initialSupply = 0;
        JB721TiersHookStore dataSourceStore = new JB721TiersHookStore();

        // Expect the error at i+1 (as the floor is now smaller than i)
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.NO_SUPPLY.selector));
        vm.etch(hook_i, address(hook).code);
        JB721TiersHook hook = JB721TiersHook(hook_i);
        hook.initialize(
            projectId,
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({
                tiers: _tiers,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            dataSourceStore,
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );
    }
}
