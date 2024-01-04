// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/juice-contracts-v4/src/structs/JBRulesetConfig.sol";
import "lib/juice-contracts-v4/src/structs/JBFundAccessLimitGroup.sol";
import "lib/juice-contracts-v4/src/structs/JBSplitGroup.sol";
import "./JBPayDataHookRulesetMetadata.sol";

/// @custom:member config A config that defines the project's first ruleset. // TODO: This should probably be a
/// `JBRulesetConfig[]`.
/// @custom:member metadata Metadata specifying the controller-specific parameters that a ruleset can have (except for
/// `useDataHookForPay`, which must be true). These properties cannot change until the next ruleset starts.
/// @custom:member mustStartAtOrAfter The earliest time the ruleset can start.
/// @custom:member splitGroups An array of splits to use for any number of groups while the ruleset is active.
/// @custom:member fundAccessLimitGroups An array of structs which dictate the amount of funds a project can access from
/// its balance in each payment terminal while the ruleset is active. Amounts are fixed point numbers using the same
/// number of decimals as the corresponding terminal. The `_payoutLimit` and `_surplusAllowance` parameters must fit in
/// a `uint232`.
/// @custom:member memo A memo to pass along to the emitted event.
struct JBQueueRulesetsConfig {
    JBRulesetConfig config;
    JBPayDataHookRulesetMetadata metadata;
    uint256 mustStartAtOrAfter;
    JBSplitGroup[] splitGroups;
    JBFundAccessLimitGroup[] fundAccessLimitGroups;
    string memo;
}
