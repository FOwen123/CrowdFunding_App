// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test{
    FundMe fundMe;

    address USER = makeAddr("user"); // return a random address
    uint256 constant SEND_VALUE = 0.1 ether; // 100000000000000000 wei
    uint256 constant USER_BALANCE = 10 ether;

    function setUp() external{
        DeployFundMe deployFundme = new DeployFundMe();
        fundMe = deployFundme.run();
        vm.deal(USER, USER_BALANCE);
    }

    function testMinimumDollarIsFive() public view{
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }   

    function testOwnerIsDeployer() public view{
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersion() public view{
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWithoutEnoughETH() public{
        vm.expectRevert(); // We expect next line to revert
        fundMe.fund(); // Send 0 value
    }

    function testFundUpdatesFundedDataStructure() public{
        vm.prank(USER); // The next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public{
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunders(0);
        assertEq(funder, USER);
    }

    modifier funded(){
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {

        vm.expectRevert(); // We expect next line to revert
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded{
        // Test Thinking Structure
        // Arrange
        uint256 initialOwnerBalance = fundMe.getOwner().balance;
        uint256 initialFundMeBalance = address(fundMe).balance;

        // Act 
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(initialFundMeBalance + initialOwnerBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded{
        // Arrange
        uint160 numberOfFunders = 10; // because address are 160 bits
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i <= numberOfFunders; i++){
            // vm.prank new address
            // vm.deal new address
            // hoax is the combination of prank and deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 initialOwnerBalance = fundMe.getOwner().balance;
        uint256 initialFundMeBalance = address(fundMe).balance;

        // Act
        // The same as vm.prank(fundMe.getOwner());
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(fundMe.getOwner().balance, initialOwnerBalance + initialFundMeBalance);
    }
}