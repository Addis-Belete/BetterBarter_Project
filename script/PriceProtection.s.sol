// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Core/PriceProtection.sol";
import "../src/Tokens/receiptToken.sol";

contract PriceProtectionScript is Script {
    address betterAddress = 0x402971caf06493EC4fbB180a07f563d9CD2898d2;
    address wETHGeorli = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address crETH = 0x0716e8f8F5D85a112aeA660b9D4a4fa17a159f1f;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiptToken receipt = new ReceiptToken("Better call option receipt token", "BCORT", 1);
        PriceProtection pr = new PriceProtection(betterAddress, address(receipt), wETHGeorli, crETH);
    }
}
