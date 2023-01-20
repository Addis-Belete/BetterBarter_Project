// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../Interfaces/IReceiptToken.sol";
import "forge-std/console2.sol";
import "../Helpers/Oracle.sol";
/**
 * @notice LP get 7% Interest in 100days
 * user provide liquidity to Better Barter by using this contract.
 * The Asset stored in LP wallet (fixed later)
 * @dev for test case days changed to minutes
 */

contract LP is ReentrancyGuard, Oracle {
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
    address internal betterAddress;
    address internal admin;

    /**
     * @notice Emitted when asset deposited to the pool
     */

    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);

    /**
     * @notice Emitted when asset withdrawn from the pool
     */
    event AssetWithdrawed(address indexed userAddress, uint256 amount, uint256 stakingId);

    /**
     * @notice Emitted when loan successfully transferred to Barter Better contract
     */
    event LoanTransferred(uint256 amount);

    modifier checkAddress(address _addr) {
        require(_addr != address(0), "InvalidAddress");
        _;
    }

    modifier onlyBetterAddress() {
        require(msg.sender == betterAddress, "Only called By Better");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only called by admin");
        _;
    }

    constructor(address _receiptTokenAddress, address _underlyingAddress, address _betterAddress) {
        receiptToken = IReceiptToken(_receiptTokenAddress);
        underlying = IERC20(_underlyingAddress);
        betterAddress = _betterAddress;
        admin = msg.sender;
    }

    /**
     * @notice Used to provide liquidity to the Better Barter
     * @param userAddress The address of the user
     * @param _amount The amount to be deposited
     * @param _stakingPeriod The period where the asset lock in. available lockin periods are 7days, 15days, 30days && 100days
     */
    function deposit(address userAddress, uint256 _amount, uint256 _stakingPeriod) external checkAddress(userAddress) {
        require(
            _stakingPeriod == 7 minutes || _stakingPeriod == 15 minutes || _stakingPeriod == 30 minutes
                || _stakingPeriod == 100 minutes,
            "Periods 7, 15, 30,100 days"
        );
        require(underlying.transferFrom(userAddress, address(this), _amount), "Transfer failed");
        uint256 _stakingId = userStakingId[userAddress] += 1;
        uint256 _stakingEndTime = block.timestamp + _stakingPeriod;

        userInfo[userAddress][_stakingId] = UserInfo({
            initialTime: block.timestamp,
            stakingPeriod: _stakingPeriod,
            amount: _amount,
            stakingEndTime: _stakingEndTime
        });

        receiptToken.mint(userAddress, _amount);
        emit Deposited(userAddress, _amount, _stakingPeriod);
    }

    /**
     * @notice Used to withdraw principal + interest from each positions after lockin period ends.
     * @param userAddress The address of the user
     * @param amount The number of asset to be withdrawn
     * @param _stakingId The Position at which user will withdraw funds.
     */
    function withdraw(address userAddress, uint256 amount, uint256 _stakingId)
        external
        checkAddress(userAddress)
        nonReentrant
    {
        UserInfo storage _userInfo = userInfo[userAddress][_stakingId];
        require(_stakingId > 0 && _userInfo.initialTime > 0, "Not staked");
        require(_userInfo.stakingEndTime <= block.timestamp, "Not matured");
        require(_userInfo.amount >= amount, "Not enough amount on this position");
        uint256 _interest = calculateInterest(amount, _userInfo.initialTime);
        console2.log(_interest, "Calculated interest");
        require(underlying.balanceOf(address(this)) >= (amount + _interest), "No enough liquidity");
        _userInfo.amount -= amount;
        receiptToken.burn(userAddress, amount);

        require(underlying.transfer(userAddress, (amount + _interest)), "Transfer failed");
        emit AssetWithdrawed(userAddress, (amount + _interest), _stakingId);
    }

    /**
     * @notice Used to transfer underlying to the better barter contract on behalf of user
     */
    function transferLoan(uint256 ethPrice) external onlyBetterAddress returns (uint256) {
        uint256 loanAmount = (ethPrice * 75) / 100;
        int256 underlyingPrice = getPriceInUSD(address(underlying));
        uint256 loanInToken = (loanAmount * 10 ** 14) / uint256(underlyingPrice); // 10**14 -> 10**6 USDC Decimal 10**8 -> price decimal from chainlink
        console2.log(loanInToken, "Loan In token");
        require(underlying.transfer(betterAddress, uint256(loanInToken)), "Transfer failed");
        emit LoanTransferred(uint256(loanAmount));
        return uint256(loanInToken);
    }

    /**
     * @notice Used to change BarterBetter contract address
     * @param _addr The address of BarterBetter contract to be changed
     */
    function setBetterAddress(address _addr) external checkAddress(_addr) onlyAdmin {
        betterAddress = _addr;
    }
    /**
     * @notice Used to get the userInfo
     * @param _userAddress The Address of the user
     * @param _stakingId The Id where the asset deposited
     */

    function getUserInfo(address _userAddress, uint256 _stakingId) external view returns (UserInfo memory) {
        return userInfo[_userAddress][_stakingId];
    }
    /**
     * @notice Used to calculate the interest
     * @param amount The number of the principal asset
     * @param _initialStakingTime The initial staking time
     */

    function calculateInterest(uint256 amount, uint256 _initialStakingTime) internal view returns (uint256) {
        uint256 totalTime = block.timestamp - _initialStakingTime;
        return ((amount * 7 * totalTime) / (100 minutes * 100));
    }
}
