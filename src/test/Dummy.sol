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
}

contract DummyCallback {
    uint256 public sum;

    function addToSum(uint256 num) public {
        sum += num;
    }

    function requestGetNumber(address requester, address target, bytes4 selector, uint256 gasLimit)
        public
        returns (bytes memory)
    {
        return
            IRequest(requester).requestView(this.addToSum.selector, target, selector, "", gasLimit);
    }
}

contract DummyView {
    uint256 num = 1;

    function getNumber() public view returns (uint256) {
        return num;
    }
}
