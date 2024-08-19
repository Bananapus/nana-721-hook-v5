// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBOwnable} from "@bananapus/ownable/src/JBOwnable.sol";
import {JBPermissioned} from "@bananapus/core/src/abstract/JBPermissioned.sol";
import {IJBDirectory} from "@bananapus/core/src/interfaces/IJBDirectory.sol";
import {IJBController} from "@bananapus/core/src/interfaces/IJBController.sol";
import {IJBPermissions} from "@bananapus/core/src/interfaces/IJBPermissions.sol";
import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {JBRulesetConfig} from "@bananapus/core/src/structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "@bananapus/core/src/structs/JBRulesetMetadata.sol";

import {IJB721TiersHookDeployer} from "./interfaces/IJB721TiersHookDeployer.sol";
import {IJB721TiersHookProjectDeployer} from "./interfaces/IJB721TiersHookProjectDeployer.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {JBDeploy721TiersHookConfig} from "./structs/JBDeploy721TiersHookConfig.sol";
import {JBLaunchRulesetsConfig} from "./structs/JBLaunchRulesetsConfig.sol";
import {JBQueueRulesetsConfig} from "./structs/JBQueueRulesetsConfig.sol";
import {JBLaunchProjectConfig} from "./structs/JBLaunchProjectConfig.sol";
import {JBPayDataHookRulesetConfig} from "./structs/JBPayDataHookRulesetConfig.sol";

