// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Core/BetterBarter.sol";

contract BetterBarterScript is Script {
    address crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f;
    address uSDCOnGeorli = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address wETHGeorli = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address cruiseContract = 0xE3aA7826348EE5559bcF70FE626a3ca6962ffBdC;
    address usdcOracleAddress = 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7;
    address ethOracleAddress = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
    address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address wethUniswap = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        console.log(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        BetterBarter _better =
        new BetterBarter(cruiseContract, wETHGeorli, routerAddress, crETH, ethOracleAddress, usdcOracleAddress, uSDCOnGeorli, wethUniswap);
        vm.stopBroadcast();
    }
}
