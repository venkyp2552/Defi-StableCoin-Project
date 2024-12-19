// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test,console} from "lib/forge-std/src/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test{
    DecentralizedStableCoin dsc;

    function setUp() public {
        dsc =new DecentralizedStableCoin();
    }

    function testMustMinMoreThanZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(this),0);
    }

    function testMintNotAllowForZeroAddress() public{
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(0),1);
    }

    function testMustBurnMoreThanZero() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this),100);
        vm.expectRevert();
        dsc.burn(101);
        vm.stopPrank();
    }

    function testMustBurnLessThanZero() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this),100);
        vm.expectRevert();
        dsc.burn(0);
        vm.stopPrank();
    }
}