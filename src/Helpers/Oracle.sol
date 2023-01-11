// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Oracle {
    function getPriceInUSD(address _oracle) internal view returns (int256) {
        (, int256 price,,,) = AggregatorV3Interface(_oracle).latestRoundData();
        return price;
    }
}
