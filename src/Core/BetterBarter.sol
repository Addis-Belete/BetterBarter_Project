// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICruise.sol";
import "../interfaces/IPriceProtection.sol";

import "../Helpers/Exchange.sol";

contract BetterBarter is Exchange {
    //Responsible for the main logic of the Better Barter APP.

    struct CallOption {
        bool isSold; // show if the premium is payed for this call option;
        bool isFullyPayed; // Shows if user buys the strike price
        bool isReadyForSell;
        uint256 amount;
        address buyer;
        uint256 strikePrice;
        uint256 deadline;
    }

    mapping(address => mapping(uint256 => CallOption)) public callOptions; //address -> callOptionId -> CallOption
    mapping(address => uint256) internal userCallOptionId;
    ICruise internal cruise;
    address internal priceProtectionAddress;
    address internal wETH;
    address internal crETH;
    address internal underlying;
    address internal LPWalletAddress;

    event NewAssetDepositedForCallOption(
        address indexed owner, uint256 indexed amount, uint256 strikePrice, uint256 deadline
    );

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

        uint256 strikePrice;
        cruise.deposit(msg.value, wETH);

        uint256 crETHAmount = IERC20(crETH).balanceOf(address(this));
        require(IERC20(crETH).transfer(priceProtectionAddress, crETHAmount), "Transfer failed");
        (bool success, uint256 assetPrice) =
            IPriceProtection(priceProtectionAddress).lockCollateral(msg.sender, crETHAmount, stakingPeriod);

        require(success, "Price Protection failed");

        uint256 loanAmount = ILPWallet(LPWalletAddress).transferLoan(assetPrice);

        uint256 swappedEthAmount = swap(address(this), underlying, wETH, loanAmount, block.timestamp + 5 minutes);
        if (stakingPeriod == 7 days) {
            strikePrice = assetPrice + (assetPrice * 14) / 100;
        } else if (stakingPeriod == 15 days) {
            strikePrice = assetPrice + (assetPrice * 30) / 100;
        } else if (stakingPeriod == 30 days) {
            strikePrice = assetPrice + (assetPrice * 60) / 100;
        } else {
            strikePrice = assetPrice + (assetPrice * 200) / 100;
        }

        uint256 id = userCallOptionId[msg.sender];
        uint256 _deadline = block.timestamp + stakingPeriod;
        CallOption memory _callOption =
            CallOption(false, false, true, swappedEthAmount, address(0), strikePrice, _deadline);

        callOptions[msg.sender][id] = _callOption;

        emit NewAssetDepositedForCallOption(msg.sender, swappedEthAmount, strikePrice, _deadline);
    }

    function withdrawEth() external {}

    function BuyCallOption() external {}
}
