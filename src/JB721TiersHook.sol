// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IJBDirectory} from "@bananapus/core-v5/src/interfaces/IJBDirectory.sol";
import {IJBPermissions} from "@bananapus/core-v5/src/interfaces/IJBPermissions.sol";
import {IJBPrices} from "@bananapus/core-v5/src/interfaces/IJBPrices.sol";
import {IJBRulesets} from "@bananapus/core-v5/src/interfaces/IJBRulesets.sol";
import {JBMetadataResolver} from "@bananapus/core-v5/src/libraries/JBMetadataResolver.sol";
import {JBRulesetMetadataResolver} from "@bananapus/core-v5/src/libraries/JBRulesetMetadataResolver.sol";
import {JBAfterPayRecordedContext} from "@bananapus/core-v5/src/structs/JBAfterPayRecordedContext.sol";
import {JBBeforeCashOutRecordedContext} from "@bananapus/core-v5/src/structs/JBBeforeCashOutRecordedContext.sol";
import {JBRuleset} from "@bananapus/core-v5/src/structs/JBRuleset.sol";
import {JBOwnable} from "@bananapus/ownable-v5/src/JBOwnable.sol";
import {JBPermissionIds} from "@bananapus/permission-ids-v5/src/JBPermissionIds.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {mulDiv} from "@prb/math/src/Common.sol";

import {JB721Hook} from "./abstract/JB721Hook.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {IJB721TiersHookStore} from "./interfaces/IJB721TiersHookStore.sol";
import {IJB721TokenUriResolver} from "./interfaces/IJB721TokenUriResolver.sol";
import {JB721TiersRulesetMetadataResolver} from "./libraries/JB721TiersRulesetMetadataResolver.sol";
import {JBIpfsDecoder} from "./libraries/JBIpfsDecoder.sol";
import {JB721Tier} from "./structs/JB721Tier.sol";
import {JB721TierConfig} from "./structs/JB721TierConfig.sol";
import {JB721TiersSetDiscountPercentConfig} from "./structs/JB721TiersSetDiscountPercentConfig.sol";
import {JB721InitTiersConfig} from "./structs/JB721InitTiersConfig.sol";
import {JB721TiersHookFlags} from "./structs/JB721TiersHookFlags.sol";
import {JB721TiersMintReservesConfig} from "./structs/JB721TiersMintReservesConfig.sol";

