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
 * It is Similar to DAI if DAIhad no goverence and no fees and was only backed by WETH & WBTC
 * @notice This contract is a core of DSC System.it handles all the logics for minting and reediming DSC
 * as well as depostiting and withdrawing collatoral.
 * This Contract is VERY loosely based on the MarkerDAO DSS(DAI) system.
 */
pragma solidity ^0.8.18;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    /// Errors ///
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressesMustBeInSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransactionFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    //// State Variables ////
    uint256 private constant ADDITIONAL_FEED_PRECISION=1e10;
    uint256 private constant PRECISION=1e18;
    uint256 private constant LIQUIDATION_THRESHOLD=50;
    uint256 private constant LIQUIDATION_PRECISION=100;
    uint256 private constant MIN_HELATH_FACTOR=1;

    mapping(address token => address priceFeed) private s_pricedFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; //User how much collateral Dsposited.
    mapping(address user=>uint256 amountDSCMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;
    
    //// Events ////
    event CollateralDeposited(address indexed depositer, address indexed tokenCollatealAddrs,uint256 indexed collateralAmount);
    event CollateralReddemed(address indexed depositer, address indexed tokenCollatealAddrs,uint256 indexed Amount);

    //// Modifiers ////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isTokenAllowed(address token) {
        if (s_pricedFeed[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //// Funcions ////

    constructor(address[] memory tokenAddress, address[] memory priceFeedAddresses, address dscAddress) {
        //USD Backed Price Feed we are using
        if (tokenAddress.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressesMustBeInSameLength();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_pricedFeed[tokenAddress[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositeCollateralAndMintDsc(address tokenCollateralAddress, uint256 collateralAmount,uint256 amountDSCtoMint) external {
        depositeCollateral(tokenCollateralAddress,collateralAmount);
        mintDsc(amountDSCtoMint);
    }

    function depositeCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        public
        moreThanZero(collateralAmount)
        isTokenAllowed(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress,collateralAmount);
        //every token have contract address nothing but this one only tokenCollateralAddress
        bool success=IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),collateralAmount);
        if(!success){
            revert DSCEngine__TransactionFailed();
        }
    }

    function reedemCollateralForDsc(address collateralTkenAddress,uint256 collateralAmount,uint256 amountDscToBurn) external {
        reedemCollateral(collateralTkenAddress,collateralAmount);
        burnDSc(amountDscToBurn);
        //reedemCollateral Already checks HF
    }

    //1.they must have HF more than 1 after collateral pulled
    //2.what kind of collateral they want to withdraw we need crosscheck wich tokenaddress they want 
    function reedemCollateral(address collateralTkenAddress,uint256 collateralAmount) public moreThanZero(collateralAmount) nonReentrant{ 
        s_collateralDeposited[msg.sender][collateralTkenAddress]-=collateralAmount;
        emit CollateralReddemed(msg.sender,collateralTkenAddress,collateralAmount);
        bool success=IERC20(collateralTkenAddress).transfer(msg.sender,collateralAmount);
        if(!success){
            revert DSCEngine__TransactionFailed();
        }
        _revertIfHelathFactorIsBroken(msg.sender);
    }

    function burnDSc(uint256 amount) public moreThanZero(amount){
        s_DSCMinted[msg.sender]-=amount;
        bool success=i_dsc.transferFrom(msg.sender,address(this),amount);
        if(!success){
            revert DSCEngine__TransactionFailed();
        }
        i_dsc.burn(amount);
        _revertIfHelathFactorIsBroken(msg.sender);
    }
    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param amountDSCToMint The amount of DSC to mint
     * @notice they must have more collateral vlaue than the minimum threshold
     */
    function mintDsc(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant{
        s_DSCMinted[msg.sender]+=amountDSCToMint;
        //1.if they mint too much more than their collateral value we should revert them back
        _revertIfHelathFactorIsBroken(msg.sender);
        bool minted=i_dsc.mint(msg.sender,amountDSCToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function liquidate() external {}

    function getHealthFactor() external view {}

    //// Internal & Private Functinos ////

    /**
     * 
     * @param user Returns how  close to user for liquidation processs
     * if the user gos below 1,then they can get liquidate HF treosuld is here 1
     */
    function _healthFactor(address user) private view returns(uint256){
        //1.total DSC Minted
        //2.totla Collateral Value (This value nust be graten than the total Minted DSC);
        (uint256 totalMinted, uint256 CollateralValueInUSD)=_getAccountInfroamtion(user);
        uint256 collateralAdjustForThreshold=(CollateralValueInUSD * LIQUIDATION_THRESHOLD)/LIQUIDATION_PRECISION;
        return (collateralAdjustForThreshold*PRECISION)/totalMinted;
        // u have $1000 ETH and u minted 100 DSC
        //1000*50=50000
        //50000/100=500
        //500/100=5 > 1
    }

    function _getAccountInfroamtion(address user) private view returns(uint256 totalDSCMinted,uint256 CollateralValueInUSD){
        totalDSCMinted=s_DSCMinted[user];
        CollateralValueInUSD=getAccountCollateralValue(user);
    }

        //1.Check the HF(do tey have enough collateral?)
        //2.Revert if they dont have good HF
    function _revertIfHelathFactorIsBroken(address user) internal view {
        uint256 userHealthFactor=_healthFactor(user);
        if(userHealthFactor < MIN_HELATH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }

    }

    /// Publilc & External View Functions ///

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUSD){
        // loop through each collateral token, get the amount they have deposited
        //map it to the price to get the USD Value
        for(uint256 i=0;i<s_collateralTokens.length;i++){
            address token=s_collateralTokens[i];
            uint256 amount=s_collateralDeposited[user][token];
            totalCollateralValueInUSD+=getUsdValue(token,amount);
        }
        return totalCollateralValueInUSD;
    } 

    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed=AggregatorV3Interface(s_pricedFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //lets take price=$1000, amount 2ETH, 1000*10^10*2=20,000,000,000,000,000,000/10^18=20USD which means 2ETH value in USD is 20USD
        return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION; //
    }
}
