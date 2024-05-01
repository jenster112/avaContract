// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITradingStorage {
    function totalOI() external view returns (uint256);
    function maxOpenInterest() external view returns (uint256);
}

contract OpenInterestChecker {
    address constant tradingStorageAddress = 0x8a311D7048c35985aa31C131B9A13e03a5f7422d;
    ITradingStorage tradingStorage = ITradingStorage(tradingStorageAddress);

    // This function checks if total open interest is greater than max open interest
    function checkOpenInterest() public view returns (uint256 totalOI, uint256 maxOpenInterest, bool openInterestTooHigh) {
        totalOI = tradingStorage.totalOI();
        maxOpenInterest = tradingStorage.maxOpenInterest();
        openInterestTooHigh = totalOI > maxOpenInterest;
        return (totalOI, maxOpenInterest, openInterestTooHigh);
    }
}