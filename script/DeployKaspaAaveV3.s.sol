// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MarketConfig, DeployFlags, MarketReport, Roles} from "@aave-v3-origin/src/deployments/inputs/MarketInput.sol";

import {DeployMarketBatch} from "override/DeployMarketBatch.sol";
import {MarketInput} from "override/MarketInput.sol";

import {KaspaMarketInput} from "./kaspa-com/KaspaMarketInput.sol";

contract DeployKaspaAaveV3 is DeployMarketBatch, KaspaMarketInput {
    function run() public override(DeployMarketBatch, KaspaMarketInput) {
        KaspaMarketInput.run();
        DeployMarketBatch.run();
    }

    function _getMarketInput(
        address deployer
    )
        internal
        override(MarketInput, KaspaMarketInput)
        returns (
            Roles memory roles,
            MarketConfig memory config,
            DeployFlags memory flags,
            MarketReport memory deployedContracts
        )
    {
        return KaspaMarketInput._getMarketInput(deployer);
    }
}
