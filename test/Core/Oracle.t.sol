// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Helpers/Oracle.sol";
import "forge-std/console2.sol";

contract OracleTest is Test {
    Oracle public oracle;
    address usdcOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address ETHOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

    function setUp() public {
        oracle = new Oracle();
        console.log(address(oracle));
    }

    function testGetPriceInUSD() public {
        vm.startPrank(0x7c7379531b2aEE82e4Ca06D4175D13b9CBEafd49);
        int256 price = oracle.getPriceInUSD(ETHOracleAddress);
        console2.log(uint256(price) / 10 ** 8, "USDC price In USD");
    }
}

//forge test --match testGetPriceInUSD --fork-url https://rpc.ankr.com/eth -vvvv
