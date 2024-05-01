// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/OpenInterestCheck.sol";

contract OpenInterestCheckerTest is Test {
    OpenInterestChecker public checker;

    function setUp() public {
        // Initialize OpenInterestChecker with the address of the live external contract
        checker = new OpenInterestChecker();
    }

    function testCheckOpenInterestAgainstFork() public {
        // Since the external contract's state can vary, you might not have control over the exact values of totalOI and maxOpenInterest.
        // This test demonstrates how you might call the checkOpenInterest function and log the results for inspection.
        (uint256 totalOI, uint256 maxOpenInterest, bool openInterestTooHigh) = checker.checkOpenInterest();

        // Log the results for inspection
        emit log_named_uint("Total Open Interest", totalOI);
        emit log_named_uint("Max Open Interest", maxOpenInterest);
        emit log_named_string("Is Open Interest Too High?", openInterestTooHigh ? "true" : "false");

        // You can add assertions here if you know the expected values or relations between them.
        // For example, to check if the function correctly identifies when open interest is too high:
        assertTrue(openInterestTooHigh == (totalOI > maxOpenInterest));
    }
}
