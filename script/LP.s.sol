// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Core/LP.sol";
import "../src/Tokens/receiptToken.sol";
import "forge-std/console2.sol";

contract LPScript is Script {
    address uSDCOnGeorli = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address betterAddress = 0x402971caf06493EC4fbB180a07f563d9CD2898d2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiptToken receipt = new ReceiptToken("Better receipt token", "BRT");
        LP lp = new LP(address(receipt), uSDCOnGeorli, betterAddress);
        console2.log("LP deployed too -->", address(lp));
    }
}
