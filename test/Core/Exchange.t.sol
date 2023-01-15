// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/Helpers/Exchange.sol";

contract TestExchange is Test {
    address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address USDCHolder = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    address WETHHolder = 0x28424507fefb6f7f8E9D3860F56504E4e5f5f390;
    address router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address qouter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    Exchange public exchange;

    function setUp() public {
        exchange = new Exchange(router, qouter);
    }

    function testSwapExactInput() public {
        vm.startPrank(USDCHolder);
        console.log(IERC20(USDC).balanceOf(USDCHolder), "Holder usdc balance");
        IERC20(USDC).approve(address(exchange), 20000000);
        exchange.swap(0, address(50), USDC, WETH, 20000000, block.timestamp + 2 minutes);
    }

    function testSwapExactOutput() public {
        vm.startPrank(WETHHolder);
        console.log(IERC20(WETH).balanceOf(WETHHolder), "Holder usdc balance");
        uint256 amountInMin = exchange.getAmountInMinimum(WETH, USDC, 200000000);
        console2.log(amountInMin, "Amount In min");

        IERC20(WETH).approve(address(exchange), amountInMin);
        exchange.swap(1, address(50), WETH, USDC, amountInMin, block.timestamp + 2 minutes);
    }
}
