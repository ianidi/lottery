// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    event Create(address indexed member, uint indexed lotteryID, uint amount, uint time);
    event Deposit(address indexed member, uint indexed lotteryID, uint amount, uint time);
    event Redeem(address indexed member, uint indexed lotteryID, uint amount, uint time);
    event Play(address indexed member, uint indexed lotteryID, uint amount, bool result, uint time);

    enum Status {Active, Closed, NoLiquidity}

    struct LotteryStruct {
        bool exist;
        Status status;
        uint lotteryID;
        uint liquidity;
        uint maxBetPercent;
        uint created;
        uint duration;
        uint formula;
        address collateral;
    }

    mapping(uint => LotteryStruct) public lottery;

    // Wallet (msg.sender) => MemberID
    mapping(address => uint) public member;

    // LotteryID => (MemberID => liquidity balance)
    mapping(uint => mapping(uint => uint)) public liquidityBalances;

    // Tokens allowed to be used as collateral
    // mapping(address => bool) public collateralList;

    uint public currentLotteryID = 1;
    uint public currentMemberID = 1;

    constructor() { }
    
    // Create a new lottery
    function create(address _collateral, uint _liquidityAmount, uint _maxBetPercent, uint _duration) external returns (uint) {
        require(_liquidityAmount > 0, "Invalid liquidity amount");
        // require(collateralList[_collateral] != false, "Invalid collateral");
        require(_duration == 0 || (_duration >= 600 seconds && _duration < 365 days), "Invalid duration");
        require(_maxBetPercent >= 1 && _maxBetPercent <= 50, "Invalid max bet percent");

        uint memberID = getMemberID();
        uint lotteryID = currentLotteryID;

        IERC20 collateral = IERC20(_collateral);

        // Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        // Set liquidity balance for member
        liquidityBalances[lotteryID][memberID] = _liquidityAmount;

        LotteryStruct memory lotteryStruct =
            LotteryStruct({
                exist: true,
                status: Status.Active,
                lotteryID: lotteryID,
                liquidity: _liquidityAmount,
                maxBetPercent: _maxBetPercent,
                created: block.timestamp,
                duration: _duration,
                formula: 1,
                collateral: _collateral
            });

        lottery[lotteryID] = lotteryStruct;

        emit Create(msg.sender, lotteryID, _liquidityAmount, block.timestamp);

        currentLotteryID++;

        return lotteryID;
    }

    // Play the lottery
    function play(uint _lotteryID, uint _betAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status == Status.Active, "Lottery is not running");
        require(_betAmount > 0, "Invalid bet amount");
        require(checkLotteryDuration(_lotteryID), "Lottery has ended");

        require(SafeMath.mul(SafeMath.div(_betAmount, lottery[_lotteryID].liquidity), uint(100)) <= lottery[_lotteryID].maxBetPercent, "Bet amount % in relation to pool size is greater than pool maxBetPercent");

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        // Withdraw collateral from member
        require(collateral.transferFrom(msg.sender, address(this), _betAmount));

        bool winner = determineGameResult(_lotteryID);

        if (winner) {
            // If member won the game, send back (withdrawn collateral * 2) to him
            require(collateral.transferFrom(msg.sender, address(this), SafeMath.mul(_betAmount, uint(2))));
            
            // Decrease lottery liquidity value
            lottery[_lotteryID].liquidity = SafeMath.sub(
                lottery[_lotteryID].liquidity,
                _betAmount
            );
        } else {
            // Increase lottery liquidity value
            lottery[_lotteryID].liquidity = SafeMath.add(
                lottery[_lotteryID].liquidity,
                _betAmount
            );
        }

        emit Play(msg.sender, _lotteryID, _betAmount, winner, block.timestamp);
    }
    
    // Add liquidity to existing lottery
    function addLiquidity(uint _lotteryID, uint _liquidityAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status != Status.Closed || checkLotteryDuration(_lotteryID), "Lottery has ended");
        require(_liquidityAmount > 0, "Invalid amount");

        uint memberID = getMemberID();

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        // Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        //Increase liquidity balance for member
        liquidityBalances[_lotteryID][memberID] = SafeMath.add(
            liquidityBalances[_lotteryID][memberID],
            _liquidityAmount
        );

        //Increase lottery liquidity value
        lottery[_lotteryID].liquidity = SafeMath.add(
            lottery[_lotteryID].liquidity,
            _liquidityAmount
        );

        // Since we added liquidity, set status Active in case lottery was paused because of no liquidity
        if(lottery[_lotteryID].status == Status.NoLiquidity) {
            lottery[_lotteryID].status = Status.Active;
        }

        emit Deposit(msg.sender, _lotteryID, _liquidityAmount, block.timestamp);
    }

    //TODO: 
    function redeem(uint _lotteryID) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");

        uint memberID = getMemberID();

        require(liquidityBalances[_lotteryID][memberID] > 0, "You didn't provide liquidity or already redeemed it");

        // Determine how much member invested % from total liquidity pool
        uint memberLiquidityPercent = SafeMath.mul(SafeMath.div(liquidityBalances[_lotteryID][memberID], lottery[_lotteryID].liquidity), uint(100));

        // Determine how much member can redeem
        uint redeemableLiquidity = SafeMath.mul(SafeMath.div(lottery[_lotteryID].liquidity, uint(100)), memberLiquidityPercent);

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        // Send collateral to member
        require(collateral.approve(msg.sender, redeemableLiquidity));
        require(collateral.transferFrom(address(this), msg.sender, redeemableLiquidity));

        // Set liquidity balance for member
        liquidityBalances[_lotteryID][memberID] = 0;

        // Decrease lottery liquidity value
        lottery[_lotteryID].liquidity = SafeMath.sub(
            lottery[_lotteryID].liquidity,
            SafeMath.mul(SafeMath.div(lottery[_lotteryID].liquidity, uint(100)),  memberLiquidityPercent)
        );

        emit Redeem(msg.sender, _lotteryID, redeemableLiquidity, block.timestamp);

        // Pause lottery in case there is no liquidity left
        if(lottery[_lotteryID].liquidity == 0) {
            lottery[_lotteryID].status = Status.NoLiquidity;
        }

        // Change status to Closed if lottery finalization time arrived
        checkLotteryDuration(_lotteryID);
    }

    function getMemberID() internal returns (uint) {
        if (member[msg.sender] == 0) {
            member[msg.sender] = currentMemberID;
            currentMemberID++;
        }
        return member[msg.sender];
    }

    //TODO: Different math formulas
    function determineGameResult(uint _lotteryID) internal pure returns (bool) {
        // lottery[_lotteryID].formula
        return false;
    }

    // Check if lottery finalization time arrived
    function checkLotteryDuration(uint _lotteryID) internal returns (bool) {
        if(lottery[_lotteryID].duration == 0){ return true;}
        if(SafeMath.add(
                lottery[_lotteryID].created,
                lottery[_lotteryID].duration
            ) < block.timestamp){ return true;}

        // Change status to Closed if lottery finalization time arrived
        lottery[_lotteryID].status = Status.Closed;
        return false;
    }

    // Edit allowed collateral tokens list
    // function setCollateral(
    //     address _collateral,
    //     bool _value
    // ) public onlyOwner {
    //     collateralList[_collateral] = _value;
    // }

    // View member liquidity balance
    // Returns initial liquidity, redeemable liquidity
    function viewLiquidity(
        uint _lotteryID,
        address _member
    ) public view returns (uint, uint) {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(member[_member] > 0, "Member doesn't exist");

        require(liquidityBalances[_lotteryID][member[_member]] > 0, "Member didn't provide liquidity or redeemed it");

        // Determine how much this member invested % from total liquidity pool
        uint memberLiquidityPercent = SafeMath.mul(SafeMath.div(liquidityBalances[_lotteryID][member[_member]], lottery[_lotteryID].liquidity), uint(100));

        // Determine how much this member can redeem
        uint redeemableLiquidity = SafeMath.mul(SafeMath.div(lottery[_lotteryID].liquidity, uint(100)), memberLiquidityPercent);

        return (liquidityBalances[_lotteryID][member[_member]], redeemableLiquidity);
    }
}