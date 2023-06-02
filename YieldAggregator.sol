pragma solidity ^0.5.16;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface WrappedETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface CompoundETH {
    function mint() external payable;
    function redeem(uint256) external returns (uint256);
    function supplyRatePerBlock() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface AaveLendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external;
    function getReserveData(address asset) external returns (
        uint256 configuration,
        uint128 liquidityIndex,
        uint128 variableBorrowIndex,
        uint128 currentLiquidityRate,
        uint128 currentVariableBorrowRate,
        uint128 currentStableBorrowRate,
        uint40 lastUpdateTimestamp,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress,
        uint8 id
    );
}

contract YieldAggregator {
    using SafeMath for uint256;

    string public name = "Yield Aggregator";
    address public owner;
    address public locationOfFunds;
    uint256 public amountDeposited;

    WrappedETH private wrappedETH;
    CompoundETH private compoundETH;
    AaveLendingPool private aaveLendingPool;

    event Deposit(address owner, uint256 amount, address depositTo);
    event Withdraw(address owner, uint256 amount, address withdrawFrom);
    event Rebalance(address owner, uint256 amount, address depositTo);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address wrappedETHAddress, address compoundETHAddress, address aaveLendingPoolAddress) public {
        owner = msg.sender;
        wrappedETH = WrappedETH(wrappedETHAddress);
        compoundETH = CompoundETH(compoundETHAddress);
        aaveLendingPool = AaveLendingPool(aaveLendingPoolAddress);
    }

    function deposit(uint256 _amount, uint256 _compAPY, uint256 _aaveAPY) public onlyOwner {
        require(_amount > 0, "Invalid amount");

        if (amountDeposited > 0) {
            rebalance(_compAPY, _aaveAPY);
        }

        wrappedETH.transferFrom(msg.sender, address(this), _amount);
        wrappedETH.deposit.value(_amount)();

        amountDeposited = amountDeposited.add(_amount);

        if (_compAPY > _aaveAPY) {
            compoundETH.mint.value(_amount)();
            locationOfFunds = address(compoundETH);
        } else {
            aaveLendingPool.deposit(address(wrappedETH), _amount, address(this), 0);
            locationOfFunds = address(aaveLendingPool);
        }

        emit Deposit(owner, _amount, locationOfFunds);
    }

    function withdraw(uint256 _amount) public onlyOwner {
        require(_amount > 0 && _amount <= amountDeposited, "Invalid amount");

        if (locationOfFunds == address(compoundETH)) {
            uint256 compoundETHBalance = compoundETH.balanceOf(address(this));
            uint256 redeemAmount = compoundETHBalance.mul(_amount).div(amountDeposited);
            uint256 withdrawnAmount = compoundETH.redeem(redeemAmount);
            require(withdrawnAmount > 0, "Compound withdraw failed");
            require(address(this).balance >= withdrawnAmount, "Insufficient ETH balance");
            msg.sender.transfer(withdrawnAmount);
        } else {
            aaveLendingPool.withdraw(address(wrappedETH), _amount, msg.sender);
        }

        amountDeposited = amountDeposited.sub(_amount);

        emit Withdraw(owner, _amount, locationOfFunds);
    }

    function rebalance(uint256 _compAPY, uint256 _aaveAPY) internal {
        if (locationOfFunds == address(compoundETH)) {
            uint256 compoundETHBalance = compoundETH.balanceOf(address(this));
            uint256 redeemAmount = compoundETHBalance.mul(amountDeposited).div(compoundETHBalance.add(amountDeposited));
            uint256 redeemedAmount = compoundETH.redeem(redeemAmount);
            require(redeemedAmount > 0, "Compound redeem failed");
            require(address(this).balance >= redeemedAmount, "Insufficient ETH balance");
            wrappedETH.withdraw(redeemedAmount);
        } else {
            aaveLendingPool.withdraw(address(wrappedETH), amountDeposited, address(this));
        }
    }

    function() external payable {}
}
