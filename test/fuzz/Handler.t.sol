// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test{
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 MAX_AMOUNT_SET=type(uint96).max;
    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;
    constructor(DSCEngine _dsce,DecentralizedStableCoin _dsc){
        dsce=_dsce;
        dsc=_dsc;

        address[] memory collateralTokens=dsce.getCollateralTokens();
        weth=ERC20Mock(collateralTokens[0]);
        wbtc=ERC20Mock(collateralTokens[1]);
    }
    //reedme collateral 
    
    function depositeCollateral(uint256 collateralSeed,uint256 collateralAmount) public{
        ERC20Mock collateral=_getCollateralFromSeed(collateralSeed); 
        //we are going to bound this value from 0 to anything to (particualalr value to another value)
        collateralAmount=bound(collateralAmount,1,MAX_AMOUNT_SET);
        
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender,collateralAmount);
        collateral.approve(address(dsce),collateralAmount);
        dsce.depositeCollateral(address(collateral),collateralAmount);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function mintDSC(uint256 amount,uint256 addressSender) public{
        if(usersWithCollateralDeposited.length==0){
            return;
        }
        address sender=usersWithCollateralDeposited[addressSender % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted,uint256 collateralValueInUsd)=dsce.getAccountInformation(sender);
        int256 maxDscToMint=(int256(collateralValueInUsd)/2)-int256(totalDscMinted);
        if(maxDscToMint<0){
            return;
        }
        amount=bound(amount,0,uint256(maxDscToMint));
        if(amount==0){
            return;
        }
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        timesMintIsCalled++;
        vm.stopPrank();

    }

    function reedemCollateral(uint256 colletralSeed,uint256 collateralAmount) public {
        ERC20Mock collateral=_getCollateralFromSeed(colletralSeed);
        //They can reedem only how much they have in their account
        uint256 maxColleteReedem=dsce.getCollateralBalanceOfUser(address(collateral),msg.sender);
        collateralAmount=bound(collateralAmount,0,maxColleteReedem);
        //here if they doesnt have any amount then also we should not call reedem functionright
        if(collateralAmount==0){
            return;
        }
        dsce.reedemCollateral(address(collateral),collateralAmount);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed % 2 ==0){
            return weth;
        }
        return wbtc;
    }
}