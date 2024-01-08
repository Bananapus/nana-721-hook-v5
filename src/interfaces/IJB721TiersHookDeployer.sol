// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBDeploy721TiersHookConfig} from "../structs/JBDeploy721TiersHookConfig.sol";
import {IJB721TiersHook} from "./IJB721TiersHook.sol";

interface IJB721TiersHookDeployer {
    event HookDeployed(uint256 indexed projectId, IJB721TiersHook newHook);

    function deployHookFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig
    )
        external
        returns (IJB721TiersHook hook);
}
