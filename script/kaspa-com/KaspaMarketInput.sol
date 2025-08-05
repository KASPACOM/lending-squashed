// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "override/MarketInput.sol";
import {Script} from "forge-std/Script.sol";

contract KaspaMarketInput is MarketInput, Script {
    bytes32 public constant SALT = bytes32("KaspaCom-lending");

    address public BASE_TOKEN_USD_AGGREGATOR;
    address public REFFERENCE_CURRENCY_USD_AGGREGATOR;
    address public WKAS;

    function run() public virtual {
        BASE_TOKEN_USD_AGGREGATOR = vm.envAddress("BASE_TOKEN_USD_AGGREGATOR");
        REFFERENCE_CURRENCY_USD_AGGREGATOR = vm.envAddress(
            "REFFERENCE_CURRENCY_USD_AGGREGATOR"
        );
        WKAS = vm.envAddress("WKAS");
    }

    function _getMarketInput(
        address deployer
    )
        internal
        virtual
        override
        returns (
            Roles memory roles,
            MarketConfig memory config,
            DeployFlags memory flags,
            MarketReport memory deployedContracts
        )
    {
        roles.marketOwner = deployer;
        roles.emergencyAdmin = deployer;
        roles.poolAdmin = deployer;

        config
            .networkBaseTokenPriceInUsdProxyAggregator = BASE_TOKEN_USD_AGGREGATOR;
        config
            .marketReferenceCurrencyPriceInUsdProxyAggregator = REFFERENCE_CURRENCY_USD_AGGREGATOR;

        config.marketId = "Kaspa Chain Market";
        config.oracleDecimals = 8;

        config.paraswapAugustusRegistry = address(0); // Some of functions with paraswap will not work
        config.l2SequencerUptimeFeed = address(0); // Oracle sequence address needed for L2 deployment
        config.l2PriceOracleSentinelGracePeriod = 0; // Set if sequence will be deployed

        config.providerId = 777;
        config.salt = SALT;
        config.wrappedNativeToken = WKAS;

        config.flashLoanPremiumTotal = 0.0005e4;
        config.flashLoanPremiumToProtocol = 0.0004e4;

        config.incentivesProxy = address(0); //Will create automatically if contract is not provided check AaveV3PeripheryBatch.sol
        config.treasury = address(0); // Will create automatically if contract is not provided check AaveV3PeripheryBatch.sol
        config.treasuryPartner = address(0);
        config.treasurySplitPercent = 0;

        flags.l2 = false;

        return (roles, config, flags, deployedContracts);
    }
}
