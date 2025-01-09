// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Stablecoin} from "../src/stablecoin.sol";

/**
 * @title Tests for Stablecoin contract
 * This contract tests all edge cases for the Stablecoin contract.
 */
contract TestStablecoin is Test {
    Stablecoin stablecoin;

    // Predefined variables for testing
    address user1 = address(1);
    address user2 = address(2);

    function setUp() public {
        // Deploy the Stablecoin contract
        stablecoin = new Stablecoin();
    }

    function testMint() public {
        uint256 amount = 100 ether;

        // Mint tokens to user1
        stablecoin.mint(user1, amount);

        // Check balance
        assertEq(stablecoin.balanceOf(user1), amount);
    }

    function testMintRevertsIfNotOwner() public {
        uint256 amount = 100 ether;
        stablecoin.mint(user1 , amount);
        // Change msg.sender to a non-owner address
        vm.prank(user2);

        // Expect revert due to access control
        vm.expectRevert("Ownable: caller is not the owner");
        stablecoin.mint(user1, amount);
        
    }
}
