// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    event Create(uint indexed lotteryID, uint _time);
    event Deposit(address indexed member, uint indexed amount, uint _time);
    event Redeem(address indexed member, uint indexed amount, uint _time);

    enum Status {Running, Pending, Paused, Closed}

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
        uint[] liquidityProviders;
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
        require(_duration >= 600 seconds && _duration < 365 days, "Invalid duration");
        require(_maxBetPercent >= 1 && _maxBetPercent <= 50, "Invalid max deposit percent");

        uint memberID = getMemberID();

        IERC20 collateral = IERC20(_collateral);

        //Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        //Set liquidity balance for current member
        liquidityBalances[currentLotteryID][memberID] = _liquidityAmount;

        uint[] storage _liquidityProviders;
        _liquidityProviders.push(memberID);

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
                collateral: _collateral,
                liquidityProviders: _liquidityProviders
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

    // play
    function play(uint _lotteryID, uint _betAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status == Status.Running, "Lottery is not running");
        require(_betAmount > 0, "Invalid bet amount");

        //calculate pool value (liquidity + award)
        //validate ticket amount is not greater than pool maxBetPercent

        //withdraw collateral

        //TODO: math formula play functions / different formulas

        //send back collateral in case of win

        //send collateral to pool in case of lose

        //adjust lottery award variable
    }
    
    function addLiquidity(uint _lotteryID, uint _liquidityAmount) external {
        require(lottery[_lotteryID].exist, "Lottery doesn't exist");
        require(lottery[_lotteryID].status == Status.Running, "Lottery is not running");
        require(_liquidityAmount > 0, "Invalid amount");

        IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        //Deposit collateral
        require(collateral.transferFrom(msg.sender, address(this), _liquidityAmount));

        //Increase member balance
        // balance[msg.sender] = SafeMath.add(
        //     balance[msg.sender],
        //     _liquidityAmount
        // );

        emit Deposit(msg.sender, _liquidityAmount, block.timestamp);
    }

    //TODO: finalize lottery

    // function redeem(uint _lotteryID) external {
    //     require(lottery[_lotteryID].exist, "Lottery doesn't exist");

        //Send collateral to user
        // IERC20 collateral = IERC20(lottery[_lotteryID].collateral);

        // require(collateral.approve(msg.sender, balance[msg.sender]));
        // require(collateral.transferFrom(address(this), msg.sender, balance[msg.sender]));

        // emit Redeem(msg.sender, balance[msg.sender], block.timestamp);

        // balance[msg.sender] = 0;
    // }

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

        liquidityBalances[_lotteryID][_member];

        // Determine how much this member invested % from total liquidity pool
        uint memberLiquidityPercent = SafeMath.Mul(SafeMath.Div(liquidityBalances[_lotteryID][_member], lottery[_lotteryID].liquidity), uint(100));
        
        // Determine how much this member can redeem
        uint totalLiquidityPoolSizeWithAward = SafeMath.Add(lottery[_lotteryID].liquidity, lottery[_lotteryID].award);

        uint redeemableLiquidity = SafeMath.Mul(SafeMath.Div(ltotalLiquidityPoolSizeWithAward, uint(100)), memberLiquidityPercent);

        return (liquidityBalances[_lotteryID][_member], redeemableLiquidity);
    }
}

//TODO: временная лотерея завершается через месяц. проверять во всех методах, не должна ли лотерея уже быть завершена, и менять ее статус на ожидающая завершения
// ожидающая завершения - можно редим пула

// бессрочная лотерея, где можно всегда снять депозит