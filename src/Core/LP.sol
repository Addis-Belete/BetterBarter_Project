// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IReceiptToken.sol";
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
    mapping(address => uint256) public lastStakingId; //address => lastStaking Id
    IReceiptToken internal receiptToken;
    IERC20 internal underlying;

    constructor(address _receiptTokenAddress, address _underlyingAddress) {
        receiptToken = IReceiptToken(_receiptTokenAddress);
        underlying = IERC20(_underlyingAddress);
    }

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
