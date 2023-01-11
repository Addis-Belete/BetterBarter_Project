// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Helpers/Oracle.sol";
// responsible to handle underlying asset that is privided by LP

contract LPWallet is Oracle {
    address internal betterAddress;
    address internal priceProtectionAddress;
    IERC20 internal underlying;

    modifier onlyPriceProtection(address _addr) {
        require(msg.sender == priceProtectionAddress, "Only called by price protection");
        _;
    }

    modifier onlyBetterAddress(address _addr) {
        require(msg.sender == betterAddress, "Only called By Better");
        _;
    }

    constructor(address _betterAddress, address _priceProtection, address _underlying) {
        betterAddress = _betterAddress;
        priceProtectionAddress = _priceProtection;
        underlying = IERC20(_underlying);
    }

    /**
     * @notice Used to transfer underlying to the better barter contract on behalf of user
     */
    function transferLoan(uint256 ethPrice) external onlyBetterAddress(msg.sender) returns (uint256) {
        int256 underlyingPrice = getPriceInUSD(address(underlying));
        uint256 loanAmount = (ethPrice * 75) / 100;
        int256 assetAmount = int256(loanAmount) / (underlyingPrice);
        //check if the collateral is locked in the price protection
        require(underlying.transferFrom((address(this)), betterAddress, uint256(assetAmount)), "Transfer failed");

        return uint256(assetAmount);
    }
}
