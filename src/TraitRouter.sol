// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {Trustus} from "trustus/Trustus.sol";

import {ERC721Order, Signature} from "./interfaces/zeroex-v4/Structs.sol";
import {TraitValidator} from "./TraitValidator.sol";

// The role of the router is to allow publishing the oracle's signed packet
// together with filling a buy order that depends on that packet within the
// same transaction. If a property is already published the fill can/should
// be triggered directly on the exchange thus avoiding the router.
contract TraitRouter {
    address public immutable zeroExV4 =
        0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    TraitValidator public traitValidator;

    constructor(address traitValidatorAddress) {
        traitValidator = TraitValidator(traitValidatorAddress);
    }

    receive() external payable {
        // For receiving ETH
    }

    function onERC721Received(
        address, // operator
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        (
            bytes32 request,
            Trustus.TrustusPacket memory packet,
            ERC721Order memory order,
            Signature memory signature,
            bool unwrapNativeToken
        ) = abi.decode(
                data,
                (bytes32, Trustus.TrustusPacket, ERC721Order, Signature, bool)
            );

        require(msg.sender == order.erc721Token, "Invalid sender");

        // Save the property.
        traitValidator.setProperty(request, packet);

        // Fill the order.
        IERC721(msg.sender).safeTransferFrom(
            address(this),
            zeroExV4,
            tokenId,
            abi.encode(order, signature, unwrapNativeToken)
        );

        // Since the router will be detected as the buy order's taker, we
        // need to send any incoming payments to the real taker.
        if (unwrapNativeToken) {
            (bool success, ) = payable(from).call{
                value: order.erc20TokenAmount
            }("");
            require(success, "Could not send payment");
        } else {
            IERC20(order.erc20Token).transfer(from, order.erc20TokenAmount);
        }

        return this.onERC721Received.selector;
    }
}
