// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @notice LP get 7% Interest in 100days
 * user provide liquidity to Better Barter by using this contract.
 */
contract LP {
    /**
     * @notice Struct that holds liquidity provider info
     */
    struct UserInfo {
        uint256 initialTime;
        uint256 stakingPeriod;
        uint256 amount;
        uint256 interestAccumulated;
    }

    mapping(address => mapping(uint256 => UserInfo)) public userInfo; // address => stakeId -> UserInfo
    /**
     * @notice User will provide liquidity by using this deposit function
     */

    function deposit() external {}

    /**
     * @notice User will withdraw funds by using this function once the staking period ends.
     */
    function withdraw() external {}

    /**
     * @notice User Will claim the accumulated interest by using this function.
     */
    function claimInterest() external {}
}
