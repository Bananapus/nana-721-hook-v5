// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity 0.8.23;

import {mulDiv} from "@prb/math/src/Common.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IJBRulesetDataHook} from "lib/juice-contracts-v4/src/interfaces/IJBRulesetDataHook.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBPayHook} from "lib/juice-contracts-v4/src/interfaces/IJBPayHook.sol";
import {IJBRedeemHook} from "lib/juice-contracts-v4/src/interfaces/IJBRedeemHook.sol";
import {IJBTerminal} from "lib/juice-contracts-v4/src/interfaces/terminal/IJBTerminal.sol";
import {JBConstants} from "lib/juice-contracts-v4/src/libraries/JBConstants.sol";
import {JBBeforePayRecordedContext} from "lib/juice-contracts-v4/src/structs/JBBeforePayRecordedContext.sol";
import {JBAfterPayRecordedContext} from "lib/juice-contracts-v4/src/structs/JBAfterPayRecordedContext.sol";
import {JBAfterRedeemRecordedContext} from "lib/juice-contracts-v4/src/structs/JBAfterRedeemRecordedContext.sol";
import {JBBeforeRedeemRecordedContext} from "lib/juice-contracts-v4/src/structs/JBBeforeRedeemRecordedContext.sol";
import {JBPayHookSpecification} from "lib/juice-contracts-v4/src/structs/JBPayHookSpecification.sol";
import {JBRedeemHookSpecification} from "lib/juice-contracts-v4/src/structs/JBRedeemHookSpecification.sol";
import {JBMetadataResolver} from "lib/juice-contracts-v4/src/libraries/JBMetadataResolver.sol";

import {IJB721Hook} from "../interfaces/IJB721Hook.sol";
import {ERC721} from "./ERC721.sol";

