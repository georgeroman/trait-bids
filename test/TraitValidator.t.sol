// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "trustus/Trustus.sol";

import {IZeroExV4} from "../src/interfaces/zeroex-v4/IZeroExV4.sol";
import {ERC721Order, Property, Signature, SignatureType, TradeDirection} from "../src/interfaces/zeroex-v4/Structs.sol";
import {TraitRouter} from "../src/TraitRouter.sol";
import {TraitValidator} from "../src/TraitValidator.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
}

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "MOCK") {}

    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId);
    }
}

contract TraitValidatorTest is Test {
    uint256 public oraclePk = uint256(0x01);
    address public oracle = vm.addr(oraclePk);
    uint256 public makerPk = uint256(0x02);
    address public maker = vm.addr(makerPk);
    uint256 public takerPk = uint256(0x03);
    address public taker = vm.addr(takerPk);

    IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IZeroExV4 public zeroExV4 =
        IZeroExV4(0xDef1C0ded9bec7F1a1670819833240f027b25EfF);

    MockERC721 public token;
    TraitValidator public traitValidator;
    TraitRouter public traitRouter;

    function setUp() public {
        token = new MockERC721();
        traitValidator = new TraitValidator(oracle);
        traitRouter = new TraitRouter(address(traitValidator));
    }

    function testFillingTraitBid() public {
        uint256 tokenId = 999;
        uint256 price = 1 ether;

        // Mint NFT to taker
        vm.prank(taker);
        token.mint(tokenId);

        // Create the order.
        ERC721Order memory order;
        order.direction = TradeDirection.BUY_NFT;
        order.maker = maker;
        // order.taker = address(0x00);
        order.expiry = block.timestamp + 1 days;
        // order.nonce = 0;
        order.erc20Token = address(weth);
        order.erc20TokenAmount = price;
        // order.fees = new Fee[](0);
        order.erc721Token = address(token);
        order.erc721TokenId = 0;
        order.erc721TokenProperties = new Property[](1);
        order.erc721TokenProperties[0].propertyValidator = traitValidator;
        order.erc721TokenProperties[0].propertyData = abi.encode(
            "trait_name",
            "trait_value"
        );

        // Sign the order.
        bytes32 orderHash = zeroExV4.getERC721OrderHash(order);
        Signature memory signature;
        signature.signatureType = SignatureType.EIP712;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(makerPk, orderHash);
            signature.v = v;
            signature.r = r;
            signature.s = s;
        }

        // Mint WETH to maker.
        deal(address(weth), maker, price);

        // Give WETH approval from exchange.
        vm.prank(maker);
        weth.approve(address(zeroExV4), price);

        // Create and sign Trustus packet.
        Trustus.TrustusPacket memory packet;
        packet.request = keccak256(
            abi.encodePacked(
                address(token),
                tokenId,
                order.erc721TokenProperties[0].propertyData
            )
        );
        packet.deadline = block.timestamp + 1 days;
        packet.payload = "";
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                oraclePk,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        traitValidator.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "VerifyPacket(bytes32 request,uint256 deadline,bytes payload)"
                                ),
                                packet.request,
                                packet.deadline,
                                keccak256(packet.payload)
                            )
                        )
                    )
                )
            );
            packet.v = v;
            packet.r = r;
            packet.s = s;
        }

        // Execute the order.
        vm.prank(taker);
        token.safeTransferFrom(
            taker,
            address(traitRouter),
            tokenId,
            abi.encode(packet.request, packet, order, signature, false)
        );

        assert(token.ownerOf(tokenId) == maker);
        assert(weth.balanceOf(maker) == 0);
        assert(weth.balanceOf(taker) == price);
    }
}
