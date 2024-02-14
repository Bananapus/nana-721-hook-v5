// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IJBAddressRegistry} from "@bananapus/address-registry/src/interfaces/IJBAddressRegistry.sol";
import {JBOwnable} from "@bananapus/ownable/src/JBOwnable.sol";

import {IJB721TiersHookDeployer} from "./interfaces/IJB721TiersHookDeployer.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {JBDeploy721TiersHookConfig} from "./structs/JBDeploy721TiersHookConfig.sol";
import {JB721TiersHook} from "./JB721TiersHook.sol";

/// @title JB721TiersHookDeployer
/// @notice Deploys a `JB721TiersHook`.
contract JB721TiersHookDeployer is IJB721TiersHookDeployer {
    //*********************************************************************//
    // ----------------------- internal properties ----------------------- //
    //*********************************************************************//

    /// @notice This contract's current nonce, used for the Juicebox address registry.
    uint256 internal _nonce;

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice A 721 tiers hook.
    JB721TiersHook public immutable HOOK;

    /// @notice A registry which stores references to contracts and their deployers.
    IJBAddressRegistry public immutable ADDRESS_REGISTRY;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param hook Reference copy of a hook.
    /// @param addressRegistry A registry which stores references to contracts and their deployers.
    constructor(JB721TiersHook hook, IJBAddressRegistry addressRegistry) {
        HOOK = hook;
        ADDRESS_REGISTRY = addressRegistry;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Deploys a 721 tiers hook for the specified project.
    /// @param projectId The ID of the project to deploy the hook for.
    /// @param deployTiersHookConfig The config to deploy the hook with, which determines its behavior.
    /// @return newHook The address of the newly deployed hook.
    function deployHookFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig
    )
        external
        override
        returns (IJB721TiersHook newHook)
    {
        // Deploy the governance variant specified by the config.
        newHook = IJB721TiersHook(Clones.clone(address(HOOK)));

        newHook.initialize({
            projectId: projectId,
            name: deployTiersHookConfig.name,
            symbol: deployTiersHookConfig.symbol,
            rulesets: deployTiersHookConfig.rulesets,
            baseUri: deployTiersHookConfig.baseUri,
            tokenUriResolver: deployTiersHookConfig.tokenUriResolver,
            contractUri: deployTiersHookConfig.contractUri,
            tiersConfig: deployTiersHookConfig.tiersConfig,
            store: deployTiersHookConfig.store,
            flags: deployTiersHookConfig.flags
        });

        // Transfer the hook's ownership to the address that called this function.
        JBOwnable(address(newHook)).transferOwnership(msg.sender);

        // Add the hook to the address registry. This contract's nonce starts at 1.
        ADDRESS_REGISTRY.registerAddress(address(this), ++_nonce);

        emit HookDeployed(projectId, newHook);
    }
}
