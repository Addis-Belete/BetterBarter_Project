// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Helpers/Oracle.sol";
import "../Interfaces/IReceiptToken.sol";
// This contract is responsible for price protection.

contract PriceProtection is Oracle {
    struct CollateralInfo {
        int256 priceInUSD;
        uint256 stakingPeriod;
        uint256 amount;
        uint256 initailTime;
        bool isLocked;
        uint256 callOptionId;
    }

    mapping(address => mapping(uint256 => CollateralInfo)) internal collateral; // address => collateralId => CollateralInfo
    mapping(address => uint256) internal userCollateralIds;
    address internal betterAddress;
    address internal underlying;
    IReceiptToken internal receiptToken;
    address internal admin;

    modifier onlyBetterAddress() {
        require(msg.sender == betterAddress, "Only called by Better address");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only called by admin");
        _;
    }

    constructor(address _betterAddress, address _receiptTokenaddress) {
        betterAddress = _betterAddress;
        receiptToken = IReceiptToken(_receiptTokenaddress);
        admin = msg.sender;
    }

    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod, uint256 callOptionId)
        external
        onlyBetterAddress
        returns (bool, uint256, uint256)
    {
        uint256 collateralId = userCollateralIds[userAddress]++;

        int256 assetPriceInUSD = (getPriceInUSD(underlying)) * int256(amount);

        CollateralInfo memory _collateralInfo =
            CollateralInfo(assetPriceInUSD, stakingPeriod, amount, block.timestamp, true, callOptionId);

        collateral[userAddress][collateralId] = _collateralInfo;

        receiptToken.mint(userAddress, amount);
        return (true, uint256(assetPriceInUSD), collateralId);
    }

    function repayDebt(address userAddress, uint256 collateralId) external onlyBetterAddress {
        CollateralInfo storage _collateral = collateral[userAddress][collateralId];
        delete _collateral.amount;
        delete _collateral.callOptionId;
        delete _collateral.isLocked;
    }

    function setBetterBarterAddress(address _betterBarterAddress) external onlyAdmin {}

    function getCollateralInfo(address userAddress, uint256 collateralId) public view returns (CollateralInfo memory) {
        return collateral[userAddress][collateralId];
    }
}

/**
 * @user posts the derivatives for call option
 * buyer can send a premium of 10% and buy with strike price until expiration date.
 * If buyer not buyed in expiration date or it is under strike price the asset sent back to the user or wothdraw any time
 */
