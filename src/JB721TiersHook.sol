// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {mulDiv} from "@prb/math/src/Common.sol";
import {JBOwnable} from "@bananapus/ownable/src/JBOwnable.sol";
import {JBOwnableOverrides} from "@bananapus/ownable/src/JBOwnableOverrides.sol";
import {IJBPermissions} from "@bananapus/core/src/interfaces/IJBPermissions.sol";
import {IJBRulesets} from "@bananapus/core/src/interfaces/IJBRulesets.sol";
import {IJBPrices} from "@bananapus/core/src/interfaces/IJBPrices.sol";
import {IJBDirectory} from "@bananapus/core/src/interfaces/IJBDirectory.sol";
import {JBRulesetMetadataResolver} from "@bananapus/core/src/libraries/JBRulesetMetadataResolver.sol";
import {JBBeforeRedeemRecordedContext} from "@bananapus/core/src/structs/JBBeforeRedeemRecordedContext.sol";
import {JBAfterPayRecordedContext} from "@bananapus/core/src/structs/JBAfterPayRecordedContext.sol";
import {JBRuleset} from "@bananapus/core/src/structs/JBRuleset.sol";
import {JBMetadataResolver} from "@bananapus/core/src/libraries/JBMetadataResolver.sol";
import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";

import {JB721Hook} from "./abstract/JB721Hook.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {IJB721TokenUriResolver} from "./interfaces/IJB721TokenUriResolver.sol";
import {IJB721TiersHookStore} from "./interfaces/IJB721TiersHookStore.sol";
import {JBIpfsDecoder} from "./libraries/JBIpfsDecoder.sol";
import {JB721TiersRulesetMetadataResolver} from "./libraries/JB721TiersRulesetMetadataResolver.sol";
import {JB721TierConfig} from "./structs/JB721TierConfig.sol";
import {JB721Tier} from "./structs/JB721Tier.sol";
import {JB721TiersHookFlags} from "./structs/JB721TiersHookFlags.sol";
import {JB721InitTiersConfig} from "./structs/JB721InitTiersConfig.sol";
import {JB721TiersMintReservesConfig} from "./structs/JB721TiersMintReservesConfig.sol";

