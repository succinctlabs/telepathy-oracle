// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

contract DummyCallback {
    uint256 public sum;
    uint256 public externalStorageVal;

    function addToSum(uint256 num) public {
        sum += num;
    }

    function saveStorageVal(uint256 val) public {
        externalStorageVal = val;
    }
}

contract DummyView {
    uint256 public num = 1;

    function getNumber() public view returns (uint256) {
        return num;
    }
}
