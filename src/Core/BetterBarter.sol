// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ICruise.sol";
import "../interfaces/IPriceProtection.sol";

import "../Helpers/Exchange.sol";
import "../Helpers/Oracle.sol";

/**
 *
 * Neccessary Addresses on Georli
 * WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
 * USDC = 0xde637d4c445ca2aae8f782ffac8d2971b93a4998;
 *
 * Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
 * Qouter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
 * crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f --> georli
 * USDCOnGeorli = 0x9FD21bE27A2B059a288229361E2fA632D8D2d074
 * WETH on Georli = 0xCCa7d1416518D095E729904aAeA087dBA749A4dC
 * Cruise Contract = 0xe3aa7826348ee5559bcf70fe626a3ca6962ffbdc
 *
 *
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

    event NewAssetDepositedForCallOption(
        address indexed owner, uint256 indexed _callOptionId, uint256 amount, uint256 strikePrice, uint256 deadline
    );

    event CallOptionSold(uint256 indexed callOptionId, address buyer);

    event StrikePricePayed(uint256 indexed _callOptionId);

    constructor(
        address _cruiseAddress,
        address _priceProtectionAddress,
        address _weth,
        address _LPAddress,
        address _routerAddress,
        address _qouterAddress
    ) Exchange(_routerAddress, _qouterAddress) {
        cruise = ICruise(_cruiseAddress);
        priceProtectionAddress = _priceProtectionAddress;
        wETH = _weth;
        LPAddress = _LPAddress;
    }

    /**
     * @notice Used to deposit ETH to the contract
     * @param stakingPeriod The period at which the ETH staked in the contract
     */
    function depositETH(uint256 stakingPeriod) external payable {
        require(msg.value > 0, "Value not 0");
        require(
            stakingPeriod == 7 days || stakingPeriod == 15 days || stakingPeriod == 30 days || stakingPeriod == 100 days,
            "Periods 7, 15, 30,100 days"
        );
        callOptionId++;

        cruise.deposit{value: msg.value}(msg.value, wETH);

        uint256 crETHAmount = IERC20(crETH).balanceOf(address(this));
        require(IERC20(crETH).transfer(priceProtectionAddress, crETHAmount), "Transfer failed");
        (bool success, uint256 collateralPrice, uint256 _collateralId) = IPriceProtection(priceProtectionAddress)
            .lockCollateral(msg.sender, crETHAmount, stakingPeriod, callOptionId);

        require(success, "Price Protection failed");

        uint256 loanAmount = ILP(LPAddress).transferLoan(collateralPrice);

        uint256 swappedEthAmount = swapETH(1, address(this), underlying, wETH, loanAmount);

        int256 priceOfEth = getPriceInUSD(ethOracleAddress);
        int256 priceOfSwappedEth = (priceOfEth * int256(swappedEthAmount)) / (10 ** 8 * 10 ** 18);
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

        int256 _underlyingPrice = getPriceInUSD(usdcOracleAddress);
        uint256 premiumPrice = _callOption.premiumPrice;

        uint256 premiumInToken = (premiumPrice * 10 ** 8) / uint256(_underlyingPrice);

        require(IERC20(underlying).transfer(address(this), premiumInToken), "Transfer failed");

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

        int256 _underlyingPrice = getPriceInUSD(usdcOracleAddress);
        uint256 strikePrice = _callOption.strikePrice;

        uint256 strikeInToken = strikePrice * 10 ** 8 / uint256(_underlyingPrice);

        require(IERC20(underlying).transfer(address(this), strikeInToken), "Transfer failed");

        _callOption.isFullyPayed = true;

        (bool success,) = (msg.sender).call{value: _callOption.amount}("");
        require(success, "Transfer failed");

        emit StrikePricePayed(_callOptionId);
    }

    /**
     * @notice Used to calculate the strike price
     * @param _price initial asset price
     * @param stakingPeriod The period at which the asset is staked
     */
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
