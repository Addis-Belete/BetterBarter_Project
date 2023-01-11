// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// responsible to handle underlying asset that is privided by LP

contract LPWallet {
    address internal betterAddress;
    address internal priceProtectionAddress;
    IERC20 internal underlying;

    modifier onlyPriceProtection(address _addr) {
        require(msg.sender == priceProtectionAddress, "Only called by price protection");
        _;
    }

    constructor(address _betterAddress, address _priceProtection, address _underlying) {
        betterAddress = _betterAddress;
        priceProtectionAddress = _priceProtection;
        underlying = IERC20(_underlying);
    }

    function transferLoan(address onBehalf, uint256 amount) external onlyPriceProtection(msg.sender) {
        //check if the collateral is locked in the price protection
        underlying.transferFrom((address(this)), betterAddress, amount);
    }
}
