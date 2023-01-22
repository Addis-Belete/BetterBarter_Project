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
    address public underlyingAddress = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address USDCHolder = 0x75C0c372da875a4Fc78E8A37f58618a6D18904e8;
    address public receiptAddress;
    address usdcOracleAddress;

    event Deposited(address indexed userAddress, uint256 amount, uint256 stakingPeriod);
    event AssetWithdrawed(address indexed userAddress, uint256 amount, uint256 stakingId);

    function setUp() public {
        vm.startPrank(address(20));
        ReceiptToken receipt = new ReceiptToken("Better receipt token", "BRT", 0);
        receiptAddress = address(receipt);
        lp = new LP(address(receipt), underlyingAddress, address(20), usdcOracleAddress);
        receipt.setPoolAddress(address(lp));
        vm.stopPrank();
    }

    function testDeposits() public {
        vm.prank(USDCHolder);

        IERC20(underlyingAddress).approve(address(lp), 20000000);
        lp.deposit(USDCHolder, 20000000, 7 minutes);

        console.log(IERC20(underlyingAddress).balanceOf(address(lp)), "pool Balance");
        assertEq(IERC20(underlyingAddress).balanceOf(address(lp)), 20000000);
        assertEq(IERC20(receiptAddress).balanceOf(USDCHolder), 20000000);
        LP.UserInfo memory _userInfo = lp.getUserInfo(USDCHolder, 1);
        console.log(_userInfo.amount);
        assertEq(_userInfo.initialTime, block.timestamp);
        assertEq(_userInfo.stakingPeriod, 7 minutes);
        assertEq(_userInfo.amount, 20000000);
        assertEq(_userInfo.stakingEndTime, block.timestamp + 7 minutes);
        vm.stopPrank();
    }

    function testFailDeposit() public {
        vm.prank(USDCHolder);
        lp.deposit(USDCHolder, 2 ether, 8 minutes);
        vm.stopPrank();
    }

    function testFailDeposit1() public {
        vm.prank(USDCHolder);

        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(USDCHolder, 2 ether, 8 minutes);
        vm.stopPrank();
    }
    /* 

    function testWithdraw() public {
        vm.startPrank(USDCHolder);
        IERC20(underlyingAddress).approve(address(lp), 2000000000);
        lp.deposit(USDCHolder, 2000000000, 7 minutes);
        // vm.expectEmit(true, false, false, false);
        vm.warp((8 minutes));

        lp.withdraw(USDCHolder, 2000000000, 1);
        // emit AssetWithdrawed(USDCHolder, 2011199983796296296, 1);
        assertEq(IERC20(receiptAddress).balanceOf(USDCHolder), 0);
        LP.UserInfo memory _userInfo = lp.getUserInfo(USDCHolder, 1);
        assertEq(_userInfo.amount, 0);
    }

    function testFailWithdraw() public {
        vm.startPrank(USDCHolder);
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(USDCHolder, 2 ether, 7 minutes);
        vm.warp(8 minutes);
        lp.withdraw(address(20), 2 ether, 1);
    }

    function testFailWithdraw1() public {
        vm.startPrank(USDCHolder);
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(USDCHolder, 2 ether, 7 minutes);
        lp.withdraw(USDCHolder, 2 ether, 1);
    }

    function testFailWithdraw2() public {
        vm.startPrank(USDCHolder);
        IERC20(underlyingAddress).approve(address(lp), 2 ether);
        lp.deposit(USDCHolder, 2 ether, 7 minutes);
        vm.warp(8 minutes);
        lp.withdraw(USDCHolder, 3 ether, 1);
    }

    function testTransferLoan() public {
        vm.startPrank(address(20));
        lp.transferLoan(1500);
        uint256 loanTransferred = IERC20(underlyingAddress).balanceOf(address(20));
        console.log(loanTransferred, "Loan Transferred");
        vm.stopPrank();
    }
*/
}
