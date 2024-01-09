// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract Test721TiersHook_adjustTier_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function test721TiersHook_adjust_tier_remove_tiers_multiple_times(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);
        uint16[] memory tiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        tiersToAdd = _sortArray(tiersToAdd);

        // Initialize the hook with default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create the configs for the new tiers to add.
        (JB721TierConfig[] memory tierConfigs,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, tiersToAdd);

        // Remove 2 tiers and add the new ones.
        uint256 tiersLeft = initialNumberOfTiers;
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 2, tierConfigs);

        // Remove another 2 tiers but don't add any new ones.
        _addDeleteTiers(hook, tiersLeft, 2, new JB721TierConfig[](0));

        // Fecth a maximum of 100 tiers (will downsize).
        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);
        // If the tiers have same category, then the the tiers added last will have a lower index in the array.
        // Otherwise, the tiers would be sorted by categories.
        for (uint256 i = 1; i < storedTiers.length; i++) {
            if (storedTiers[i - 1].category == storedTiers[i].category) {
                assertGt(storedTiers[i - 1].id, storedTiers[i].id, "Sorting error (if same category).");
            } else {
                assertLt(storedTiers[i - 1].category, storedTiers[i].category, "Sorting error (if different category).");
            }
        }
    }

    function test721TiersHook_added_recently_fetched_first_sorted_category_wise_after_tiers_have_been_cleaned(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 3, 14);
        numberOfTiersToAdd = bound(numberOfTiersToAdd, 1, 15);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create the new tiers to add.
        uint256 currentNumberOfTiers = initialNumberOfTiers;

        (JB721TierConfig[] memory tierConfigsToAdd,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        currentNumberOfTiers = _addDeleteTiers(hook, currentNumberOfTiers, 0, tierConfigsToAdd);
        currentNumberOfTiers = _addDeleteTiers(hook, currentNumberOfTiers, 2, tierConfigsToAdd);

        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        assertEq(storedTiers.length, currentNumberOfTiers, "Length mismatch.");
        // If the tiers have same category, then the tiers added last will have a lower index in the array.
        // Otherwise, the tiers would be sorted by categories.
        for (uint256 i = 1; i < storedTiers.length; i++) {
            if (storedTiers[i - 1].category == storedTiers[i].category) {
                assertGt(storedTiers[i - 1].id, storedTiers[i].id, "Sorting error (if same category).");
            } else {
                assertLt(storedTiers[i - 1].category, storedTiers[i].category, "Sorting error (if different category).");
            }
        }
    }

    function test721TiersHook_tiers_added_recently_fetched_first_sorted_category_wise(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create the new tiers to add.
        (JB721TierConfig[] memory tierConfigs,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers.
        uint256 tiersLeft = initialNumberOfTiers;

        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigs);

        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);
        // If the tiers have same category, then the tiers added last will have a lower index in the array.
        // Otherwise, the tiers would be sorted by categories.
        for (uint256 i = 1; i < storedTiers.length; i++) {
            if (storedTiers[i - 1].category == storedTiers[i].category) {
                assertGt(storedTiers[i - 1].id, storedTiers[i].id, "Sorting error (if same category).");
            } else {
                assertLt(storedTiers[i - 1].category, storedTiers[i].category, "Sorting error (if different category).");
            }
        }
    }

    function test721TiersHook_adjustTiers_addNewTiers_with_non_sequential_categories(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory defaultStoredTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        // Create the new tiers to add.
        (JB721TierConfig[] memory tierConfigsToAdd, JB721Tier[] memory tiersToAdd) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd, 2);

        // Add the new tiers.
        uint256 tiersLeft = initialNumberOfTiers;

        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigsToAdd);

        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        // Check: Expected number of tiers?
        assertEq(storedTiers.length, tiersLeft, "Length mismatch.");

        // Check: Are all tiers in the new tiers (unsorted)?
        assertTrue(_isIn(defaultStoredTiers, storedTiers), "Original tiers not stored."); // Original tiers
        assertTrue(_isIn(tiersToAdd, storedTiers), "Added tiers not stored."); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < storedTiers.length; i++) {
            assertLt(storedTiers[i - 1].category, storedTiers[i].category, "Sorting error.");
        }
    }

    function test721TiersHook_adjustTiers_addNewTiers(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory intialTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        // Create the new tiers to add.
        (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory tiersAdded) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers.
        uint256 tiersLeft = initialNumberOfTiers;

        _addDeleteTiers(hook, tiersLeft, 0, tierConfigs);

        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        // Check: Expected number of tiers?
        assertEq(storedTiers.length, intialTiers.length + tiersAdded.length, "Length mismatch.");

        // Check: Are all tiers in the new tiers (unsorted)?
        assertTrue(_isIn(intialTiers, storedTiers), "original tiers not found"); // Original tiers
        assertTrue(_isIn(tiersAdded, storedTiers), "new tiers not found"); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < storedTiers.length; i++) {
            assertLe(storedTiers[i - 1].category, storedTiers[i].category, "Sorting error");
        }
    }

    function test721TiersHook_adjustTiers_with_same_category_multiple_times(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);
        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);

        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers of a given category.
        defaultTierConfig.category = 100;
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add with a new category.
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory tierConfigsToAdd, JB721Tier[] memory tiersToAdd) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers.
        _addDeleteTiers(hook, 0, 0, tierConfigsToAdd);

        (tierConfigsToAdd, tiersToAdd) = _createTiers(defaultTierConfig, numberOfTiersToAdd);

        _addDeleteTiers(hook, 0, 0, tierConfigsToAdd);

        // Check: All tiers stored?
        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);
        assertEq(storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2);

        // Check: Are all tiers in the new tiers (unsorted)?
        uint256[] memory categories = new uint256[](1);
        categories[0] = 101;

        JB721Tier[] memory stored101Tiers =
            hook.STORE().tiersOf(address(hook), categories, false, 0, floorTiersToAdd.length * 2);

        assertEq(stored101Tiers.length, floorTiersToAdd.length * 2);

        // Check: Are all the tiers in the initial tiers?
        categories[0] = 100;
        JB721Tier[] memory stored100Tiers = hook.STORE().tiersOf(address(hook), categories, false, 0, 100);
        assertEq(stored100Tiers.length, initialNumberOfTiers);

        // Check: sorting order.
        for (uint256 i; i < floorTiersToAdd.length; i++) {
            assertGt(stored101Tiers[i].id, stored101Tiers[i + floorTiersToAdd.length].id);
        }
    }

    function test721TiersHook_adjustTiers_with_different_categories(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 1, 10);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers.
        defaultTierConfig.category = 100;
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add.
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory tiersAdded) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers.
        uint256 tiersLeft = initialNumberOfTiers;

        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigs);

        defaultTierConfig.category = 102;
        (tierConfigs, tiersAdded) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigs);

        JB721Tier[] memory allStoredTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, 100);

        uint256[] memory categories = new uint256[](1);
        categories[0] = 102;
        JB721Tier[] memory stored102Tiers = hook.STORE().tiersOf(address(hook), categories, false, 0, 100);

        // Check: does the number of stored 102 tiers match the number of tiers that were added?
        assertEq(stored102Tiers.length, floorTiersToAdd.length);

        // Ensure that each stored 102 tier has category `102`.
        for (uint256 i = 0; i < stored102Tiers.length; i++) {
            assertEq(stored102Tiers[i].category, uint8(102));
        }

        categories[0] = 101;

        JB721Tier[] memory stored101Tiers = hook.STORE().tiersOf(address(hook), categories, false, 0, 100);

        // Check: does the number of stored 101 tiers match the number of tiers that were added?
        assertEq(stored101Tiers.length, floorTiersToAdd.length);

        // Ensure that each stored 102 tier has category `101`.
        for (uint256 i = 0; i < stored101Tiers.length; i++) {
            assertEq(stored101Tiers[i].category, uint8(101));
        }

        // Ensure that the tiers are sorted.
        for (uint256 i = 1; i < initialNumberOfTiers + floorTiersToAdd.length * 2; i++) {
            assertGt(allStoredTiers[i].id, allStoredTiers[i - 1].id);
            assertLe(allStoredTiers[i - 1].category, allStoredTiers[i].category);
        }
    }

    function test721TiersHook_adjustTiers_with_0_category(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Use category 0 for the default tiers.
        defaultTierConfig.category = 0;

        // Initialize the hook with default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add.
        defaultTierConfig.category = 5;
        (JB721TierConfig[] memory tierConfigsToAdd,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd, 2);

        // Add the new tiers.
        uint256 tiersLeft = initialNumberOfTiers;
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigsToAdd);

        // Get all stored tiers (category 0 gets all).
        uint256[] memory categories = new uint256[](1);
        categories[0] = 0;
        JB721Tier[] memory allStoredTiers = hook.STORE().tiersOf(address(hook), categories, false, 0, 100);

        // TODO: I don't understand this check.
        assertEq(allStoredTiers.length, initialNumberOfTiers);
        // Make sure each stored tier is in category 0.
        for (uint256 i = 0; i < allStoredTiers.length; i++) {
            assertEq(allStoredTiers[i].category, uint8(0));
        }
    }

    function test721TiersHook_adjustTiers_with_different_categories_and_fetched_together(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 14);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 1, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize the hook with default tiers of category 100.
        defaultTierConfig.category = 100;
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add (with category 101).
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory tierConfigsToAdd,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the 101 tiers.
        uint256 tiersLeft = initialNumberOfTiers;
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigsToAdd);

        // Create new tiers to add (with category 102).
        defaultTierConfig.category = 102;
        (tierConfigsToAdd,) = _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the 102 tiers.
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigsToAdd);

        // Get the stored tiers with categories 100-102.
        uint256[] memory categories = new uint256[](3);
        categories[0] = 102;
        categories[1] = 100;
        categories[2] = 101;
        JB721Tier[] memory allStoredTiers = hook.STORE().tiersOf(address(hook), categories, false, 0, 100);

        // Ensure the correct number of tiers are stored.
        assertEq(
            allStoredTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2, "Wrong total number of tiers."
        );

        uint256 tier_100_max_index = allStoredTiers.length - floorTiersToAdd.length;

        for (uint256 i = 0; i < floorTiersToAdd.length; i++) {
            assertEq(allStoredTiers[i].category, uint8(102), "Wrong, first category (102).");
        }

        for (uint256 i = floorTiersToAdd.length; i < tier_100_max_index; i++) {
            assertEq(allStoredTiers[i].category, uint8(100), "Wrong, second category (100).");
        }

        for (uint256 i = tier_100_max_index; i < allStoredTiers.length; i++) {
            assertEq(allStoredTiers[i].category, uint8(101), "Wrong, third category (101).");
        }
    }

    function test721TiersHook_adjustTiers_addNewTiers_fetch_specific_tier(
        uint256 initialNumberOfTiers,
        uint256 numberOfTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 14);

        numberOfTiersToAdd = bound(numberOfTiersToAdd, 1, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfTiersToAdd, seed);

        // Sort tiers in ascending order by price.
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize hook with default tiers from category 100.
        defaultTierConfig.category = 100;
        JB721TiersHook hook = _initHookDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add (with category 101).
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory tierConfigsToAdd,) =
            _createTiers(defaultTierConfig, numberOfTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers
        uint256 tiersLeft = initialNumberOfTiers;
        tiersLeft = _addDeleteTiers(hook, tiersLeft, 0, tierConfigsToAdd);

        // Get the tiers from category 101.
        uint256[] memory categories = new uint256[](1);
        categories[0] = 101;
        JB721Tier[] memory storedTiers =
            hook.STORE().tiersOf(address(hook), categories, false, 0, initialNumberOfTiers + floorTiersToAdd.length);

        // Ensure the number of tiers match.
        assertEq(storedTiers.length, floorTiersToAdd.length);

        // Check: Do the tiers have category 101?
        for (uint256 i = 0; i < storedTiers.length; i++) {
            assertEq(storedTiers[i].category, uint8(101));
        }
    }

    function test721TiersHook_adjustTiers_removeTiers(
        uint256 initialNumberOfTiers,
        uint256 seed,
        uint256 numberOfTiersToRemove
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 14);
        numberOfTiersToRemove = bound(numberOfTiersToRemove, 0, initialNumberOfTiers);

        // Create random tiers to remove.
        uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);

        // Use the `seed` to generate new random tiers, and iterate on `i` to fill the `tiersToRemove` array.
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers + 1;
            bool invalidTier;
            if (newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (newTierCandidate == tiersToRemove[j]) {
                        invalidTier = true;
                        break;
                    }
                }
                if (!invalidTier) {
                    tiersToRemove[i] = newTierCandidate;
                    i++;
                }
            }
            // Overflow to loop over (seed is fuzzed, and could start at max(uint256)).
            unchecked {
                seed++;
            }
        }

        // Order the tiers to remove for event matching (which are ordered too).
        tiersToRemove = _sortArray(tiersToRemove);
        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);

        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierConfigs,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);

        // Will be resized later.
        JB721TierConfig[] memory tierConfigsRemaining = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < tiers.length; i++) {
            tierConfigsRemaining[i] = tierConfigs[i];
            tiersRemaining[i] = tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
                if (tiersRemaining[i].id == tiersToRemove[j]) {
                    // Swap and pop removed tiers.
                    tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
                    tierConfigsRemaining[i] = tierConfigsRemaining[tierConfigsRemaining.length - 1];
                    // Remove the last elelment / reduce array length by 1.
                    assembly ("memory-safe") {
                        mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
                        mstore(tierConfigsRemaining, sub(mload(tierConfigsRemaining), 1))
                    }
                    swappedAndPopped = true;
                    break;
                }
            }
            if (!swappedAndPopped) i++;
        }
        // Check: emitted correct event params?
        for (uint256 i; i < tiersToRemove.length; i++) {
            vm.expectEmit(true, false, false, true, address(hook));
            emit RemoveTier(tiersToRemove[i], owner);
        }
        vm.prank(owner);
        hook.adjustTiers(new JB721TierConfig[](0), tiersToRemove);
        {
            uint256 finalNumberOfTiers = initialNumberOfTiers - tiersToRemove.length;
            JB721Tier[] memory storedTiers =
                hook.test_store().tiersOf(address(hook), new uint256[](0), false, 0, finalNumberOfTiers);
            // Check the number of tiers.
            assertEq(storedTiers.length, finalNumberOfTiers);
            // Ensure that all the remaining tiers still exist.
            assertTrue(_isIn(tiersRemaining, storedTiers));
            // Ensure that none of the removed tiers still exist.
            assertTrue(_isIn(storedTiers, tiersRemaining));
        }
    }

    function test721TiersHook_adjustTiers_addAndRemoveTiers() public {
        uint256 initialNumberOfTiers = 5;
        uint256 numberOfTiersToAdd = 5;
        uint256 numberOfTiersToRemove = 3;
        uint256[] memory tiersToAdd = new uint256[](numberOfTiersToAdd);
        tiersToAdd[0] = 1;
        tiersToAdd[1] = 4;
        tiersToAdd[2] = 5;
        tiersToAdd[3] = 6;
        tiersToAdd[4] = 10;
        uint256[] memory tierIdsToRemove = new uint256[](numberOfTiersToRemove);
        tierIdsToRemove[0] = 1;
        tierIdsToRemove[1] = 3;
        tierIdsToRemove[2] = 4;
        // Initial tiers configs and data.
        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        //  Deploy the hook and its store with the initial tiers.
        JB721TiersHookStore store = new JB721TiersHookStore();
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
                tiers: tierConfigs,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        // -- Build expected removed/remaining tiers --
        JB721TierConfig[] memory tierConfigsRemaining = new JB721TierConfig[](2);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](2);
        uint256 arrayIndex;
        for (uint256 i; i < initialNumberOfTiers; i++) {
            // Tiers which will remain.
            if (i + 1 != 1 && i + 1 != 3 && i + 1 != 4) {
                tierConfigsRemaining[arrayIndex] = JB721TierConfig({
                    price: uint104((i + 1) * 10),
                    initialSupply: uint32(100),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(i),
                    reserveBeneficiary: reserveBeneficiary,
                    encodedIPFSUri: tokenUris[0],
                    category: uint24(100),
                    allowOwnerMint: false,
                    useReserveBeneficiaryAsDefault: false,
                    transfersPausable: false,
                    useVotingUnits: true
                });
                tiersRemaining[arrayIndex] = JB721Tier({
                    id: i + 1,
                    price: tierConfigsRemaining[arrayIndex].price,
                    remainingSupply: tierConfigsRemaining[arrayIndex].initialSupply,
                    initialSupply: tierConfigsRemaining[arrayIndex].initialSupply,
                    votingUnits: tierConfigsRemaining[arrayIndex].votingUnits,
                    reserveFrequency: tierConfigsRemaining[arrayIndex].reserveFrequency,
                    reserveBeneficiary: tierConfigsRemaining[arrayIndex].reserveBeneficiary,
                    encodedIPFSUri: tierConfigsRemaining[arrayIndex].encodedIPFSUri,
                    category: tierConfigsRemaining[arrayIndex].category,
                    allowOwnerMint: tierConfigsRemaining[arrayIndex].allowOwnerMint,
                    transfersPausable: tierConfigsRemaining[arrayIndex].transfersPausable,
                    resolvedUri: ""
                });
                arrayIndex++;
            } else {
                // Otherwise, part of the tiers removed:
                // Check: emitted correct event params?
                vm.expectEmit(true, false, false, true, address(hook));
                emit RemoveTier(i + 1, owner);
            }
        }
        // -- Build expected added tiers --
        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberOfTiersToAdd);
        JB721Tier[] memory tiersAdded = new JB721Tier[](numberOfTiersToAdd);
        for (uint256 i; i < numberOfTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104(tiersToAdd[i]) * 11,
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100 + i),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiersAdded[i] = JB721Tier({
                id: tiers.length + (i + 1),
                price: tierConfigsToAdd[i].price,
                remainingSupply: tierConfigsToAdd[i].initialSupply,
                initialSupply: tierConfigsToAdd[i].initialSupply,
                votingUnits: tierConfigsToAdd[i].votingUnits,
                reserveFrequency: tierConfigsToAdd[i].reserveFrequency,
                reserveBeneficiary: tierConfigsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigsToAdd[i].encodedIPFSUri,
                category: tierConfigsToAdd[i].category,
                allowOwnerMint: tierConfigsToAdd[i].allowOwnerMint,
                transfersPausable: tierConfigsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
            vm.expectEmit(true, true, true, true, address(hook));
            emit AddTier(tiersAdded[i].id, tierConfigsToAdd[i], owner);
        }
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, tierIdsToRemove);
        JB721Tier[] memory storedTiers = hook.STORE().tiersOf(
            address(hook),
            new uint256[](0),
            false,
            0,
            7 // 7 tiers remaining - hard-coded to avoid stack too deep.
        );
        // Check: Expected number of remaining tiers?
        assertEq(storedTiers.length, 7);
        // Check: Are all non-deleted and added tiers in the new tiers (unsorted)?
        assertTrue(_isIn(tiersRemaining, storedTiers)); // Original tiers
        assertTrue(_isIn(tiersAdded, storedTiers)); // New tiers
        // Check: Are all the deleted tiers removed?
        assertFalse(_isIn(tiers, storedTiers)); // Will emit `_isIn: incomplete inclusion but without failing assertion`
        // Check: Are all the tiers sorted?
        for (uint256 j = 1; j < storedTiers.length; j++) {
            assertLe(storedTiers[j - 1].category, storedTiers[j].category);
        }
    }

    function test721TiersHook_adjustTiers_revertIfAddingWithVotingPower(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierParams[i].price,
                remainingSupply: tierParams[i].initialSupply,
                initialSupply: tierParams[i].initialSupply,
                votingUnits: tierParams[i].votingUnits,
                reserveFrequency: tierParams[i].reserveFrequency,
                reserveBeneficiary: tierParams[i].reserveBeneficiary,
                encodedIPFSUri: tierParams[i].encodedIPFSUri,
                category: tierParams[i].category,
                allowOwnerMint: tierParams[i].allowOwnerMint,
                transfersPausable: tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierParams,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104(0),
                initialSupply: uint32(100),
                votingUnits: uint16(i + 1),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiersAdded[i] = JB721Tier({
                id: tiers.length + (i + 1),
                price: tierConfigsToAdd[i].price,
                remainingSupply: tierConfigsToAdd[i].initialSupply,
                initialSupply: tierConfigsToAdd[i].initialSupply,
                votingUnits: tierConfigsToAdd[i].votingUnits,
                reserveFrequency: tierConfigsToAdd[i].reserveFrequency,
                reserveBeneficiary: tierConfigsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigsToAdd[i].encodedIPFSUri,
                category: tierConfigsToAdd[i].category,
                allowOwnerMint: tierConfigsToAdd[i].allowOwnerMint,
                transfersPausable: tierConfigsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.VOTING_UNITS_NOT_ALLOWED.selector));
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, new uint256[](0));
    }

    function test721TiersHook_adjustTiers_revertIfAddingWithReserveFrequency(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierConfigs,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i + 1),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiersAdded[i] = JB721Tier({
                id: tiers.length + (i + 1),
                price: tierConfigsToAdd[i].price,
                remainingSupply: tierConfigsToAdd[i].initialSupply,
                initialSupply: tierConfigsToAdd[i].initialSupply,
                votingUnits: tierConfigsToAdd[i].votingUnits,
                reserveFrequency: tierConfigsToAdd[i].reserveFrequency,
                reserveBeneficiary: tierConfigsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigsToAdd[i].encodedIPFSUri,
                category: tierConfigsToAdd[i].category,
                allowOwnerMint: tierConfigsToAdd[i].allowOwnerMint,
                transfersPausable: tierConfigsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.RESERVE_FREQUENCY_NOT_ALLOWED.selector));
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, new uint256[](0));
    }

    function test721TiersHook_adjustTiers_revertIfEmptyQuantity(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierConfigs,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(0),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            tiersAdded[i] = JB721Tier({
                id: tiers.length + (i + 1),
                price: tierConfigsToAdd[i].price,
                remainingSupply: tierConfigsToAdd[i].initialSupply,
                initialSupply: tierConfigsToAdd[i].initialSupply,
                votingUnits: tierConfigsToAdd[i].votingUnits,
                reserveFrequency: tierConfigsToAdd[i].reserveFrequency,
                reserveBeneficiary: tierConfigsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigsToAdd[i].encodedIPFSUri,
                category: tierConfigsToAdd[i].category,
                allowOwnerMint: tierConfigsToAdd[i].allowOwnerMint,
                transfersPausable: tierConfigsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.NO_SUPPLY.selector));
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, new uint256[](0));
    }

    function test721TiersHook_adjustTiers_revertIfRemovingALockedTier(
        uint256 initialNumberOfTiers,
        uint256 lockedTierIndex
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 15);
        lockedTierIndex = bound(lockedTierIndex, 0, initialNumberOfTiers - 1);

        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        JB721TiersHookStore store = new JB721TiersHookStore();
        vm.etch(hook_i, address(hook).code);
        JB721TiersHook hook = JB721TiersHook(hook_i); // TODO: Maybe use a different name for hook here? Works, but
            // confusing given line above.
        hook.initialize(
            projectId,
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({
                tiers: tierConfigs,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        uint256[] memory tierToRemove = new uint256[](1);
        tierToRemove[0] = lockedTierIndex + 1;
        // Check: remove the tier after the lock.
        vm.warp(block.timestamp + 11);
        vm.prank(owner);
        hook.adjustTiers(new JB721TierConfig[](0), tierToRemove);
        // Check: the hook should have one less tier after the removal.
        assertEq(
            hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, initialNumberOfTiers).length,
            initialNumberOfTiers - 1
        );
    }

    function test721TiersHook_adjustTiers_revertIfInvalidCategorySortOrder(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 2, 15);

        ForTest_JB721TiersHook hook = _initializeForTestHook(initialNumberOfTiers);

        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
        }
        tierConfigsToAdd[numberTiersToAdd - 1].category = uint8(99);

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INVALID_CATEGORY_SORT_ORDER.selector));
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, new uint256[](0));
    }

    function test721TiersHook_adjustTiers_revertIfMoreVotingUnitsNotAllowedWithPriceChange(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }

        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierConfigs,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);

        JB721TierConfig[] memory tierConfigsToAdd = new JB721TierConfig[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            tierConfigsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }
        tierConfigsToAdd[numberTiersToAdd - 1].category = uint8(99);
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.VOTING_UNITS_NOT_ALLOWED.selector));
        vm.prank(owner);
        hook.adjustTiers(tierConfigsToAdd, new uint256[](0));
    }

    function test721TiersHook_cleanTiers_removeInactiveTiers(
        uint256 initialNumberOfTiers,
        uint256 seed,
        uint256 numberOfTiersToRemove
    )
        public
    {
        // Include adding X new tiers with 0 current tiers.
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 15);
        numberOfTiersToRemove = bound(numberOfTiersToRemove, 0, initialNumberOfTiers - 1);

        // Create random tiers to remove.
        uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);
        // Use `seed` to generate new random tiers, and iterate on `i` to fill the `tiersToRemove` array.
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
            bool invalidTier;
            if (newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (newTierCandidate == tiersToRemove[j]) {
                        invalidTier = true;
                        break;
                    }
                }
                if (!invalidTier) {
                    tiersToRemove[i] = newTierCandidate;
                    i++;
                }
            }
            // Overflow to loop over (the seed is fuzzed, and may start at max(uint256)).
            unchecked {
                seed++;
            }
        }
        // Order the tiers to remove for event matching (which are ordered too).
        tiersToRemove = _sortArray(tiersToRemove);
        JB721TierConfig[] memory tierConfigs = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            tiers[i] = JB721Tier({
                id: i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tierConfigs,
            IJB721TiersHookStore(address(store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        hook.transferOwnership(owner);
        // Will be resized later
        JB721TierConfig[] memory tierConfigsRemaining = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < tiers.length; i++) {
            tierConfigsRemaining[i] = tierConfigs[i];
            tiersRemaining[i] = tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
                if (tiersRemaining[i].id == tiersToRemove[j]) {
                    // Swap and pop tiers removed
                    tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
                    tierConfigsRemaining[i] = tierConfigsRemaining[tierConfigsRemaining.length - 1];
                    // Remove the last elelment / reduce array length by 1
                    assembly ("memory-safe") {
                        mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
                        mstore(tierConfigsRemaining, sub(mload(tierConfigsRemaining), 1))
                    }
                    swappedAndPopped = true;
                    break;
                }
            }
            if (!swappedAndPopped) i++;
        }
        vm.prank(owner);
        hook.adjustTiers(new JB721TierConfig[](0), tiersToRemove);
        JB721Tier[] memory tiersListDump = hook.test_store().ForTest_dumpTiersList(address(hook));
        // Check: are all of the tiers are still in the linked list (both active and inactive)?
        assertTrue(_isIn(tiers, tiersListDump));
        // Check: does the linked list include only the tiers (active and inactives)?
        assertTrue(_isIn(tiersListDump, tiers));
        // Check: was the correct event emitted?
        vm.expectEmit(true, false, false, true, address(hook.test_store()));
        emit CleanTiers(address(hook), beneficiary);
        vm.startPrank(beneficiary);
        hook.test_store().cleanTiers(address(hook));
        vm.stopPrank();
        tiersListDump = hook.test_store().ForTest_dumpTiersList(address(hook));
        // Check the number of tiers.
        assertEq(tiersListDump.length, initialNumberOfTiers - numberOfTiersToRemove);
        // Check: are the active tiers in the linked list?
        assertTrue(_isIn(tiersRemaining, tiersListDump));
        // Check: does the linked list only contain the active tiers?
        assertTrue(_isIn(tiersListDump, tiersRemaining));
    }

    function test721TiersHook_tiersOf_emptyArrayIfNoInitializedTiers(uint256 size) public {
        // Initialize a hook without default tiers.
        JB721TiersHook hook = _initHookDefaultTiers(0);

        // Try to get `size` tiers
        JB721Tier[] memory intialTiers = hook.STORE().tiersOf(address(hook), new uint256[](0), false, 0, size);

        // Check: Array of size 0?
        assertEq(intialTiers.length, 0, "Length mismatch.");
    }
}
