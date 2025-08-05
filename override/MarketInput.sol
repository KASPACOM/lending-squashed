// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@aave-v3-origin/src/deployments/interfaces/IMarketReportTypes.sol";

abstract contract MarketInput {
    function _getMarketInput(
        address
    )
        internal
        virtual
        returns (
            Roles memory roles,
            MarketConfig memory config,
            DeployFlags memory flags,
            MarketReport memory deployedContracts
        );
}
