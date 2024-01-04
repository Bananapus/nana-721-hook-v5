// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity 0.8.23;

import "src/interfaces/IJB721TiersHook.sol";

import "src/JB721TiersHook.sol";
import "src/JB721TiersHookStore.sol";

import "src/structs/JBBitmapWord.sol";

import "lib/juice-contracts-v4/src/structs/JBRulesetMetadata.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBPermissioned.sol";
import {MetadataResolverHelper} from "lib/juice-contracts-v4/test/helpers/MetadataResolverHelper.sol";

import "lib/juice-contracts-v4/src/libraries/JBConstants.sol";

import "./UnitTestSetup.sol"; // Only to get the PAY_HOOK_ID and REDEEM_HOOK_ID constants...

interface IJB721TiersHookStore_ForTest is IJB721TiersHookStore {
    function ForTest_dumpTiersList(address nft) external view returns (JB721Tier[] memory tiers);
    function ForTest_setTier(address hook, uint256 index, JBStored721Tier calldata newTier) external;
    function ForTest_setBalanceOf(address hook, address holder, uint256 tier, uint256 balance) external;
    function ForTest_setReservesMintedFor(address hook, uint256 tier, uint256 amount) external;
    function ForTest_setIsTierRemoved(address hook, uint256 tokenId) external;
    function ForTest_packBools(
        bool allowOwnerMint,
        bool transfersPausable,
        bool useVotingUnits
    )
=======
pragma solidity ^0.8.16;

import "../../interfaces/IJBTiered721Delegate.sol";

import "../../JBTiered721Delegate.sol";
import "../../JBTiered721DelegateStore.sol";

import "../../structs/JBBitmapWord.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatable.sol";
import {JBDelegateMetadataHelper} from '@jbx-protocol/juice-delegate-metadata-lib/src/JBDelegateMetadataHelper.sol';

import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";

import "./UnitTestSetup.sol"; // Only to get the PAY_DELEGATE_ID and REDEEM_DELEGATE_ID constants...

interface IJBTiered721DelegateStore_ForTest is IJBTiered721DelegateStore {
    function ForTest_dumpTiersList(address _nft) external view returns (JB721Tier[] memory _tiers);
    function ForTest_setTier(address _delegate, uint256 index, JBStored721Tier calldata newTier) external;
    function ForTest_setBalanceOf(address _delegate, address holder, uint256 tier, uint256 balance) external;
    function ForTest_setReservesMintedFor(address _delegate, uint256 tier, uint256 amount) external;
    function ForTest_setIsTierRemoved(address _delegate, uint256 _tokenId) external;
    function ForTest_packBools(bool _allowManualMint, bool _transfersPausable, bool _useVotingUnits)
>>>>>>> intermediate
        external
        returns (uint8);
}

<<<<<<< HEAD
contract ForTest_JB721TiersHook is JB721TiersHook {
    IJB721TiersHookStore_ForTest public test_store;
    MetadataResolverHelper metadataHelper;

    uint256 constant SURPLUS = 10e18;
    uint256 constant REDEMPTION_RATE = JBConstants.MAX_RESERVED_RATE; // 40%

    constructor(
        uint256 projectId,
        IJBDirectory directory,
        string memory name,
        string memory symbol,
        IJBRulesets rulesets,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721TierConfig[] memory tiers,
        IJB721TiersHookStore _test_store,
        JB721TiersHookFlags memory flags
    )
        // The directory is also an IJBPermissioned
        JB721TiersHook(directory, IJBPermissioned(address(directory)).operatorStore(), PAY_HOOK_ID, REDEEM_HOOK_ID)
    {
        // Disable the safety check to not allow initializing the original contract
        codeOrigin = address(0);
        JB721TiersHook.initialize(
            projectId,
            name,
            symbol,
            rulesets,
            baseUri,
            tokenUriResolver,
            contractUri,
            JB721InitTiersConfig({tiers: tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            _test_store,
            flags
        );
        test_store = IJB721TiersHookStore_ForTest(address(_test_store));

        metadataHelper = new MetadataResolverHelper();
    }

    function ForTest_setOwnerOf(uint256 tokenId, address owner) public {
        _owners[tokenId] = owner;
    }
}

contract ForTest_JB721TiersHookStore is JB721TiersHookStore, IJB721TiersHookStore_ForTest {
    using JBBitmap for mapping(uint256 => uint256);
    using JBBitmap for JBBitmapWord;

    function ForTest_dumpTiersList(address nft) public view override returns (JB721Tier[] memory tiers) {
        // Keep a reference to the max tier ID.
        uint256 maxTierId = maxTierIdOf[nft];
        // Initialize an array with the appropriate length.
        tiers = new JB721Tier[](maxTierId);
        // Count the number of included tiers.
        uint256 numberOfIncludedTiers;
        // Get a reference to the index being iterated on, starting with the starting index.
        uint256 currentSortIndex = _firstSortedTierIdOf(nft, 0);
        // Keep a reference to the tier being iterated on.
        JBStored721Tier memory storedTier;
        // Make the sorted array.
        while (currentSortIndex != 0 && numberOfIncludedTiers < maxTierId) {
            storedTier = _storedTierOf[nft][currentSortIndex];

            // Unpack stored tier
            (bool allowOwnerMint, bool transfersPausable,) = _unpackBools(storedTier.packedBools);

            // Add the tier to the array being returned.
            tiers[numberOfIncludedTiers++] = JB721Tier({
                id: currentSortIndex,
                price: storedTier.price,
                remainingSupply: storedTier.remainingSupply,
                initialSupply: storedTier.initialSupply,
                votingUnits: storedTier.votingUnits,
                reserveFrequency: storedTier.reserveFrequency,
                reserveBeneficiary: reserveBeneficiaryOf(nft, currentSortIndex),
                encodedIPFSUri: encodedIPFSUriOf[nft][currentSortIndex],
                category: storedTier.category,
                allowOwnerMint: allowOwnerMint,
                transfersPausable: transfersPausable,
                resolvedUri: ""
            });
            // Set the next sort index.
            currentSortIndex = _nextSortedTierIdOf(nft, currentSortIndex, maxTierId);
        }
        // Drop the empty tiers at the end of the array (coming from maxTierIdOf which *might* be bigger than actual
        // bigger tier)
        for (uint256 i = tiers.length - 1; i >= 0; i--) {
            if (tiers[i].id == 0) {
                assembly ("memory-safe") {
                    mstore(tiers, sub(mload(tiers), 1))
=======
contract ForTest_JBTiered721Delegate is JBTiered721Delegate {
    IJBTiered721DelegateStore_ForTest public test_store;
    JBDelegateMetadataHelper metadataHelper;

    uint256 constant OVERFLOW = 10e18;
    uint256 constant REDEMPTION_RATE = JBConstants.MAX_RESERVED_RATE; // 40%

    constructor(
        uint256 _projectId,
        IJBDirectory _directory,
        string memory _name,
        string memory _symbol,
        IJBFundingCycleStore _fundingCycleStore,
        string memory _baseUri,
        IJB721TokenUriResolver _tokenUriResolver,
        string memory _contractUri,
        JB721TierParams[] memory _tiers,
        IJBTiered721DelegateStore _test_store,
        JBTiered721Flags memory _flags
    )   
        // The directory is also an IJBOperatable
        JBTiered721Delegate(
            _directory,
            IJBOperatable(address(_directory)).operatorStore(),
            PAY_DELEGATE_ID,
            REDEEM_DELEGATE_ID
        )
    {

        // Disable the safety check to not allow initializing the original contract
        codeOrigin = address(0);
        JBTiered721Delegate.initialize(
            _projectId,
            _name,
            _symbol,
            _fundingCycleStore,
            _baseUri,
            _tokenUriResolver,
            _contractUri,
            JB721PricingParams({tiers: _tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            _test_store,
            _flags
        );
        test_store = IJBTiered721DelegateStore_ForTest(address(_test_store));

        metadataHelper = new JBDelegateMetadataHelper();
    }

    function ForTest_setOwnerOf(uint256 tokenId, address _owner) public {
        _owners[tokenId] = _owner;
    }
}

contract ForTest_JBTiered721DelegateStore is JBTiered721DelegateStore, IJBTiered721DelegateStore_ForTest {
    using JBBitmap for mapping(uint256 => uint256);
    using JBBitmap for JBBitmapWord;

    function ForTest_dumpTiersList(address _nft) public view override returns (JB721Tier[] memory _tiers) {
        // Keep a reference to the max tier ID.
        uint256 _maxTierId = maxTierIdOf[_nft];
        // Initialize an array with the appropriate length.
        _tiers = new JB721Tier[](_maxTierId);
        // Count the number of included tiers.
        uint256 _numberOfIncludedTiers;
        // Get a reference to the index being iterated on, starting with the starting index.
        uint256 _currentSortIndex = _firstSortedTierIdOf(_nft, 0);
        // Keep a reference to the tier being iterated on.
        JBStored721Tier memory _storedTier;
        // Make the sorted array.
        while (_currentSortIndex != 0 && _numberOfIncludedTiers < _maxTierId) {
            _storedTier = _storedTierOf[_nft][_currentSortIndex];

            // Unpack stored tier
            (bool _allowManualMint, bool _transfersPausable,) = _unpackBools(_storedTier.packedBools);

            // Add the tier to the array being returned.
            _tiers[_numberOfIncludedTiers++] = JB721Tier({
                id: _currentSortIndex,
                price: _storedTier.price,
                remainingQuantity: _storedTier.remainingQuantity,
                initialQuantity: _storedTier.initialQuantity,
                votingUnits: _storedTier.votingUnits,
                reservedRate: _storedTier.reservedRate,
                reservedTokenBeneficiary: reservedTokenBeneficiaryOf(_nft, _currentSortIndex),
                encodedIPFSUri: encodedIPFSUriOf[_nft][_currentSortIndex],
                category: _storedTier.category,
                allowManualMint: _allowManualMint,
                transfersPausable: _transfersPausable,
                resolvedUri: ""
            });
            // Set the next sort index.
            _currentSortIndex = _nextSortedTierIdOf(_nft, _currentSortIndex, _maxTierId);
        }
        // Drop the empty tiers at the end of the array (coming from maxTierIdOf which *might* be bigger than actual bigger tier)
        for (uint256 i = _tiers.length - 1; i >= 0; i--) {
            if (_tiers[i].id == 0) {
                assembly ("memory-safe") {
                    mstore(_tiers, sub(mload(_tiers), 1))
>>>>>>> intermediate
                }
            } else {
                break;
            }
        }
    }

<<<<<<< HEAD
    function ForTest_setTier(address hook, uint256 index, JBStored721Tier calldata newTier) public override {
        _storedTierOf[address(hook)][index] = newTier;
    }

    function ForTest_setBalanceOf(address hook, address holder, uint256 tier, uint256 balance) public override {
        tierBalanceOf[address(hook)][holder][tier] = balance;
    }

    function ForTest_setReservesMintedFor(address hook, uint256 tier, uint256 amount) public override {
        numberOfReservesMintedFor[address(hook)][tier] = amount;
    }

    function ForTest_setIsTierRemoved(address hook, uint256 tokenId) public override {
        _isTierRemovedBitmapWord[hook].removeTier(tokenId);
    }

    function ForTest_packBools(
        bool allowOwnerMint,
        bool transfersPausable,
        bool useVotingUnits
    )
=======
    function ForTest_setTier(address _delegate, uint256 index, JBStored721Tier calldata newTier) public override {
        _storedTierOf[address(_delegate)][index] = newTier;
    }

    function ForTest_setBalanceOf(address _delegate, address holder, uint256 tier, uint256 balance) public override {
        tierBalanceOf[address(_delegate)][holder][tier] = balance;
    }

    function ForTest_setReservesMintedFor(address _delegate, uint256 tier, uint256 amount) public override {
        numberOfReservesMintedFor[address(_delegate)][tier] = amount;
    }

    function ForTest_setIsTierRemoved(address _delegate, uint256 _tokenId) public override {
        _isTierRemovedBitmapWord[_delegate].removeTier(_tokenId);
    }

    function ForTest_packBools(bool _allowManualMint, bool _transfersPausable, bool _useVotingUnits)
>>>>>>> intermediate
        public
        pure
        returns (uint8)
    {
<<<<<<< HEAD
        return _packBools(allowOwnerMint, transfersPausable, useVotingUnits);
    }

    function ForTest_unpackBools(uint8 packed) public pure returns (bool, bool, bool) {
        return _unpackBools(packed);
=======
        return _packBools(_allowManualMint, _transfersPausable, _useVotingUnits);
    }

    function ForTest_unpackBools(uint8 _packed) public pure returns (bool, bool, bool) {
        return _unpackBools(_packed);
>>>>>>> intermediate
    }
}
