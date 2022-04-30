// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// https://github.com/0xProject/protocol/blob/ba719a96312a8ea3bfe1db2990ed72e0e0fd18c1/contracts/zero-ex/contracts/src/vendor/IPropertyValidator.sol

interface IPropertyValidator {
    function validateProperty(
        address tokenAddress,
        uint256 tokenId,
        bytes calldata propertyData
    ) external view;
}
