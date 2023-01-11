// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceProtection {
    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod)
        external
        returns (bool, uint256);
}

interface ILPWallet {
    function transferLoan(uint256 ethPrice) external returns (uint256);
}
