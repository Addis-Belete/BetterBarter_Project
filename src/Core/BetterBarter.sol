// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICruise.sol";
import "../interfaces/IPriceProtection.sol";

import "../Helpers/Exchange.sol";
import "../Helpers/Oracle.sol";

contract BetterBarter is Exchange, Oracle {
    //Responsible for the main logic of the Better Barter APP.

    struct CallOption {
        bool isSold; // show if the premium is payed for this call option;
        bool isFullyPayed; // Shows if user buys the strike price
        bool isReadyForSell;
        uint256 amount;
        address owner;
        address buyer;
        uint256 strikePrice;
        uint256 premiumPrice;
        uint256 deadline;
        uint256 collateralId;
        uint256 loanAmount;
    }

    mapping(uint256 => CallOption) public callOptions; //address -> callOptionId -> CallOption

    ICruise internal cruise;
    address internal priceProtectionAddress;
    address internal wETH;
    address internal crETH;
    address internal underlying;
    address internal LPWalletAddress;
    uint256 private callOptionId;
    address internal ethOracleAddress;
    address internal usdcOracleAddress;

    event NewAssetDepositedForCallOption(
        address indexed owner, uint256 indexed _callOptionId, uint256 amount, uint256 strikePrice, uint256 deadline
    );

    event CallOptionSold(uint256 indexed callOptionId, address buyer);

    event StrikePricePayed(uint256 indexed _callOptionId);

    constructor(
        address _cruiseAddress,
        address _priceProtectionAddress,
        address _weth,
        address _LPWalletAddress,
        address _routerAddress,
        address _qouterAddress
    ) Exchange(_routerAddress, _qouterAddress) {
        cruise = ICruise(_cruiseAddress);
        priceProtectionAddress = _priceProtectionAddress;
        wETH = _weth;
        LPWalletAddress = _LPWalletAddress;
    }

    function depositETH(uint256 stakingPeriod) external payable {
        require(msg.value > 0, "Value not 0");
        require(
            stakingPeriod == 7 days || stakingPeriod == 15 days || stakingPeriod == 30 days || stakingPeriod == 100 days,
            "Periods 7, 15, 30,100 days"
        );
        callOptionId++;

        cruise.deposit(msg.value, wETH);

        uint256 crETHAmount = IERC20(crETH).balanceOf(address(this));
        require(IERC20(crETH).transfer(priceProtectionAddress, crETHAmount), "Transfer failed");
        (bool success, uint256 assetPrice, uint256 _collateralId) = IPriceProtection(priceProtectionAddress)
            .lockCollateral(msg.sender, crETHAmount, stakingPeriod, callOptionId);

        require(success, "Price Protection failed");

        uint256 loanAmount = ILPWallet(LPWalletAddress).transferLoan(assetPrice);

        uint256 swappedEthAmount = swap(address(this), underlying, wETH, loanAmount, block.timestamp + 5 minutes);

        int256 priceOfSwappedEth = getPriceInUSD(ethOracleAddress);

        uint256 strikePrice = calculateStrikePrice(priceOfSwappedEth, stakingPeriod);
        //Must changed to 75% of asset

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

    //Tobe fixed but for now assume StrikePrice == token amount;
    function withdrawEth(address userAddress, uint256 _callOptionId) external {
        CallOption memory _callOption = callOptions[_callOptionId];
        require(block.timestamp > _callOption.deadline, "Not ready to withdraw");
        IPriceProtection.CollateralInfo memory _collateral =
            IPriceProtection(priceProtectionAddress).getCollateralInfo(userAddress, _callOption.collateralId);
        uint256 interest = calculateInterest(_collateral.initailTime, _callOption.loanAmount);

        if (_callOption.isSold && _callOption.isFullyPayed) {
            uint256 totalUnderlyingCollacted = _callOption.premiumPrice + _callOption.strikePrice;
            require(_callOption.loanAmount < totalUnderlyingCollacted, "Error");

            require(
                IERC20(underlying).transferFrom(address(this), LPWalletAddress, _callOption.loanAmount + interest),
                "Transfer failed"
            );

            uint256 releasedAmount =
                IPriceProtection(priceProtectionAddress).unLockCollateral(userAddress, _callOption.collateralId);
            uint256 balanceBeforeWithdraw = address(this).balance;
            cruise.withdraw(releasedAmount, wETH);
            uint256 amountWithdrawed = address(this).balance - balanceBeforeWithdraw;
            uint256 profit = totalUnderlyingCollacted - _callOption.loanAmount + interest;
            uint256 profitInEth = swap(address(this), underlying, wETH, profit, block.timestamp + 5 minutes);

            (bool success,) = (msg.sender.call{value: profitInEth + amountWithdrawed}(""));

            require(success, "Transfer failed");
        } else if (_callOption.isSold && !_callOption.isFullyPayed) {
            // convert Eth to USDC;
            // payLoan
            // swap the remaining to ETH
        } else if (!_callOption.isSold && !_callOption.isFullyPayed) {
            // Convert ETH to USDT
            // Withdraw ETH From Cruise and convert it USDT
            // payLoan
            // Transfer the remaining to user
        }
    }

    function buyCallOption(uint256 _callOptionId) external {
        CallOption storage _callOption = callOptions[_callOptionId];
        require(block.timestamp < _callOption.deadline, "Expired");
        require(_callOption.isReadyForSell, "Not ready for sell");
        require(!_callOption.isSold, "Already sold");

        int256 _underlyingPrice = getPriceInUSD(usdcOracleAddress);
        uint256 premiumPrice = _callOption.premiumPrice;

        uint256 premiumInToken = premiumPrice / uint256(_underlyingPrice);

        require(IERC20(underlying).transfer(address(this), premiumInToken), "Transfer failed");

        _callOption.buyer = msg.sender;
        _callOption.isSold = true;

        emit CallOptionSold(_callOptionId, msg.sender);
    }

    function payStrikePrice(uint256 _callOptionId) external {
        CallOption storage _callOption = callOptions[_callOptionId];
        require(block.timestamp < _callOption.deadline, "Expired");
        require(_callOption.buyer == msg.sender, "Not buyer");
        require(!_callOption.isFullyPayed, "Arleady paid");

        int256 _underlyingPrice = getPriceInUSD(usdcOracleAddress);
        uint256 strikePrice = _callOption.amount;

        uint256 strikeInToken = strikePrice / uint256(_underlyingPrice);

        require(IERC20(underlying).transfer(address(this), strikeInToken), "Transfer failed");

        _callOption.isFullyPayed = true;

        (bool success,) = (msg.sender).call{value: _callOption.amount}("");
        require(success, "Transfer failed");

        emit StrikePricePayed(_callOptionId);
    }

    function calculateStrikePrice(int256 _price, uint256 stakingPeriod) internal pure returns (uint256 strikePrice) {
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

    function calculateInterest(uint256 initialStakingTime, uint256 loanAmount) internal view returns (uint256) {
        //100days 7%
        uint256 loanPeriod = block.timestamp - initialStakingTime;
        uint256 interest = (loanAmount * 7 * loanPeriod) / (100 days * 100);
        return interest;
    }
}
