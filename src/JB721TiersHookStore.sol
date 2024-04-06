// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IJB721TiersHookStore} from "./interfaces/IJB721TiersHookStore.sol";
import {IJB721TokenUriResolver} from "./interfaces/IJB721TokenUriResolver.sol";
import {JBBitmap} from "./libraries/JBBitmap.sol";
import {JBBitmapWord} from "./structs/JBBitmapWord.sol";
import {JB721Tier} from "./structs/JB721Tier.sol";
import {JB721TierConfig} from "./structs/JB721TierConfig.sol";
import {JBStored721Tier} from "./structs/JBStored721Tier.sol";
import {JB721TiersHookFlags} from "./structs/JB721TiersHookFlags.sol";

/// @title JB721TiersHookStore
/// @notice This contract stores and manages data for an `IJB721TiersHook`'s NFTs.
contract JB721TiersHookStore is IJB721TiersHookStore {
    using JBBitmap for mapping(uint256 => uint256);
    using JBBitmap for JBBitmapWord;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error CANT_MINT_MANUALLY();
    error CANT_REMOVE_TIER();
    error PRICE_EXCEEDS_AMOUNT();
    error INSUFFICIENT_PENDING_RESERVES();
    error INVALID_CATEGORY_SORT_ORDER();
    error INVALID_QUANTITY();
    error INVALID_TIER();
    error MAX_TIERS_EXCEEDED();
    error NO_SUPPLY();
    error INSUFFICIENT_SUPPLY_REMAINING();
    error RESERVE_FREQUENCY_NOT_ALLOWED();
    error MANUAL_MINTING_NOT_ALLOWED();
    error TIER_REMOVED();
    error VOTING_UNITS_NOT_ALLOWED();

    //*********************************************************************//
    // -------------------- private constant properties ------------------ //
    //*********************************************************************//

    /// @notice Just a kind reminder to our readers.
    /// @dev Used in 721 token ID generation.
    uint256 private constant _ONE_BILLION = 1_000_000_000;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Returns the largest tier ID currently used on the provided 721 contract.
    /// @dev This may not include the last tier ID if it has been removed.
    /// @custom:param hook The 721 contract to get the largest tier ID from.
    mapping(address hook => uint256) public override maxTierIdOf;

    /// @notice Returns the number of NFTs which the provided owner address owns from the provided 721 contract and tier
    /// ID.
    /// @custom:param hook The 721 contract to get the balance from.
    /// @custom:param owner The address to get the tier balance of.
    /// @custom:param tierId The ID of the tier to get the balance for.
    mapping(address hook => mapping(address owner => mapping(uint256 tierId => uint256))) public override tierBalanceOf;

    /// @notice Returns the number of reserve NFTs which have been minted from the provided tier ID of the provided 721
    /// contract.
    /// @custom:param hook The 721 contract that the tier belongs to.
    /// @custom:param tierId The ID of the tier to get the reserve mint count of.
    mapping(address hook => mapping(uint256 tierId => uint256)) public override numberOfReservesMintedFor;

    /// @notice Returns the number of NFTs which have been burned from the provided tier ID of the provided 721
    /// contract.
    /// @custom:param hook The 721 contract that the tier belongs to.
    /// @custom:param tierId The ID of the tier to get the burn count of.
    mapping(address hook => mapping(uint256 tierId => uint256)) public override numberOfBurnedFor;

    /// @notice Returns the default reserve beneficiary for the provided 721 contract.
    /// @dev If a tier has a reserve beneficiary set, it will override this value.
    /// @custom:param hook The 721 contract to get the default reserve beneficiary of.
    mapping(address hook => address) public override defaultReserveBeneficiaryOf;

    /// @notice Returns the custom token URI resolver which overrides the default token URI resolver for the provided
    /// 721 contract.
    /// @custom:param hook The 721 contract to get the custom token URI resolver of.
    mapping(address hook => IJB721TokenUriResolver) public override tokenUriResolverOf;

    /// @notice Returns the encoded IPFS URI for the provided tier ID of the provided 721 contract.
    /// @dev Token URIs managed by this contract are stored in 32 bytes, based on stripped down IPFS hashes.
    /// @custom:param hook The 721 contract that the tier belongs to.
    /// @custom:param tierId The ID of the tier to get the encoded IPFS URI of.
    /// @custom:returns The encoded IPFS URI.
    mapping(address hook => mapping(uint256 tierId => bytes32)) public override encodedIPFSUriOf;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice Returns the ID of the tier which comes after the provided tier ID (sorted by price).
    /// @dev If empty, assume the next tier ID should come after.
    /// @custom:param hook The address of the 721 contract to get the next tier ID from.
    /// @custom:param tierId The ID of the tier to get the next tier ID in relation to.
    /// @custom:returns The following tier's ID.
    mapping(address hook => mapping(uint256 tierId => uint256)) internal _tierIdAfter;

    /// @notice Returns the reserve beneficiary (if there is one) for the provided tier ID on the provided
    /// `IJB721TiersHook` contract.
    /// @custom:param hook The address of the 721 contract to get the reserve beneficiary from.
    /// @custom:param tierId The ID of the tier to get the reserve beneficiary of.
    /// @custom:returns The address of the reserved token beneficiary.
    mapping(address hook => mapping(uint256 tierId => address)) internal _reserveBeneficiaryOf;

    /// @notice Returns the stored tier of the provided tier ID on the provided `IJB721TiersHook` contract.
    /// @custom:param hook The address of the 721 contract to get the tier from.
    /// @custom:param tierId The ID of the tier to get.
    /// @custom:returns The stored tier, as a `JBStored721Tier` struct.
    mapping(address hook => mapping(uint256 tierId => JBStored721Tier)) internal _storedTierOf;

    /// @notice Returns the flags which dictate the behavior of the provided `IJB721TiersHook` contract.
    /// @custom:param hook The address of the 721 contract to get the flags for.
    /// @custom:returns The flags.
    mapping(address hook => JB721TiersHookFlags) internal _flagsOf;

    /// @notice Get the bitmap word at the provided depth from the provided 721 contract's tier removal bitmap.
    /// @dev See `JBBitmap` for more information.
    /// @custom:param hook The 721 contract to get the bitmap word from.
    /// @custom:param depth The depth of the bitmap row to get. Each row stores 256 tiers.
    /// @custom:returns word The bitmap row's content.
    mapping(address hook => mapping(uint256 depth => uint256 word)) internal _removedTiersBitmapWordOf;

    /// @notice Return the ID of the last sorted tier from the provided 721 contract.
    /// @dev If not set, it is assumed the `maxTierIdOf` is the last sorted tier ID.
    /// @custom:param hook The 721 contract to get the last sorted tier ID from.
    mapping(address hook => uint256) internal _lastTrackedSortedTierIdOf;

    /// @notice Returns the ID of the first tier in the provided category on the provided 721 contract.
    /// @custom:param hook The 721 contract to get the category's first tier ID from.
    /// @custom:param category The category to get the first tier ID of.
    mapping(address hook => mapping(uint256 category => uint256)) internal _startingTierIdOfCategory;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets an array of currently active 721 tiers for the provided 721 contract.
    /// @param hook The 721 contract to get the tiers of.
    /// @param categories An array tier categories to get tiers from. Send an empty array to get all categories.
    /// @param includeResolvedUri If set to `true`, if the contract has a token URI resolver, its content will be
    /// resolved and included.
    /// @param startingId The ID of the first tier to get (sorted by price). Send 0 to get all active tiers.
    /// @param size The number of tiers to include.
    /// @return tiers An array of active 721 tiers.
    function tiersOf(
        address hook,
        uint256[] calldata categories,
        bool includeResolvedUri,
        uint256 startingId,
        uint256 size
    )
        external
        view
        override
        returns (JB721Tier[] memory tiers)
    {
        // Keep a reference to the last tier ID.
        uint256 lastTierId = _lastSortedTierIdOf(hook);

        // Return an empty array if there are no tiers.
        if (lastTierId == 0) return tiers;

        // Initialize an array with the provided length.
        tiers = new JB721Tier[](size);

        // Count the number of tiers to include in the result.
        uint256 numberOfIncludedTiers;

        // Keep a reference to the tier being iterated upon.
        JBStored721Tier memory storedTier;

        // Initialize a `JBBitmapWord` to track if whether tiers have been removed.
        JBBitmapWord memory bitmapWord;

        // Keep a reference to an iterator variable to represent the category being iterated upon.
        uint256 i;

        // Iterate at least once.
        do {
            // Stop iterating if the size limit has been reached.
            if (numberOfIncludedTiers == size) break;

            // Get a reference to the ID of the tier being iterated upon, starting with the first tier ID if no starting
            // ID was specified.
            uint256 currentSortedTierId =
                startingId != 0 ? startingId : _firstSortedTierIdOf(hook, categories.length == 0 ? 0 : categories[i]);

            // Add the tiers from the category being iterated upon.
            while (currentSortedTierId != 0 && numberOfIncludedTiers < size) {
                if (!_isTierRemovedWithRefresh(hook, currentSortedTierId, bitmapWord)) {
                    storedTier = _storedTierOf[hook][currentSortedTierId];

                    // If categories were provided and the current tier's category is greater than category being added,
                    // break.
                    if (categories.length != 0 && storedTier.category > categories[i]) {
                        break;
                    }
                    // If a category is specified and matches, add the returned values.
                    else if (categories.length == 0 || storedTier.category == categories[i]) {
                        // Add the tier to the array being returned.
                        tiers[numberOfIncludedTiers++] =
                            _getTierFrom(hook, currentSortedTierId, storedTier, includeResolvedUri);
                    }
                }
                // Set the next sorted tier ID.
                currentSortedTierId = _nextSortedTierIdOf(hook, currentSortedTierId, lastTierId);
            }

            unchecked {
                i++;
            }
        } while (i < categories.length);

        // Resize the array if there are removed tiers.
        if (numberOfIncludedTiers != size) {
            assembly ("memory-safe") {
                mstore(tiers, numberOfIncludedTiers)
            }
        }
    }

    /// @notice Get the tier with the provided ID from the provided 721 contract.
    /// @param hook The 721 contract to get the tier from.
    /// @param id The ID of the tier to get.
    /// @param includeResolvedUri If set to `true`, if the contract has a token URI resolver, its content will be
    /// resolved and included.
    /// @return The tier.
    function tierOf(
        address hook,
        uint256 id,
        bool includeResolvedUri
    )
        public
        view
        override
        returns (JB721Tier memory)
    {
        return _getTierFrom(hook, id, _storedTierOf[hook][id], includeResolvedUri);
    }

    /// @notice Get the tier of the 721 with the provided token ID in the provided 721 contract.
    /// @param hook The 721 contract that the tier belongs to.
    /// @param tokenId The token ID of the 721 to get the tier of.
    /// @param includeResolvedUri If set to `true`, if the contract has a token URI resolver, its content will be
    /// resolved and included.
    /// @return The tier.
    function tierOfTokenId(
        address hook,
        uint256 tokenId,
        bool includeResolvedUri
    )
        external
        view
        override
        returns (JB721Tier memory)
    {
        // Get a reference to the tier's ID.
        uint256 tierId = tierIdOfToken(tokenId);
        return _getTierFrom(hook, tierId, _storedTierOf[hook][tierId], includeResolvedUri);
    }

    /// @notice Get the number of NFTs which have been minted from the provided 721 contract (across all tiers).
    /// @param hook The 721 contract to get a total supply of.
    /// @return supply The total number of NFTs minted from all tiers on the contract.
    function totalSupplyOf(address hook) external view override returns (uint256 supply) {
        // Keep a reference to the tier being iterated on.
        JBStored721Tier memory storedTier;

        // Keep a reference to the greatest tier ID.
        uint256 maxTierId = maxTierIdOf[hook];

        for (uint256 i = maxTierId; i != 0; i--) {
            // Set the tier being iterated on.
            storedTier = _storedTierOf[hook][i];

            // Increment the total supply by the number of tokens already minted.
            supply += storedTier.initialSupply - storedTier.remainingSupply;
        }
    }

    /// @notice Get the number of pending reserve NFTs for the provided tier ID of the provided 721 contract.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param hook The 721 contract to check for pending reserved NFTs.
    /// @param tierId The ID of the tier to get the number of pending reserves for.
    /// @return The number of pending reserved NFTs.
    function numberOfPendingReservesFor(address hook, uint256 tierId) external view override returns (uint256) {
        return _numberOfPendingReservesFor(hook, tierId, _storedTierOf[hook][tierId]);
    }

    /// @notice Get the number of voting units the provided address has for the provided 721 contract (across all
    /// tiers).
    /// @dev NFTs have a tier-specific number of voting units. If the tier does not have a custom number of voting
    /// units, the price is used.
    /// @param hook The 721 contract to get the voting units within.
    /// @param account The address to get the voting unit total of.
    /// @return units The total voting units the address has within the 721 contract.
    function votingUnitsOf(address hook, address account) external view virtual override returns (uint256 units) {
        // Keep a reference to the greatest tier ID.
        uint256 maxTierId = maxTierIdOf[hook];

        // Keep a reference to the balance being iterated upon.
        uint256 balance;

        // Keep a reference to the stored tier.
        JBStored721Tier memory storedTier;

        // Loop through all tiers.
        for (uint256 i = maxTierId; i != 0; i--) {
            // Get a reference to the account's balance in this tier.
            balance = tierBalanceOf[hook][account][i];

            // If the account has no balance, return.
            if (balance == 0) continue;

            // Get the tier.
            storedTier = _storedTierOf[hook][i];

            // Parse the flags.
            (,, bool useVotingUnits,) = _unpackBools(storedTier.packedBools);

            // Add the voting units for the address' balance in this tier.
            // Use custom voting units if set. Otherwise, use the tier's price.
            units += balance * (useVotingUnits ? storedTier.votingUnits : storedTier.price);
        }
    }

    /// @notice Returns the number of voting units an addresses has within the specified tier of the specified 721
    /// contract.
    /// @dev NFTs have a tier-specific number of voting units. If the tier does not have a custom number of voting
    /// units, the price is used.
    /// @param hook The 721 contract that the tier belongs to.
    /// @param account The address to get the voting units of within the tier.
    /// @param tierId The ID of the tier to get voting units within.
    /// @return The address' voting units within the tier.
    function tierVotingUnitsOf(
        address hook,
        address account,
        uint256 tierId
    )
        external
        view
        virtual
        override
        returns (uint256)
    {
        // Get a reference to the account's balance in this tier.
        uint256 balance = tierBalanceOf[hook][account][tierId];

        if (balance == 0) return 0;

        // Keep a reference to the stored tier.
        JBStored721Tier memory storedTier = _storedTierOf[hook][tierId];

        // Check if voting units should be used. Price will be used otherwise.
        (,, bool useVotingUnits,) = _unpackBools(storedTier.packedBools);

        // Return the address' voting units within the tier.
        return balance * (useVotingUnits ? storedTier.votingUnits : storedTier.price);
    }

    /// @notice Resolves the encoded IPFS URI for the tier of the 721 with the provided token ID from the provided 721
    /// contract.
    /// @param hook The 721 contract that the encoded IPFS URI belongs to.
    /// @param tokenId The token ID of the 721 to get the encoded tier IPFS URI of.
    /// @return The encoded IPFS URI.
    function encodedTierIPFSUriOf(address hook, uint256 tokenId) external view override returns (bytes32) {
        return encodedIPFSUriOf[hook][tierIdOfToken(tokenId)];
    }

    /// @notice Get the flags that dictate the behavior of the provided 721 contract.
    /// @param hook The 721 contract to get the flags of.
    /// @return The flags.
    function flagsOf(address hook) external view override returns (JB721TiersHookFlags memory) {
        return _flagsOf[hook];
    }

    /// @notice Check if the provided tier has been removed from the provided 721 contract.
    /// @param hook The 721 contract the tier belongs to.
    /// @param tierId The ID of the tier to check the removal status of.
    /// @return A bool which is `true` if the tier has been removed, and `false` otherwise.
    function isTierRemoved(address hook, uint256 tierId) external view override returns (bool) {
        JBBitmapWord memory bitmapWord = _removedTiersBitmapWordOf[hook].readId(tierId);

        return bitmapWord.isTierIdRemoved(tierId);
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Get the number of NFTs that the specified address has from the specified 721 contract (across all
    /// tiers).
    /// @param hook The 721 contract to get the balance within.
    /// @param owner The address to check the balance of.
    /// @return balance The number of NFTs the owner has from the 721 contract.
    function balanceOf(address hook, address owner) public view override returns (uint256 balance) {
        // Keep a reference to the greatest tier ID.
        uint256 maxTierId = maxTierIdOf[hook];

        // Loop through all tiers.
        for (uint256 i = maxTierId; i != 0; i--) {
            // Get a reference to the account's balance within this tier.
            balance += tierBalanceOf[hook][owner][i];
        }
    }

    /// @notice The combined redemption weight of the NFTs with the provided token IDs.
    /// @dev Redemption weight is based on 721 price.
    /// @dev Divide this result by the `totalRedemptionWeight` to get the portion of funds that can be reclaimed by
    /// redeeming these NFTs.
    /// @param hook The 721 contract that the NFTs belong to.
    /// @param tokenIds The token IDs of the NFTs to get the redemption weight of.
    /// @return weight The redemption weight.
    function redemptionWeightOf(
        address hook,
        uint256[] calldata tokenIds
    )
        public
        view
        override
        returns (uint256 weight)
    {
        // Get a reference to the total number of tokens.
        uint256 numberOfTokenIds = tokenIds.length;

        // Add each 721's price (from its tier) to the weight.
        for (uint256 i; i < numberOfTokenIds; i++) {
            weight += _storedTierOf[hook][tierIdOfToken(tokenIds[i])].price;
        }
    }

    /// @notice The combined redemption weight for all NFTs from the provided 721 contract.
    /// @param hook The 721 contract to get the total redemption weight of.
    /// @return weight The total redemption weight.
    function totalRedemptionWeight(address hook) public view override returns (uint256 weight) {
        // Keep a reference to the greatest tier ID.
        uint256 maxTierId = maxTierIdOf[hook];

        // Keep a reference to the tier being iterated upon.
        JBStored721Tier memory storedTier;

        // Add each 721's price (from its tier) to the weight.
        for (uint256 i; i < maxTierId; i++) {
            // Keep a reference to the stored tier.
            unchecked {
                storedTier = _storedTierOf[hook][i + 1];
            }

            // Add the tier's price multiplied by the number of NFTs minted from the tier.
            weight += storedTier.price
                * (
                    (storedTier.initialSupply - storedTier.remainingSupply)
                        + _numberOfPendingReservesFor(hook, i + 1, storedTier)
                );
        }
    }

    /// @notice The tier ID for the 721 with the provided token ID.
    /// @dev Tiers are 1-indexed from the `tiers` array, meaning the 0th element of the array is tier 1.
    /// @param tokenId The token ID of the 721 to get the tier ID of.
    /// @return The ID of the 721's tier.
    function tierIdOfToken(uint256 tokenId) public pure override returns (uint256) {
        return tokenId / _ONE_BILLION;
    }

    /// @notice The reserve beneficiary for the provided tier ID on the provided 721 contract.
    /// @param hook The 721 contract that the tier belongs to.
    /// @param tierId The ID of the tier to get the reserve beneficiary of.
    /// @return The reserve beneficiary for the tier.
    function reserveBeneficiaryOf(address hook, uint256 tierId) public view override returns (address) {
        // Get the stored reserve beneficiary.
        address storedReserveBeneficiaryOfTier = _reserveBeneficiaryOf[hook][tierId];

        // If the tier has a beneficiary specified, return it.
        if (storedReserveBeneficiaryOfTier != address(0)) {
            return storedReserveBeneficiaryOfTier;
        }

        // Otherwise, return the contract's default reserve benficiary.
        return defaultReserveBeneficiaryOf[hook];
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Record newly added tiers.
    /// @param tiersToAdd The tiers to add.
    /// @return tierIds The IDs of the tiers being added.
    function recordAddTiers(JB721TierConfig[] calldata tiersToAdd)
        external
        override
        returns (uint256[] memory tierIds)
    {
        // Get a reference to the number of tiers to add.
        uint256 numberOfNewTiers = tiersToAdd.length;

        // Keep a reference to the current greatest tier ID.
        uint256 currentMaxTierIdOf = maxTierIdOf[msg.sender];

        // Make sure the max number of tiers won't be exceeded.
        if (currentMaxTierIdOf + numberOfNewTiers > type(uint16).max) revert MAX_TIERS_EXCEEDED();

        // Keep a reference to the current last sorted tier ID (sorted by price).
        uint256 currentLastSortedTierId = _lastSortedTierIdOf(msg.sender);

        // Initialize an array for the new tier IDs to be returned.
        tierIds = new uint256[](numberOfNewTiers);

        // Keep a reference to the first sorted tier ID, to use when sorting new tiers if needed.
        // There's no need for sorting if there are no current tiers.
        uint256 startSortedTierId = currentMaxTierIdOf == 0 ? 0 : _firstSortedTierIdOf(msg.sender, 0);

        // Keep track of the previous tier's ID while iterating.
        uint256 previousTierId;

        // Keep a reference to the tier being iterated upon.
        JB721TierConfig memory tierToAdd;

        // Keep a reference to the 721 contract's flags.
        JB721TiersHookFlags memory flags = _flagsOf[msg.sender];

        for (uint256 i; i < numberOfNewTiers; i++) {
            // Set the tier being iterated upon.
            tierToAdd = tiersToAdd[i];

            // Make sure the supply maximum is enforced. If it's greater than one billion, it would overflow into the
            // next tier.
            if (tierToAdd.initialSupply > _ONE_BILLION - 1) revert INVALID_QUANTITY();

            // Keep a reference to the previous tier.
            JB721TierConfig memory previousTier;

            // Make sure the tier's category is greater than or equal to the previously added tier's category.
            if (i != 0) {
                // Set the reference to the previously added tier.
                previousTier = tiersToAdd[i - 1];

                // Revert if the category is not equal or greater than the previously added tier's category.
                if (tierToAdd.category < previousTier.category) revert INVALID_CATEGORY_SORT_ORDER();
            }

            // Make sure the new tier doesn't have voting units if the 721 contract's flags don't allow it to.
            if (
                flags.noNewTiersWithVotes
                    && (
                        (tierToAdd.useVotingUnits && tierToAdd.votingUnits != 0)
                            || (!tierToAdd.useVotingUnits && tierToAdd.price != 0)
                    )
            ) {
                revert VOTING_UNITS_NOT_ALLOWED();
            }

            // Make sure the new tier doesn't have a reserve frequency if the 721 contract's flags don't allow it to,
            // OR if manual minting is allowed.
            if ((flags.noNewTiersWithReserves || tierToAdd.allowOwnerMint) && tierToAdd.reserveFrequency != 0) {
                revert RESERVE_FREQUENCY_NOT_ALLOWED();
            }

            // Make sure the new tier doesn't have owner minting enabled if the 721 contract's flags don't allow it to.
            if (flags.noNewTiersWithOwnerMinting && tierToAdd.allowOwnerMint) {
                revert MANUAL_MINTING_NOT_ALLOWED();
            }

            // Make sure the tier has a non-zero supply.
            if (tierToAdd.initialSupply == 0) revert NO_SUPPLY();

            // Get a reference to the ID for the new tier.
            uint256 tierId = currentMaxTierIdOf + i + 1;

            // Store the tier with that ID.
            _storedTierOf[msg.sender][tierId] = JBStored721Tier({
                price: uint104(tierToAdd.price),
                remainingSupply: uint32(tierToAdd.initialSupply),
                initialSupply: uint32(tierToAdd.initialSupply),
                votingUnits: uint40(tierToAdd.votingUnits),
                reserveFrequency: uint16(tierToAdd.reserveFrequency),
                category: uint24(tierToAdd.category),
                packedBools: _packBools(
                    tierToAdd.allowOwnerMint,
                    tierToAdd.transfersPausable,
                    tierToAdd.useVotingUnits,
                    tierToAdd.cannotBeRemoved
                )
            });

            // If this is the first tier in a new category, store it as the first tier in that category.
            // The `_startingTierIdOfCategory` of the category "0" will always be the same as the `_tierIdAfter` the 0th
            // tier.
            if (previousTier.category != tierToAdd.category && tierToAdd.category != 0) {
                _startingTierIdOfCategory[msg.sender][tierToAdd.category] = tierId;
            }

            // Set the reserve beneficiary if needed.
            if (tierToAdd.reserveBeneficiary != address(0)) {
                if (tierToAdd.useReserveBeneficiaryAsDefault) {
                    if (defaultReserveBeneficiaryOf[msg.sender] != tierToAdd.reserveBeneficiary) {
                        defaultReserveBeneficiaryOf[msg.sender] = tierToAdd.reserveBeneficiary;
                    }
                } else {
                    _reserveBeneficiaryOf[msg.sender][tierId] = tierToAdd.reserveBeneficiary;
                }
            }

            // Set the `encodedIPFSUri` if needed.
            if (tierToAdd.encodedIPFSUri != bytes32(0)) {
                encodedIPFSUriOf[msg.sender][tierId] = tierToAdd.encodedIPFSUri;
            }

            if (startSortedTierId != 0) {
                // Keep track of the sorted tier ID being iterated on.
                uint256 currentSortedTierId = startSortedTierId;

                // Keep a reference to the tier ID to iterate to next.
                uint256 nextTierId;

                // Make sure the tier is sorted correctly.
                while (currentSortedTierId != 0) {
                    // Set the next tier ID.
                    nextTierId = _nextSortedTierIdOf(msg.sender, currentSortedTierId, currentLastSortedTierId);

                    // If the category is less than or equal to the sorted tier being iterated on,
                    // AND the tier being iterated on isn't among those being added, store the order.
                    if (
                        tierToAdd.category <= _storedTierOf[msg.sender][currentSortedTierId].category
                            && currentSortedTierId <= currentMaxTierIdOf
                    ) {
                        // If the tier ID being iterated on isn't the next tier ID, set the `_tierIdAfter` (next tier
                        // ID).
                        if (currentSortedTierId != tierId + 1) {
                            _tierIdAfter[msg.sender][tierId] = currentSortedTierId;
                        }

                        // If this is the first tier being added, track it as the current last sorted tier ID (if it's
                        // not already tracked).
                        if (_lastTrackedSortedTierIdOf[msg.sender] != currentLastSortedTierId) {
                            _lastTrackedSortedTierIdOf[msg.sender] = currentLastSortedTierId;
                        }

                        // If the previous tier's `_tierIdAfter` was set to something else, update it.
                        if (previousTierId != tierId - 1 || _tierIdAfter[msg.sender][previousTierId] != 0) {
                            // Set the the previous tier's `_tierIdAfter` to the tier being added, or 0 if the tier ID
                            // is
                            // incremented.
                            _tierIdAfter[msg.sender][previousTierId] = previousTierId == tierId - 1 ? 0 : tierId;
                        }

                        // When the next tier is being added, start at the sorted tier just set.
                        startSortedTierId = currentSortedTierId;

                        // Use the current tier ID as the "previous tier ID" when the next tier is being added.
                        previousTierId = tierId;

                        // Set the current sorted tier ID to zero to break out of the loop (the tier has been sorted).
                        currentSortedTierId = 0;
                    }
                    // If the tier being iterated on is the last tier, add the new tier after it.
                    else if (nextTierId == 0 || nextTierId > currentMaxTierIdOf) {
                        if (tierId != currentSortedTierId + 1) {
                            _tierIdAfter[msg.sender][currentSortedTierId] = tierId;
                        }

                        // For the next tier being added, start at this current tier ID.
                        startSortedTierId = tierId;

                        // Break out.
                        currentSortedTierId = 0;

                        // If there's currently a last sorted tier ID tracked, override it.
                        if (_lastTrackedSortedTierIdOf[msg.sender] != 0) _lastTrackedSortedTierIdOf[msg.sender] = 0;
                    }
                    // Move on to the next tier ID.
                    else {
                        // Set the previous tier ID to be the current tier ID.
                        previousTierId = currentSortedTierId;

                        // Go to the next tier ID.
                        currentSortedTierId = nextTierId;
                    }
                }
            }

            // Add the tier ID to the array being returned.
            tierIds[i] = tierId;
        }

        // Update the maximum tier ID to include the new tiers.
        maxTierIdOf[msg.sender] = currentMaxTierIdOf + numberOfNewTiers;
    }

    /// @notice Record reserve 721 minting for the provided tier ID on the provided 721 contract.
    /// @param tierId The ID of the tier to mint reserves from.
    /// @param count The number of reserve NFTs to mint.
    /// @return tokenIds The token IDs of the reserve NFTs which were minted.
    function recordMintReservesFor(
        uint256 tierId,
        uint256 count
    )
        external
        override
        returns (uint256[] memory tokenIds)
    {
        // Get a reference to the stored tier.
        JBStored721Tier storage storedTier = _storedTierOf[msg.sender][tierId];

        // Get a reference to the number of pending reserve NFTs for the tier.
        // "Pending" means that the NFTs have been reserved, but have not been minted yet.
        uint256 numberOfPendingReserves = _numberOfPendingReservesFor(msg.sender, tierId, storedTier);

        // Can't mint more than the number of pending reserves.
        if (count > numberOfPendingReserves) revert INSUFFICIENT_PENDING_RESERVES();

        // Increment the number of reserve NFTs minted.
        numberOfReservesMintedFor[msg.sender][tierId] += count;

        // Initialize an array for the token IDs to be returned.
        tokenIds = new uint256[](count);

        // Keep a reference to the number of NFTs burned within the tier.
        uint256 numberOfBurnedFromTier = numberOfBurnedFor[msg.sender][tierId];

        for (uint256 i; i < count; i++) {
            // Generate the NFTs.
            tokenIds[i] = _generateTokenId(
                tierId, storedTier.initialSupply - --storedTier.remainingSupply + numberOfBurnedFromTier
            );
        }
    }

    /// @notice Record an 721 transfer.
    /// @param tierId The ID of the tier that the 721 being transferred belongs to.
    /// @param from The address that the 721 is being transferred from.
    /// @param to The address that the 721 is being transferred to.
    function recordTransferForTier(uint256 tierId, address from, address to) external override {
        // If this is not a mint,
        if (from != address(0)) {
            // then subtract the tier balance from the sender.
            --tierBalanceOf[msg.sender][from][tierId];
        }

        // If this is not a burn,
        if (to != address(0)) {
            unchecked {
                // then increase the tier balance for the receiver.
                ++tierBalanceOf[msg.sender][to][tierId];
            }
        }
    }

    /// @notice Record tiers being removed.
    /// @param tierIds The IDs of the tiers being removed.
    function recordRemoveTierIds(uint256[] calldata tierIds) external override {
        // Get a reference to the number of tiers being removed.
        uint256 numTiers = tierIds.length;

        // Keep a reference to the tier ID being iterated upon.
        uint256 tierId;

        for (uint256 i; i < numTiers; i++) {
            // Set the tier being iterated upon (0-indexed).
            tierId = tierIds[i];

            // Get a reference to the stored tier.
            JBStored721Tier storage storedTier = _storedTierOf[msg.sender][tierId];

            // Parse the flags.
            (,,, bool cannotBeRemoved) = _unpackBools(storedTier.packedBools);

            // Make sure the tier can be removed.
            if (cannotBeRemoved) revert CANT_REMOVE_TIER();

            // Remove the tier by marking it as removed in the bitmap.
            _removedTiersBitmapWordOf[msg.sender].removeTier(tierId);
        }
    }

    /// @notice Record 721 mints from the provided tiers.
    /// @param amount The amount being spent on NFTs. The total price must not exceed this amount.
    /// @param tierIds The IDs of the tiers to mint from.
    /// @param isOwnerMint A flag indicating whether this function is being directly called by the 721 contract's owner.
    /// @return tokenIds The token IDs of the NFTs which were minted.
    /// @return leftoverAmount The `amount` remaining after minting.
    function recordMint(
        uint256 amount,
        uint16[] calldata tierIds,
        bool isOwnerMint
    )
        external
        override
        returns (uint256[] memory tokenIds, uint256 leftoverAmount)
    {
        // Set the leftover amount as the initial amount.
        leftoverAmount = amount;

        // Get a reference to the number of tiers.
        uint256 numberOfTiers = tierIds.length;

        // Keep a reference to the tier being iterated on.
        JBStored721Tier storage storedTier;

        // Keep a reference to the tier ID being iterated on.
        uint256 tierId;

        // Initialize the array for the token IDs to be returned.
        tokenIds = new uint256[](numberOfTiers);

        // Initialize a `JBBitmapWord` for checking whether tiers have been removed.
        JBBitmapWord memory bitmapWord;

        for (uint256 i; i < numberOfTiers; i++) {
            // Set the tier ID being iterated on.
            tierId = tierIds[i];

            // Make sure the tier hasn't been removed.
            if (_isTierRemovedWithRefresh(msg.sender, tierId, bitmapWord)) revert TIER_REMOVED();

            // Keep a reference to the stored tier being iterated on.
            storedTier = _storedTierOf[msg.sender][tierId];

            // Parse the flags.
            (bool allowOwnerMint,,,) = _unpackBools(storedTier.packedBools);

            // If this is an owner mint, make sure owner minting is allowed.
            if (isOwnerMint && !allowOwnerMint) revert CANT_MINT_MANUALLY();

            // Make sure the provided tier exists (tiers cannot have a supply of 0).
            if (storedTier.initialSupply == 0) revert INVALID_TIER();

            // Make sure the `amount` is greater than or equal to the tier's price.
            if (storedTier.price > leftoverAmount) revert PRICE_EXCEEDS_AMOUNT();

            // Make sure there are enough NFTs available to mint.
            if (storedTier.remainingSupply <= _numberOfPendingReservesFor(msg.sender, tierId, storedTier)) {
                revert INSUFFICIENT_SUPPLY_REMAINING();
            }

            // Mint the 721.
            unchecked {
                // Keep a reference to its token ID.
                tokenIds[i] = _generateTokenId(
                    tierId,
                    storedTier.initialSupply - --storedTier.remainingSupply + numberOfBurnedFor[msg.sender][tierId]
                );
                leftoverAmount = leftoverAmount - storedTier.price;
            }
        }
    }

    /// @notice Records 721 burns.
    /// @param tokenIds The token IDs of the NFTs to burn.
    function recordBurn(uint256[] calldata tokenIds) external override {
        // Get a reference to the number of token IDs provided.
        uint256 numberOfTokenIds = tokenIds.length;

        // Keep a reference to the token ID being iterated on.
        uint256 tokenId;

        // Iterate through all token IDs to increment the burn count.
        for (uint256 i; i < numberOfTokenIds; i++) {
            // Set the 721's token ID.
            tokenId = tokenIds[i];

            uint256 tierId = tierIdOfToken(tokenId);

            // Increment the number of NFTs burned from the tier.
            numberOfBurnedFor[msg.sender][tierId]++;

            // Increment the remaining supply of the tier.
            _storedTierOf[msg.sender][tierId].remainingSupply++;
        }
    }

    /// @notice Record a newly set token URI resolver.
    /// @param resolver The resolver to set.
    function recordSetTokenUriResolver(IJB721TokenUriResolver resolver) external override {
        tokenUriResolverOf[msg.sender] = resolver;
    }

    /// @notice Record a new encoded IPFS URI for a tier.
    /// @param tierId The ID of the tier to set the encoded IPFS URI of.
    /// @param encodedIPFSUri The encoded IPFS URI to set for the tier.
    function recordSetEncodedIPFSUriOf(uint256 tierId, bytes32 encodedIPFSUri) external override {
        encodedIPFSUriOf[msg.sender][tierId] = encodedIPFSUri;
    }

    /// @notice Record newly set flags.
    /// @param flags The flags to set.
    function recordFlags(JB721TiersHookFlags calldata flags) external override {
        _flagsOf[msg.sender] = flags;
    }

    /// @notice Cleans an 721 contract's removed tiers from the tier sorting sequence.
    /// @param hook The 721 contract to clean tiers for.
    function cleanTiers(address hook) external override {
        // Keep a reference to the last tier ID.
        uint256 lastSortedTierId = _lastSortedTierIdOf(hook);

        // Get a reference to the tier ID being iterated on, starting with the starting tier ID.
        uint256 currentSortedTierId = _firstSortedTierIdOf(hook, 0);

        // Keep track of the previous non-removed tier ID.
        uint256 previousSortedTierId;

        // Initialize a `JBBitmapWord` for tracking removed tiers.
        JBBitmapWord memory bitmapWord;

        // Make the sorted array.
        while (currentSortedTierId != 0) {
            // If the current tier ID being iterated on isn't an increment of the previous one,
            if (!_isTierRemovedWithRefresh(hook, currentSortedTierId, bitmapWord)) {
                // Update its `_tierIdAfter` if needed.
                if (currentSortedTierId != previousSortedTierId + 1) {
                    if (_tierIdAfter[hook][previousSortedTierId] != currentSortedTierId) {
                        _tierIdAfter[hook][previousSortedTierId] = currentSortedTierId;
                    }
                    // Otherwise, if the current tier ID IS an increment of the previous one,
                    // AND the tier ID after it isn't 0,
                } else if (_tierIdAfter[hook][previousSortedTierId] != 0) {
                    // Set its `_tierIdAfter` to 0.
                    _tierIdAfter[hook][previousSortedTierId] = 0;
                }

                // Iterate by setting the previous tier ID for the next loop to the current tier ID.
                previousSortedTierId = currentSortedTierId;
            }
            // Iterate by updating the current sorted tier ID to the next sorted tier ID.
            currentSortedTierId = _nextSortedTierIdOf(hook, currentSortedTierId, lastSortedTierId);
        }

        emit CleanTiers(hook, msg.sender);
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Returns the tier corresponding to the stored tier provided.
    /// @dev Translate `JBStored721Tier` to `JB721Tier`.
    /// @param hook The 721 contract to get the tier from.
    /// @param tierId The ID of the tier to get.
    /// @param storedTier The stored tier to get the corresponding tier for.
    /// @param includeResolvedUri If set to `true`, if the contract has a token URI resolver, its content will be
    /// resolved and included.
    /// @return tier The tier as a `JB721Tier` struct.
    function _getTierFrom(
        address hook,
        uint256 tierId,
        JBStored721Tier memory storedTier,
        bool includeResolvedUri
    )
        internal
        view
        returns (JB721Tier memory)
    {
        // Get a reference to the reserve beneficiary.
        address reserveBeneficiary = reserveBeneficiaryOf(hook, tierId);

        (bool allowOwnerMint, bool transfersPausable, bool useVotingUnits, bool cannotBeRemoved) =
            _unpackBools(storedTier.packedBools);

        return JB721Tier({
            id: tierId,
            price: storedTier.price,
            remainingSupply: storedTier.remainingSupply,
            initialSupply: storedTier.initialSupply,
            votingUnits: useVotingUnits ? storedTier.votingUnits : storedTier.price,
            // No reserve frequency if there is no reserve beneficiary.
            reserveFrequency: reserveBeneficiary == address(0) ? 0 : storedTier.reserveFrequency,
            reserveBeneficiary: reserveBeneficiary,
            encodedIPFSUri: encodedIPFSUriOf[hook][tierId],
            category: storedTier.category,
            allowOwnerMint: allowOwnerMint,
            transfersPausable: transfersPausable,
            cannotBeRemoved: cannotBeRemoved,
            resolvedUri: !includeResolvedUri || tokenUriResolverOf[hook] == IJB721TokenUriResolver(address(0))
                ? ""
                : tokenUriResolverOf[hook].tokenUriOf(hook, _generateTokenId(tierId, 0))
        });
    }

    /// @notice Check whether a tier has been removed while refreshing the relevant bitmap word if needed.
    /// @param hook The 721 contract to check for removals on.
    /// @param tierId The ID of the tier to check the removal status of.
    /// @param bitmapWord The bitmap word to use.
    /// @return A boolean which is `true` if the tier has been removed.
    function _isTierRemovedWithRefresh(
        address hook,
        uint256 tierId,
        JBBitmapWord memory bitmapWord
    )
        internal
        view
        returns (bool)
    {
        // If the current tier ID is outside current bitmap word (depth), refresh the bitmap word.
        if (bitmapWord.refreshBitmapNeeded(tierId) || (bitmapWord.currentWord == 0 && bitmapWord.currentDepth == 0)) {
            bitmapWord = _removedTiersBitmapWordOf[hook].readId(tierId);
        }

        return bitmapWord.isTierIdRemoved(tierId);
    }

    /// @notice Get the number of pending reserve NFTs for the specified tier ID.
    /// @param hook The 721 contract that the tier belongs to.
    /// @param tierId The ID of the tier to get the number of pending reserve NFTs for.
    /// @param storedTier The stored tier to get the number of pending reserve NFTs for.
    /// @return numberReservedTokensOutstanding The number of pending reserve NFTs for the tier.
    function _numberOfPendingReservesFor(
        address hook,
        uint256 tierId,
        JBStored721Tier memory storedTier
    )
        internal
        view
        returns (uint256)
    {
        // No pending reserves if no mints, no reserve frequency, or no reserve beneficiary.
        if (
            storedTier.reserveFrequency == 0 || storedTier.initialSupply == storedTier.remainingSupply
                || reserveBeneficiaryOf(hook, tierId) == address(0)
        ) return 0;

        // The number of reserve NFTs which have already been minted from the tier.
        uint256 numberOfReserveMints = numberOfReservesMintedFor[hook][tierId];

        // If only the reserved 721 (from rounding up) has been minted so far, return 0.
        if (storedTier.initialSupply - numberOfReserveMints == storedTier.remainingSupply) {
            return 0;
        }

        // Get a reference to the number of NFTs minted from the tier (not counting reserve mints or burned tokens).
        uint256 numberOfNonReserveMints;
        unchecked {
            numberOfNonReserveMints = storedTier.initialSupply - storedTier.remainingSupply - numberOfReserveMints;
        }

        // Get the number of total available reserve 721 mints given the number of non-reserve NFTs minted divided by
        // the reserve frequency. This will round down.
        uint256 totalNumberOfAvailableReserveMints = numberOfNonReserveMints / storedTier.reserveFrequency;

        // Round up.
        if (numberOfNonReserveMints % storedTier.reserveFrequency > 0) ++totalNumberOfAvailableReserveMints;

        // Fill out the remaining supply with reserve NFTs if needed.
        if (
            (storedTier.initialSupply % storedTier.reserveFrequency) + totalNumberOfAvailableReserveMints
                > storedTier.initialSupply
        ) {
            totalNumberOfAvailableReserveMints = storedTier.remainingSupply;
        }

        // Make sure there are more available reserve mints than actual reserve mints.
        // This condition becomes possible if some NFTs have been burned.
        if (numberOfReserveMints > totalNumberOfAvailableReserveMints) return 0;

        // Return the difference between the number of available reserve mints and the amount already minted.
        unchecked {
            return totalNumberOfAvailableReserveMints - numberOfReserveMints;
        }
    }

    /// @notice Generate a token ID for an 721 given a tier ID and a token number within that tier.
    /// @param tierId The ID of the tier to generate a token ID for.
    /// @param tokenNumber The token number of the 721 within the tier.
    /// @return The token ID of the 721.
    function _generateTokenId(uint256 tierId, uint256 tokenNumber) internal pure returns (uint256) {
        return (tierId * _ONE_BILLION) + tokenNumber;
    }

    /// @notice Get the tier ID which comes after the provided one when sorted by price.
    /// @param hook The 721 contract to get the next sorted tier ID from.
    /// @param id The tier ID to get the next sorted tier ID relative to.
    /// @param max The maximum tier ID.
    /// @return The next sorted tier ID.
    function _nextSortedTierIdOf(address hook, uint256 id, uint256 max) internal view returns (uint256) {
        // If this is the last tier (maximum), return zero.
        if (id == max) return 0;

        // If a tier ID is saved to come after the provided ID, return it.
        uint256 storedNext = _tierIdAfter[hook][id];

        if (storedNext != 0) return storedNext;

        // Otherwise, increment the provided tier ID.
        return id + 1;
    }

    /// @notice Get the first tier ID from an 721 contract (when sorted by price) within a provided category.
    /// @param hook The 721 contract to get the first sorted tier ID of.
    /// @param category The category to get the first sorted tier ID within. Send 0 for the first ID across all tiers,
    /// which might not be in the 0th category if the 0th category does not exist.
    /// @return id The first sorted tier ID within the provided category.
    function _firstSortedTierIdOf(address hook, uint256 category) internal view returns (uint256 id) {
        id = category == 0 ? _tierIdAfter[hook][0] : _startingTierIdOfCategory[hook][category];
        // Start at the first tier ID if nothing is specified.
        if (id == 0) id = 1;
    }

    /// @notice The last sorted tier ID from an 721 contract (when sorted by price).
    /// @param hook The 721 contract to get the last sorted tier ID of.
    /// @return id The last sorted tier ID.
    function _lastSortedTierIdOf(address hook) internal view returns (uint256 id) {
        id = _lastTrackedSortedTierIdOf[hook];
        // Use the maximum tier ID if nothing is specified.
        if (id == 0) id = maxTierIdOf[hook];
    }

    /// @notice Pack three bools into a single uint8.
    /// @param allowOwnerMint Whether or not owner minting is allowed in new tiers.
    /// @param transfersPausable Whether or not 721 transfers can be paused.
    /// @param useVotingUnits Whether or not custom voting unit amounts are allowed in new tiers.
    /// @param cannotBeRemoved Whether or not attempts to remove the tier will revert.
    /// @return packed The packed bools.
    function _packBools(
        bool allowOwnerMint,
        bool transfersPausable,
        bool useVotingUnits,
        bool cannotBeRemoved
    )
        internal
        pure
        returns (uint8 packed)
    {
        assembly {
            packed := or(allowOwnerMint, packed)
            packed := or(shl(0x1, transfersPausable), packed)
            packed := or(shl(0x2, useVotingUnits), packed)
            packed := or(shl(0x3, cannotBeRemoved), packed)
        }
    }

    /// @notice Unpack three bools from a single uint8.
    /// @param packed The packed bools.
    /// @param allowOwnerMint Whether or not owner minting is allowed in new tiers.
    /// @param transfersPausable Whether or not 721 transfers can be paused.
    /// @param useVotingUnits Whether or not custom voting unit amounts are allowed in new tiers.
    /// @param cannotBeRemoved Whether or not the tier can be removed once added.
    function _unpackBools(uint8 packed)
        internal
        pure
        returns (bool allowOwnerMint, bool transfersPausable, bool useVotingUnits, bool cannotBeRemoved)
    {
        assembly {
            allowOwnerMint := iszero(iszero(and(0x1, packed)))
            transfersPausable := iszero(iszero(and(0x2, packed)))
            useVotingUnits := iszero(iszero(and(0x4, packed)))
            cannotBeRemoved := iszero(iszero(and(0x8, packed)))
        }
    }
}
