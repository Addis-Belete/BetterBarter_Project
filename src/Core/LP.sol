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
    }

    mapping(address => uint256) public userStakingId;
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;

    IReceiptToken internal receiptToken;
    IERC20 internal underlying;

    /**
     * @notice Emitted when asset deposited to the pool
     */
    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);

    /**
     * @notice Emitted when asset withdrawn from the pool
     */
    event AssetWithdrawed(address indexed userAddress, uint256 amount, uint256 stakingId);

    modifier checkAddress(address _addr) {
        require(_addr != address(0), "InvalidAddress");
        _;
    }

    constructor(address _receiptTokenAddress, address _underlyingAddress) {
        receiptToken = IReceiptToken(_receiptTokenAddress);
        underlying = IERC20(_underlyingAddress);
    }

    /**
     * @notice Used to provide liquidity to the Better Barter
     * @param userAddress The address of the user
     * @param amount The amount to be deposited
     * @param stakingPeriod The period where the asset lock in. available lockin periods are 7days, 15days, 30days && 100days
     */
    function deposit(address userAddress, uint256 amount, uint256 stakingPeriod) external checkAddress(userAddress) {
        require(
            stakingPeriod == 7 days || stakingPeriod == 15 days || stakingPeriod == 30 days || stakingPeriod == 100 days,
            "Periods 7, 15, 30,100 days"
        );
        require(underlying.transferFrom(userAddress, address(this), amount), "Transfer failed");
        uint256 _stakingId = userStakingId[userAddress]++;
        uint256 _stakingEndTime = block.timestamp + stakingPeriod;
        UserInfo memory _userInfo = UserInfo(block.timestamp, stakingPeriod, amount, _stakingEndTime);
        userInfo[userAddress][_stakingId] = _userInfo;
        receiptToken.mint(userAddress, amount);
        emit Deposited(userAddress, amount, stakingPeriod);
    }

    /**
     * @notice Used to withdraw principal + interest from each positions after lockin period ends.
     * @param userAddress The address of the user
     * @param amount The number of asset to be withdrawn
     * @param _stakingId The Position at which user will withdraw funds.
     */
    function withdraw(address userAddress, uint256 amount, uint256 _stakingId) external checkAddress(userAddress) {
        UserInfo storage _userInfo = userInfo[userAddress][_stakingId];
        require(_stakingId > 0 && _userInfo.initialTime > 0, "Not staked");
        require(_userInfo.stakingEndTime <= block.timestamp, "Not matured");
        require(_userInfo.amount >= amount, "Not enough amount on this position");
        uint256 _interest = calculateInterest(amount, _userInfo.initialTime);
        require(underlying.balanceOf(address(this)) >= (amount + _interest), "No enough liquidity");
        _userInfo.amount -= amount;
        receiptToken.burn(userAddress, amount);
        require(underlying.transfer(userAddress, (amount + _interest)), "Transfer failed");
        emit AssetWithdrawed(userAddress, amount, _stakingId);
    }

    /**
     * @notice Used to calculate the interest
     * @param amount The number of the principal asset
     * @param _initialStakingTime The initial staking time
     */
    function calculateInterest(uint256 amount, uint256 _initialStakingTime) internal view returns (uint256) {
        uint256 totalTime = block.timestamp - _initialStakingTime;
        return ((amount * 7 * totalTime * 10 ** 18) / (100 * 100));
    }
}
