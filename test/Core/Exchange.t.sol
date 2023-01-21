// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/Helpers/Exchange.sol";

contract TestExchange is Test {
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDCHolder = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;
    address WETHHolder = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
    address ethHolder = 0x473780deAF4a2Ac070BBbA936B0cdefe7F267dFc;
    address router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address routerV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address qouter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    Exchange public exchange;

    function setUp() public {
        exchange = new Exchange(routerV2);
    }

    /**
     * function testSwapExactInput() public {
     *     vm.startPrank(USDCHolder);
     *     console.log(IERC20(USDC).balanceOf(USDCHolder), "Holder usdc balance");
     *     IERC20(USDC).approve(address(exchange), 20000000);
     *     exchange.swap(0, address(50), USDC, WETH, 20000000, block.timestamp + 2 minutes);
     * }
     *
     * function testSwapExactOutput() public {
     *     vm.startPrank(WETHHolder);
     *     console.log(IERC20(WETH).balanceOf(WETHHolder), "Holder usdc balance");
     *     uint256 amountInMin = exchange.getAmountInMinimum(WETH, USDC, 200000000);
     *     console2.log(amountInMin, "Amount In min");
     *
     *     IERC20(WETH).approve(address(exchange), amountInMin);
     *     exchange.swap(1, address(50), WETH, USDC, 200000000, block.timestamp + 2 minutes);
     * }
     */
    function testSwapETH() public {
        vm.startPrank(ethHolder);
        console2.log(ethHolder.balance, "Balance");

        uint256[] memory amountOutMin = exchange.getAmountInMaximum(WETH, USDC, 200000000);
        console.log(amountOutMin[1]);
        exchange.swapETH{value: amountOutMin[0]}(0, address(30), WETH, USDC, 200000000);
    }

    function testSwapETH1() public {
        vm.startPrank(USDCHolder);
        console2.log(IERC20(USDC).balanceOf(USDCHolder), "Balance");
        uint256[] memory amountOutMin = exchange.getAmountOutMinimum(USDC, WETH, 200000000);
        console.log(amountOutMin[1], "Amount out min");
        IERC20(USDC).approve(address(exchange), 200000000);
        exchange.swapETH(1, address(40), USDC, WETH, 200000000);
        console2.log(address(40).balance, "Balance after swap");
    }
}
