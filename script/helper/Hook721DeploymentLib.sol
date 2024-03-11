// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {SphinxConstants, NetworkInfo} from "@sphinx-labs/contracts/SphinxConstants.sol";

import {JB721TiersHookDeployer} from "../../src/JB721TiersHookDeployer.sol";
import {JB721TiersHookProjectDeployer} from "../../src/JB721TiersHookProjectDeployer.sol";
import {JB721TiersHookStore} from "../../src/JB721TiersHookStore.sol";

struct Hook721Deployment {
    JB721TiersHookDeployer hook_deployer;
    JB721TiersHookProjectDeployer project_deployer;
    JB721TiersHookStore store;
}

library Hook721DeploymentLib{
    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function getDeployment(string memory path) internal returns (Hook721Deployment memory deployment) {
        // get chainId for which we need to get the deployment.
        uint256 chainId = block.chainid;

        // Deploy to get the constants.
        // TODO: get constants without deploy.
        SphinxConstants sphinxConstants = new SphinxConstants();
        NetworkInfo[] memory networks = sphinxConstants.getNetworkInfoArray();

        for(uint256 _i; _i < networks.length; _i++) {
            if(networks[_i].chainId == chainId) {
                return getDeployment(path, networks[_i].name);
            }
        }

        revert("ChainID is not (currently) supported by Sphinx.");
    }

    function getDeployment(string memory path, string memory network_name) internal view returns (Hook721Deployment memory deployment)  {
        deployment.hook_deployer = JB721TiersHookDeployer(_getDeploymentAddress(
            path,
            "nana-core",
            network_name,
            "JB721TiersHookDeployer"
        ));

        deployment.project_deployer = JB721TiersHookProjectDeployer(_getDeploymentAddress(
            path,
            "nana-core",
            network_name,
            "JB721TiersHookProjectDeployer"
        ));

        deployment.store = JB721TiersHookStore(_getDeploymentAddress(
            path,
            "nana-core",
            network_name,
            "JB721TiersHookStore"
        ));
    }


    /// @notice Get the address of a contract that was deployed by the Deploy script.
    /// @dev Reverts if the contract was not found.
    /// @param path The path to the deployment file.
    /// @param contractName The name of the contract to get the address of.
    /// @return The address of the contract.
    function _getDeploymentAddress(
        string memory path,
        string memory project_name,
        string memory network_name,
        string memory contractName
    ) internal view returns (address) {
        string memory deploymentJson = vm.readFile(string.concat(path, project_name, "/", network_name, "/", contractName, ".json"));
        return stdJson.readAddress(deploymentJson, ".address");
    }
} 