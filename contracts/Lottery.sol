// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    event Create(uint indexed lotteryID, uint _time);
    event Deposit(address indexed member, uint indexed amount, uint _time);
    event Redeem(address indexed member, uint indexed amount, uint _time);

    enum Status {Running, Paused, Closed}

    // Member ID by wallet
    mapping(address => uint) public member;

    // Each member's liquidity balance per lottery
    mapping(uint => mapping(uint => uint)) public liquidityBalances;

    mapping(address => bool) public collateralList;

    struct LotteryStruct {
        bool exist;
        uint lotteryID;
        uint liquidity;
        int award;
        uint maxBetPercent;
        address collateral;
        uint created;
        uint duration;
        Status status;
    }

    mapping(uint => LotteryStruct) public lottery;

    uint internal currentLotteryID = 1;
    uint internal currentMemberID = 1;

    constructor() {
        
    }
    
    function create(address _collateral, uint _liquidityAmount, uint _maxBetPercent, uint _duration) external {
        require(_liquidityAmount > 0, "Invalid liquidity amount");
        require(collateralList[_collateral] != false, "Invalid collateral");
        require(_duration == 0 || (_duration >= 600 seconds && _duration < 365 days), "Invalid duration");
        require(_maxBetPercent >= 1 && _maxBetPercent <= 50, "Invalid max bet percent");

        uint memberID = getMemberID();

        IERC20 collateral = IERC20(_collateral);

        //Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        //Set liquidity balance for current member
        liquidityBalances[currentLotteryID][memberID] = _liquidityAmount;

        LotteryStruct memory lotteryStruct =
            LotteryStruct({
                exist: true,
                // status: Status.Pending,
                lotteryID: currentLotteryID,
                liquidity: _liquidityAmount,
                award: 0,
                maxBetPercent: _maxBetPercent,
                created: block.timestamp,
                duration: _duration,
                collateral: _collateral
            });

        lottery[currentLotteryID] = lotteryStruct;

        emit Create(currentLotteryID, block.timestamp);

        currentLotteryID++;
    }

    function getMemberID() internal returns (uint) {
        if (member[msg.sender] == 0) {
            member[msg.sender] = currentMemberID;
            currentMemberID++;
        }

        return member[msg.sender];
    }

    //TODO: math formula play functions / different formulas
    function determineGameResult(uint _lotteryID) internal returns (bool) {
        // lottery[_lotteryID].formula
        return false;
    }

    //check if the lottery finalization time and change its status to closed
    function checkLotteryTimeNotEnd(uint _lotteryID) internal returns (bool) {
        if(lottery[_lotteryID].duration == 0){ return true;}
        if(SafeMath.add(
                lottery[_lotteryID].created,
                lottery[_lotteryID].duration
            ) < block.timestamp){ return true;}

        lottery[_lotteryID].status = Status.Closed;
        return false;
    }

    // play
    function play(uint _lotteryID, uint _betAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status == Status.Running, "Lottery is not running");
        require(_betAmount > 0, "Invalid bet amount");
        require(checkLotteryTimeNotEnd(_lotteryID), "Lottery is ended");

        // Determine total pool value (liquidity + award)
        uint totalLiquidityPoolSizeWithAward = SafeMath.Add(lottery[_lotteryID].liquidity, lottery[_lotteryID].award);

        require(SafeMath.mul(SafeMath.div(_betAmount, totalLiquidityPoolSizeWithAward), uint(100)) <= maxBetPercent, "Bet amount % in relation to pool size is greater than pool maxBetPercent");

        uint memberID = getMemberID();

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        //withdraw collateral from member in order to play a game
        require(collateral.transferFrom(msg.sender, address(this), _betAmount));

        bool gameResult = determineGameResult(_lotteryID);

        if (gameResult) {
            //send back collateral in case of win
            //transfer back withdrawn x2
            require(collateral.transferFrom(msg.sender, address(this), SafeMath.mul(_betAmount, uint(2))));
            //award minus
            lottery[_lotteryID].award = SafeMath.sub(lottery[_lotteryID].award, _betAmount);
        } else {
            //adjust collateral to pool in case of lose
            //award plus
            lottery[_lotteryID].award = SafeMath.add(lottery[_lotteryID].award, _betAmount);
        }

        //event _lotteryID memberID _betAmount gameResult
    }
    
    function addLiquidity(uint _lotteryID, uint _liquidityAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status == Status.Running, "Lottery is not running");
        require(_liquidityAmount > 0, "Invalid amount");
        require(checkLotteryTimeNotEnd(_lotteryID), "Lottery is ended");

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        //Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        //Set liquidity balance for current member
        liquidityBalances[_lotteryID][memberID] = _liquidityAmount;

        //Increase lottery liquidity value
        lottery[_lotteryID].liquidity = SafeMath.add(
            lottery[_lotteryID].liquidity,
            _liquidityAmount
        );

        //TODO: member is a new liquidity provider event

        emit Deposit(msg.sender, _liquidityAmount, block.timestamp);
    }

    //TODO: 
    function redeem(uint _lotteryID) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");

        uint memberID = getMemberID();

        require(liquidityBalances[_lotteryID][memberID] > 0, "Member didn't provide liquidity or redeemed it");

        // Determine total pool value (liquidity + award)
        uint totalLiquidityPoolSizeWithAward = SafeMath.Add(lottery[_lotteryID].liquidity, lottery[_lotteryID].award);

        // Determine how much this member invested % from total liquidity pool
        uint memberLiquidityPercent = SafeMath.Mul(SafeMath.Div(liquidityBalances[_lotteryID][memberID], lottery[_lotteryID].liquidity), uint(100));

        // Determine how much this member can redeem
        uint redeemableLiquidity = SafeMath.Mul(SafeMath.Div(ltotalLiquidityPoolSizeWithAward, uint(100)), memberLiquidityPercent);

        // Send collateral to user
        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        require(collateral.approve(msg.sender, redeemableLiquidity));
        require(collateral.transferFrom(address(this), msg.sender, redeemableLiquidity));

        //Set liquidity balance for current member
        liquidityBalances[_lotteryID][memberID] = uint(0);

        //Decrease lottery liquidity value
        lottery[_lotteryID].liquidity = SafeMath.sub(
            lottery[_lotteryID].liquidity,
            SafeMath.Mul(SafeMath.Div(lottery[_lotteryID].liquidity, uint(100)) *  memberLiquidityPercent)
        );
        //Decrease lottery award value
        lottery[_lotteryID].award = SafeMath.sub(
            lottery[_lotteryID].award,
            SafeMath.Mul(SafeMath.Div(lottery[_lotteryID].award, uint(100)) *  memberLiquidityPercent)
        );

        emit Redeem(msg.sender, redeemableLiquidity, block.timestamp);

        //pause lottery in case there is no liquidity left
        if(SafeMath.add(lottery[_lotteryID].liquidity, lottery[_lotteryID].award) == 0) {
            lottery[_lotteryID].status = Status.Paused;
        }

        checkLotteryTimeNotEnd(_lotteryID);
    }

    function setCollateral(
        address _collateral,
        bool _value
    ) public onlyOwner {
        collateralList[_collateral] = _value;
    }

    // View member liquidity balance
    // Returns initial liquidity, redeemable liquidity
    function viewLiquidity(
        uint _lotteryID,
        address _member
    ) public view returns (uint, uint) {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(member[_member] > 0, "Member doesn't exist");
        require(liquidityBalances[_lotteryID][_member] > 0, "Member didn't provide liquidity or redeemed it");

        // Determine total pool value (liquidity + award)
        uint totalLiquidityPoolSizeWithAward = SafeMath.Add(lottery[_lotteryID].liquidity, lottery[_lotteryID].award);

        // Determine how much this member invested % from total liquidity pool
        uint memberLiquidityPercent = SafeMath.Mul(SafeMath.Div(liquidityBalances[_lotteryID][_member], lottery[_lotteryID].liquidity), uint(100));

        // Determine how much this member can redeem
        uint redeemableLiquidity = SafeMath.Mul(SafeMath.Div(ltotalLiquidityPoolSizeWithAward, uint(100)), memberLiquidityPercent);

        return (liquidityBalances[_lotteryID][_member], redeemableLiquidity);
    }
}

//todo: rename award to gameresults (poolAdjustment)