/// @title JB721Hook
/// @notice When a project which uses this hook is paid, this hook may mint NFTs to the payer, depending on this hook's
/// setup, the amount paid, and information specified by the payer. The project's owner can enable NFT redemptions
/// through this hook, allowing the NFT holders to burn their NFTs to reclaim funds from the project (in proportion to
/// the NFT's price).
abstract contract JB721Hook is ERC721, IJB721Hook, IJBRulesetDataHook, IJBPayHook, IJBRedeemHook {
=======
pragma solidity ^0.8.16;

import {mulDiv} from '@prb/math/src/Common.sol';
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import { IJBFundingCycleDataSource3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleDataSource3_1_1.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import { IJBPayDelegate3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayDelegate3_1_1.sol";
import { IJBRedemptionDelegate3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBRedemptionDelegate3_1_1.sol";
import { IJBPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import { JBConstants } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import { JBPayParamsData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayParamsData.sol";
import { JBDidPayData3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData3_1_1.sol";
import { JBDidRedeemData3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData3_1_1.sol";
import { JBRedeemParamsData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol";
import { JBPayDelegateAllocation3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayDelegateAllocation3_1_1.sol";
import { JBRedemptionDelegateAllocation3_1_1 } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedemptionDelegateAllocation3_1_1.sol";
import { JBDelegateMetadataLib } from '@jbx-protocol/juice-delegate-metadata-lib/src/JBDelegateMetadataLib.sol';

import { IJB721Delegate } from "../interfaces/IJB721Delegate.sol";
import { ERC721 } from "./ERC721.sol";

/// @title JB721Delegate
/// @notice This delegate makes NFTs available to a project's contributors upon payment, and allows project owners to enable NFT redemption for treasury assets.
abstract contract JB721Delegate is
    ERC721,
    IJB721Delegate,
    IJBFundingCycleDataSource3_1_1,
    IJBPayDelegate3_1_1,
    IJBRedemptionDelegate3_1_1
{
>>>>>>> intermediate
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    error INVALID_PAY_EVENT();
    error INVALID_REDEEM_EVENT();
    error UNAUTHORIZED_TOKEN(uint256 tokenId);
    error UNEXPECTED_TOKEN_REDEEMED();
=======
    error INVALID_PAYMENT_EVENT();
    error INVALID_REDEMPTION_EVENT();
    error UNAUTHORIZED_TOKEN(uint256 _tokenId);
    error UNEXPECTED_TOKEN_REDEEMED();
    error INVALID_REDEMPTION_METADATA();
>>>>>>> intermediate

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice This contract's pay hook ID; used for parsing payment metadata.
    /// @dev Metadata hook IDs are 4 bytes each.
    bytes4 public immutable override metadataPayHookId;

    /// @notice This contract's redeem hook ID; used for parsing redemption metadata.
    /// @dev Metadata hook IDs are 4 bytes each.
    bytes4 public immutable override metadataRedeemHookId;
=======

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public override immutable directory;

    /// @notice The 4bytes ID of this delegate, used for pay metadata parsing
    bytes4 public override immutable payMetadataDelegateId;

    /// @notice The 4bytes ID of this delegate, used for redeem metadata parsing
    bytes4 public override immutable redeemMetadataDelegateId;
>>>>>>> intermediate

    //*********************************************************************//
    // -------------------- public stored properties --------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @notice The ID of the project that this contract is associated with.
=======
    /// @notice The Juicebox project ID this contract's functionality applies to.
>>>>>>> intermediate
    uint256 public override projectId;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @notice The data calculated before a payment is recorded in the terminal store. This data is provided to the
    /// terminal's `pay(...)` transaction.
    /// @dev Sets this contract as the pay hook. Part of `IJBRulesetDataHook`.
    /// @param context The payment context passed to this contract by the `pay(...)` function.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return memo A memo to be forwarded to the event.
    /// @return hookSpecifications The amount and data to send to pay hooks (this contract) instead of adding to the
    /// terminal's balance.
    function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
=======
    /// @notice This function gets called when the project receives a payment. It sets this contract as the delegate to get a callback from the terminal. Part of IJBFundingCycleDataSource.
    /// @param _data The Juicebox standard project payment data.
    /// @return weight The weight that tokens should get minted in accordance with.
    /// @return memo A memo to be forwarded to the event.
    /// @return delegateAllocations Amount to be sent to delegates instead of adding to local balance.
    function payParams(JBPayParamsData calldata _data)
>>>>>>> intermediate
        public
        view
        virtual
        override
<<<<<<< HEAD
        returns (uint256 weight, string memory memo, JBPayHookSpecification[] memory hookSpecifications)
    {
        // Forward the received weight and memo, and use this contract as the only pay hook.
        weight = context.weight;
        memo = context.memo;
        hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification(this, 0, bytes(""));
    }

    /// @notice The data calculated before a redemption is recorded in the terminal store. This data is provided to the
    /// terminal's `redeemTokensOf(...)` transaction.
    /// @dev Sets this contract as the redeem hook. Part of `IJBRulesetDataHook`.
    /// @dev This function is used for NFT redemptions, and will only be called if the project's ruleset has
    /// `useDataHookForRedeem` set to `true`.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return reclaimAmount Amount to be reclaimed, overriding the terminal's logic.
    /// @return memo A memo to be forwarded to the event.
    /// @return hookSpecifications The amount and data to send to redeem hooks (this contract) instead of returning to
    /// the beneficiary.
    function beforeRedeemRecordedWith(JBBeforeRedeemRecordedContext calldata context)
=======
        returns (uint256 weight, string memory memo, JBPayDelegateAllocation3_1_1[] memory delegateAllocations)
    {
        // Forward the received weight and memo, and use this contract as a pay delegate.
        weight = _data.weight;
        memo = _data.memo;
        delegateAllocations = new JBPayDelegateAllocation3_1_1[](1);
        delegateAllocations[0] = JBPayDelegateAllocation3_1_1(this, 0, bytes(''));
    }

    /// @notice This function gets called when the project's (NFT) token holders redeem. Part of IJBFundingCycleDataSource.
    /// @param _data Standard Juicebox project redemption data.
    /// @return reclaimAmount Amount to be reclaimed from the treasury.
    /// @return memo A memo to be forwarded to the event.
    /// @return delegateAllocations Amount to be sent to delegates instead of being added to the beneficiary.
    function redeemParams(JBRedeemParamsData calldata _data)
>>>>>>> intermediate
        public
        view
        virtual
        override
<<<<<<< HEAD
        returns (uint256 reclaimAmount, string memory memo, JBRedeemHookSpecification[] memory hookSpecifications)
    {
        // Make sure (fungible) project tokens aren't also being redeemed.
        if (context.tokenCount > 0) revert UNEXPECTED_TOKEN_REDEEMED();

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool found, bytes memory metadata) = JBMetadataResolver.getMetadata(metadataRedeemHookId, context.metadata);

        // Use this contract as the only redeem hook.
        hookSpecifications = new JBRedeemHookSpecification[](1);
        hookSpecifications[0] = JBRedeemHookSpecification(this, 0, bytes(""));

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (found) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Get a reference to the redemption weight of the provided tokens.
        uint256 redemptionWeight = redemptionWeightOf(decodedTokenIds, context);

        // Get a reference to the total redemption weight.
        uint256 total = totalRedemptionWeight(context);

        // Get a reference to the linear proportion that the provided tokens constitute (out of the total redemption
        // weight).
        uint256 base = mulDiv(context.surplus, redemptionWeight, total);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are
        // necessary.
        if (context.redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return (base, context.memo, hookSpecifications);
        }

        // Return the weighted surplus, and this contract as the redeem hook (so that the tokens can be burned).
        return (
            mulDiv(
                base,
                context.redemptionRate
                    + mulDiv(redemptionWeight, JBConstants.MAX_REDEMPTION_RATE - context.redemptionRate, total),
                JBConstants.MAX_REDEMPTION_RATE
                ),
            context.memo,
            hookSpecifications
=======
        returns (uint256 reclaimAmount, string memory memo, JBRedemptionDelegateAllocation3_1_1[] memory delegateAllocations)
    {
        // Make sure fungible project tokens aren't also being redeemed.
        if (_data.tokenCount > 0) revert UNEXPECTED_TOKEN_REDEEMED();

        // fetch this delegates metadata from the delegate id
        (bool _found, bytes memory _metadata) = JBDelegateMetadataLib.getMetadata(redeemMetadataDelegateId, _data.metadata);

        // Set the only delegate allocation to be a callback to this contract.
        delegateAllocations = new JBRedemptionDelegateAllocation3_1_1[](1);
        delegateAllocations[0] = JBRedemptionDelegateAllocation3_1_1(this, 0, bytes(''));

        uint256[] memory _decodedTokenIds;

        // Decode the metadata
        if (_found) _decodedTokenIds = abi.decode(_metadata, (uint256[]));

        // Get a reference to the redemption rate of the provided tokens.
        uint256 _redemptionWeight = redemptionWeightOf(_decodedTokenIds, _data);

        // Get a reference to the total redemption weight.
        uint256 _total = totalRedemptionWeight(_data);

        // Get a reference to the linear proportion.
        uint256 _base = mulDiv(_data.overflow, _redemptionWeight, _total);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are necessary.
        if (_data.redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return (_base, _data.memo, delegateAllocations);
        }

        // Return the weighted overflow, and this contract as the delegate so that tokens can be deleted.
        return (
            mulDiv(
                _base,
                _data.redemptionRate
                    + mulDiv(_redemptionWeight, JBConstants.MAX_REDEMPTION_RATE - _data.redemptionRate, _total),
                JBConstants.MAX_REDEMPTION_RATE
                ),
            _data.memo,
            delegateAllocations
>>>>>>> intermediate
        );
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @notice Returns the cumulative redemption weight of the specified token IDs relative to the
    /// `totalRedemptionWeight`.
    /// @param tokenIds The NFT token IDs to calculate the cumulative redemption weight of.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The cumulative redemption weight of the specified token IDs.
    function redemptionWeightOf(
        uint256[] memory tokenIds,
        JBBeforeRedeemRecordedContext calldata context
    )
=======
    /// @notice Returns the cumulative redemption weight of the given token IDs relative to the `totalRedemptionWeight`.
    /// @param _tokenIds The token IDs to calculate the cumulative redemption weight for.
    /// @param _data Standard Juicebox project redemption data.
    /// @return The cumulative redemption weight of the specified token IDs.
    function redemptionWeightOf(uint256[] memory _tokenIds, JBRedeemParamsData calldata _data)
>>>>>>> intermediate
        public
        view
        virtual
        returns (uint256)
    {
<<<<<<< HEAD
        tokenIds; // Prevents unused var compiler and natspec complaints.
        context; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    /// @notice Calculates the cumulative redemption weight of all NFT token IDs.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The total cumulative redemption weight of all NFT token IDs.
    function totalRedemptionWeight(JBBeforeRedeemRecordedContext calldata context)
        public
        view
        virtual
        returns (uint256)
    {
        context; // Prevents unused var compiler and natspec complaints.
=======
        _tokenIds; // Prevents unused var compiler and natspec complaints.
        _data; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    /// @notice Calculates the cumulative redemption weight of all token IDs.
    /// @param _data Standard Juicebox project redemption data.
    /// @return Total cumulative redemption weight of all token IDs.
    function totalRedemptionWeight(JBRedeemParamsData calldata _data) public view virtual returns (uint256) {
        _data; // Prevents unused var compiler and natspec complaints.
>>>>>>> intermediate
        return 0;
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
<<<<<<< HEAD
        return _interfaceId == type(IJB721Hook).interfaceId || _interfaceId == type(IJBRulesetDataHook).interfaceId
            || _interfaceId == type(IJBPayHook).interfaceId || _interfaceId == type(IJBRedeemHook).interfaceId
=======
        return _interfaceId == type(IJB721Delegate).interfaceId
            || _interfaceId == type(IJBFundingCycleDataSource3_1_1).interfaceId
            || _interfaceId == type(IJBPayDelegate3_1_1).interfaceId || _interfaceId == type(IJBRedemptionDelegate3_1_1).interfaceId
>>>>>>> intermediate
            || _interfaceId == type(IERC2981).interfaceId || super.supportsInterface(_interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @param directory A directory of terminals and controllers for projects.
    /// @param _metadataPayHookId This contract's pay hook ID; used for parsing payment metadata.
    /// @param _metadataRedeemHookId This contract's redeem hook ID; used for parsing redemption metadata.
    constructor(IJBDirectory directory, bytes4 _metadataPayHookId, bytes4 _metadataRedeemHookId) {
        DIRECTORY = directory;
        metadataPayHookId = _metadataPayHookId;
        metadataRedeemHookId = _metadataRedeemHookId;
    }

    /// @notice Initializes the contract by associating it with a project and adding ERC721 details.
    /// @param _projectId The ID of the project that this contract is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    function _initialize(uint256 _projectId, string memory name, string memory symbol) internal {
        ERC721._initialize(name, symbol);
=======
    /// @param _directory A directory of terminals and controllers for projects.
    /// @param _payMetadataDelegateId The 4bytes ID of this delegate, used for pay metadata parsing
    /// @param _redeemMetadataDelegateId The 4bytes ID of this delegate, used for redeem metadata parsing
    constructor(IJBDirectory _directory, bytes4 _payMetadataDelegateId, bytes4 _redeemMetadataDelegateId) {
        directory = _directory;
        payMetadataDelegateId = _payMetadataDelegateId;
        redeemMetadataDelegateId = _redeemMetadataDelegateId;
    }

    /// @notice Initializes the contract with project details and ERC721 token details.
    /// @param _projectId The ID of the project this contract's functionality applies to.
    /// @param _name The name of the token.
    /// @param _symbol The symbol representing the token.
    function _initialize(uint256 _projectId, string memory _name, string memory _symbol)
        internal
    {
        ERC721._initialize(_name, _symbol);
>>>>>>> intermediate
        projectId = _projectId;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

<<<<<<< HEAD
    /// @notice Mints one or more NFTs to the `context.benficiary` upon payment if conditions are met. Part of
    /// `IJBPayHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The payment context passed in by the terminal.
    function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable virtual override {
        uint256 _projectId = projectId;

        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(_projectId, IJBTerminal(msg.sender))
                || context.projectId != _projectId
        ) revert INVALID_PAY_EVENT();

        // Process the payment.
        _processPayment(context);
    }

    /// @notice Burns the specified NFTs upon token holder redemption, reclaiming funds from the project's balance for
    /// `context.beneficiary`. Part of `IJBRedeemHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The redemption context passed in by the terminal.
    function afterRedeemRecordedWith(JBAfterRedeemRecordedContext calldata context) external payable virtual override {
        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(projectId, IJBTerminal(msg.sender))
                || context.projectId != projectId
        ) revert INVALID_REDEEM_EVENT();

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool found, bytes memory metadata) =
            JBMetadataResolver.getMetadata(metadataRedeemHookId, context.redeemerMetadata);

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (found) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Get a reference to the number of NFT token IDs to check the owner of.
        uint256 numberOfTokenIds = decodedTokenIds.length;

        // Keep a reference to the NFT token ID being iterated upon.
        uint256 tokenId;

        // Iterate through the NFTs, burning them if the owner is correct.
        for (uint256 i; i < numberOfTokenIds;) {
            // Set the current NFT's token ID.
            tokenId = decodedTokenIds[i];

            // Make sure the token's owner is correct.
            if (_owners[tokenId] != context.holder) revert UNAUTHORIZED_TOKEN(tokenId);

            // Burn the token.
            _burn(tokenId);

            unchecked {
                ++i;
=======
    /// @notice Mints an NFT to the contributor (_data.beneficiary) upon project payment if conditions are met. Part of IJBPayDelegate.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param _data Standard Juicebox project payment data.
    function didPay(JBDidPayData3_1_1 calldata _data) external payable virtual override {
        uint256 _projectId = projectId;

        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
        if (
            msg.value != 0 || !directory.isTerminalOf(_projectId, IJBPaymentTerminal(msg.sender))
                || _data.projectId != _projectId
        ) revert INVALID_PAYMENT_EVENT();

        // Process the payment.
        _processPayment(_data);
    }

    /// @notice Burns specified NFTs upon token holder redemption, reclaiming funds from the project's balance to _data.beneficiary. Part of IJBRedeemDelegate.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param _data Standard Juicebox project redemption data.
    function didRedeem(JBDidRedeemData3_1_1 calldata _data) external payable virtual override {
        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
        if (
            msg.value != 0 || !directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))
                || _data.projectId != projectId
        ) revert INVALID_REDEMPTION_EVENT();

        // fetch this delegates metadata from the delegate id
        (bool _found, bytes memory _metadata) = JBDelegateMetadataLib.getMetadata(redeemMetadataDelegateId, _data.redeemerMetadata);

        uint256[] memory _decodedTokenIds;

        // Decode the metadata.
        if (_found) _decodedTokenIds = abi.decode(_metadata, (uint256[]));

        // Get a reference to the number of token IDs being checked.
        uint256 _numberOfTokenIds = _decodedTokenIds.length;

        // Keep a reference to the token ID being iterated upon.
        uint256 _tokenId;

        // Iterate through all tokens, burning them if the owner is correct.
        for (uint256 _i; _i < _numberOfTokenIds;) {
            // Set the token's ID.
            _tokenId = _decodedTokenIds[_i];

            // Make sure the token's owner is correct.
            if (_owners[_tokenId] != _data.holder) revert UNAUTHORIZED_TOKEN(_tokenId);

            // Burn the token.
            _burn(_tokenId);

            unchecked {
                ++_i;
>>>>>>> intermediate
            }
        }

        // Call the hook.
<<<<<<< HEAD
        _didBurn(decodedTokenIds);
=======
        _didBurn(_decodedTokenIds);
>>>>>>> intermediate
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Process a received payment.
<<<<<<< HEAD
    /// @param context The payment context passed in by the terminal.
    function _processPayment(JBAfterPayRecordedContext calldata context) internal virtual {
        context; // Prevents unused var compiler and natspec complaints.
    }

    /// @notice Executes after NFTs have been burned via redemption.
    /// @param tokenIds The token IDs of the NFTs that were burned.
    function _didBurn(uint256[] memory tokenIds) internal virtual {
        tokenIds;
=======
    /// @param _data Standard Juicebox project payment data.
    function _processPayment(JBDidPayData3_1_1 calldata _data) internal virtual {
        _data; // Prevents unused var compiler and natspec complaints.
    }

    /// @notice Executes after tokens have been burned via redemption.
    /// @param _tokenIds The IDs of the tokens that were burned.
    function _didBurn(uint256[] memory _tokenIds) internal virtual {
        _tokenIds;
>>>>>>> intermediate
    }
}
