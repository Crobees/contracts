// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Honey} from "src/token/Honey.sol";
import {CrobeesAccessControls} from "src/access/CrobeesAccessControls.sol";

contract HoneyScript is Script {
    address internal crobeesAddress = 0x17FAff43ea149351FEa89467dc9DAAB72e4D6BC8;
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CrobeesAccessControls crobeesAccessControls = new CrobeesAccessControls();
        new Honey(crobeesAddress, address(crobeesAccessControls));
    }
}
