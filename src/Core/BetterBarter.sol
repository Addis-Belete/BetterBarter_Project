// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ICruise.sol";
import "../interfaces/IPriceProtection.sol";

import "../Helpers/Exchange.sol";
import "../Helpers/Oracle.sol";
import "forge-std/console2.sol";
/**
 *
 * Neccessary Addresses on Georli
 *
 * crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f --> georli
 * USDCOnGeorli = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F
 * WETH on Georli = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
 * Cruise Contract = 0xe3aa7826348ee5559bcf70fe626a3ca6962ffbdc
 * usdcOracleAddress = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7
 * ethOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
 */

contract BetterBarter is Exchange, Oracle, ReentrancyGuard {
    struct CallOption {
        bool isSold; // show if the premium is payed for this call option;
        bool isFullyPayed; // Shows if user buys the strike price
        bool isReadyForSell; // bool that shows if the call option is ready for sale
        uint256 amount; // The amount of ETH this call option contains
        address owner; // The owner of the call option
        address buyer; // The buyer of the call option
        uint256 strikePrice; // The price at which th callOption sold
        uint256 premiumPrice; // The 10% premium price
        uint256 deadline; // The time at which the call option expires
        uint256 collateralId; // The collateral id of the collateral used for this contrct
        uint256 loanAmount; // The amount of loan got from the better barter
    }

    mapping(uint256 => CallOption) public callOptions; //address -> callOptionId -> CallOption

    ICruise internal cruise;
    address internal priceProtectionAddress;
    address internal crETH;
    address internal LPAddress;
    uint256 private callOptionId;
    address internal ethOracleAddress;
    address internal usdcOracleAddress;
    address internal owner;
    address internal wethAddressforUniswap;

    event NewAssetDepositedForCallOption(
        address indexed owner, uint256 indexed _callOptionId, uint256 amount, uint256 strikePrice, uint256 deadline
    );

    event CallOptionSold(uint256 indexed callOptionId, address buyer);

    event StrikePricePayed(uint256 indexed _callOptionId);

    event PriceProtectionAddressSetted(address _addr);

    event LPAddressSetted(address _addr);

    modifier onlyOwner() {
        require(msg.sender == owner, "only called by owner");
        _;
    }

    constructor(
        address _cruiseAddress,
        address _weth,
        address _routerAddress,
        address _crEth,
        address _ethOracleaddress,
        address _usdcOracleAddress,
        address _underlying,
        address _wethAddressForUniswap
    ) Exchange(_routerAddress) {
        require(
            _cruiseAddress != address(0) || _weth != address(0) || _routerAddress != address(0) || _crEth != address(0)
                || _usdcOracleAddress != address(0) || _ethOracleaddress != address(0),
            "Invalid address"
        );
        cruise = ICruise(_cruiseAddress);
        wETH = _weth;
        owner = msg.sender;
        crETH = _crEth;
        usdcOracleAddress = _usdcOracleAddress;
        ethOracleAddress = _ethOracleaddress;
        underlying = _underlying;
        wethAddressforUniswap = _wethAddressForUniswap;
    }

    receive() external payable {}
    /**
     * @notice Used to deposit ETH to the contract
     * @param stakingPeriod The period at which the ETH staked in the contract
     * @dev used to different weth addresses for cruise and uniswap for test purpose
     */

    function depositETH(uint256 stakingPeriod, uint256 amount) external payable {
        // require(msg.value > 0, "Value not 0");
        require(
            stakingPeriod == 7 minutes || stakingPeriod == 15 minutes || stakingPeriod == 30 minutes
                || stakingPeriod == 100 minutes,
            "Periods 7, 15, 30,100 days"
        );
        callOptionId++;

        IERC20(wETH).approve(address(cruise), amount);
        cruise.deposit(amount, wETH);
        uint256 crETHAmount = IERC20(crETH).balanceOf(address(this));
        require(IERC20(crETH).transfer(priceProtectionAddress, crETHAmount), "Transfer failed");
        (bool success, uint256 collateralPrice, uint256 _collateralId) = IPriceProtection(priceProtectionAddress)
            .lockCollateral(msg.sender, crETHAmount, stakingPeriod, callOptionId);
        require(success, "Price Protection failed");
        uint256 loanAmount = ILP(LPAddress).transferLoan(collateralPrice);
        uint256 swappedEthAmount = swapETH(1, address(this), underlying, wethAddressforUniswap, loanAmount);
        int256 priceOfEth = getPriceInUSD(ethOracleAddress);
        uint256 priceOfSwappedEth = (uint256(priceOfEth) * (swappedEthAmount)) / (10 ** 8 * 10 ** 18);
        uint256 strikePrice = calculateStrikePrice(priceOfSwappedEth, stakingPeriod);
        uint256 _premiumPrice = (uint256(priceOfSwappedEth) * 10) / 100;
        uint256 _deadline = block.timestamp + stakingPeriod;
        CallOption memory _callOption = CallOption(
            false,
            false,
            true,
            swappedEthAmount,
            msg.sender,
            address(0),
            strikePrice,
            _premiumPrice,
            _deadline,
            _collateralId,
            loanAmount
        );

        callOptions[callOptionId] = _callOption;

        emit NewAssetDepositedForCallOption(msg.sender, callOptionId, swappedEthAmount, strikePrice, _deadline);
    }

    /**
     * @notice Used to withdraw staked ETH
     * @param _callOptionId The Id of the call option
     */
    function withdrawEth(uint256 _callOptionId) external nonReentrant {
        CallOption memory _callOption = callOptions[_callOptionId];
        require(block.timestamp > _callOption.deadline, "Not ready to withdraw");
        require(_callOption.owner == msg.sender, "Not owner");
        IPriceProtection.CollateralInfo memory _collateral =
            IPriceProtection(priceProtectionAddress).getCollateralInfo(msg.sender, _callOption.collateralId);
        uint256 interest = calculateInterest(_collateral.initailTime, _callOption.loanAmount);
        /**
         *
         * 			When CallOption sold and strike Price fully paid
         *
         *
         */
        if (_callOption.isSold && _callOption.isFullyPayed) {
            uint256 totalUnderlyingCollacted = _callOption.premiumPrice + _callOption.strikePrice;
            require(_callOption.loanAmount < totalUnderlyingCollacted, "Error");

            require(IERC20(underlying).transfer(LPAddress, _callOption.loanAmount + interest), "Transfer failed");

            uint256 releasedAmount =
                IPriceProtection(priceProtectionAddress).unLockCollateral(msg.sender, _callOption.collateralId);
            uint256 balanceBeforeWithdraw = address(this).balance;
            IERC20(crETH).approve(address(cruise), releasedAmount);
            cruise.withdraw(releasedAmount, wETH);
            uint256 amountWithdrawed = address(this).balance - balanceBeforeWithdraw;
            uint256 profit = totalUnderlyingCollacted - _callOption.loanAmount + interest;
            uint256 profitInEth = swapETH(1, address(this), underlying, wETH, profit);

            (bool success,) = (msg.sender.call{value: profitInEth + amountWithdrawed}(""));

            require(success, "Transfer failed");
            /**
             *
             * 	When CallOption sold but, strike Price not paid
             *
             *
             */
        } else if (_callOption.isSold && !_callOption.isFullyPayed) {
            uint256 _loanAmount = _callOption.loanAmount;
            uint256 debt = _loanAmount + interest - _callOption.premiumPrice;
            uint256[] memory amountsInMax = getAmountInMaximum(wETH, underlying, debt);
            uint256 profit;
            uint256 unPaidDebt;
            if (_callOption.amount >= amountsInMax[0]) {
                swapETH(0, address(this), wETH, underlying, debt);
                profit = _callOption.amount - amountsInMax[0];
            } else {
                uint256[] memory amountOuts = getAmountOutMinimum(wETH, underlying, _callOption.amount);
                uint256 amountOut = swapETH(0, address(this), wETH, underlying, amountOuts[1]);
                unPaidDebt = debt - amountOut;
            }

            if (unPaidDebt > 0) {
                uint256 releasedAmount =
                    IPriceProtection(priceProtectionAddress).unLockCollateral(msg.sender, _callOption.collateralId);
                uint256 balanceBeforeWithdraw = address(this).balance;
                cruise.withdraw(releasedAmount, wETH);
                uint256 amountWithdrawed = address(this).balance - balanceBeforeWithdraw;
                uint256 amountIn = swapETH(0, address(this), wETH, underlying, unPaidDebt);
                require(IERC20(underlying).transfer(LPAddress, _callOption.premiumPrice + debt), "Transfer failed");
                uint256 amountToTransfer = amountWithdrawed - amountIn;
                (bool success,) = msg.sender.call{value: amountToTransfer}("");
                require(success, "Transfer failed");
            } else {
                require(IERC20(underlying).transfer(LPAddress, _callOption.premiumPrice + debt), "Transfer failed");
                uint256 releasedAmount =
                    IPriceProtection(priceProtectionAddress).unLockCollateral(msg.sender, _callOption.collateralId);
                uint256 balanceBeforeWithdraw = address(this).balance;
                cruise.withdraw(releasedAmount, wETH);
                uint256 amountWithdrawed = address(this).balance - balanceBeforeWithdraw;
                uint256 amountToTransfer = amountWithdrawed + _callOption.amount - amountsInMax[0];
                (bool success,) = msg.sender.call{value: amountToTransfer}("");
                require(success, "Transfer failed");
            }

            /**
             *
             * 			When CallOption Not sold
             *
             *
             */
        } else if (!_callOption.isSold && !_callOption.isFullyPayed) {
            uint256 _loanAmount = _callOption.loanAmount;
            uint256 totalDebt = _loanAmount + interest;
            uint256 amountOut = swapETH(0, address(this), wETH, underlying, _callOption.amount);
            uint256 releasedAmount =
                IPriceProtection(priceProtectionAddress).unLockCollateral(msg.sender, _callOption.collateralId);
            uint256 balanceBeforeWithdraw = address(this).balance;
            cruise.withdraw(releasedAmount, wETH);
            uint256 amountWithdrawed = address(this).balance - balanceBeforeWithdraw;

            if (totalDebt > amountOut) {
                uint256 amountLeft = totalDebt - amountOut;
                uint256 amountIn = swapETH(0, address(this), wETH, underlying, amountLeft);
                amountWithdrawed -= amountIn;
            }
            require(IERC20(underlying).transferFrom(address(this), LPAddress, totalDebt), "Transfer failed");

            (bool success,) = address(this).call{value: amountWithdrawed}("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @notice Used to buy a call option
     * @param _callOptionId The Id of the call optoin to be bought
     */
    function buyCallOption(uint256 _callOptionId) external {
        CallOption storage _callOption = callOptions[_callOptionId];
        require(block.timestamp < _callOption.deadline, "Expired");
        require(_callOption.isReadyForSell, "Not ready for sell");
        require(!_callOption.isSold, "Already sold");

        uint256 premiumPrice = _callOption.premiumPrice;
        uint256 premiumInToken = convertPriceToToken(premiumPrice, usdcOracleAddress);
        require(IERC20(underlying).transferFrom(msg.sender, address(this), premiumInToken), "Transfer failed");

        _callOption.buyer = msg.sender;
        _callOption.isSold = true;

        emit CallOptionSold(_callOptionId, msg.sender);
    }

    /**
     * @notice Used to pay a strike price for already bought call option
     * @param _callOptionId The Id of the call option
     */
    function payStrikePrice(uint256 _callOptionId) external {
        CallOption storage _callOption = callOptions[_callOptionId];
        require(block.timestamp < _callOption.deadline, "Expired");
        require(_callOption.buyer == msg.sender, "Not buyer");
        require(!_callOption.isFullyPayed, "Arleady paid");

        uint256 strikePrice = _callOption.strikePrice;

        uint256 strikeInToken = convertPriceToToken(strikePrice, usdcOracleAddress);

        require(IERC20(underlying).transferFrom(msg.sender, address(this), strikeInToken), "Transfer failed");

        _callOption.isFullyPayed = true;

        (bool success,) = (msg.sender).call{value: _callOption.amount}("");
        require(success, "Transfer failed");

        emit StrikePricePayed(_callOptionId);
    }

    /**
     * @notice Used to set the address of price protection
     * @param _addr The address of price protection contract
     * @dev only called by the owner
     */
    function setPriceProtectionAddress(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid address");
        priceProtectionAddress = _addr;
        emit PriceProtectionAddressSetted(_addr);
    }

    /**
     * @notice Used to set the address of LP contract
     * @param _addr The address of LP contract
     * @dev only called by the owner
     */
    function setLPAddress(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid address");
        LPAddress = _addr;
        emit LPAddressSetted(_addr);
    }

    function getCallOption(uint256 _callOptionId) external view returns (CallOption memory) {
        return callOptions[_callOptionId];
    }

    function convertPriceToToken(uint256 price, address tokenOracleAddress) public view returns (uint256) {
        int256 _underlyingPrice = getPriceInUSD(tokenOracleAddress);
        uint256 tokenAmount = price * 10 ** 8 / uint256(_underlyingPrice);
        return tokenAmount;
    }
    /**
     * @notice Used to calculate the strike price
     * @param _price initial asset price
     * @param stakingPeriod The period at which the asset is staked
     */

    function calculateStrikePrice(uint256 _price, uint256 stakingPeriod) internal pure returns (uint256 strikePrice) {
        if (stakingPeriod == 7 days) {
            strikePrice = uint256(_price) + (uint256(_price) * 14) / 100;
        } else if (stakingPeriod == 15 days) {
            strikePrice = uint256(_price) + (uint256(_price) * 30) / 100;
        } else if (stakingPeriod == 30 days) {
            strikePrice = uint256(_price) + (uint256(_price) * 60) / 100;
        } else {
            strikePrice = uint256(_price) + (uint256(_price) * 200) / 100;
        }
    }
    /**
     * @notice Used to calculate The interest.
     * @param initialStakingTime The intial staking time
     * @param loanAmount The number of loan
     */

    function calculateInterest(uint256 initialStakingTime, uint256 loanAmount) internal view returns (uint256) {
        uint256 loanPeriod = block.timestamp - initialStakingTime;
        uint256 interest = (loanAmount * 7 * loanPeriod) / (100 days * 100);
        return interest;
    }
}
