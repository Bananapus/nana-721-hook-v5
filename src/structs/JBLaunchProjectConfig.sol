// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/juice-contracts-v4/src/structs/JBRulesetConfig.sol";
import "lib/juice-contracts-v4/src/structs/JBTerminalConfig.sol";

/// @custom:member owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
/// @custom:member projectMetadata Metadata to associate with the project. This can be updated any time by the owner of the
/// project.
/// @custom:member rulesetConfigurations The ruleset configurations to queue.
/// @custom:member terminalConfigurations The terminal configurations to add for the project.
/// @custom:member memo A memo to pass along to the emitted event.
struct JBLaunchProjectConfig {
    address owner;
    string projectMetadata;
    JBRulesetConfig[] rulesetConfigurations;
    JBTerminalConfig[] terminalConfigurations;
    string memo;
}
