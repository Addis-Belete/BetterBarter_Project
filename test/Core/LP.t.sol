// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/LP.sol";

import "../../src/Core/LPWallet.sol";
import "../../src/Tokens/receiptToken.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/Tokens/testToken.sol";
import "forge-std/console2.sol";

contract LPTest is Test {
    LP public lp;
    address public underlyingAddress;
    address public receiptAddress;

    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);
    event AssetWithdrawed(address indexed userAddress, uint256 amount, uint256 stakingId);

    function setUp() public {
        vm.startPrank(address(20));
        ReceiptToken receipt = new ReceiptToken("Better receipt token", "BRT");
        receiptAddress = address(receipt);
        TestToken underlying = new TestToken("USD coin", "USDC");

        underlying.mint(address(30), 5000 ether);

        underlyingAddress = address(underlying);
        lp = new LP(address(receipt), address(underlying), address(20));
        underlying.mint(address(lp), 100 ether);

        receipt.setPoolAddress(address(lp));
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.prank(address(30));
        vm.expectEmit(true, false, false, false);
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        emit Deposited(address(30), 2 ether, 7 days);

        assertEq(IERC20(underlyingAddress).balanceOf(address(lp)), 100 ether + 2 ether);
        assertEq(IERC20(receiptAddress).balanceOf(address(30)), 2 ether);
        LP.UserInfo memory _userInfo = lp.getUserInfo(address(30), 1);
        console.log(_userInfo.amount);
        assertEq(_userInfo.initialTime, block.timestamp);
        assertEq(_userInfo.stakingPeriod, 7 days);
        assertEq(_userInfo.amount, 2 ether);
        assertEq(_userInfo.stakingEndTime, block.timestamp + 7 days);
        vm.stopPrank();
    }

    function testFailDeposit() public {
        vm.prank(address(30));
        lp.deposit(address(30), 2 ether, 8 days);
        vm.stopPrank();
    }

    function testFailDeposit1() public {
        vm.prank(address(30));

        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 8 days);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(address(30));
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        vm.expectEmit(true, false, false, false);
        vm.warp(8 days);
        lp.withdraw(address(30), 2 ether, 1);
        emit AssetWithdrawed(address(30), 2011199983796296296, 1);
        assertEq(IERC20(receiptAddress).balanceOf(address(30)), 0);
        LP.UserInfo memory _userInfo = lp.getUserInfo(address(30), 1);
        assertEq(_userInfo.amount, 0);
    }

    function testFailWithdraw() public {
        vm.startPrank(address(30));
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        vm.warp(8 days);
        lp.withdraw(address(20), 2 ether, 1);
    }

    function testFailWithdraw1() public {
        vm.startPrank(address(30));
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        lp.withdraw(address(30), 2 ether, 1);
    }

    function testFailWithdraw2() public {
        vm.startPrank(address(30));
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(address(30), 2 ether, 7 days);
        vm.warp(8 days);
        lp.withdraw(address(30), 3 ether, 1);
    }

    function testTransferLoan() public {
        vm.startPrank(address(20));
        lp.transferLoan(1500);
        uint256 loanTransferred = IERC20(underlyingAddress).balanceOf(address(20));
        console.log(loanTransferred, "Loan Transferred");
        vm.stopPrank();
    }
}