/// @title JB721TiersHookProjectDeployer
/// @notice Deploys a project and a 721 tiers hook for it. Can be used to queue rulesets for the project if given
/// `JBPermissionIds.QUEUE_RULESETS`.
contract JB721TiersHookProjectDeployer is JBPermissioned, IJB721TiersHookProjectDeployer {
    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The 721 tiers hook deployer.
    IJB721TiersHookDeployer public immutable override HOOK_DEPLOYER;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory The directory of terminals and controllers for projects.
    /// @param permissions A contract storing permissions.
    /// @param hookDeployer The 721 tiers hook deployer.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions,
        IJB721TiersHookDeployer hookDeployer
    )
        JBPermissioned(permissions)
    {
        DIRECTORY = directory;
        HOOK_DEPLOYER = hookDeployer;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Launches a new project with a 721 tiers hook attached.
    /// @param owner The address to set as the owner of the project. The ERC-721 which confers this project's ownership
    /// will be sent to this address.
    /// @param deployTiersHookConfig Configuration which dictates the behavior of the 721 tiers hook which is being
    /// deployed.
    /// @param launchProjectConfig Configuration which dictates the behavior of the project which is being launched.
    /// @param controller The controller that the project's rulesets will be queued with.
    /// @return projectId The ID of the newly launched project.
    function launchProjectFor(
        address owner,
        JBDeploy721TiersHookConfig calldata deployTiersHookConfig,
        JBLaunchProjectConfig calldata launchProjectConfig,
        IJBController controller
    )
        external
        override
        returns (uint256 projectId)
    {
        // Get the project's ID, optimistically knowing it will be one greater than the current number of projects.
        projectId = DIRECTORY.PROJECTS().count() + 1;

        // Deploy the hook.
        IJB721TiersHook hook = HOOK_DEPLOYER.deployHookFor(projectId, deployTiersHookConfig);

        // Launch the project.
        _launchProjectFor(owner, launchProjectConfig, hook, controller);

        // Transfer the hook's ownership to the project.
        JBOwnable(address(hook)).transferOwnershipToProject(projectId);
    }

    /// @notice Launches rulesets for a project with an attached 721 tiers hook.
    /// @dev Only a project's owner or an operator with the `QUEUE_RULESETS` permission can launch its rulesets.
    /// @param projectId The ID of the project that rulesets are being launched for.
    /// @param deployTiersHookConfig Configuration which dictates the behavior of the 721 tiers hook which is being
    /// deployed.
    /// @param launchRulesetsConfig Configuration which dictates the project's new rulesets.
    /// @param controller The controller that the project's rulesets will be queued with.
    /// @return rulesetId The ID of the successfully created ruleset.
    function launchRulesetsFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig calldata deployTiersHookConfig,
        JBLaunchRulesetsConfig calldata launchRulesetsConfig,
        IJBController controller
    )
        external
        override
        returns (uint256 rulesetId)
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: DIRECTORY.PROJECTS().ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.QUEUE_RULESETS
        });

        // Deploy the hook.
        IJB721TiersHook hook = HOOK_DEPLOYER.deployHookFor(projectId, deployTiersHookConfig);

        // Transfer the hook's ownership to the project.
        JBOwnable(address(hook)).transferOwnershipToProject(projectId);

        // Launch the rulesets.
        return _launchRulesetsFor(projectId, launchRulesetsConfig, hook, controller);
    }

    /// @notice Queues rulesets for a project with an attached 721 tiers hook.
    /// @dev Only a project's owner or an operator with the `QUEUE_RULESETS` permission can queue its rulesets.
    /// @param projectId The ID of the project that rulesets are being queued for.
    /// @param deployTiersHookConfig Configuration which dictates the behavior of the 721 tiers hook which is being
    /// deployed.
    /// @param queueRulesetsConfig Configuration which dictates the project's newly queued rulesets.
    /// @param controller The controller that the project's rulesets will be queued with.
    /// @return rulesetId The ID of the successfully created ruleset.
    function queueRulesetsOf(
        uint256 projectId,
        JBDeploy721TiersHookConfig calldata deployTiersHookConfig,
        JBQueueRulesetsConfig calldata queueRulesetsConfig,
        IJBController controller
    )
        external
        override
        returns (uint256 rulesetId)
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: DIRECTORY.PROJECTS().ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.QUEUE_RULESETS
        });

        // Deploy the hook.
        IJB721TiersHook hook = HOOK_DEPLOYER.deployHookFor(projectId, deployTiersHookConfig);

        // Transfer the hook's ownership to the project.
        JBOwnable(address(hook)).transferOwnershipToProject(projectId);

        // Queue the rulesets.
        return _queueRulesetsOf(projectId, queueRulesetsConfig, hook, controller);
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Launches a project.
    /// @param owner The address that will own the project.
    /// @param launchProjectConfig Configuration which dictates the behavior of the project which is being launched.
    /// @param dataHook The data hook to use for the project.
    /// @param controller The controller that the project's rulesets will be queued with.
    function _launchProjectFor(
        address owner,
        JBLaunchProjectConfig memory launchProjectConfig,
        IJB721TiersHook dataHook,
        IJBController controller
    )
        internal
    {
        // Keep a reference to how many ruleset configurations there are.
        uint256 numberOfRulesetConfigurations = launchProjectConfig.rulesetConfigurations.length;

        // Initialize an array of ruleset configurations.
        JBRulesetConfig[] memory rulesetConfigurations = new JBRulesetConfig[](numberOfRulesetConfigurations);

        // Keep a reference to the pay data ruleset config being iterated on.
        JBPayDataHookRulesetConfig memory payDataRulesetConfig;

        // Set the data hook to be active for pay transactions for each ruleset configuration.
        for (uint256 i; i < numberOfRulesetConfigurations; i++) {
            // Set the pay data ruleset config being iterated on.
            payDataRulesetConfig = launchProjectConfig.rulesetConfigurations[i];

            // Add the ruleset config.
            rulesetConfigurations[i] = JBRulesetConfig({
                mustStartAtOrAfter: payDataRulesetConfig.mustStartAtOrAfter,
                duration: payDataRulesetConfig.duration,
                weight: payDataRulesetConfig.weight,
                decayPercent: payDataRulesetConfig.decayPercent,
                approvalHook: payDataRulesetConfig.approvalHook,
                metadata: JBRulesetMetadata({
                    reservedPercent: payDataRulesetConfig.metadata.reservedPercent,
                    redemptionRate: payDataRulesetConfig.metadata.redemptionRate,
                    baseCurrency: payDataRulesetConfig.metadata.baseCurrency,
                    pausePay: payDataRulesetConfig.metadata.pausePay,
                    pauseCreditTransfers: payDataRulesetConfig.metadata.pauseCreditTransfers,
                    allowOwnerMinting: payDataRulesetConfig.metadata.allowOwnerMinting,
                    allowSetCustomToken: false,
                    allowTerminalMigration: payDataRulesetConfig.metadata.allowTerminalMigration,
                    allowSetTerminals: payDataRulesetConfig.metadata.allowSetTerminals,
                    allowSetController: payDataRulesetConfig.metadata.allowSetController,
                    allowAddAccountingContext: payDataRulesetConfig.metadata.allowAddAccountingContext,
                    allowAddPriceFeed: payDataRulesetConfig.metadata.allowAddPriceFeed,
                    allowCrosschainSuckerExtension: payDataRulesetConfig.metadata.allowCrosschainSuckerExtension,
                    ownerMustSendPayouts: payDataRulesetConfig.metadata.ownerMustSendPayouts,
                    holdFees: payDataRulesetConfig.metadata.holdFees,
                    useTotalSurplusForRedemptions: payDataRulesetConfig.metadata.useTotalSurplusForRedemptions,
                    useDataHookForPay: true,
                    useDataHookForRedeem: payDataRulesetConfig.metadata.useDataHookForRedeem,
                    dataHook: address(dataHook),
                    metadata: payDataRulesetConfig.metadata.metadata
                }),
                splitGroups: payDataRulesetConfig.splitGroups,
                fundAccessLimitGroups: payDataRulesetConfig.fundAccessLimitGroups
            });
        }

        // Launch the project.
        controller.launchProjectFor({
            owner: owner,
            projectUri: launchProjectConfig.projectUri,
            rulesetConfigurations: rulesetConfigurations,
            terminalConfigurations: launchProjectConfig.terminalConfigurations,
            memo: launchProjectConfig.memo
        });
    }

    /// @notice Launches rulesets for a project.
    /// @param projectId The ID of the project to launch rulesets for.
    /// @param launchRulesetsConfig Configuration which dictates the behavior of the project's rulesets.
    /// @param dataHook The data hook to use for the project.
    /// @param controller The controller that the project's rulesets will be queued with.
    /// @return rulesetId The ID of the successfully created ruleset.
    function _launchRulesetsFor(
        uint256 projectId,
        JBLaunchRulesetsConfig memory launchRulesetsConfig,
        IJB721TiersHook dataHook,
        IJBController controller
    )
        internal
        returns (uint256)
    {
        // Keep a reference to how many ruleset configurations there are.
        uint256 numberOfRulesetConfigurations = launchRulesetsConfig.rulesetConfigurations.length;

        // Initialize an array of ruleset configurations.
        JBRulesetConfig[] memory rulesetConfigurations = new JBRulesetConfig[](numberOfRulesetConfigurations);

        // Keep a reference to the pay data ruleset config being iterated on.
        JBPayDataHookRulesetConfig memory payDataRulesetConfig;

        // Set the data hook to be active for pay transactions for each ruleset configuration.
        for (uint256 i; i < numberOfRulesetConfigurations; i++) {
            // Set the pay data ruleset config being iterated on.
            payDataRulesetConfig = launchRulesetsConfig.rulesetConfigurations[i];

            // Add the ruleset config.
            rulesetConfigurations[i] = JBRulesetConfig({
                mustStartAtOrAfter: payDataRulesetConfig.mustStartAtOrAfter,
                duration: payDataRulesetConfig.duration,
                weight: payDataRulesetConfig.weight,
                decayPercent: payDataRulesetConfig.decayPercent,
                approvalHook: payDataRulesetConfig.approvalHook,
                metadata: JBRulesetMetadata({
                    reservedPercent: payDataRulesetConfig.metadata.reservedPercent,
                    redemptionRate: payDataRulesetConfig.metadata.redemptionRate,
                    baseCurrency: payDataRulesetConfig.metadata.baseCurrency,
                    pausePay: payDataRulesetConfig.metadata.pausePay,
                    pauseCreditTransfers: payDataRulesetConfig.metadata.pauseCreditTransfers,
                    allowOwnerMinting: payDataRulesetConfig.metadata.allowOwnerMinting,
                    allowSetCustomToken: false,
                    allowTerminalMigration: payDataRulesetConfig.metadata.allowTerminalMigration,
                    allowSetTerminals: payDataRulesetConfig.metadata.allowSetTerminals,
                    allowSetController: payDataRulesetConfig.metadata.allowSetController,
                    allowAddAccountingContext: payDataRulesetConfig.metadata.allowAddAccountingContext,
                    allowAddPriceFeed: payDataRulesetConfig.metadata.allowAddPriceFeed,
                    allowCrosschainSuckerExtension: payDataRulesetConfig.metadata.allowCrosschainSuckerExtension,
                    ownerMustSendPayouts: payDataRulesetConfig.metadata.ownerMustSendPayouts,
                    holdFees: payDataRulesetConfig.metadata.holdFees,
                    useTotalSurplusForRedemptions: payDataRulesetConfig.metadata.useTotalSurplusForRedemptions,
                    useDataHookForPay: true,
                    useDataHookForRedeem: payDataRulesetConfig.metadata.useDataHookForRedeem,
                    dataHook: address(dataHook),
                    metadata: payDataRulesetConfig.metadata.metadata
                }),
                splitGroups: payDataRulesetConfig.splitGroups,
                fundAccessLimitGroups: payDataRulesetConfig.fundAccessLimitGroups
            });
        }

        // Launch the rulesets.
        return controller.launchRulesetsFor({
            projectId: projectId,
            rulesetConfigurations: rulesetConfigurations,
            terminalConfigurations: launchRulesetsConfig.terminalConfigurations,
            memo: launchRulesetsConfig.memo
        });
    }

    /// @notice Queues rulesets for a project.
    /// @param projectId The ID of the project to queue rulesets for.
    /// @param queueRulesetsConfig Configuration which dictates the behavior of the project's rulesets.
    /// @param dataHook The data hook to use for the project.
    /// @param controller The controller that the project's rulesets will be queued with.
    /// @return The ID of the successfully created ruleset.
    function _queueRulesetsOf(
        uint256 projectId,
        JBQueueRulesetsConfig memory queueRulesetsConfig,
        IJB721TiersHook dataHook,
        IJBController controller
    )
        internal
        returns (uint256)
    {
        // Keep a reference to how many ruleset configurations there are.
        uint256 numberOfRulesetConfigurations = queueRulesetsConfig.rulesetConfigurations.length;

        // Initialize an array of ruleset configurations.
        JBRulesetConfig[] memory rulesetConfigurations = new JBRulesetConfig[](numberOfRulesetConfigurations);

        // Keep a reference to the pay data ruleset config being iterated on.
        JBPayDataHookRulesetConfig memory payDataRulesetConfig;

        // Set the data hook to be active for pay transactions for each ruleset configuration.
        for (uint256 i; i < numberOfRulesetConfigurations; i++) {
            // Set the pay data ruleset config being iterated on.
            payDataRulesetConfig = queueRulesetsConfig.rulesetConfigurations[i];

            // Add the ruleset config.
            rulesetConfigurations[i] = JBRulesetConfig({
                mustStartAtOrAfter: payDataRulesetConfig.mustStartAtOrAfter,
                duration: payDataRulesetConfig.duration,
                weight: payDataRulesetConfig.weight,
                decayPercent: payDataRulesetConfig.decayPercent,
                approvalHook: payDataRulesetConfig.approvalHook,
                metadata: JBRulesetMetadata({
                    reservedPercent: payDataRulesetConfig.metadata.reservedPercent,
                    redemptionRate: payDataRulesetConfig.metadata.redemptionRate,
                    baseCurrency: payDataRulesetConfig.metadata.baseCurrency,
                    pausePay: payDataRulesetConfig.metadata.pausePay,
                    pauseCreditTransfers: payDataRulesetConfig.metadata.pauseCreditTransfers,
                    allowOwnerMinting: payDataRulesetConfig.metadata.allowOwnerMinting,
                    allowSetCustomToken: false,
                    allowTerminalMigration: payDataRulesetConfig.metadata.allowTerminalMigration,
                    allowSetTerminals: payDataRulesetConfig.metadata.allowSetTerminals,
                    allowSetController: payDataRulesetConfig.metadata.allowSetController,
                    allowAddAccountingContext: payDataRulesetConfig.metadata.allowAddAccountingContext,
                    allowAddPriceFeed: payDataRulesetConfig.metadata.allowAddPriceFeed,
                    allowCrosschainSuckerExtension: payDataRulesetConfig.metadata.allowCrosschainSuckerExtension,
                    ownerMustSendPayouts: payDataRulesetConfig.metadata.ownerMustSendPayouts,
                    holdFees: payDataRulesetConfig.metadata.holdFees,
                    useTotalSurplusForRedemptions: payDataRulesetConfig.metadata.useTotalSurplusForRedemptions,
                    useDataHookForPay: true,
                    useDataHookForRedeem: payDataRulesetConfig.metadata.useDataHookForRedeem,
                    dataHook: address(dataHook),
                    metadata: payDataRulesetConfig.metadata.metadata
                }),
                splitGroups: payDataRulesetConfig.splitGroups,
                fundAccessLimitGroups: payDataRulesetConfig.fundAccessLimitGroups
            });
        }

        // Queue the rulesets.
        return controller.queueRulesetsOf({
            projectId: projectId,
            rulesetConfigurations: rulesetConfigurations,
            memo: queueRulesetsConfig.memo
        });
    }
}
