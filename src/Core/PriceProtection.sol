// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Helpers/Oracle.sol";
import "../Interfaces/IReceiptToken.sol";
// This contract is responsible for price protection.
// TOKen/USD decimal is 8
import "forge-std/console2.sol";

contract PriceProtection is Oracle {
    struct CollateralInfo {
        int256 priceInUSD;
        uint256 stakingPeriod;
        uint256 collateralPrice; // The amount of collateral in USD
        uint256 collateralAmount;
        uint256 initailTime;
        bool isLocked;
        uint256 callOptionId; // The Id of the callOption created by using this collateral
    }

    mapping(address => mapping(uint256 => CollateralInfo)) internal collateral; // address => collateralId => CollateralInfo
    mapping(address => uint256) internal userCollateralIds;
    address internal betterAddress;
    address internal underlying;
    address internal wETH;
    IReceiptToken internal receiptToken;
    address internal admin;
    address internal crETH;

    /**
     * @notice Emitted when collateral locked in the contract
     */
    event CollateralLocked(address userAddress, uint256 amount);

    /**
     * @notice Emitted when collateral unlocked in the contract
     */
    event CollateralUnLocked(address owner, uint256 amount);

    /**
     * @notice Emitted after Better Barter contract address changed successfully
     */

    event BetterAddressChanged(address _betterAddress);

    modifier onlyBetterAddress() {
        require(msg.sender == betterAddress, "Only called by Better address");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only called by admin");
        _;
    }

    modifier checkAddress(address _addr) {
        require(_addr != address(0), "InvalidAddress");
        _;
    }

    constructor(address _betterAddress, address _receiptTokenaddress)
        checkAddress(_betterAddress)
        checkAddress(_receiptTokenaddress)
    {
        betterAddress = _betterAddress;
        receiptToken = IReceiptToken(_receiptTokenaddress);
        admin = msg.sender;
    }

    /**
     * @notice Used to lock a collateral in the contract
     * @param userAddress The address of the user who owns the collateral
     * @param amount The number of the collateral
     * @param stakingPeriod The number of staking period
     * @param callOptionId The Id of the callOption
     */
    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod, uint256 callOptionId)
        external
        onlyBetterAddress
        returns (bool, uint256, uint256)
    {
        uint256 collateralId = userCollateralIds[userAddress] += 1;

        int256 assetPriceInUSD = ((getPriceInUSD(wETH)) * int256(amount)) / (10 ** 8 * 10 ** 18);
        console2.log(uint256(assetPriceInUSD), "AssetPrice");
        uint256 _collateralPrice = (uint256(assetPriceInUSD) * 85) / 100; // Wee got 85% of asset from cruise finance
        CollateralInfo memory _collateralInfo = CollateralInfo(
            assetPriceInUSD, stakingPeriod, _collateralPrice, amount, block.timestamp, true, callOptionId
        );

        collateral[userAddress][collateralId] = _collateralInfo;

        receiptToken.mint(userAddress, amount);
        emit CollateralLocked(userAddress, amount);
        return (true, _collateralPrice, collateralId);
    }

    /**
     * @notice Used to unlock the collateral from the contract
     * @param userAddress The address of the user
     * @param collateralId The Id of the collateral
     */
    function unLockCollateral(address userAddress, uint256 collateralId) external onlyBetterAddress returns (uint256) {
        CollateralInfo storage _collateral = collateral[userAddress][collateralId];
        require(_collateral.isLocked, "Collateral not available");
        require(receiptToken.balanceOf(userAddress) >= _collateral.collateralAmount, "Not enough fund");
        receiptToken.burn(userAddress, _collateral.collateralAmount);
        _collateral.isLocked = false;

        require(IERC20(crETH).transfer(betterAddress, _collateral.collateralAmount), "Transfer failed");
        emit CollateralUnLocked(userAddress, _collateral.collateralAmount);
        return _collateral.collateralAmount;
    }

    /**
     * @notice Used to set or change the Better Barter contract address
     * @param _betterBarterAddress The address of Better Barter contract to be changed
     * @dev Only called by admin
     */
    function setBetterBarterAddress(address _betterBarterAddress)
        external
        checkAddress(_betterBarterAddress)
        onlyAdmin
    {
        betterAddress = _betterBarterAddress;
        emit BetterAddressChanged(_betterBarterAddress);
    }

    /**
     * @notice Used to get the Collater info of a given user address and collateral id
     * @param userAddress The address of the user
     * @param collateralId The Id of the collateral
     * @return The call returns the collateral info
     */
    function getCollateralInfo(address userAddress, uint256 collateralId) public view returns (CollateralInfo memory) {
        return collateral[userAddress][collateralId];
    }
}

/**
 * @user posts the derivatives for call option
 * buyer can send a premium of 10% and buy with strike price until expiration date.
 * If buyer not buyed in expiration date or it is under strike price the asset sent back to the user or wothdraw any time
 */
