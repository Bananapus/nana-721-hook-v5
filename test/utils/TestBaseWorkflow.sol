// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/juice-contracts-v4/src/JBController.sol";
import "lib/juice-contracts-v4/src/JBDirectory.sol";
import "lib/juice-contracts-v4/src/JBMultiTerminal.sol";
import "lib/juice-contracts-v4/src/JBFundAccessLimits.sol";
import "lib/juice-contracts-v4/src/JBFeelessAddresses.sol";
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
import "lib/juice-contracts-v4/src/structs/JBPermissionsData.sol";
import "lib/juice-contracts-v4/src/structs/JBBeforePayRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBBeforeRedeemRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBSplit.sol";

import "lib/juice-contracts-v4/src/interfaces/terminal/IJBTerminal.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBToken.sol";

import "lib/juice-contracts-v4/src/libraries/JBPermissionIds.sol";
import "lib/juice-contracts-v4/src/libraries/JBRulesetMetadataResolver.sol";

import {mulDiv} from "lib/prb-math/src/Common.sol";

import "forge-std/Test.sol";

import "./AccessJBLib.sol";

import "src/structs/JBPayDataHookRulesetConfig.sol";
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

    JBPermissions internal _jbPermissions;
    JBProjects internal _jbProjects;
    JBPrices internal _jbPrices;
    JBDirectory internal _jbDirectory;
    JBRulesets internal _jbRulesets;
    JBTokens internal _jbTokens;
    JBFundAccessLimits internal _jbFundAccessLimits;
    JBFeelessAddresses internal _jbFeelessAddresses;
    JBSplits internal _jbSplits;
    JBController internal _jbController;
    JBTerminalStore internal _jbTerminalStore;
    JBMultiTerminal internal _jbMultiTerminal;
    string internal _projectMetadata;
    JBRulesetConfig internal _config;
    JBTerminalConfig[] internal _terminalConfigurations;
    JBPayDataHookRulesetConfig[] internal _rulesetConfigurations;
    JBPayDataHookRulesetMetadata internal _metadata;
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
        _jbPermissions = new JBPermissions();
        vm.label(address(_jbPermissions), "JBPermissions");

        _jbProjects = new JBProjects(_projectOwner);
        vm.label(address(_jbProjects), "JBProjects");

        _jbPrices = new JBPrices(_jbPermissions, _jbProjects, _projectOwner);
        vm.label(address(_jbPrices), "JBPrices");

        _jbDirectory = new JBDirectory(_jbPermissions, _jbProjects, _projectOwner);
        vm.label(address(_jbDirectory), "JBDirectory");

        _jbRulesets = new JBRulesets(_jbDirectory);
        vm.label(address(_jbRulesets), "JBRulesets");

        _jbFundAccessLimits = new JBFundAccessLimits(_jbDirectory);
        vm.label(address(_jbFundAccessLimits), "JBFundAccessLimits");

        _jbFeelessAddresses = new JBFeelessAddresses(address(69));
        vm.label(address(_jbFeelessAddresses), "JBFeelessAddresses");

        _jbTokens = new JBTokens(_jbDirectory);
        vm.label(address(_jbTokens), "JBTokens");

        _jbSplits = new JBSplits(_jbDirectory);
        vm.label(address(_jbSplits), "JBSplits");

        _jbController = new JBController(
            _jbPermissions,
            _jbProjects,
            _jbDirectory,
            _jbRulesets,
            _jbTokens,
            _jbSplits,
            _jbFundAccessLimits,
            address(0)
        );
        vm.label(address(_jbController), "JBController");

        vm.prank(_projectOwner);
        _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

        _jbTerminalStore = new JBTerminalStore(_jbDirectory, _jbRulesets, _jbPrices);
        vm.label(address(_jbTerminalStore), "JBTerminalStore");

        _accessJBLib = new AccessJBLib();

        _jbMultiTerminal = new JBMultiTerminal(
            _jbPermissions,
            _jbProjects,
            _jbDirectory,
            _jbSplits,
            _jbTerminalStore,
            _jbFeelessAddresses,
            IPermit2(address(0)),
            address(0)
        );
        vm.label(address(_jbMultiTerminal), "JBMultiTerminal");

        _terminals.push(_jbMultiTerminal);

        _projectMetadata = "myIPFSHash";

        _metadata = JBPayDataHookRulesetMetadata({
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForRedeem: true,
            metadata: 0x00
        });

        // Package up the ruleset configuration.
        JBPayDataHookRulesetConfig memory _rulesetConfiguration;
        _rulesetConfiguration.mustStartAtOrAfter = 0;
        _rulesetConfiguration.duration = 14;
        _rulesetConfiguration.weight = 1000 * 10 ** 18;
        _rulesetConfiguration.decayRate = 450_000_000;
        _rulesetConfiguration.approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfiguration.metadata = _metadata;
        _rulesetConfiguration.fundAccessLimitGroups = _fundAccessLimitGroups;
        _rulesetConfigurations.push(_rulesetConfiguration);

        address[] memory _tokensToAccept = new address[](1);
        _tokensToAccept[0] = JBConstants.NATIVE_TOKEN;
        JBTerminalConfig memory _terminalConfiguration = JBTerminalConfig({terminal: _jbMultiTerminal, tokensToAccept: _tokensToAccept});
        _terminalConfigurations.push(_terminalConfiguration);

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
