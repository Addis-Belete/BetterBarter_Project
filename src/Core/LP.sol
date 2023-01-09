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
        uint256 stakingEndTime;
        bool isInterestAccumulated;
    }

    mapping(address => UserInfo[]) public userInfo; // address => stakeId -> UserInfo
    mapping(address => bool) public isProvider;
    mapping(address => uint256) internal accumulatedInterest;
    IReceiptToken internal receiptToken;
    IERC20 internal underlying;

    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);

    modifier checkAddress(address _addr) {
        require(_addr != address(0), "InvalidAddress");
        _;
    }

    constructor(address _receiptTokenAddress, address _underlyingAddress) {
        receiptToken = IReceiptToken(_receiptTokenAddress);
        underlying = IERC20(_underlyingAddress);
    }

    /**
     * @notice User will provide liquidity by using this deposit function
     */
    function deposit(address userAddress, uint256 amount, uint256 stakingPeriod) external checkAddress(userAddress) {
        require(
            stakingPeriod == 7 days || stakingPeriod == 15 days || stakingPeriod == 30 days || stakingPeriod == 100 days,
            "Periods 7, 15, 30,100 days"
        );
        require(underlying.transferFrom(userAddress, address(this), amount), "Transfer failed");
        if (!isProvider[userAddress]) {
            isProvider[userAddress] = true;
        }

        UserInfo memory _userInfo =
            UserInfo(block.timestamp, stakingPeriod, amount, block.timestamp + stakingPeriod, false);
        userInfo[userAddress].push(_userInfo);
        receiptToken.mint(userAddress, amount);

        emit Deposited(userAddress, amount, stakingPeriod);
    }

    /**
     * @notice User will withdraw funds by using this function once the staking period ends.
     */
    function withdraw(address userAddress, uint256 amount) external checkAddress(userAddress) {
        uint256 withdrawableBalance = getWithdrawableBalance(userAddress);
        require(withdrawableBalance >= amount, "Insufficeint amount");
    }

    /**
     * @notice User Will claim the accumulated interest by using this function.
     */
    function claimInterest() external {}

    function getWithdrawableBalance(address userAddress) internal view returns (uint256) {
        UserInfo[] memory _userInfo = userInfo[userAddress];
        uint256 withdrawableBalance;
        for (uint256 i; i < _userInfo.length; i++) {
            uint256 stakingEndTime = _userInfo[i].stakingEndTime;
            if (block.timestamp > stakingEndTime) {
                withdrawableBalance += _userInfo[i].amount;
            }
        }
        return withdrawableBalance;
    }

    function calculateInterest(uint256 amount) internal view returns (uint256) {
        return ((amount * 7 * block.timestamp * 10 ** 18) / (100 * 100));
    }
}
