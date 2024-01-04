// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/juice-contracts-v4/src/JBController.sol";
import "lib/juice-contracts-v4/src/JBDirectory.sol";
import "lib/juice-contracts-v4/src/JBMultiTerminal.sol";
import "lib/juice-contracts-v4/src/JBFundAccessLimits.sol";
import "lib/juice-contracts-v4/src/JBTerminalStore.sol";
import "lib/juice-contracts-v4/src/JBRulesets.sol";
import "lib/juice-contracts-v4/src/JBPermissions.sol";
import "lib/juice-contracts-v4/src/JBPrices.sol";
import {JBProjects} from "lib/juice-contracts-v4/src/JBProjects.sol";
import "lib/juice-contracts-v4/src/JBSplits.sol";
import "lib/juice-contracts-v4/src/JBERC20.sol";
import "lib/juice-contracts-v4/src/JBTokens.sol";

import "lib/juice-contracts-v4/src/structs/JBAfterPayRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBAfterRedeemRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBFee.sol";
import "lib/juice-contracts-v4/src/structs/JBFundAccessLimitGroup.sol";
import "lib/juice-contracts-v4/src/structs/JBRuleset.sol";
import "lib/juice-contracts-v4/src/structs/JBRulesetConfig.sol";
import "lib/juice-contracts-v4/src/structs/JBRulesetMetadata.sol";
import "lib/juice-contracts-v4/src/structs/JBSplitGroup.sol";
import "lib/juice-contracts-v4/src/structs/JBPermissionsData.sol";
import "lib/juice-contracts-v4/src/structs/JBBeforePayRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBBeforeRedeemRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBSplit.sol";

import "lib/juice-contracts-v4/src/interfaces/terminal/IJBTerminal.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBToken.sol";

import "lib/juice-contracts-v4/src/libraries/JBPermissionIds.sol";
import "lib/juice-contracts-v4/src/libraries/JBRulesetMetadataResolver.sol";

import {mulDiv} from "@prb/math/src/Common.sol";

import "forge-std/Test.sol";

import "./AccessJBLib.sol";

import "src/structs/JBPayDataHookRulesetMetadata.sol";

// Base contract for Juicebox system tests.
//
// Provides common functionality, such as deploying contracts on test setup.
contract TestBaseWorkflow is Test {
    //*********************************************************************//
    // --------------------- internal stored properties ------------------- //
    //*********************************************************************//

    address internal _projectOwner = address(123);
    address internal _beneficiary = address(69_420);
    address internal _caller = address(696_969);

    JBPermissions internal _jbOperatorStore;
    JBProjects internal _jbProjects;
    JBPrices internal _jbPrices;
    JBDirectory internal _jbDirectory;
    JBRulesets internal _jbFundingCycleStore;
    JBTokens internal _jbTokenStore;
    JBFundAccessLimits internal _jbFundsAccessConstraintsStore;
    JBSplits internal _jbSplitsStore;
    JBController internal _jbController;
    JBTerminalStore internal _jbPaymentTerminalStore;
    JBMultiTerminal internal _jbETHPaymentTerminal;
    JBProjectMetadata internal _projectMetadata;
    JBRulesetConfig internal _config;
    JBPayDataHookRulesetMetadata internal _metadata;
    JBSplitGroup[] internal _splitGroups;
    JBFundAccessLimitGroup[] internal _fundAccessLimitGroups;
    IJBTerminal[] internal _terminals;
    IJBToken internal _tokenV2;

    AccessJBLib internal _accessJBLib;

    //*********************************************************************//
    // --------------------------- test setup ---------------------------- //
    //*********************************************************************//

    // Deploys and initializes contracts for testing.
    function setUp() public virtual {
        // ---- Set up project ----
        _jbOperatorStore = new JBPermissions();
        vm.label(address(_jbOperatorStore), "JBPermissions");

        _jbProjects = new JBProjects(_jbOperatorStore);
        vm.label(address(_jbProjects), "JBProjects");

        _jbPrices = new JBPrices(_projectOwner);
        vm.label(address(_jbPrices), "JBPrices");

        address contractAtNoncePlusOne = addressFrom(address(this), 5);

        _jbFundingCycleStore = new JBRulesets(IJBDirectory(contractAtNoncePlusOne));
        vm.label(address(_jbFundingCycleStore), "JBRulesets");

        _jbDirectory = new JBDirectory(_jbOperatorStore, _jbProjects, _jbFundingCycleStore, _projectOwner);
        vm.label(address(_jbDirectory), "JBDirectory");

        _jbFundsAccessConstraintsStore = new JBFundAccessLimits(_jbDirectory);

        _jbTokenStore = new JBTokens(_jbOperatorStore, _jbProjects, _jbDirectory, _jbFundingCycleStore);
        vm.label(address(_jbTokenStore), "JBTokens");

        _jbSplitsStore = new JBSplits(_jbOperatorStore, _jbProjects, _jbDirectory);
        vm.label(address(_jbSplitsStore), "JBSplits");

        _jbController = new JBController(
            _jbOperatorStore,
            _jbProjects,
            _jbDirectory,
            _jbFundingCycleStore,
            _jbTokenStore,
            _jbSplitsStore,
            _jbFundsAccessConstraintsStore
        );
        vm.label(address(_jbController), "JBController");

        vm.prank(_projectOwner);
        _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

        _jbPaymentTerminalStore = new JBTerminalStore(_jbDirectory, _jbFundingCycleStore, _jbPrices);
        vm.label(address(_jbPaymentTerminalStore), "JBTerminalStore");

        _accessJBLib = new AccessJBLib();

        _jbETHPaymentTerminal = new JBMultiTerminal(
            _accessJBLib.NATIVE(),
            _jbOperatorStore,
            _jbProjects,
            _jbDirectory,
            _jbSplitsStore,
            _jbPrices,
            address(_jbPaymentTerminalStore),
            _projectOwner
        );
        vm.label(address(_jbETHPaymentTerminal), "JBMultiTerminal");

        _terminals.push(_jbETHPaymentTerminal);

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _config = JBRulesetConfig({ // TODO: fix this
            duration: 14,
            weight: 1000 * 10 ** 18,
            discountRate: 450_000_000,
            ballot: IJBRulesetApprovalHook(address(0))
        });

        _metadata = JBPayDataHookRulesetMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            ballotRedemptionRate: 5000,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: true,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForRedeem: true,
            metadata: 0x00
        });

        // ---- general setup ----
        vm.deal(_beneficiary, 100 ether);
        vm.deal(_projectOwner, 100 ether);
        vm.deal(_caller, 100 ether);

        vm.label(_projectOwner, "projectOwner");
        vm.label(_beneficiary, "beneficiary");
        vm.label(_caller, "caller");
    }

    //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
    function addressFrom(address origin, uint256 nonce) internal pure returns (address addr) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), origin, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), origin, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), origin, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), origin, bytes1(0x84), uint32(nonce));
        }
        bytes32 hash = keccak256(data);
        assembly ("memory-safe") {
            mstore(0, hash)
            addr := mload(0)
        }
    }
}
