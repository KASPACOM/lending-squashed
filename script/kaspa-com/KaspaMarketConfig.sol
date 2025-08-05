// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {ConfiguratorInputTypes} from "@aave-v3-origin/src/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import {IPoolConfigurator} from "@aave-v3-origin/src/contracts/interfaces/IPoolConfigurator.sol";
import {IAaveOracle} from "@aave-v3-origin/src/contracts/interfaces/IAaveOracle.sol";
import {IERC20Detailed} from "@aave-v3-origin/src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import {DataTypes} from "@aave-v3-origin/src/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "@aave-v3-origin/src/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-origin/src/contracts/interfaces/IPoolAddressesProvider.sol";
import {IDefaultInterestRateStrategyV2} from "@aave-v3-origin/src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

struct MarketInfra {
    address poolConfiguratorProxy;
    address aaveOracle;
    address treasury;
    address aToken;
    address vToken;
    address interestRateStrategy;
    address poolAddressesProvider;
    address rewardsControllerProxy;
}

struct RiskParams {
    uint256 ltv;
    uint256 lt;
    uint256 liqBonus;
}

struct Caps {
    uint256 supplyCap;
    uint256 borrowCap;
}

struct InterestRateData {
    uint16 usageRatio;
    uint32 borrowRateBase;
    uint32 borrowRateSlope1;
    uint32 borrowRateSlope2;
}

struct AssetConfig {
    string symbol;
    address addr;
    address priceFeed;
    RiskParams riskParams;
    Caps caps;
    uint8 decimals;
    uint256 reserveFactor;
    bool borrowingEnabled;
    bool useVirtualBalance;
    InterestRateData interestRateData;
}

