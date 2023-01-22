// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/Helpers/Exchange.sol";
import "../../src/Core/LP.sol";

import "../../src/Tokens/receiptToken.sol";
import "../../src/Core/BetterBarter.sol";
import "../../src/Core/PriceProtection.sol";
import "../../src/Interfaces/IUniswap.sol";

contract BetterBarterTest is Test {
    LP public lp;
    address receiptAddress;

    BetterBarter public better;
    PriceProtection public priceProtection;
    address crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f;
    address uSDCOnGeorli = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address wETHGeorli = 0xCCa7d1416518D095E729904aAeA087dBA749A4dC;
    address cruiseContract = 0xE3aA7826348EE5559bcF70FE626a3ca6962ffBdC;
    address usdcOracleAddress = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7;
    address ethOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address ethHolder = 0xE807C2a81366dc10a68cd8e95660477294B6019B;
    address wethHolder = 0x05C7f50A3704cf84bCCB81AB7Eaf566d7fF8d77D;
    address USDCHolder = 0x75C0c372da875a4Fc78E8A37f58618a6D18904e8;
    address wethForUniswap = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function setUp() public {
        vm.startPrank(0x148e772046B59f5A61ea0F0322110eCE5f6bb146);
        //Deploy Better Barter
        better =
        new BetterBarter(cruiseContract, wETHGeorli, routerAddress, crETH, ethOracleAddress, usdcOracleAddress,uSDCOnGeorli, wethForUniswap);
        //Deploy Price protection
        ReceiptToken recPrice = new ReceiptToken("Better Receipt For callOptions", "BRFCO", 1);

        priceProtection = new PriceProtection(address(better), address(recPrice), ethOracleAddress, crETH);
        recPrice.setPoolAddress(address(priceProtection));
        //Deploy LP

        ReceiptToken receipt = new ReceiptToken("Better receipt token", "BRT", 0);
        receiptAddress = address(receipt);
        lp = new LP(address(receipt), uSDCOnGeorli, address(better), usdcOracleAddress);
        receipt.setPoolAddress(address(lp));

        better.setPriceProtectionAddress(address(priceProtection));
        better.setLPAddress(address(lp));

        vm.stopPrank();
    }

    function testProvideLiquidity() public {
        vm.startPrank(USDCHolder);
        IERC20(uSDCOnGeorli).approve(address(lp), 2000000000);
        lp.deposit(USDCHolder, 2000000000, 100 minutes);
        vm.stopPrank();
    }

    function testDepositETH() public {
        testProvideLiquidity();
        vm.startPrank(wethHolder);
        console.log(IERC20(wETHGeorli).balanceOf(wethHolder));
        IERC20(wETHGeorli).transfer(address(better), 1 ether);
        better.depositETH(7 minutes, 1 ether);

        BetterBarter.CallOption memory _callOption = better.getCallOption(1);
        assertEq(_callOption.isReadyForSell, true);
        assertEq(_callOption.isSold, false);
        assertEq(_callOption.isFullyPayed, false);
        assertEq(_callOption.strikePrice, 108);
        assertEq(_callOption.premiumPrice, 3);
        assertEq(_callOption.owner, wethHolder);
        assertEq(_callOption.buyer, address(0));
    }

    function testBuyCallOptions() public {
        testProvideLiquidity();
        vm.startPrank(wethHolder);
        console.log(IERC20(wETHGeorli).balanceOf(wethHolder));
        IERC20(wETHGeorli).transfer(address(better), 1 ether);
        better.depositETH(7 minutes, 1 ether);
        vm.stopPrank();
        vm.startPrank(USDCHolder);
        BetterBarter.CallOption memory _callOption = better.getCallOption(1);
        uint256 premiumPriceInToken = better.convertPriceToToken(_callOption.premiumPrice, usdcOracleAddress);
        console.log(premiumPriceInToken, "From test");
        IERC20(uSDCOnGeorli).approve(address(better), premiumPriceInToken);
        better.buyCallOption(1);

        BetterBarter.CallOption memory _callOption1 = better.getCallOption(1);
        assertEq(_callOption1.isSold, true);
        assertEq(_callOption1.buyer, USDCHolder);
    }

    function testPayStrikePrice() public {
        testProvideLiquidity();
        vm.startPrank(wethHolder);
        console.log(IERC20(wETHGeorli).balanceOf(wethHolder));
        IERC20(wETHGeorli).transfer(address(better), 1 ether);
        better.depositETH(7 minutes, 1 ether);
        vm.stopPrank();
        vm.startPrank(USDCHolder);
        BetterBarter.CallOption memory _callOption = better.getCallOption(1);
        uint256 premiumPriceInToken = better.convertPriceToToken(_callOption.premiumPrice, usdcOracleAddress);
        console.log(premiumPriceInToken, "From test");
        IERC20(uSDCOnGeorli).approve(address(better), premiumPriceInToken);
        better.buyCallOption(1);

        uint256 strikePriceInToken = better.convertPriceToToken(_callOption.strikePrice, usdcOracleAddress);
        console2.log(strikePriceInToken, "strike from test");
        IERC20(uSDCOnGeorli).approve(address(better), strikePriceInToken);
        better.payStrikePrice(1);

        BetterBarter.CallOption memory _callOption1 = better.getCallOption(1);
        assertEq(_callOption1.isSold, true);
        assertEq(_callOption1.buyer, USDCHolder);
        assertEq(_callOption1.isFullyPayed, true);
    }
}
