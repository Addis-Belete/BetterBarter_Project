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
        address indexed owner, uint256 indexed amount, uint256 strikePrice, uint256 deadline
    );

    event CallOptionSold(uint256 indexed callOptionId, address buyer);

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
            _collateralId
        );

        callOptions[callOptionId] = _callOption;

        emit NewAssetDepositedForCallOption(msg.sender, swappedEthAmount, strikePrice, _deadline);
    }

    function withdrawEth() external {}

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
        // Tobe Continued
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
}
