// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/core/script/helpers/CoreDeploymentLib.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {JBAddressRegistry} from "@bananapus/address-registry/src/JBAddressRegistry.sol";
import {JB721TiersHookDeployer} from "../src/JB721TiersHookDeployer.sol";
import {JB721TiersHookProjectDeployer} from "../src/JB721TiersHookProjectDeployer.sol";
import {JB721TiersHookStore} from "../src/JB721TiersHookStore.sol";
import {JB721TiersHook} from "../src/JB721TiersHook.sol";

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    address private constant TRUSTED_FORWARDER = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

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

    /// @notice each contract here will be deployed it if needs to be (re)deployed.
    /// It will deploy if the contracts bytecode changes or if any constructor arguments change.
    /// Since all the contract dependencies are passed in using the constructor args,
    // this makes it so that if any dependency contract (address) changes the contract will be redeployed.
    function deploy() public sphinx {
        // TODO: For now we also deploy the `JBAddressRegistry` here, we probably want to move this to its repository.
        JBAddressRegistry registry;
        {
            // Perform the check for the registry.
            (address _registry, bool _registryIsDeployed) =
                _isDeployed(ADDRESS_REGISTRY_SALT, type(JBAddressRegistry).creationCode, "");
            // Deploy it if it has not been deployed yet.
            registry = !_registryIsDeployed
                ? new JBAddressRegistry{salt: ADDRESS_REGISTRY_SALT}()
                : JBAddressRegistry(_registry);
        }

        JB721TiersHook hook;
        {
            // Perform the check for the registry.
            (address _hook, bool _hookIsDeployed) = _isDeployed(
                HOOK_SALT,
                type(JB721TiersHook).creationCode,
                abi.encode(core.directory, core.permissions, TRUSTED_FORWARDER)
            );

            // Deploy it if it has not been deployed yet.
            hook = !_hookIsDeployed
                ? new JB721TiersHook{salt: HOOK_SALT}(core.directory, core.permissions, TRUSTED_FORWARDER)
                : JB721TiersHook(_hook);
        }

        JB721TiersHookStore store;
        {
            // Perform the check for the store.
            (address _store, bool _storeIsDeployed) =
                _isDeployed(HOOK_STORE_SALT, type(JB721TiersHookStore).creationCode, "");

            // Deploy it if it has not been deployed yet.
            store = !_storeIsDeployed ? new JB721TiersHookStore{salt: HOOK_STORE_SALT}() : JB721TiersHookStore(_store);
        }

        JB721TiersHookDeployer hookDeployer;
        {
            // Perform the check for the registry.
            (address _hookDeployer, bool _hookDeployerIsDeployed) = _isDeployed(
                HOOK_DEPLOYER_SALT,
                type(JB721TiersHookDeployer).creationCode,
                abi.encode(hook, store, registry, TRUSTED_FORWARDER)
            );

            hookDeployer = !_hookDeployerIsDeployed
                ? new JB721TiersHookDeployer{salt: HOOK_DEPLOYER_SALT}(hook, store, registry, TRUSTED_FORWARDER)
                : JB721TiersHookDeployer(_hookDeployer);
        }

        JB721TiersHookProjectDeployer projectDeployer;
        {
            // Perform the check for the registry.
            (address _projectDeployer, bool _projectDeployerIsdeployed) = _isDeployed(
                PROJECT_DEPLOYER_SALT,
                type(JB721TiersHookProjectDeployer).creationCode,
                abi.encode(core.directory, core.permissions, hookDeployer)
            );

            projectDeployer = !_projectDeployerIsdeployed
                ? new JB721TiersHookProjectDeployer{salt: PROJECT_DEPLOYER_SALT}(
                    core.directory, core.permissions, hookDeployer
                )
                : JB721TiersHookProjectDeployer(_projectDeployer);
        }
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    )
        internal
        view
        returns (address, bool)
    {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return (_deployedTo, address(_deployedTo).code.length != 0);
    }
}
