//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; 

interface ICrobeesAccessControls {
    function hasAdminRole(address _address) external view returns (bool);
    function hasBurnerRole(address _address) external view returns (bool);
    function addAdminRole(address _address) external;
    function removeAdminRole(address _address) external;
    function addBurnerRole(address _address) external;
    function removeBurnerRole(address _address) external;
}