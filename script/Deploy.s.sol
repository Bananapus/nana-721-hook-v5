// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// import "../src/deployers/BPOptimismSuckerDeployer.sol";
import "@bananapus/core/script/helpers/CoreDeploymentLib.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {JBAddressRegistry, IJBAddressRegistry} from "@bananapus/address-registry/src/JBAddressRegistry.sol";
import {JB721TiersHookDeployer} from "../src/JB721TiersHookDeployer.sol";
import {JB721TiersHookProjectDeployer} from "../src/JB721TiersHookProjectDeployer.sol";
import {JB721TiersHookStore} from "../src/JB721TiersHookStore.sol";
import {JB721TiersHook} from "../src/JB721TiersHook.sol";

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the addressed of the deployers that will get pre-approved.
    address[] PRE_APPROVED_DEPLOYERS;

    /// @notice the salts that are used to deploy the contracts.
    bytes32 ADDRESS_REGISTRY_SALT = "JBAddressRegistry";
    bytes32 HOOK_SALT = "JB721TiersHook";
    bytes32 HOOK_DEPLOYER_SALT = "JB721TiersHookDeployer";
    bytes32 HOOK_STORE_SALT = "JB721TiersHookStore";
    bytes32 PROJECT_DEPLOYER_SALT = "JB721TiersHookProjectDeployer";

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.owners = [0x26416423d530b1931A2a7a6b7D435Fac65eED27d];
        sphinxConfig.orgId = "cltepuu9u0003j58rjtbd0hvu";
        sphinxConfig.projectName = "nana-721-hook";
        sphinxConfig.threshold = 1;
        sphinxConfig.mainnets = ["ethereum", "optimism", "polygon"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "polygon_mumbai"];
        sphinxConfig.saltNonce = 3;
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core/deployments/"))
        );
        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        // TODO: For now we also deploy the `JBAddressRegistry` here, we probably want to move this to its repository.
        JBAddressRegistry _registry = new JBAddressRegistry{salt: ADDRESS_REGISTRY_SALT}();
        JB721TiersHook hook = new JB721TiersHook{salt: HOOK_SALT}(core.directory, core.permissions);
        JB721TiersHookDeployer hookDeployer = new JB721TiersHookDeployer{salt: HOOK_DEPLOYER_SALT}(
            hook,
            new JB721TiersHookStore{salt: HOOK_STORE_SALT}(),
            _registry
        );
        new JB721TiersHookProjectDeployer{salt: PROJECT_DEPLOYER_SALT}(core.directory, core.permissions, hookDeployer);
    }
}
