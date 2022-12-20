# telepathy-oracle

Request results from view functions and storage slots on Ethereum via Telepathy.

### - requestView

Create a request in the Requester contract. An event is emitted with the target contract and function selector to call on Ethereum. The fulfiller contract performs the call and forwards the result to the Succinct Telepathy relayer. On `receiveSuccinct` the saved callback is called with the return data from the requested view.

### - requestStorage

Create a request in the Requester contract. The requested Ethereum address, storage slot and callback are emitted in an event. Anyone can fulfill the request by providing a proof of the storage slot and the value. Once verified the callback is called with the retrieved value

### - receiveStorageDirect

`requestStorage` without the request. Simply provide a value from an Ethereum contract along with the appropriate proofs and a contract and function selector you want the value forwarded to.

## ENS Example

There is an example of using the `requestView` capability in the `ENSReceiver` contract. `requestENS` requests the owner of an ENS node (hashed `.eth` name) and provides a callback to receive the owner.

This example requires the `ENSFulfiller` contract to obtain the resolver and owner of an ens name in a single view call.
