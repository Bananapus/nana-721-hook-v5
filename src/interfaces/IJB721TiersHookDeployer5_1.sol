// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJB721TiersHook5_1} from "./IJB721TiersHook5_1.sol";
import {JBDeploy721TiersHookConfig} from "../structs/JBDeploy721TiersHookConfig.sol";

interface IJB721TiersHookDeployer5_1 {
    event HookDeployed(uint256 indexed projectId, IJB721TiersHook5_1 hook, address caller);

    function deployHookFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig,
        bytes32 salt
    )
        external
        returns (IJB721TiersHook5_1 hook);
}