/// @title JB721TiersHook
/// @notice A Juicebox project can use this hook to sell tiered ERC-721 NFTs with different prices and metadata. When
/// the project is paid, the hook may mint NFTs to the payer, depending on the hook's setup, the amount paid, and
/// information specified by the payer. The project's owner can enable NFT cash outs through this hook, allowing
/// holders to burn their NFTs to reclaim funds from the project (in proportion to the NFT's price).
contract JB721TiersHook is JBOwnable, ERC2771Context, JB721Hook, IJB721TiersHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JB721TiersHook_AlreadyInitialized(uint256 projectId);
    error JB721TiersHook_NoProjectId();
    error JB721TiersHook_Overspending(uint256 leftoverAmount);
    error JB721TiersHook_MintReserveNftsPaused();
    error JB721TiersHook_TierTransfersPaused();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override RULESETS;

    /// @notice The contract that stores and manages data for this contract's NFTs.
    IJB721TiersHookStore public immutable override STORE;

    //*********************************************************************//
    // ---------------------- public stored properties ------------------- //
    //*********************************************************************//
    /// @notice The base URI for the NFT `tokenUris`.
    string public override baseURI;

    /// @notice This contract's metadata URI.
    string public override contractURI;

    /// @notice If an address pays more than the price of the NFT they received, the extra amount is stored as credits
    /// which can be cashed out to mint NFTs.
    /// @custom:param addr The address to get the NFT credits balance of.
    /// @return The amount of credits the address has.
    mapping(address addr => uint256) public override payCreditsOf;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The first owner of each token ID, stored on first transfer out.
    /// @custom:param The token ID of the NFT to get the stored first owner of.
    mapping(uint256 tokenId => address) internal _firstOwnerOf;

    /// @notice Packed context for the pricing of this contract's tiers.
    /// @dev Packed into a uint256:
    /// - currency in bits 0-31 (32 bits),
    /// - pricing decimals in bits 32-39 (8 bits), and
    /// - prices contract in bits 40-199 (160 bits).
    uint256 internal _packedPricingContext;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    /// @param permissions A contract storing permissions.
    /// @param rulesets A contract storing and managing project rulesets.
    /// @param store The contract which stores the NFT's data.
    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions,
        IJBRulesets rulesets,
        IJB721TiersHookStore store,
        address trustedForwarder
    )
        JBOwnable(permissions, directory.PROJECTS(), msg.sender, uint88(0))
        JB721Hook(directory)
        ERC2771Context(trustedForwarder)
    {
        RULESETS = rulesets;
        STORE = store;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The first owner of an NFT.
    /// @dev This is generally the address which paid for the NFT.
    /// @param tokenId The token ID of the NFT to get the first owner of.
    /// @return The address of the NFT's first owner.
    function firstOwnerOf(uint256 tokenId) external view override returns (address) {
        // Get a reference to the first owner.
        address storedFirstOwner = _firstOwnerOf[tokenId];

        // If the stored first owner is set, return it.
        if (storedFirstOwner != address(0)) return storedFirstOwner;

        // Otherwise, the first owner must be the current owner.
        return _ownerOf(tokenId);
    }

    /// @notice Context for the pricing of this hook's tiers.
    /// @dev If the `prices` contract is the zero address, this contract only accepts payments in the `currency` token.
    /// @return currency The currency used for tier prices.
    /// @return decimals The amount of decimals being used in tier prices.
    /// @return prices The prices contract used to resolve the value of payments in currencies other than `currency`.
    function pricingContext() external view override returns (uint256 currency, uint256 decimals, IJBPrices prices) {
        // Get a reference to the packed pricing context.
        uint256 packed = _packedPricingContext;
        // currency in bits 0-31 (32 bits).
        currency = uint256(uint32(packed));
        // pricing decimals in bits 32-39 (8 bits).
        decimals = uint256(uint8(packed >> 32));
        // prices contract in bits 40-199 (160 bits).
        prices = IJBPrices(address(uint160(packed >> 40)));
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The total number of this hook's NFTs that an address holds (from all tiers).
    /// @param owner The address to check the balance of.
    /// @return balance The number of NFTs the address owns across this hook's tiers.
    function balanceOf(address owner) public view override returns (uint256 balance) {
        return STORE.balanceOf(address(this), owner);
    }

    /// @notice Initializes a cloned copy of the original `JB721Hook` contract.
    /// @param projectId The ID of the project this this hook is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    /// @param baseUri The URI to use as a base for full NFT `tokenUri`s.
    /// @param tokenUriResolver An optional contract responsible for resolving the token URI for each NFT's token ID.
    /// @param contractUri A URI where this contract's metadata can be found.
    /// @param tiersConfig The NFT tiers and pricing context to initialize the hook with. The tiers must be sorted by
    /// category (from least to greatest).
    /// @param flags A set of additional options which dictate how the hook behaves.
    function initialize(
        uint256 projectId,
        string memory name,
        string memory symbol,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721InitTiersConfig memory tiersConfig,
        JB721TiersHookFlags memory flags
    )
        public
        override
    {
        // Stop re-initialization by ensuring a projectId is provided and doesn't already exist.
        if (PROJECT_ID != 0) revert JB721TiersHook_AlreadyInitialized(PROJECT_ID);

        // Make sure a projectId is provided.
        if (projectId == 0) revert JB721TiersHook_NoProjectId();

        // Initialize the superclass.
        JB721Hook._initialize(projectId, name, symbol);

        // Pack pricing context from the `tiersConfig`.
        uint256 packed;
        // pack the currency in bits 0-31 (32 bits).
        packed |= uint256(tiersConfig.currency);
        // pack the pricing decimals in bits 32-39 (8 bits).
        packed |= uint256(tiersConfig.decimals) << 32;
        // pack the prices contract in bits 40-199 (160 bits).
        packed |= uint256(uint160(address(tiersConfig.prices))) << 40;
        // Store the packed value.
        // slither-disable-next-line events-maths
        _packedPricingContext = packed;

        // Store the base URI if provided.
        if (bytes(baseUri).length != 0) baseURI = baseUri;

        // Set the contract URI if provided.
        if (bytes(contractUri).length != 0) contractURI = contractUri;

        // Set the token URI resolver if provided.
        if (tokenUriResolver != IJB721TokenUriResolver(address(0))) {
            _recordSetTokenUriResolver(tokenUriResolver);
        }

        // Record the tiers in this hook's store.
        // slither-disable-next-line unused-return
        if (tiersConfig.tiers.length != 0) STORE.recordAddTiers(tiersConfig.tiers);

        // Set the flags if needed.
        if (
            flags.noNewTiersWithReserves || flags.noNewTiersWithVotes || flags.noNewTiersWithOwnerMinting
                || flags.preventOverspending
        ) STORE.recordFlags(flags);

        // Transfer ownership to the initializer.
        _transferOwnership(_msgSender());
    }

    /// @notice The combined cash out weight of the NFTs with the specified token IDs.
    /// @dev An NFT's cash out weight is its price.
    /// @dev To get their relative cash out weight, divide the result by the `totalCashOutWeight(...)`.
    /// @param tokenIds The token IDs of the NFTs to get the cumulative cash out weight of.
    /// @return weight The cash out weight of the tokenIds.
    function cashOutWeightOf(
        uint256[] memory tokenIds,
        JBBeforeCashOutRecordedContext calldata
    )
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.cashOutWeightOf(address(this), tokenIds);
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, JB721Hook) returns (bool) {
        return interfaceId == type(IJB721TiersHook).interfaceId || JB721Hook.supportsInterface(interfaceId);
    }

    /// @notice The metadata URI of the NFT with the specified token ID.
    /// @dev Defers to the `tokenUriResolver` if it is set. Otherwise, use the `tokenUri` corresponding with the NFT's
    /// tier.
    /// @param tokenId The token ID of the NFT to get the metadata URI of.
    /// @return The token URI from the `tokenUriResolver` if it is set. If it isn't set, the token URI for the NFT's
    /// tier.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // Get a reference to the `tokenUriResolver`.
        IJB721TokenUriResolver resolver = STORE.tokenUriResolverOf(address(this));

        // If a `tokenUriResolver` is set, use it to resolve the token URI.
        if (address(resolver) != address(0)) return resolver.tokenUriOf(address(this), tokenId);

        // Otherwise, return the token URI corresponding with the NFT's tier.
        return JBIpfsDecoder.decode(baseURI, STORE.encodedTierIPFSUriOf(address(this), tokenId));
    }

    /// @notice The combined cash out weight of all outstanding NFTs.
    /// @dev An NFT's cash out weight is its price.
    /// @return weight The total cash out weight.
    function totalCashOutWeight(JBBeforeCashOutRecordedContext calldata)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.totalCashOutWeight(address(this));
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @dev ERC-2771 specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    /// @notice The project's current ruleset.
    /// @param projectId The ID of the project to check.
    /// @return The project's current ruleset.
    function _currentRulesetOf(uint256 projectId) internal view returns (JBRuleset memory) {
        // slither-disable-next-line calls-loop
        return RULESETS.currentOf(projectId);
    }

    /// @notice Returns the calldata, prefered to use over `msg.data`
    /// @return calldata the `msg.data` of this call
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @notice Returns the sender, prefered to use over `msg.sender`
    /// @return sender the sender address of this call.
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Add or delete tiers.
    /// @dev Only the contract's owner or an operator with the `ADJUST_TIERS` permission from the owner can adjust the
    /// tiers.
    /// @dev Any added tiers must adhere to this hook's `JB721TiersHookFlags`.
    /// @param tiersToAdd The tiers to add, as an array of `JB721TierConfig` structs`.
    /// @param tierIdsToRemove The tiers to remove, as an array of tier IDs.
    function adjustTiers(JB721TierConfig[] calldata tiersToAdd, uint256[] calldata tierIdsToRemove) external override {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: PROJECT_ID, permissionId: JBPermissionIds.ADJUST_721_TIERS});

        // Remove the tiers.
        if (tierIdsToRemove.length != 0) {
            // Emit events for each removed tier.
            for (uint256 i; i < tierIdsToRemove.length; i++) {
                emit RemoveTier({tierId: tierIdsToRemove[i], caller: _msgSender()});
            }

            // Record the removed tiers.
            // slither-disable-next-line reentrancy-events
            STORE.recordRemoveTierIds(tierIdsToRemove);
        }

        // Add the tiers.
        if (tiersToAdd.length != 0) {
            // Record the added tiers in the store.
            uint256[] memory tierIdsAdded = STORE.recordAddTiers(tiersToAdd);

            // Emit events for each added tier.
            for (uint256 i; i < tiersToAdd.length; i++) {
                emit AddTier({tierId: tierIdsAdded[i], tier: tiersToAdd[i], caller: _msgSender()});
            }
        }
    }

    /// @notice Manually mint NFTs from the provided tiers .
    /// @param tierIds The IDs of the tiers to mint from.
    /// @param beneficiary The address to mint to.
    /// @return tokenIds The IDs of the newly minted tokens.
    function mintFor(
        uint16[] calldata tierIds,
        address beneficiary
    )
        external
        override
        returns (uint256[] memory tokenIds)
    {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: PROJECT_ID, permissionId: JBPermissionIds.MINT_721});

        // Record the mint. The token IDs returned correspond to the tiers passed in.
        // slither-disable-next-line reentrancy-events,unused-return
        (tokenIds,) = STORE.recordMint({
            amount: type(uint256).max, // force the mint.
            tierIds: tierIds,
            isOwnerMint: true // manual mint.
        });

        for (uint256 i; i < tierIds.length; i++) {
            // Set the token ID.
            uint256 tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(beneficiary, tokenId);

            emit Mint({
                tokenId: tokenId,
                tierId: tierIds[i],
                beneficiary: beneficiary,
                totalAmountPaid: 0,
                caller: _msgSender()
            });
        }
    }

    /// @notice Mint pending reserved NFTs based on the provided information.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param reserveMintConfigs Contains information about how many reserved tokens to mint for each tier.
    function mintPendingReservesFor(JB721TiersMintReservesConfig[] calldata reserveMintConfigs) external override {
        for (uint256 i; i < reserveMintConfigs.length; i++) {
            // Get a reference to the params being iterated upon.
            JB721TiersMintReservesConfig memory params = reserveMintConfigs[i];

            // Mint pending reserved NFTs from the tier.
            mintPendingReservesFor(params.tierId, params.count);
        }
    }

    /// @notice Allows the collection's owner to set the discount for a tier, if the tier allows it.
    /// @dev Only the contract's owner or an operator with the `SET_721_DISCOUNT_PERCENT` permission from the owner can
    /// adjust the
    /// tiers.
    /// @param tierId The ID of the tier to set the discount of.
    /// @param discountPercent The discount percent to set.
    function setDiscountPercentOf(uint256 tierId, uint256 discountPercent) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: owner(),
            projectId: PROJECT_ID,
            permissionId: JBPermissionIds.SET_721_DISCOUNT_PERCENT
        });
        _setDiscountPercentOf(tierId, discountPercent);
    }

    /// @notice Allows the collection's owner to set the discount percent for multiple tiers.
    /// @param configs The configs to set the discount percent for.
    function setDiscountPercentsOf(JB721TiersSetDiscountPercentConfig[] calldata configs) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: owner(),
            projectId: PROJECT_ID,
            permissionId: JBPermissionIds.SET_721_DISCOUNT_PERCENT
        });

        for (uint256 i; i < configs.length; i++) {
            // Set the config being iterated on.
            JB721TiersSetDiscountPercentConfig memory config = configs[i];

            _setDiscountPercentOf(config.tierId, config.discountPercent);
        }
    }

    /// @notice Update this hook's URI metadata properties.
    /// @dev Only this contract's owner can set the metadata.
    /// @param baseUri The new base URI.
    /// @param contractUri The new contract URI.
    /// @param tokenUriResolver The new URI resolver.
    /// @param encodedIPFSTUriTierId The ID of the tier to set the encoded IPFS URI of.
    /// @param encodedIPFSUri The encoded IPFS URI to set.
    function setMetadata(
        string calldata baseUri,
        string calldata contractUri,
        IJB721TokenUriResolver tokenUriResolver,
        uint256 encodedIPFSTUriTierId,
        bytes32 encodedIPFSUri
    )
        external
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: PROJECT_ID, permissionId: JBPermissionIds.SET_721_METADATA});

        if (bytes(baseUri).length != 0) {
            // Store the new base URI.
            baseURI = baseUri;
            emit SetBaseUri({baseUri: baseUri, caller: _msgSender()});
        }
        if (bytes(contractUri).length != 0) {
            // Store the new contract URI.
            contractURI = contractUri;
            emit SetContractUri({uri: contractUri, caller: _msgSender()});
        }

        if (tokenUriResolver != IJB721TokenUriResolver(address(this))) {
            // Store the new URI resolver.
            // slither-disable-next-line reentrancy-events
            _recordSetTokenUriResolver(tokenUriResolver);
        }
        if (encodedIPFSTUriTierId != 0 && encodedIPFSUri != bytes32(0)) {
            emit SetEncodedIPFSUri({tierId: encodedIPFSTUriTierId, encodedUri: encodedIPFSUri, caller: _msgSender()});

            // Store the new encoded IPFS URI.
            STORE.recordSetEncodedIPFSUriOf(encodedIPFSTUriTierId, encodedIPFSUri);
        }
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Mint reserved pending reserved NFTs within the provided tier.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param tierId The ID of the tier to mint reserved NFTs from.
    /// @param count The number of reserved NFTs to mint.
    function mintPendingReservesFor(uint256 tierId, uint256 count) public override {
        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = _currentRulesetOf(PROJECT_ID);

        // Pending reserve mints must not be paused.
        if (JB721TiersRulesetMetadataResolver.mintPendingReservesPaused((JBRulesetMetadataResolver.metadata(ruleset))))
        {
            revert JB721TiersHook_MintReserveNftsPaused();
        }

        // Record the reserved mint for the tier.
        // slither-disable-next-line reentrancy-events,calls-loop
        uint256[] memory tokenIds = STORE.recordMintReservesFor(tierId, count);

        // Keep a reference to the beneficiary.
        // slither-disable-next-line calls-loop
        address reserveBeneficiary = STORE.reserveBeneficiaryOf(address(this), tierId);

        for (uint256 i; i < count; i++) {
            // Set the token ID.
            uint256 tokenId = tokenIds[i];

            emit MintReservedNft({
                tokenId: tokenId,
                tierId: tierId,
                beneficiary: reserveBeneficiary,
                caller: _msgSender()
            });

            // Mint the NFT.
            // slither-disable-next-line reentrency-events
            _mint(reserveBeneficiary, tokenId);
        }
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice A function which gets called after NFTs have been cashed out and recorded by the terminal.
    /// @param tokenIds The token IDs of the NFTs that were burned.
    function _didBurn(uint256[] memory tokenIds) internal virtual override {
        // Add to burned counter.
        STORE.recordBurn(tokenIds);
    }

    /// @notice Mints one NFT from each of the specified tiers for the beneficiary.
    /// @dev The same tier can be specified more than once.
    /// @param amount The amount to base the mints on. The total price of the NFTs being minted cannot be larger than
    /// this amount.
    /// @param mintTierIds An array of NFT tier IDs to be minted.
    /// @param beneficiary The address receiving the newly minted NFTs.
    /// @return leftoverAmount The `amount` leftover after minting.
    function _mintAll(
        uint256 amount,
        uint16[] memory mintTierIds,
        address beneficiary
    )
        internal
        returns (uint256 leftoverAmount)
    {
        // Keep a reference to the NFT token IDs.
        uint256[] memory tokenIds;

        // Record the NFT mints. The token IDs returned correspond to the tier IDs passed in.
        (tokenIds, leftoverAmount) = STORE.recordMint({
            amount: amount,
            tierIds: mintTierIds,
            isOwnerMint: false // Not a manual mint
        });

        // Loop through each token ID and mint the corresponding NFT.
        for (uint256 i; i < tokenIds.length; i++) {
            // Get a reference to the token ID being iterated on.
            uint256 tokenId = tokenIds[i];

            emit Mint({
                tokenId: tokenId,
                tierId: mintTierIds[i],
                beneficiary: beneficiary,
                totalAmountPaid: amount,
                caller: _msgSender()
            });

            // Mint the NFT.
            // slither-disable-next-line reentrancy-events
            _mint(beneficiary, tokenId);
        }
    }

    /// @notice Process a payment, minting NFTs and updating credits as necessary.
    /// @param context Payment context provided by the terminal after it has recorded the payment in the terminal store.
    function _processPayment(JBAfterPayRecordedContext calldata context) internal virtual override {
        // Normalize the payment value based on the pricing context.
        uint256 value;

        {
            uint256 packed = _packedPricingContext;
            // pricing currency in bits 0-31 (32 bits).
            uint256 pricingCurrency = uint256(uint32(packed));
            if (context.amount.currency == pricingCurrency) {
                value = context.amount.value;
            } else {
                // prices in bits 40-199 (160 bits).
                IJBPrices prices = IJBPrices(address(uint160(packed >> 40)));
                if (prices != IJBPrices(address(0))) {
                    // pricing decimals in bits 32-39 (8 bits).
                    uint256 pricingDecimals = uint256(uint8(packed >> 32));
                    value = mulDiv(
                        context.amount.value,
                        10 ** pricingDecimals,
                        prices.pricePerUnitOf({
                            projectId: PROJECT_ID,
                            pricingCurrency: context.amount.currency,
                            unitCurrency: pricingCurrency,
                            decimals: context.amount.decimals
                        })
                    );
                } else {
                    return;
                }
            }
        }

        // Keep a reference to the number of NFT credits the beneficiary already has.
        uint256 payCredits = payCreditsOf[context.beneficiary];

        // Set the leftover amount as the initial value.
        uint256 leftoverAmount = value;

        // If the payer is the beneficiary, combine their NFT credits with the amount paid.
        uint256 unusedPayCredits;
        if (context.payer == context.beneficiary) {
            unchecked {
                leftoverAmount += payCredits;
            }
        } else {
            // Otherwise, the payer's NFT credits won't be used, and we keep track of the unused credits.
            unusedPayCredits = payCredits;
        }

        // Keep a reference to the boolean indicating whether paying more than the price of the NFTs being minted is
        // allowed. Defaults to the collection's flag.
        bool allowOverspending = !STORE.flagsOf(address(this)).preventOverspending;

        // Resolve the metadata.
        (bool found, bytes memory metadata) =
            JBMetadataResolver.getDataFor(JBMetadataResolver.getId("pay", METADATA_ID_TARGET), context.payerMetadata);

        if (found) {
            // Keep a reference to the IDs of the tier be to minted.
            uint16[] memory tierIdsToMint;

            // Keep a reference to the payer's flag indicating whether overspending is allowed.
            bool payerAllowsOverspending;

            // Decode the metadata.
            (payerAllowsOverspending, tierIdsToMint) = abi.decode(metadata, (bool, uint16[]));

            // Make sure overspending is allowed if requested.
            if (allowOverspending && !payerAllowsOverspending) {
                allowOverspending = false;
            }

            // Mint NFTs from the tiers as specified.
            if (tierIdsToMint.length != 0) {
                // slither-disable-next-line reentrancy-events,reentrancy-no-eth
                leftoverAmount =
                    _mintAll({amount: leftoverAmount, mintTierIds: tierIdsToMint, beneficiary: context.beneficiary});
            }
        }

        // If overspending is allowed and there are leftover funds, add those funds to the beneficiary's NFT credits.
        if (leftoverAmount != 0) {
            // If overspending isn't allowed, revert.
            if (!allowOverspending) revert JB721TiersHook_Overspending(leftoverAmount);

            // Increment the leftover amount.
            unchecked {
                // Keep a reference to the amount of new NFT credits.
                uint256 newPayCredits = leftoverAmount + unusedPayCredits;

                // Emit the change in NFT credits.
                if (newPayCredits > payCredits) {
                    emit AddPayCredits({
                        amount: newPayCredits - payCredits,
                        newTotalCredits: newPayCredits,
                        account: context.beneficiary,
                        caller: _msgSender()
                    });
                } else if (payCredits > newPayCredits) {
                    emit UsePayCredits({
                        amount: payCredits - newPayCredits,
                        newTotalCredits: newPayCredits,
                        account: context.beneficiary,
                        caller: _msgSender()
                    });
                }

                // Store the new NFT credits for the beneficiary.
                payCreditsOf[context.beneficiary] = newPayCredits;
            }
            // Otherwise, reset their NFT credits.
        } else if (payCredits != unusedPayCredits) {
            // Emit the change in NFT credits.
            emit UsePayCredits({
                amount: payCredits - unusedPayCredits,
                newTotalCredits: unusedPayCredits,
                account: context.beneficiary,
                caller: _msgSender()
            });

            // Store the new NFT credits.
            payCreditsOf[context.beneficiary] = unusedPayCredits;
        }
    }

    /// @notice Record the setting of a new token URI resolver.
    /// @param tokenUriResolver The new token URI resolver.
    function _recordSetTokenUriResolver(IJB721TokenUriResolver tokenUriResolver) internal {
        emit SetTokenUriResolver({resolver: tokenUriResolver, caller: _msgSender()});

        STORE.recordSetTokenUriResolver(tokenUriResolver);
    }

    /// @notice Internal function to set the discount percent for a tier.
    /// @param tierId The ID of the tier to set the discount percent for.
    /// @param discountPercent The discount percent to set for the tier.
    function _setDiscountPercentOf(uint256 tierId, uint256 discountPercent) internal {
        emit SetDiscountPercent({tierId: tierId, discountPercent: discountPercent, caller: _msgSender()});

        // Record the discount percent for the tier.
        // slither-disable-next-line calls-loop
        STORE.recordSetDiscountPercentOf({tierId: tierId, discountPercent: discountPercent});
    }

    /// @notice Before transferring an NFT, register its first owner (if necessary).
    /// @param to The address the NFT is being transferred to.
    /// @param tokenId The token ID of the NFT being transferred.
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address from) {
        // Get a reference to the tier.
        // slither-disable-next-line calls-loop
        JB721Tier memory tier = STORE.tierOfTokenId({hook: address(this), tokenId: tokenId, includeResolvedUri: false});

        // Record the transfers and keep a reference to where the token is coming from.
        from = super._update(to, tokenId, auth);

        // Transfers must not be paused (when not minting or burning).
        if (from != address(0)) {
            // If transfers are pausable, check if they're paused.
            if (tier.transfersPausable) {
                // Get a reference to the project's current ruleset.
                JBRuleset memory ruleset = _currentRulesetOf(PROJECT_ID);

                // If transfers are paused and the NFT isn't being transferred to the zero address, revert.
                if (
                    to != address(0)
                        && JB721TiersRulesetMetadataResolver.transfersPaused((JBRulesetMetadataResolver.metadata(ruleset)))
                ) revert JB721TiersHook_TierTransfersPaused();
            }

            // If the token isn't already associated with a first owner, store the sender as the first owner.
            // slither-disable-next-line calls-loop
            if (_firstOwnerOf[tokenId] == address(0)) _firstOwnerOf[tokenId] = from;
        }

        // Record the transfer.
        // slither-disable-next-line reentrency-events,calls-loop
        STORE.recordTransferForTier(tier.id, from, to);
    }
}
