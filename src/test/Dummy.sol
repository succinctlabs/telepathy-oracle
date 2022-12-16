// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IRequest {
    function requestView(
        bytes4 callbackSelector,
        address target,
        bytes4 selector,
        bytes memory data,
        uint256 gasLimit
    ) external returns (bytes memory);

    function requestStorage(
        address l1Address,
        uint256 storageSlot,
        uint256 blockNumber,
        bytes4 callbackSelector
    ) external;
}

contract DummyCallback {
    uint256 public sum;
    uint256 public externalStorageVal;

    function addToSum(uint256 num) public {
        sum += num;
    }

    function saveStorageVal(uint256 val) public {
        externalStorageVal = val;
    }

    function requestGetNumber(address requester, address target, bytes4 selector, uint256 gasLimit)
        public
        returns (bytes memory)
    {
        return
            IRequest(requester).requestView(this.addToSum.selector, target, selector, "", gasLimit);
    }

    function requestStorage(
        address requester,
        address l1Address,
        uint256 storageSlot,
        uint256 blockNumber
    ) public {
        IRequest(requester).requestStorage(
            l1Address, storageSlot, blockNumber, this.saveStorageVal.selector
        );
    }
}

contract DummyView {
    uint256 num = 1;

    function getNumber() public view returns (uint256) {
        return num;
    }
}
