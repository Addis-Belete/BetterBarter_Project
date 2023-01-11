// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../Interfaces/IReceiptToken.sol";
// This contract is responsible for price protection.

contract PriceProtection {
    struct CollateralInfo {
        int256 priceInUSD;
        uint256 stakingPeriod;
        uint256 amount;
        uint256 initailTime;
        bool isLocked;
    }

    mapping(address => mapping(uint256 => CollateralInfo)) public collateral; // address => collateralId => CollateralInfo
    mapping(address => uint256) internal userCollateralIds;
    address internal betterAddress;
    address internal underlying;
    IReceiptToken internal receiptToken;

    modifier onlyBetterAddress(address _addr) {
        require(msg.sender == _addr, "Only called by Better address");
        _;
    }

    constructor(address _betterAddress, address _receiptTokenaddress) {
        betterAddress = _betterAddress;
        receiptToken = IReceiptToken(_receiptTokenaddress);
    }

    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod)
        external
        onlyBetterAddress(msg.sender)
        returns (int256)
    {
        uint256 collateralId = userCollateralIds[userAddress]++;

        int256 assetPriceInUSD = (getPriceInUSD(underlying)) * int256(amount);

        CollateralInfo memory _collateralInfo =
            CollateralInfo(assetPriceInUSD, stakingPeriod, amount, block.timestamp, true);

        collateral[userAddress][collateralId] = _collateralInfo;

        receiptToken.mint(userAddress, amount);
        return assetPriceInUSD;
    }

    function getPriceInUSD(address _oracle) internal view returns (int256) {
        (, int256 price,,,) = AggregatorV3Interface(_oracle).latestRoundData();
        return price;
    }
}

/**
 * @user posts the derivatives for call option
 * buyer can send a premium of 10% and buy with strike price until expiration date.
 * If buyer not buyed in expiration date or it is under strike price the asset sent back to the user or wothdraw any time
 */
