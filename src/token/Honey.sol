// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; 

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICrobeesAccessControls} from "src/interfaces/ICrobeesAccessControls.sol";

contract Honey is ERC20Permit {
    ICrobeesAccessControls public immutable crobeesAccessControls;
    address public immutable crobeesAddress;
    bytes32 public constant MINTER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant MAX_SUPPLY = 10_000_000 * 10 ** 18;

    modifier onlyBurner() {
        require(crobeesAccessControls.hasBurnerRole(msg.sender), "Honey: only burner");
        _;
    }

    constructor(address _team, address _crobeesAccess) ERC20("Honey", "HONEY") ERC20Permit("Honey") {
        require(_team != address(0), "Honey: access null address");
        require(_crobeesAccess != address(0), "Honey: minter null address");
        crobeesAccessControls = ICrobeesAccessControls(_crobeesAccess);
        crobeesAddress = _team;
        _mint(_team, MAX_SUPPLY);
    }

    function burn(uint256 amount) external onlyBurner {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyBurner {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}




