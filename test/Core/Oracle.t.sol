// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Helpers/Oracle.sol";
import "forge-std/console2.sol";

contract OracleTest is Test {
    Oracle public oracle;
    address usdcOracleAddress = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    address ETHOracleAddress = 0xF9680D99D6C9589e2a93a78A04A279e509205945;

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
