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

