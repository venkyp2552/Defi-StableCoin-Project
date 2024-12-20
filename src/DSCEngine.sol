// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
/**
 * @title DSCEngine
 * @author Venkaiah P
 * This System designed as minimal as possible, have the tokens maintain 1token = $1peg
 * This StableCoin has properties of 
 * -Exogenous Colletaral
 * -Dollar Pegged
 * -Algorithimically Stable
 * @Note Our DSC system is always "overcolletaralized",At any point of time, 
 * all collateral <= the $ backed value of DSC
 * It is Similar to DAI if DAIhad no goverence and no fees and was only backed by WETH & WBTC
 * 
 * @notice This contract is a core of DSC System.it handles all the logics for minting and reediming DSC
 * as well as depostiting and withdrawing collatoral. 
 * 
 * This Contract is VERY loosely based on the MarkerDAO DSS(DAI) system.
 */
pragma solidity ^0.8.18;


contract DSCEngine{
    /////////////////////// 
    /////// Errors ///////
    /////////////////////
    error DSCEngine__NeedMoreThanZer();

    /////////////////////// 
    /// State Variables ////
    /////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds;

    /////////////////////// 
    /////// Modifiers ////
    /////////////////////

    modifier moreThanZero(uint256 amount) {
        //Colletral Amount Should Be more than Zer
        if(amount == 0){
            revert DSCEngine__NeedMoreThanZer();
        }
        _;
    }

    modifier isAllowedToken(address collateralTokenAddr) {
        //we will not allow every assets (Every tokens address to mint the DSC except WETH,WBTC)
        _;
    }

    constructor(){}

    function depositeCollateralAndMindDsc() external{}

    function depositeCollateral(
        address tokenCollateralAddress,
        uint256 collateralAmount
    ) moreThanZero(collateralAmount) external{

    }

    function reedemCollateralForDsc() external{}

    function reedemCollateral() external{}
    
    function mintDsc() external {}

    function burnDsc()external {}

    function liquidate() external{}

    function getHelathFactor() external view {}

}
