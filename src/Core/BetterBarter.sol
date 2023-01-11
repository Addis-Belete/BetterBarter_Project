// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/ICruise.sol";

contract BetterBarter {
    //Responsible for the main logic of the Better Barter APP.

    struct Info {
        uint256 amount;
        uint256 initialTime;
        uint256 price;
        uint256 stakingPeriod;
    }

    struct CallOption {
        uint256 amount;
        uint256 initialTime;
        uint256 strikePrice;
        bool isSold; // show if the premium is payed for this call option;
        bool isFullyPayed; // Shows if user buys the strike price
    }

    mapping(address => mapping(uint256 => CallOption)) public callOptions; //address -> callOptionId -> CallOption
    ICruise internal cruise;
    address internal priceProtectionAddress;

    constructor(address _cruiseAddress, address _priceProtectionAddress) {
        cruise = ICruise(_cruiseAddress);
        priceProtectionAddress = _priceProtectionAddress;
    }

    function depositETH() external payable {
        require(msg.value > 0, "Value not 0");
        /**
         * deposit Eth
         * 			lock crEth in price contract
         * 			borrow 75% from LP wallet
         * 			swap to ETH
         * 			post for call option
         */
    }

    function withdrawEth() external {}

    function BuyCallOption() external {}

    function swap() internal {}
}
