// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Flowers} from "src/nft/Flowers.sol";

contract FlowersScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new Flowers(
            "https://crobees.mypinata.cloud/ipfs/QmUSSsFSQKn7eVbzzPxoro7Xuw7siP4qc6bQeAFbR7srFC/10.json",
            0x305ffc55133918Ce1579d8cF3eAff588fb8a7633
        );
    }
}
