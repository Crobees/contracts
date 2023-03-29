//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; 

import "@openzeppelin/contracts/access/AccessControl.sol";
    
contract CrobeesAccessControls is AccessControl { 
    
    /// @notice Role definitions
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Adding/Removing roles
    event AdminRoleGranted(address indexed beneficiary, address indexed caller);
    event AdminRoleRemoved(address indexed beneficiary, address indexed caller);

    event BurnerRoleGranted(address indexed beneficiary, address indexed caller);
    event BurnerRoleRemoved(address indexed beneficiary, address indexed caller);

    /**
     * @notice Admin role granted automatically to deployer address
     */
     constructor() {
        _setupRole(BURNER_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Check if an address has the admin role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasAdminRole(address _address) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _address);
    }

    /**
     * @notice Check if an address has the Burner role
     * @param _address EOA or contract being checked
     * @return bool True if the account has the role or false if it does not
     */
    function hasBurnerRole(address _address) external view returns (bool) {
        return hasRole(BURNER_ROLE, _address);
    }

    /**
     * @notice Grants the admin role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addAdminRole(address _address) external {
        grantRole(DEFAULT_ADMIN_ROLE, _address);
        emit AdminRoleGranted(_address, _msgSender());
    }

    /**
     * @notice Removes the admin role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeAdminRole(address _address) external {
        revokeRole(DEFAULT_ADMIN_ROLE, _address);
        emit AdminRoleRemoved(_address, _msgSender());
    }

    /**
     * @notice Grants the Burner role to an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract receiving the new role
     */
    function addBurnerRole(address _address) external {
        grantRole(BURNER_ROLE, _address);
        emit BurnerRoleGranted(_address, _msgSender());
    }

    /**
     * @notice Removes the burner role from an address
     * @dev The sender must have the admin role
     * @param _address EOA or contract affected
     */
    function removeBurnerRole(address _address) external {
        revokeRole(BURNER_ROLE, _address);
        emit BurnerRoleRemoved(_address, _msgSender());
    }
}