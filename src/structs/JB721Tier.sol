// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity ^0.8.0;

/// @custom:member id The tier's ID.
/// @custom:member price The price to buy an NFT in this tier, in terms of the currency in its `JBInitTiersConfig`.
/// @custom:member remainingSupply The remaining number of NFTs which can be minted from this tier.
/// @custom:member initialSupply The total number of NFTs which can be minted from this tier.
/// @custom:member votingUnits The number of votes that each NFT in this tier gets.
/// @custom:member reserveFrequency The frequency at which an extra NFT is minted for the `reserveBeneficiary` from this
/// tier. With a `reserveFrequency` of 5, an extra NFT will be minted for the `reserveBeneficiary` for every 5 NFTs
/// purchased.
/// @custom:member reserveBeneficiary The address which receives any reserve NFTs from this tier.
/// @custom:member encodedIPFSUri The IPFS URI to use for each NFT in this tier.
/// @custom:member category The category that NFTs in this tier belongs to. Used to group NFT tiers.
/// @custom:member allowOwnerMint A boolean indicating whether the contract's owner can mint NFTs from this tier
/// on-demand.
/// @custom:member transfersPausable A boolean indicating whether transfers for NFTs in tier can be paused.
/// @custom:member resolvedUri A resolved token URI for NFTs in this tier. Only available if the NFT this tier belongs
/// to has a resolver.
struct JB721Tier {
    uint256 id;
    uint256 price;
    uint256 remainingSupply;
    uint256 initialSupply;
    uint256 votingUnits;
    uint256 reserveFrequency;
    address reserveBeneficiary;
    bytes32 encodedIPFSUri;
    uint256 category;
    bool allowOwnerMint;
=======
pragma solidity ^0.8.16;

/// @custom:member id The tier's ID.
/// @custom:member price The price that must be paid to qualify for this tier.
/// @custom:member remainingQuantity Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
/// @custom:member initialQuantity The initial `remainingAllowance` value when the tier was set.
/// @custom:member votingUnits The amount of voting significance to give this tier compared to others.
/// @custom:member reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
/// @custom:member reservedRateBeneficiary The beneificary of the reserved tokens for this tier.
/// @custom:member encodedIPFSUri The URI to use for each token within the tier.
/// @custom:member category A category to group NFT tiers by.
/// @custom:member allowManualMint A flag indicating if the contract's owner can mint from this tier on demand.
/// @custom:member transfersPausable A flag indicating if transfers from this tier can be pausable. 
/// @custom:member resolvedTokenUri A resolved token URI if a resolver is included for the NFT to which this tier belongs.
struct JB721Tier {
    uint256 id;
    uint256 price;
    uint256 remainingQuantity;
    uint256 initialQuantity;
    uint256 votingUnits;
    uint256 reservedRate;
    address reservedTokenBeneficiary;
    bytes32 encodedIPFSUri;
    uint256 category;
    bool allowManualMint;
>>>>>>> intermediate
    bool transfersPausable;
    string resolvedUri;
}
