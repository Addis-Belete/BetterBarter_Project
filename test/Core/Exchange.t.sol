// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/Helpers/Exchange.sol";

contract TestExchange is Test {
    address crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f;
    address USDC = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address cruiseContract = 0xE3aA7826348EE5559bcF70FE626a3ca6962ffBdC;
    address usdcOracleAddress = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7;
    address ethOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address USDCHolder = 0x75C0c372da875a4Fc78E8A37f58618a6D18904e8;
    address ethHolder = 0xE807C2a81366dc10a68cd8e95660477294B6019B;

    Exchange public exchange;

    function setUp() public {
        exchange = new Exchange(routerAddress);
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
