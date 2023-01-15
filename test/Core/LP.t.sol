// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/LP.sol";
import "../../src/Tokens/receiptToken.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/Tokens/testToken.sol";
import "forge-std/console2.sol";

contract LPTest is Test {
    LP public lp;
    address public underlyingAddress;

    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);

    function setUp() public {
        vm.startPrank(address(20));
        ReceiptToken receipt = new ReceiptToken("Better receipt token", "BRT");

        TestToken underlying = new TestToken("USD coin", "USDC");
        underlying.mint(address(30), 5000 ether);

        underlyingAddress = address(underlying);
        lp = new LP(address(receipt), address(underlying));
        receipt.setPoolAddress(address(lp));
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.prank(address(30));
        vm.expectEmit(true, false, false, false);
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        emit Deposited(address(30), 2 ether, 7 days);

        assertEq(IERC20(underlyingAddress).balanceOf(address(lp)), 2 ether);

        LP.UserInfo memory _userInfo = lp.getUserInfo(address(30), 1);
        console.log(_userInfo.amount);
        assertEq(_userInfo.initialTime, block.timestamp);
        assertEq(_userInfo.stakingPeriod, 7 days);
        assertEq(_userInfo.amount, 2 ether);
        assertEq(_userInfo.stakingEndTime, block.timestamp + 7 days);
    }
}
