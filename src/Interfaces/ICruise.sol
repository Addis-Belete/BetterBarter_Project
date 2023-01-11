// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICruise {
    function deposit(uint256 amount, address reserve) external payable;
    function withdraw(uint256 amount, address token) external;
}
