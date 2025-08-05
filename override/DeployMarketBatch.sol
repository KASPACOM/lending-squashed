// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@aave-v3-origin/src/deployments/interfaces/IMarketReportTypes.sol";
import {IMetadataReporter} from "@aave-v3-origin/src/deployments/interfaces/IMetadataReporter.sol";
import {DeployUtils} from "@aave-v3-origin/src/deployments/contracts/utilities/DeployUtils.sol";
import {AaveV3BatchOrchestration} from "@aave-v3-origin/src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol";

import {MarketInput} from "./MarketInput.sol";

abstract contract DeployMarketBatch is DeployUtils, MarketInput, Script {
    using stdJson for string;

    uint public DEPLOYER_KEY;

    function run() public virtual {
        DEPLOYER_KEY = vm.envUint("DEPLOYER_KEY");

        Roles memory roles;
        MarketConfig memory config;
        DeployFlags memory flags;
        MarketReport memory report;

        console.log("Aave V3 Batch Deployment");
        console.log("deployer", msg.sender);

        (roles, config, flags, report) = _getMarketInput(msg.sender);

        _loadWarnings(config, flags);

        vm.startBroadcast(DEPLOYER_KEY);
        report = AaveV3BatchOrchestration.deployAaveV3(
            msg.sender,
            roles,
            config,
            flags,
            report
        );
        vm.stopBroadcast();

        // Write market deployment JSON report at /reports
        IMetadataReporter metadataReporter = IMetadataReporter(
            _deployFromArtifacts("MetadataReporter.sol:MetadataReporter")
        );
        metadataReporter.writeJsonReportMarket(report);
    }

    function _loadWarnings(
        MarketConfig memory config,
        DeployFlags memory flags
    ) internal pure {
        if (config.paraswapAugustusRegistry == address(0)) {
            console.log(
                "Warning: Paraswap Adapters will be skipped at deployment due missing config.paraswapAugustusRegistry"
            );
        }
        if (
            (flags.l2 &&
                (config.l2SequencerUptimeFeed == address(0) ||
                    config.l2PriceOracleSentinelGracePeriod == 0))
        ) {
            console.log(
                "Warning: L2 Sequencer uptime feed wont be set at deployment due missing config.l2SequencerUptimeFeed config.l2PriceOracleSentinelGracePeriod"
            );
        }
        if (
            config.networkBaseTokenPriceInUsdProxyAggregator == address(0) ||
            config.marketReferenceCurrencyPriceInUsdProxyAggregator ==
            address(0)
        ) {
            console.log(
                "Warning: UiPoolDataProvider will be skipped at deployment due missing config.networkBaseTokenPriceInUsdProxyAggregator or config.marketReferenceCurrencyPriceInUsdProxyAggregator"
            );
        }
        if (config.wrappedNativeToken == address(0)) {
            console.log(
                "Warning: WrappedTokenGateway will be skipped at deployment due missing config.wrappedNativeToken"
            );
        }
    }
}
