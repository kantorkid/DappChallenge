// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract YieldAggregator {
    using SafeERC20 for IERC20;

    address public compoundAddress; // Address of the Compound contract
    address public aaveAddress; // Address of the Aave contract

    IERC20 public wethToken; // ERC20 token used (WETH)

    constructor(address _compoundAddress, address _aaveAddress, address _wethToken) {
        compoundAddress = _compoundAddress;
        aaveAddress = _aaveAddress;
        wethToken = IERC20(_wethToken);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        // Approve transfer of WETH to both Compound and Aave contracts
        wethToken.safeApprove(compoundAddress, amount);
        wethToken.safeApprove(aaveAddress, amount);

        // Get the current APY rates of Compound and Aave
        uint256 compoundAPY = getCompoundAPY();
        uint256 aaveAPY = getAaveAPY();

        if (compoundAPY >= aaveAPY) {
            // Deposit WETH into Compound
            compoundDeposit(amount);
        } else {
            // Deposit WETH into Aave
            aaveDeposit(amount);
        }
    }

    function rebalance() external {
        // Get the current APY rates of Compound and Aave
        uint256 compoundAPY = getCompoundAPY();
        uint256 aaveAPY = getAaveAPY();

        if (compoundAPY > aaveAPY) {
            // Withdraw from Aave and deposit into Compound
            uint256 aaveBalance = getAaveBalance();
            aaveWithdraw(aaveBalance);
            compoundDeposit(aaveBalance);
        } else if (aaveAPY > compoundAPY) {
            // Withdraw from Compound and deposit into Aave
            uint256 compoundBalance = getCompoundBalance();
            compoundWithdraw(compoundBalance);
            aaveDeposit(compoundBalance);
        }
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        uint256 compoundBalance = getCompoundBalance();
        uint256 aaveBalance = getAaveBalance();

        if (amount <= compoundBalance) {
            // Withdraw from Compound
            compoundWithdraw(amount);
        } else if (amount <= compoundBalance + aaveBalance) {
            // Withdraw from Aave
            aaveWithdraw(amount - compoundBalance);
        } else {
            revert("Insufficient funds");
        }
    }

    // Helper functions for interacting with Compound and Aave contracts
    function compoundDeposit(uint256 amount) internal {
        // Implement the deposit logic for Compound
        // ...
    }

    function compoundWithdraw(uint256 amount) internal {
        // Implement the withdrawal logic for Compound
        // ...
    }

    function aaveDeposit(uint256 amount) internal {
        // Implement the deposit logic for Aave
        // ...
    }

    function aaveWithdraw(uint256 amount) internal {
        // Implement the withdrawal logic for Aave
        // ...
    }

    // Helper functions to get APY rates
    function getCompoundAPY() internal view returns (uint256) {
        // Implement the logic to get the APY rate from Compound
        // ...
    }

    function getAaveAP
