// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

contract HoneyBonding {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice The different periods available for bonding
    enum Period {
        TwoWeeks, // 14 days with a maximum of 62 500 $HONEY per period
        OneMonth, // 30 days with a maximum of 120 000 $HONEY per period
        TwoMonths // 60 days with a maximum of 250 000 $HONEY per period
    }

    /// @notice Bonds struct, contains the current allocation and the rewards percentage
    struct Bond {
        uint248 currentAllocation;
        uint8 rewardsPercentage;
    }

    /// @notice UserBond struct, info about the user
    struct UserBond {
        uint128 startingTimestamp;
        uint128 totalBonded;
    }

    // The address to which the fees will be sent
    address public immutable crobeesAddress;

    // The starting timestamp of the epoch 0 of all periods
    uint128 public immutable startingTimestamp;

    // The ending timestamp of the bonding (720 days after the starting timestamp)
    uint128 public immutable endingTimestamp;

    // The total honey allocate for the bonding
    uint256 public immutable bondingAllocation = 3_000_000 * 10 ** 18;

    // Honey token
    IERC20 public immutable honey;

    // Period => epoch => Bond
    mapping(Period => mapping(uint256 => Bond)) public bonds;

    // user => Period => epoch => UserBond
    mapping(address => mapping(Period => mapping(uint256 => UserBond))) public bonders;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NullAddress();
    error NullAmount();

    error MaxUserAllocationExceeded();
    error MaxPoolAllocationExceeded();

    error BondingNotStarted();
    error BondingHasEnded();
    
    error EpochNotEnded();
    error BadEpoch();
    
    error NotEnoughHoney();
    error UserAlreadyCommited();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Bonded(address indexed user, Period period, uint256 epoch, uint88 amount);
    event Claimed(address indexed user, Period period, uint256 epoch, uint88 amount);
    event Compound(address indexed user, Period period, uint256 epoch, uint88 amount);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyCrobees() {
        require(msg.sender == crobeesAddress, "HoneyBonding: only crobees");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Honey bonding constructor, set the token contract, starting timestamp of epoch0 and crobees fees address
    /// @param _honey The address of the honey token
    /// @param _startingTimestamp The starting timestamp of epoch 0 of all periods
    /// @param _crobeesAddress The address which will receive the fees
    constructor(address _honey, uint128 _startingTimestamp, address _crobeesAddress) {
        require(_startingTimestamp > block.timestamp, "HoneyBonding: starting timestamp must be in the future");

        if (_honey == address(0)) revert NullAddress();
        honey = IERC20(_honey);
        crobeesAddress = _crobeesAddress;

        bonds[Period.TwoWeeks][0] = Bond({currentAllocation: 0, rewardsPercentage: 10});
        bonds[Period.OneMonth][0] = Bond({currentAllocation: 0, rewardsPercentage: 23});
        bonds[Period.TwoMonths][0] = Bond({currentAllocation: 0, rewardsPercentage: 67});

        startingTimestamp = _startingTimestamp;
        endingTimestamp = _startingTimestamp + 720 days;
    }

    /*//////////////////////////////////////////////////////////////
                             BONDING LOGIC
    //////////////////////////////////////////////////////////////*/
    function bond(Period period, uint88 amount) external {
        _bond(period, amount, false);
    }
    /// @notice Commit honey for a given period
    /// @param period The period to bond honey for, can be 2 weeks, 1 month or 2 months
    /// @param amount The amount of honey to bond, must be less than 10% of getBondMaxAllocation(period)
    /// @dev The user can't bond honey for the same epoch's period twice
    function _bond(Period period, uint88 amount, bool isCompound) internal {
        // Check if the bonding is active
        if (block.timestamp < startingTimestamp) revert BondingNotStarted();
        if (block.timestamp > endingTimestamp) revert BondingHasEnded();

        uint256 epoch = getEpoch(period);
        Bond storage currentBond = bonds[period][epoch];
        UserBond storage currentUserBond = bonders[msg.sender][period][epoch];

        // Get the max allocation for this period
        uint256 bondMaxAllocation = getBondMaxAllocation(period);

        // If the user is trying to bond more than 10% of the max allocation, revert
        if (amount > bondMaxAllocation / 10) revert MaxUserAllocationExceeded();

        // Check if the user has already bonded honey for this epoch, if so revert
        if (currentUserBond.totalBonded > 0) revert UserAlreadyCommited();

        // Can not bond a null amount
        if (amount == 0) revert NullAmount();

        // If the current pool allocation + the amount to bond is greater than the max allocation, revert
        if (currentBond.currentAllocation + amount > bondMaxAllocation) revert MaxPoolAllocationExceeded();
        
        // Update the current pool allocation
        currentBond.currentAllocation += amount;

        // init the user bond
        currentUserBond.startingTimestamp = uint128(block.timestamp);
        currentUserBond.totalBonded = amount;

        // TransferFrom should be call only if the user is not bonding honey from a compound
        if (!isCompound) {
            // If the user is trying to bond more honey than he has, revert
            if (honey.balanceOf(msg.sender) < amount) revert NotEnoughHoney();
            honey.transferFrom(msg.sender, address(this), amount);
        }        
        
        emit Bonded(msg.sender, period, epoch, amount);
    }

    /// @notice Claime honey rewards for a given period and epoch
    /// @param period The period to claim honey rewards for, can be 2 weeks, 1 month or 2 months
    /// @param epoch The epoch to claim honey rewards for, must be a past epoch
    /// @dev The claim must be done after the bonding period has ended (getTimeframe(period))
    /// @dev 2% of the rewards are sent to crobees
    function claimBond(Period period, uint8 epoch) external {
        // Check if the epoch is valid, can't claim for future epochs
        if (epoch > getEpoch(period)) revert BadEpoch();

        // Check if the epoch has ended
        UserBond storage currentUserBond = bonders[msg.sender][period][epoch];
        if (block.timestamp < currentUserBond.startingTimestamp + getTimeframe(period)) revert EpochNotEnded();

        // Check if the user has bonded honey for this epoch, if not revert
        uint256 bondedAmount = currentUserBond.totalBonded;
        if (bondedAmount == 0) revert NullAmount();

        // Compute the rewards and fees
        uint256 rewards = (bondedAmount * bonds[period][epoch].rewardsPercentage) / 100;

        currentUserBond.totalBonded = 0;
        uint256 amountToTransfer = bondedAmount + rewards;
        uint256 fees = amountToTransfer * 2 / 100;
        amountToTransfer -= fees;

        honey.transfer(msg.sender, amountToTransfer);
        honey.transfer(crobeesAddress, fees);

        emit Claimed(msg.sender, period, epoch, uint88(amountToTransfer));
    }

    /// @notice Compound honey rewards for a given period and epoch
    /// @dev The compound must be done after the bonding period has ended (getTimeframe(period))
    /// @dev No fees are taken on the compound
    /// @dev The user can only compound once per epoch, the rewards are bonded for the next epoch
    /// @dev If the user has already bonded honey for the next epoch, it reverts
    /// @dev If the rewards are greater than the max allocation for the next epoch, it computes the difference 
    ///      and bonds it for the next next epoch. The rewards remaining are sent to the user
    /// @param period The period to compound honey rewards for, can be 2 weeks, 1 month or 2 months
    /// @param epoch The epoch to compound honey rewards for, must be a past epoch
    function compound(Period period, uint8 epoch) external {
        UserBond storage currentUserBond = bonders[msg.sender][period][epoch];

        // Check if the bonding period has ended
        if (block.timestamp < currentUserBond.startingTimestamp + getTimeframe(period)) revert EpochNotEnded();

        // if the user has already bonded honey for the next epoch, it reverts
        uint currentGlobalEpoch = getEpoch(period);
        if (bonders[msg.sender][period][currentGlobalEpoch].totalBonded > 0) revert UserAlreadyCommited();

        // check if the user has bonded honey for the current epoch, revert if not
        uint256 bondedAmount = currentUserBond.totalBonded;
        if (bondedAmount == 0) revert NullAmount();

        // compute the rewards
        uint256 rewards = (bondedAmount * bonds[period][epoch].rewardsPercentage) / 100;

        // amount to compound is the rewards + the bonded amount
        uint256 amountToCompound = bondedAmount + rewards;

        // reset the user's bond, so he can't claim it again
        currentUserBond.totalBonded = 0;

        // compute the remaining allowance for the current pool's epoch
        uint256 remainingAllowance = 
            getBondMaxAllocation(period) - bonds[period][currentGlobalEpoch].currentAllocation;
        
        // if the pool is full, it reverts
        if (remainingAllowance == 0) revert MaxPoolAllocationExceeded();

        uint256 amountToTransfer;

        // if the amount to compound is greater than the max allocation for the next epoch, it computes the difference
        if (amountToCompound > remainingAllowance) {
            amountToTransfer = amountToCompound - remainingAllowance;
            amountToCompound = remainingAllowance;
        }

        // bond the rewards for the next epoch
        _bond(period, uint88(amountToCompound), true);

        // transfer the remaining rewards to the user, compute the fees and send them to crobees
        if(amountToTransfer > 0) {
            uint256 fees = amountToTransfer * 2 / 100;
            amountToTransfer -= fees;
            honey.transfer(msg.sender, amountToTransfer);
            honey.transfer(crobeesAddress, fees);
        }
        
        emit Compound(msg.sender, period, epoch, uint88(amountToCompound));
    }

    /// @notice Returns the current epoch for a given period
    /// @param period The period to get the epoch for
    /// @return The current epoch
    function getEpoch(Period period) public view returns (uint256) {
        if (block.timestamp < startingTimestamp) return 0;
        return (getTimestamp() - startingTimestamp) / getTimeframe(period);
    }

    /// @notice Returns the maximum allocation for a bond
    /// @param period The period to get the maximum allocation for
    /// @return maxAllocation The maximum bond's allocation
    function getBondMaxAllocation(Period period) public pure returns (uint256 maxAllocation) {
        if (period == Period.TwoWeeks) return 62_500 * 10 ** 18;
        if (period == Period.OneMonth) return 125_000 * 10 ** 18;
        if (period == Period.TwoMonths) return 250_000 * 10 ** 18;
    }

    /// @notice Returns the starting timestamp for the current bond epoch
    /// @param period The period to get the starting timestamp for
    /// @return The starting timestamp
    function getCurrentBondStartingTimestamp(Period period) public view returns (uint256) {
        if (block.timestamp < startingTimestamp) return startingTimestamp;
        uint256 totalEpochs = (block.timestamp - startingTimestamp) / getTimeframe(period);
        return startingTimestamp + (totalEpochs * getTimeframe(period)) ;
    }

    function getCurrentBondEpochTimestampInfo(Period period) public view returns (uint128 start, uint128 end) {
        start = uint128(getCurrentBondStartingTimestamp(period));
        end = start + uint128(getTimeframe(period));
    }

    /// @notice Returns the total epoch's time for a given period
    /// @param period The period to get the timeframe for
    /// @return timeframe
    function getTimeframe(Period period) public pure returns (uint256 timeframe) {
        if (period == Period.TwoWeeks) return 15 days;
        if (period == Period.OneMonth) return 30 days;
        if (period == Period.TwoMonths) return 60 days;
    }

    /// @notice Returns the current timestamp
    /// @dev If the current timestamp is greater than the ending timestamp, it returns the ending timestamp
    /// @return The current timestamp
    function getTimestamp() internal view returns (uint256) {
        if (block.timestamp > endingTimestamp) return endingTimestamp;
        return block.timestamp;
    }

    /// @notice Withdraws the honey from the bonding contract
    /// @dev Only crobees can call this function
    /// @dev Can be called only after all the bonding periods have ended
    function withdrawHoney() external onlyCrobees {
        if (honey.balanceOf(address(this)) == 0) revert NullAmount();
        if (block.timestamp < endingTimestamp) revert EpochNotEnded();
        honey.transfer(crobeesAddress, honey.balanceOf(address(this)));
    }
}
