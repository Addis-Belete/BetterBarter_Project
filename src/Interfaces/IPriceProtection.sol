// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceProtection {
    function lockCollateral(address userAddress, uint256 amount, uint256 stakingPeriod) external returns (int256);
}
