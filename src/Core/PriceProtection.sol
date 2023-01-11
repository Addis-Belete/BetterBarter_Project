// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// This contract is responsible for price protection.
contract PriceProtection {
    struct CollateralInfo {
        uint256 priceInUSD;
        uint256 stakingPeriod;
        uint256 amount;
        uint256 initailTime;
        bool isLocked;
    }

    mapping(address => mapping(uint256 => CollateralInfo)) public collateral; // address => collateralId => CollateralInfo
    mapping(address => uint256) internal userCollateralIds;
    address internal betterAddress;
    address internal underlying;

    modifier onlyBetterAddress(address _addr) {
        require(msg.sender == _addr, "Only called by Better address");
        _;
    }

    constructor(address _betterAddress) {
        betterAddress = _betterAddress;
    }

    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod)
        external
        onlyBetterAddress(msg.sender)
        returns (uint256)
    {
        uint256 collateralId = userCollateralIds[userAddress]++;

        uint256 assetPriceInUSD = getPriceInUSD(underlying) * amount;

        CollateralInfo memory _collateralInfo =
            CollateralInfo(assetPriceInUSD, stakingPeriod, amount, block.timestamp, true);

        collateral[userAddress][collateralId] = _collateralInfo;

        return assetPriceInUSD;
    }

    function getPriceInUSD(address addr) internal returns (uint256) {}
}

/**
 * @user posts the derivatives for call option
 * buyer can send a premium of 10% and buy with strike price until expiration date.
 * If buyer not buyed in expiration date or it is under strike price the asset sent back to the user or wothdraw any time
 */
