// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Trustus} from "trustus/Trustus.sol";

import {IPropertyValidator} from "./interfaces/zeroex-v4/IPropertyValidator.sol";

contract TraitValidator is IPropertyValidator, Trustus {
    event PropertySet(bytes32 indexed request, uint256 deadline);

    // Maps properties (eg. `hash(token, tokenId, property)`) to their deadline.
    mapping(bytes32 => uint256) public propertyDeadline;

    constructor(address oracleAddress) {
        // We can potentially accept packets from several oracles in order
        // to avoid scenarios where a single oracle goes down (which could
        // result in invalidating all orders which rely on that particular
        // oracle's signature).
        isTrusted[oracleAddress] = true;
    }

    function setProperty(bytes32 request, TrustusPacket calldata packet)
        external
    {
        if (!_verifyPacket(request, packet)) {
            revert Trustus__InvalidPacket();
        }

        // The packet's `payload` field is unused since we don't actually need
        // to know the actual traits that are being checked on-chain. All that
        // we care about is that a token matches a property, regardless of the
        // actual contents of that property.

        // The deadline handles scenarios where an NFT's traits are updateable.
        // In cases like that, the oracle should use short-lived packets, while
        // in all the other cases the packets can/should be permanent (in order
        // to save as much gas as possible).
        propertyDeadline[request] = packet.deadline;

        emit PropertySet(request, packet.deadline);
    }

    function validateProperty(
        address tokenAddress,
        uint256 tokenId,
        bytes calldata propertyData
    ) external view {
        // We must check that the NFT being used to fill the buy order
        // matches the order's properties. For this to happen, someone
        // must have published the signed oracle

        require(
            propertyDeadline[
                keccak256(abi.encodePacked(tokenAddress, tokenId, propertyData))
            ] > block.timestamp,
            "Expired or inexistent property"
        );
    }

    function _computeDomainSeparator()
        internal
        view
        override
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("TraitValidator"),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}
