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
import {OracleLib} from "./libraries/OracleLib.sol";
contract DSCEngine is ReentrancyGuard {
    /// Errors ///
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressesMustBeInSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransactionFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HFNotImproved();

    //Types//

    using OracleLib for AggregatorV3Interface;

    //// State Variables ////
    uint256 private constant ADDITIONAL_FEED_PRECISION=1e10;
    uint256 private constant PRECISION=1e18;
    uint256 private constant LIQUIDATION_THRESHOLD=50;
    uint256 private constant LIQUIDATION_PRECISION=100;
    uint256 private constant MIN_HELATH_FACTOR=1e18;
    uint256 private constant LIQUIDATION_BONUS=10; // 105 bonus for liquidators

    mapping(address token => address priceFeed) private s_pricedFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; //User how much collateral Dsposited.
    mapping(address user=>uint256 amountDSCMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;
    
    //// Events ////
    event CollateralDeposited(address indexed depositer, address indexed tokenCollatealAddrs,uint256 indexed collateralAmount);
    event CollateralReddemed(address indexed reedemedFrom, address indexed depositTo,address indexed collateralAddres,uint256 Amount);

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
        // s_collateralDeposited[msg.sender][collateralTkenAddress]-=collateralAmount;
        // emit CollateralReddemed(msg.sender,collateralTkenAddress,collateralAmount);
        // bool success=IERC20(collateralTkenAddress).transfer(msg.sender,collateralAmount);
        // if(!success){
        //     revert DSCEngine__TransactionFailed();
        // }

        //After refracting
        _reedemCollateral(msg.sender,msg.sender,collateralTkenAddress,collateralAmount);
        _revertIfHelathFactorIsBroken(msg.sender);
    }

    function burnDSc(uint256 amount) public moreThanZero(amount){
        // s_DSCMinted[msg.sender]-=amount;
        // bool success=i_dsc.transferFrom(msg.sender,address(this),amount);
        // if(!success){
        //     revert DSCEngine__TransactionFailed();
        // }
        // i_dsc.burn(amount);

        //After Refractroitng
        _burnDSC(amount,msg.sender,msg.sender);
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

    //If we do start nearing undercollaterazation, we need someone to liquidate position (Refer Project Docu)
    //$100 ETH backed by $50 DSC 
    //After price in Dollar 
    //$20 ETH  back $50DSC <- DSC Isn't worthy.
    /**
     * @param collateral the ERC20 collateral address to liquidate from the user.
     * @param user The use who has broken the helath factor, their _HF should be below the MIN_HF_THRESOLD
     * @param debtToCover The amount of DSC you want to burn to improve the user HF
     * @notice you can partially liquidate the user.
     * @notice You will get liquidation bonus for taking user funds
     * @notice This function working assumes the protocal will be roughly 200% overcollateralized in order for this to work.
     * @notice A know bug would be if the protocal were 100% or less collateraliazed , then we wouldn't be able to incentivese the liquidators.
     *  Followa :CEI Checks Effects Interactions
     */
    function liquidate(address collateral,address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant{
        //1.Need to check HF of the user
        uint256 StartingUserHealthFactor=_healthFactor(user);
        if(StartingUserHealthFactor >= MIN_HELATH_FACTOR){
            revert DSCEngine__HealthFactorOk();
        }
        //1.we want to burn their DSC "debt"
        //2.And Taje their collateral
        //Bad User: Deposite:$140 ETH, backed:$100 DSC
        //Debt to Cover : $100 DSC
        //$100 of DSC == ?? ETH
        uint256 tokenAmountFromDebitCovered=getTokenAmountFromUsd(collateral,debtToCover);
        //Give them 10% bonus 
        //So we are giving the liquidator $110 of WETH for 100 DSC
        //We should implement a feature to liquidate in the event the protocal is insolvent
        //And Sweep extra amount in a treasury

        //lets we have got the calculation from above getToeknFunction 
        //// (10e18 * 1e18) / $2000e8 * 1e10 or $2000 * 1e18
        //=10,000,000,000,000,000,000 / 2000 * 1,000,000,000,000,000,000 = 0.005
        //0.05 * 0.1(bcz 10%)=0.005 this is bonus amount
        //0.05+0.005=0.055 totla amount he will get
        uint256 bonusCollateral=(tokenAmountFromDebitCovered*LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        uint256 totalCollateralToReedem=tokenAmountFromDebitCovered+bonusCollateral;
        _reedemCollateral(user,msg.sender,collateral,totalCollateralToReedem);
        _burnDSC(debtToCover,user,msg.sender);

        //Once we have done with we need to check HF 

        uint256 endingUserHF=_healthFactor(user);
        if(endingUserHF==StartingUserHealthFactor){
            revert DSCEngine__HFNotImproved();
        }

        //if there is no improvements in HF we should not affect the liquidator HF so we can return
        _revertIfHelathFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    //// Internal & Private Functinos ////

    /**
     * @dev Low-level internal function, do not call unless the function callling it is checking HF being broken
     */
    function _burnDSC(uint256 amountDSCToBurn,address onBehalfOf,address dscFrom) private{
        s_DSCMinted[onBehalfOf]-=amountDSCToBurn;
        bool success=i_dsc.transferFrom(dscFrom,address(this),amountDSCToBurn);
        if(!success){
            revert DSCEngine__TransactionFailed();
        }
        i_dsc.burn(amountDSCToBurn);
    }

    function _reedemCollateral(address from,address to,address collateralAddres,uint256 collateralAmount) private{
        s_collateralDeposited[msg.sender][collateralAddres]-=collateralAmount;
        emit CollateralReddemed(from,to,collateralAddres,collateralAmount);
        bool success=IERC20(collateralAddres).transfer(to,collateralAmount);
        if(!success){
            revert DSCEngine__TransactionFailed();
        }
    }
    

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

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_pricedFeed[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

     function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
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

    function getTokenAmountFromUsd(address tokenAddress,uint256 usdAmountInWei) public view returns(uint256){
        //1.Need to know Price of ETH
        //2.Price of DSC Token
        //3.usdAmountInWei / Price of ETH
        AggregatorV3Interface priceFeed=AggregatorV3Interface(s_pricedFeed[tokenAddress]);
        (,int256 price, , ,)=priceFeed.staleCheckLatestRoundData();
        // (10e18 * 1e18) / $2000e8 * 1e10 or $2000 * 1e18
        //=10,000,000,000,000,000,000 / 2000 * 1,000,000,000,000,000,000 = 0.005
        return (usdAmountInWei * PRECISION/uint256(price)*ADDITIONAL_FEED_PRECISION);

    }

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
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        //lets take price=$1000, amount 2ETH, 1000*10^10*2=20,000,000,000,000,000,000/10^18=20USD which means 2ETH value in USD is 20USD
        return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION; //
    }

    function getAccountsInformation(address user) external view returns(uint256 totalDSCMinted,uint256 collateralValueInUsd){
        (totalDSCMinted,collateralValueInUsd)=_getAccountInfroamtion(user);
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInfroamtion(user);
    }

    function getUsdsValue(
        address token,
        uint256 amount // in WEI
    )
        external
        view
        returns (uint256)
    {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountsCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokensAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_pricedFeed[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HELATH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_pricedFeed[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
