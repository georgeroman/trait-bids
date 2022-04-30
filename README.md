# Trait Bids

Trait bids powered by [0x v4](https://github.com/0xProject/protocol) and [Trustus](https://github.com/ZeframLou/trustus).

There are two main ways of creating trait bids:

- Use a merkle tree. This implies having all the tokens that match a particular trait aggregated into a merkle root (this will be happenning fully off-chain) which is part of the buy order. Then, when filling the order, the taker has to provide a merkle proof showing that the token they are trying to fill with is part of the buy order's merkle root. In most cases, this method is stateless (no need to store anything on-chain), efficient (the exchange contract will only need to run a simple merkle proof verification) and trustless (no need to depend on any external sources when filling). This approach was pioneered by [Reservoir](https://github.com/reservoirprotocol) and is currently in active use powering projects such as [Levee](https://levee.bid).

- Use an oracle. A designated oracle would have to attest that the token being filled with matches any properties requested by the buy order. This method can be either stateless or stateful, depending on the oracle (signature-based vs transaction-based) and the underlying exchange contract implementation. However, this approach is trustful since it depends on the oracle being available and correctly attesting (it's possible to allow attestations from multiple oracles in order to avoid cases when filling is blocked due to a single oracle being unavailable). No mainstream projects use this approach as of now.

This project shows a basic integration of trait bids on 0x v4, using the signature-based oracle approach (via Trustus). Due to the exchange contract's limitations (not possible to verify a buy order directly against data provided by the taker) it uses a stateful approach (the oracle's attestation must be available on-chain before filling the order). However, with the usage of a router contract, we can have the attesation and the fill hapenning with a single on-chain transaction.

### Todo

- add support for ERC1155
- integrate merkle root oracle attestations (eg. have the oracle submit the merkle root of all tokens matching a particular property) so that a single attesation is required per property (this will require the taker submitting a merkle proof when filling though, as in the merkle tree approach)

### Usage

Make sure to patch a minor issue in `trustus` before running the tests (https://github.com/ZeframLou/trustus/issues/3).

```bash
# Install
forge install

# Build
forge build

# Test (should be run against a recent mainnet fork)
forge test --fork-url $MAINNET_RPC_URL
```