/// @title JB721TiersHook
/// @notice A Juicebox project can use this hook to sell tiered ERC-721 NFTs with different prices and metadata. When
/// the project is paid, the hook may mint NFTs to the payer, depending on the hook's setup, the amount paid, and
/// information specified by the payer. The project's owner can enable NFT redemptions through this hook, allowing
/// holders to burn their NFTs to reclaim funds from the project (in proportion to the NFT's price).
contract JB721TiersHook is JBOwnable, ERC2771Context, JB721Hook, IJB721TiersHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error OVERSPENDING();
    error MINT_RESERVE_NFTS_PAUSED();
    error TIER_TRANSFERS_PAUSED();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The address of the original `JB721TiersHook`.
    /// @dev Used in `initialize(...)` to check if this is the original `JB721TiersHook`, and to revert initialization
    /// if it is.
    address public immutable override CODE_ORIGIN;

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
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The contract that stores and manages data for this contract's NFTs.
    /// @dev Set once in initializer.
    IJB721TiersHookStore public override STORE;

    /// @notice The contract storing and managing project rulesets.
    /// @dev Set once in initializer.
    IJBRulesets public override RULESETS;

    /// @notice If an address pays more than the price of the NFT they received, the extra amount is stored as credits
    /// which can be redeemed to mint NFTs.
    /// @custom:param addr The address to get the NFT credits balance of.
    /// @return The amount of credits the address has.
    mapping(address addr => uint256) public override payCreditsOf;

    /// @notice The base URI for the NFT `tokenUris`.
    string public override baseURI;

    /// @notice This contract's metadata URI.
    string public override contractURI;

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

    /// @notice The metadata URI of the NFT with the specified token ID.
    /// @dev Defers to the `tokenUriResolver` if it is set. Otherwise, use the `tokenUri` corresponding with the NFT's
    /// tier.
    /// @param tokenId The token ID of the NFT to get the metadata URI of.
    /// @return The token URI from the `tokenUriResolver` if it is set. If it isn't set, the token URI for the NFT's
    /// tier.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // Keep a reference to the store.
        IJB721TiersHookStore store = STORE;

        // Get a reference to the `tokenUriResolver`.
        IJB721TokenUriResolver resolver = store.tokenUriResolverOf(address(this));

        // If a `tokenUriResolver` is set, use it to resolve the token URI.
        if (address(resolver) != address(0)) return resolver.tokenUriOf(address(this), tokenId);

        // Otherwise, return the token URI corresponding with the NFT's tier.
        return JBIpfsDecoder.decode(baseURI, store.encodedTierIPFSUriOf(address(this), tokenId));
    }

    /// @notice The combined redemption weight of the NFTs with the specified token IDs.
    /// @dev An NFT's redemption weight is its price.
    /// @dev To get their relative redemption weight, divide the result by the `totalRedemptionWeight(...)`.
    /// @param tokenIds The token IDs of the NFTs to get the cumulative redemption weight of.
    /// @return weight The redemption weight of the tokenIds.
    function redemptionWeightOf(
        uint256[] memory tokenIds,
        JBBeforeRedeemRecordedContext calldata
    )
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.redemptionWeightOf(address(this), tokenIds);
    }

    /// @notice The combined redemption weight of all outstanding NFTs.
    /// @dev An NFT's redemption weight is its price.
    /// @return weight The total redemption weight.
    function totalRedemptionWeight(JBBeforeRedeemRecordedContext calldata)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.totalRedemptionWeight(address(this));
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IJB721TiersHook).interfaceId || super.supportsInterface(interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    /// @param permissions A contract storing permissions.
    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions,
        address trustedForwarder
    )
        JBOwnable(directory.PROJECTS(), permissions, msg.sender, uint88(0))
        JB721Hook(directory)
        ERC2771Context(trustedForwarder)
    {
        CODE_ORIGIN = address(this);
    }

    /// @notice Initializes a cloned copy of the original `JB721Hook` contract.
    /// @param projectId The ID of the project this this hook is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    /// @param rulesets A contract storing and managing project rulesets.
    /// @param baseUri The URI to use as a base for full NFT `tokenUri`s.
    /// @param tokenUriResolver An optional contract responsible for resolving the token URI for each NFT's token ID.
    /// @param contractUri A URI where this contract's metadata can be found.
    /// @param tiersConfig The NFT tiers and pricing context to initialize the hook with. The tiers must be sorted by
    /// price (from least to greatest).
    /// @param store The contract which stores the NFT's data.
    /// @param flags A set of additional options which dictate how the hook behaves.
    function initialize(
        uint256 projectId,
        string memory name,
        string memory symbol,
        IJBRulesets rulesets,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721InitTiersConfig memory tiersConfig,
        IJB721TiersHookStore store,
        JB721TiersHookFlags memory flags
    )
        public
        override
    {
        // Stop re-initialization.
        if (address(STORE) != address(0)) revert();

        // Initialize the superclass.
        JB721Hook._initialize(projectId, name, symbol);

        RULESETS = rulesets;
        STORE = store;

        // Pack pricing context from the `tiersConfig`.
        uint256 packed;
        // pack the currency in bits 0-31 (32 bits).
        packed |= uint256(tiersConfig.currency);
        // pack the pricing decimals in bits 32-39 (8 bits).
        packed |= uint256(tiersConfig.decimals) << 32;
        // pack the prices contract in bits 40-199 (160 bits).
        packed |= uint256(uint160(address(tiersConfig.prices))) << 40;
        // Store the packed value.
        _packedPricingContext = packed;

        // Store the base URI if provided.
        if (bytes(baseUri).length != 0) baseURI = baseUri;

        // Set the contract URI if provided.
        if (bytes(contractUri).length != 0) contractURI = contractUri;

        // Set the token URI resolver if provided.
        if (tokenUriResolver != IJB721TokenUriResolver(address(0))) {
            store.recordSetTokenUriResolver(tokenUriResolver);
        }

        // Record the tiers in this hook's store.
        if (tiersConfig.tiers.length != 0) store.recordAddTiers(tiersConfig.tiers);

        // Set the flags if needed.
        if (
            flags.noNewTiersWithReserves || flags.noNewTiersWithVotes || flags.noNewTiersWithOwnerMinting
                || flags.preventOverspending
        ) store.recordFlags(flags);

        // Transfer ownership to the initializer.
        _transferOwnership(_msgSender());
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

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
        _requirePermissionFrom({account: owner(), projectId: projectId, permissionId: JBPermissionIds.MINT_721});

        // Record the mint. The token IDs returned correspond to the tiers passed in.
        (tokenIds,) = STORE.recordMint({
            amount: type(uint256).max, // force the mint.
            tierIds: tierIds,
            isOwnerMint: true // manual mint.
        });

        // Keep a reference to the number of NFTs being minted.
        uint256 numberOfNfts = tierIds.length;

        // Keep a reference to the token ID being iterated upon.
        uint256 tokenId;

        for (uint256 i; i < numberOfNfts; i++) {
            // Set the token ID.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(beneficiary, tokenId);

            emit Mint(tokenId, tierIds[i], beneficiary, 0, _msgSender());
        }
    }

    /// @notice Mint pending reserved NFTs based on the provided information.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param reserveMintConfigs Contains information about how many reserved tokens to mint for each tier.
    function mintPendingReservesFor(JB721TiersMintReservesConfig[] calldata reserveMintConfigs) external override {
        // Keep a reference to the number of tiers to mint reserves for.
        uint256 numberOfTiers = reserveMintConfigs.length;

        for (uint256 i; i < numberOfTiers; i++) {
            // Get a reference to the params being iterated upon.
            JB721TiersMintReservesConfig memory params = reserveMintConfigs[i];

            // Mint pending reserved NFTs from the tier.
            mintPendingReservesFor(params.tierId, params.count);
        }
    }

    /// @notice Add or delete tiers.
    /// @dev Only the contract's owner or an operator with the `ADJUST_TIERS` permission from the owner can adjust the
    /// tiers.
    /// @dev Any added tiers must adhere to this hook's `JB721TiersHookFlags`.
    /// @param tiersToAdd The tiers to add, as an array of `JB721TierConfig` structs`.
    /// @param tierIdsToRemove The tiers to remove, as an array of tier IDs.
    function adjustTiers(JB721TierConfig[] calldata tiersToAdd, uint256[] calldata tierIdsToRemove) external override {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: projectId, permissionId: JBPermissionIds.ADJUST_721_TIERS});

        // Get a reference to the number of tiers being added.
        uint256 numberOfTiersToAdd = tiersToAdd.length;

        // Get a reference to the number of tiers being removed.
        uint256 numberOfTiersToRemove = tierIdsToRemove.length;

        // Keep a reference to the store.
        IJB721TiersHookStore store = STORE;

        // Remove the tiers.
        if (numberOfTiersToRemove != 0) {
            // Record the removed tiers.
            store.recordRemoveTierIds(tierIdsToRemove);

            // Emit events for each removed tier.
            for (uint256 i; i < numberOfTiersToRemove; i++) {
                emit RemoveTier(tierIdsToRemove[i], _msgSender());
            }
        }

        // Add the tiers.
        if (numberOfTiersToAdd != 0) {
            // Record the added tiers in the store.
            uint256[] memory tierIdsAdded = store.recordAddTiers(tiersToAdd);

            // Emit events for each added tier.
            for (uint256 i; i < numberOfTiersToAdd; i++) {
                emit AddTier(tierIdsAdded[i], tiersToAdd[i], _msgSender());
            }
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
        _requirePermissionFrom({account: owner(), projectId: projectId, permissionId: JBPermissionIds.SET_721_METADATA});

        if (bytes(baseUri).length != 0) {
            // Store the new base URI.
            baseURI = baseUri;
            emit SetBaseUri(baseUri, _msgSender());
        }
        if (bytes(contractUri).length != 0) {
            // Store the new contract URI.
            contractURI = contractUri;
            emit SetContractUri(contractUri, _msgSender());
        }

        // Keep a reference to the store.
        IJB721TiersHookStore store = STORE;

        if (tokenUriResolver != IJB721TokenUriResolver(address(this))) {
            // Store the new URI resolver.
            store.recordSetTokenUriResolver(tokenUriResolver);

            emit SetTokenUriResolver(tokenUriResolver, _msgSender());
        }
        if (encodedIPFSTUriTierId != 0 && encodedIPFSUri != bytes32(0)) {
            // Store the new encoded IPFS URI.
            store.recordSetEncodedIPFSUriOf(encodedIPFSTUriTierId, encodedIPFSUri);

            emit SetEncodedIPFSUri(encodedIPFSTUriTierId, encodedIPFSUri, _msgSender());
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
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Pending reserve mints must not be paused.
        if (JB721TiersRulesetMetadataResolver.mintPendingReservesPaused((JBRulesetMetadataResolver.metadata(ruleset))))
        {
            revert MINT_RESERVE_NFTS_PAUSED();
        }

        // Keep a reference to the store.
        IJB721TiersHookStore store = STORE;

        // Record the reserved mint for the tier.
        uint256[] memory tokenIds = store.recordMintReservesFor(tierId, count);

        // Keep a reference to the beneficiary.
        address reserveBeneficiary = store.reserveBeneficiaryOf(address(this), tierId);

        // Keep a reference to the token ID being iterated upon.
        uint256 tokenId;

        for (uint256 i; i < count; i++) {
            // Set the token ID.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(reserveBeneficiary, tokenId);

            emit MintReservedNft(tokenId, tierId, reserveBeneficiary, _msgSender());
        }
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

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
                            projectId: projectId,
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
        // allowed. Defaults to false.
        bool allowOverspending;

        // The metadata ID is the first 4 bytes of this contract's address.
        bytes4 metadataId = bytes4(bytes20(address(this)));

        // Resolve the metadata.
        (bool found, bytes memory metadata) = JBMetadataResolver.getDataFor(metadataId, context.payerMetadata);

        if (found) {
            // Keep a reference to the IDs of the tier be to minted.
            uint16[] memory tierIdsToMint;

            // Decode the metadata.
            (allowOverspending, tierIdsToMint) = abi.decode(metadata, (bool, uint16[]));

            // Make sure overspending is allowed if requested.
            if (allowOverspending && STORE.flagsOf(address(this)).preventOverspending) {
                allowOverspending = false;
            }

            // Mint NFTs from the tiers as specified.
            if (tierIdsToMint.length != 0) {
                leftoverAmount =
                    _mintAll({amount: leftoverAmount, mintTierIds: tierIdsToMint, beneficiary: context.beneficiary});
            }
        } else if (!STORE.flagsOf(address(this)).preventOverspending) {
            allowOverspending = true;
        }

        // If overspending is allowed and there are leftover funds, add those funds to the beneficiary's NFT credits.
        if (leftoverAmount != 0) {
            // If overspending isn't allowed, revert.
            if (!allowOverspending) revert OVERSPENDING();

            // Increment the leftover amount.
            unchecked {
                // Keep a reference to the amount of new NFT credits.
                uint256 newPayCredits = leftoverAmount + unusedPayCredits;

                // Emit the change in NFT credits.
                if (newPayCredits > payCredits) {
                    emit AddPayCredits(newPayCredits - payCredits, newPayCredits, context.beneficiary, _msgSender());
                } else if (payCredits > newPayCredits) {
                    emit UsePayCredits(payCredits - newPayCredits, newPayCredits, context.beneficiary, _msgSender());
                }

                // Store the new NFT credits for the beneficiary.
                payCreditsOf[context.beneficiary] = newPayCredits;
            }
            // Otherwise, reset their NFT credits.
        } else if (payCredits != unusedPayCredits) {
            // Emit the change in NFT credits.
            emit UsePayCredits(payCredits - unusedPayCredits, unusedPayCredits, context.beneficiary, _msgSender());

            // Store the new NFT credits.
            payCreditsOf[context.beneficiary] = unusedPayCredits;
        }
    }

    /// @notice A function which gets called after NFTs have been redeemed and recorded by the terminal.
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

        // Get a reference to the number of NFTs being minted.
        uint256 mintsLength = tokenIds.length;

        // Keep a reference to the token ID being iterated on.
        uint256 tokenId;

        // Loop through each token ID and mint the corresponding NFT.
        for (uint256 i; i < mintsLength; i++) {
            // Get a reference to the token ID being iterated on.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(beneficiary, tokenId);

            emit Mint(tokenId, mintTierIds[i], beneficiary, amount, _msgSender());
        }
    }

    /// @notice Before transferring an NFT, register its first owner (if necessary).
    /// @param to The address the NFT is being transferred to.
    /// @param tokenId The token ID of the NFT being transferred.
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address from) {
        // Keep a reference to the store.
        IJB721TiersHookStore store = STORE;

        // Get a reference to the tier.
        JB721Tier memory tier = store.tierOfTokenId({hook: address(this), tokenId: tokenId, includeResolvedUri: false});

        // Record the transfers and keep a reference to where the token is coming from.
        from = super._update(to, tokenId, auth);

        // Transfers must not be paused (when not minting or burning).
        if (from != address(0)) {
            // If transfers are pausable, check if they're paused.
            if (tier.transfersPausable) {
                // Get a reference to the project's current ruleset.
                JBRuleset memory ruleset = RULESETS.currentOf(projectId);

                // If transfers are paused and the NFT isn't being transferred to the zero address, revert.
                if (
                    to != address(0)
                        && JB721TiersRulesetMetadataResolver.transfersPaused((JBRulesetMetadataResolver.metadata(ruleset)))
                ) revert TIER_TRANSFERS_PAUSED();
            }

            // If the token isn't already associated with a first owner, store the sender as the first owner.
            if (_firstOwnerOf[tokenId] == address(0)) _firstOwnerOf[tokenId] = from;
        }

        // Record the transfer.
        store.recordTransferForTier(tier.id, from, to);
    }

    /// @notice Returns the sender, prefered to use over `msg.sender`
    /// @return sender the sender address of this call.
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns the calldata, prefered to use over `msg.data`
    /// @return calldata the `msg.data` of this call
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @dev ERC-2771 specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return super._contextSuffixLength();
    }
}