contract KaspaMarketConfig is Script {
    using stdJson for string;

    string public configPath;

    MarketInfra public marketInfra;

    address public POOL_ADMIN_KEY;

    AssetConfig[] public assetsConfig;

    AssetConfig[] public assetsToInitialize;

    IPool public pool;

    function run() public virtual {
        configPath = vm.envString("CONFIG_PATH");

        POOL_ADMIN_KEY = vm.envAddress("POOL_ADMIN_KEY");

        readInfra();

        require(
            marketInfra.poolConfiguratorProxy != address(0),
            "Pool configurator address not set"
        );

        require(marketInfra.aaveOracle != address(0), "Oracle address not set");

        require(marketInfra.treasury != address(0), "Treasury address not set");

        require(
            marketInfra.aToken != address(0),
            "aToken implementation address not set"
        );

        require(
            marketInfra.vToken != address(0),
            "Variable debt token implementation address not set"
        );

        require(
            marketInfra.interestRateStrategy != address(0),
            "Interest rate strategy address not set"
        );

        require(assetsConfig.length > 0, "No tokens found");

        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(
            marketInfra.poolAddressesProvider
        );

        pool = IPool(addressesProvider.getPool());

        IPoolConfigurator configurator = IPoolConfigurator(
            marketInfra.poolConfiguratorProxy
        );

        IAaveOracle oracle = IAaveOracle(marketInfra.aaveOracle);

        initializeReserves(configurator);

        configureRiskParameters(configurator);

        setPriceSources(oracle);

        setSupplyAndBorrowCaps(configurator);

        configureAdditionalSettings(configurator);
    }

    function readInfra() public virtual {
        string memory jsonConfig = vm.readFile(configPath);

        marketInfra.poolConfiguratorProxy = jsonConfig.readAddress(
            ".marketConfig.poolConfiguratorProxy"
        );

        marketInfra.aaveOracle = jsonConfig.readAddress(
            ".marketConfig.aaveOracle"
        );

        marketInfra.treasury = jsonConfig.readAddress(".marketConfig.treasury");

        marketInfra.aToken = jsonConfig.readAddress(".marketConfig.aToken");

        marketInfra.vToken = jsonConfig.readAddress(
            ".marketConfig.variableDebtToken"
        );

        marketInfra.interestRateStrategy = jsonConfig.readAddress(
            ".marketConfig.defaultInterestRateStrategy"
        );

        marketInfra.poolAddressesProvider = jsonConfig.readAddress(
            ".marketConfig.poolAddressesProvider"
        );

        marketInfra.rewardsControllerProxy = jsonConfig.readAddress(
            ".marketConfig.rewardsControllerProxy"
        );

        uint8 i = 0;
        while (true) {
            string memory prefix = string.concat(
                ".tokens[",
                vm.toString(i),
                "]"
            );

            if (
                jsonConfig.parseRaw(string.concat(prefix, ".caps")).length == 0
            ) {
                break;
            }

            Caps memory caps = Caps({
                supplyCap: jsonConfig.readUint(
                    string.concat(prefix, ".caps.supplyCap")
                ),
                borrowCap: jsonConfig.readUint(
                    string.concat(prefix, ".caps.borrowCap")
                )
            });

            RiskParams memory riskParams = RiskParams({
                ltv: jsonConfig.readUint(
                    string.concat(prefix, ".riskParams.ltv")
                ),
                lt: jsonConfig.readUint(
                    string.concat(prefix, ".riskParams.liquidationThreshold")
                ),
                liqBonus: jsonConfig.readUint(
                    string.concat(prefix, ".riskParams.liquidationBonus")
                )
            });
            InterestRateData memory interestRateData = InterestRateData({
                usageRatio: uint16(
                    jsonConfig.readUint(
                        string.concat(
                            prefix,
                            ".interestRateData.optimalUsageRatio"
                        )
                    )
                ),
                borrowRateBase: uint32(
                    jsonConfig.readUint(
                        string.concat(
                            prefix,
                            ".interestRateData.baseVariableBorrowRate"
                        )
                    )
                ),
                borrowRateSlope1: uint32(
                    jsonConfig.readUint(
                        string.concat(
                            prefix,
                            ".interestRateData.variableRateSlope1"
                        )
                    )
                ),
                borrowRateSlope2: uint32(
                    jsonConfig.readUint(
                        string.concat(
                            prefix,
                            ".interestRateData.variableRateSlope2"
                        )
                    )
                )
            });

            AssetConfig memory token = AssetConfig({
                symbol: jsonConfig.readString(string.concat(prefix, ".symbol")),
                addr: jsonConfig.readAddress(string.concat(prefix, ".address")),
                priceFeed: jsonConfig.readAddress(
                    string.concat(prefix, ".priceFeed")
                ),
                riskParams: riskParams,
                caps: caps,
                decimals: uint8(
                    jsonConfig.readUint(string.concat(prefix, ".decimals"))
                ),
                reserveFactor: jsonConfig.readUint(
                    string.concat(prefix, ".reserveFactor")
                ),
                borrowingEnabled: jsonConfig.readBool(
                    string.concat(prefix, ".borrowingEnabled")
                ),
                useVirtualBalance: jsonConfig.readBool(
                    string.concat(prefix, ".useVirtualBalance")
                ),
                interestRateData: interestRateData
            });

            // Add token to configurations
            assetsConfig.push(token);

            i++;
        }
    }

    function initializeReserves(IPoolConfigurator configurator) internal {
        ConfiguratorInputTypes.InitReserveInput[]
            memory inputReservesProbe = new ConfiguratorInputTypes.InitReserveInput[](
                assetsConfig.length
            );

        uint inputReservesLength;

        for (uint256 i = 0; i < assetsConfig.length; i++) {
            AssetConfig memory asset = assetsConfig[i];

            if (pool.getReserveData(asset.addr).aTokenAddress != address(0)) {
                continue;
            }

            inputReservesProbe[i] = ConfiguratorInputTypes.InitReserveInput({
                aTokenImpl: marketInfra.aToken,
                variableDebtTokenImpl: marketInfra.vToken,
                useVirtualBalance: asset.useVirtualBalance,
                interestRateStrategyAddress: marketInfra.interestRateStrategy,
                underlyingAsset: asset.addr,
                treasury: marketInfra.treasury,
                incentivesController: marketInfra.rewardsControllerProxy,
                aTokenName: string.concat("Aave ", asset.symbol),
                aTokenSymbol: string.concat("a", asset.symbol),
                variableDebtTokenName: string.concat(
                    "Aave Variable Debt ",
                    asset.symbol
                ),
                variableDebtTokenSymbol: string.concat("v", asset.symbol),
                params: bytes(""),
                interestRateData: abi.encode(
                    IDefaultInterestRateStrategyV2.InterestRateData({
                        optimalUsageRatio: asset.interestRateData.usageRatio,
                        baseVariableBorrowRate: asset
                            .interestRateData
                            .borrowRateBase,
                        variableRateSlope1: asset
                            .interestRateData
                            .borrowRateSlope1,
                        variableRateSlope2: asset
                            .interestRateData
                            .borrowRateSlope2
                    })
                )
            });

            inputReservesLength++;
        }

        ConfiguratorInputTypes.InitReserveInput[]
            memory inputReserves = new ConfiguratorInputTypes.InitReserveInput[](
                inputReservesLength
            );

        for (uint256 i = 0; i < inputReservesProbe.length; i++) {
            inputReserves[i] = inputReservesProbe[i];
        }

        vm.startBroadcast(POOL_ADMIN_KEY);
        configurator.initReserves(inputReserves);
        vm.stopBroadcast();
    }

    function configureRiskParameters(IPoolConfigurator configurator) internal {
        vm.startBroadcast(POOL_ADMIN_KEY);

        for (uint256 i = 0; i < assetsConfig.length; i++) {
            AssetConfig memory asset = assetsConfig[i];

            if (pool.getReserveData(asset.addr).aTokenAddress != address(0)) {
                console.log(
                    "Skipping risk parameters for non-initialized token:",
                    asset.symbol
                );
                continue;
            }

            configurator.configureReserveAsCollateral(
                asset.addr,
                asset.riskParams.ltv,
                asset.riskParams.lt,
                asset.riskParams.liqBonus
            );
        }

        vm.stopBroadcast();
    }

    function setPriceSources(IAaveOracle oracle) internal {
        address[] memory assets = new address[](assetsConfig.length);
        address[] memory sources = new address[](assetsConfig.length);

        for (uint256 i = 0; i < assetsConfig.length; i++) {
            AssetConfig memory asset = assetsConfig[i];

            assets[i] = asset.addr;
            sources[i] = asset.priceFeed;
        }

        vm.startBroadcast(POOL_ADMIN_KEY);
        oracle.setAssetSources(assets, sources);
        vm.stopBroadcast();
    }

    function setSupplyAndBorrowCaps(IPoolConfigurator configurator) internal {
        vm.startBroadcast(POOL_ADMIN_KEY);

        // Set caps for each token
        for (uint256 i = 0; i < assetsConfig.length; i++) {
            AssetConfig memory asset = assetsConfig[i];

            if (pool.getReserveData(asset.addr).aTokenAddress != address(0)) {
                continue;
            }

            // Calculate actual caps with decimals
            uint256 supplyCap = asset.caps.supplyCap;
            uint256 borrowCap = asset.caps.borrowCap;

            configurator.setSupplyCap(asset.addr, supplyCap);
            configurator.setBorrowCap(asset.addr, borrowCap);
        }

        vm.stopBroadcast();
    }

    function configureAdditionalSettings(
        IPoolConfigurator configurator
    ) internal {
        vm.startBroadcast(POOL_ADMIN_KEY);

        for (uint256 i = 0; i < assetsConfig.length; i++) {
            AssetConfig memory asset = assetsConfig[i];

            if (pool.getReserveData(asset.addr).aTokenAddress != address(0)) {
                console.log(
                    "Skipping additional settings for non-initialized token:",
                    asset.symbol
                );
                continue;
            }

            configurator.setReserveFactor(asset.addr, asset.reserveFactor);

            if (asset.borrowingEnabled) {
                configurator.setReserveBorrowing(asset.addr, true);
            }

            configurator.setReserveActive(asset.addr, true);
        }

        vm.stopBroadcast();
    }
}
