# Networking

Three kinds of traffic, three sets of tools. All of them are wrapped in operations
(see code/concurrency.md).

| Traffic                          | Tooling                                                    |
|----------------------------------|------------------------------------------------------------|
| Substrate JSON-RPC over WebSocket| `SubstrateSdk` + `ChainConnection` from `ConnectionPool`    |
| Plain HTTP (REST/GraphQL/JSON)   | `NetworkOperation` from `Operation_iOS`                     |
| EVM JSON-RPC                     | `web3swift` / `Web3Core` + `EvmWebSocketOperationFactory`   |

## Substrate JSON-RPC

Always get the connection from the chain registry — never construct an engine:

```swift
guard
    let connection = chainRegistry.getConnection(for: chainId),
    let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId)
else { throw ChainRegistryError.connectionUnavailable }
```

### Storage queries

Use `StorageRequestFactory` (from `SubstrateSdk`), constructed with `StorageKeyFactory` and an
`OperationManager`:

```swift
let requestFactory = StorageRequestFactory(
    remoteFactory: StorageKeyFactory(),
    operationManager: OperationManager(operationQueue: operationQueue)
)

let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> = requestFactory.queryItems(
    engine: connection,
    keyParams: { [accountId] },
    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
    storagePath: Staking.stakingLedger
)
```

- Storage paths are declared as `StorageCodingPath` constants in `Common/Substrate/Types/` — add new
  ones there, never inline `("Staking", "Ledger")` tuples.
- For prefix scans use the factory's `queryByPrefix` / paged variants rather than fetching keys and
  values in two hand-written steps.
- Decoding always needs a coder factory from the chain's own `RuntimeProvider`.

### Runtime calls (state calls)

`Common/Substrate/Operations/StateCall/` plus the API-specific folders (`XcmPaymentApi`,
`DryRun`, `BlockLimit`, `HydrationApi`, `Multisig`, `Identity`). Add a new runtime API as a factory
there, with an integration test in `novawalletIntegrationTests/StateCall/`.

### Subscriptions

On-chain subscriptions are owned by the remote subscription services
(`Common/Services/RemoteSubscription/`), not by modules. They are refcounted per key — see
architecture/data-flow.md.

`JSONRPCTimeout` and `ConnectionAutobalancing` handle timeouts and node failover; do not add
per-request retry loops on top.

## HTTP

`BaseFetchOperationFactory` (`Common/Network/BaseOperationFactory/`) is the base class for simple
JSON GET endpoints:

```swift
final class SomeOperationFactory: BaseFetchOperationFactory {
    func createFetchWrapper() -> CompoundOperationWrapper<SomeDTO> {
        let operation: BaseOperation<SomeDTO> = createFetchOperation(from: url)
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
```

For anything more complex, build the `BlockNetworkRequestFactory` +
`AnyNetworkResultFactory` pair directly and wrap them in a `NetworkOperation`.

Conventions:

- Use the typed HTTP constants from `Operation_iOS` — `HttpMethod`, `HttpContentType`,
  `HttpHeaderKey` — not string literals.
- Responses are `Decodable` DTOs decoded with `JSONDecoder`; **parse at the boundary** and hand
  domain models (not `[String: Any]`) to the rest of the code.
- All base URLs come from `ApplicationConfig` or `GlobalConfig` (see
  architecture/services-lifecycle.md). API keys come from `CIKeys.generated.swift`.

### Backends in use

| Directory                     | Backend                                                     |
|-------------------------------|-------------------------------------------------------------|
| `Network/Subquery/`           | Transaction history, rewards, multistaking aggregation       |
| `Network/Coingecko/`          | Fiat prices                                                  |
| `Network/Etherscan/`          | EVM transaction history                                      |
| `Network/Ethereum/`           | EVM RPC helpers                                              |
| `Network/DistributedStorage/` | IPFS-style content for NFTs/metadata                         |
| `Network/GovMetadataOperationFactory/` | Referendum metadata                                 |
| `Network/Files/`              | Remote JSON files (chain list, XCM config, dApp list)        |
| `Network/IPAddressProvider/`  | Region detection for on-ramp availability                    |

## EVM

`EvmWebSocketOperationFactory` and the `web3swift` types back
`Common/Services/ExtrinsicService/Evm/`. Gas estimation, nonce, and price handling live there — a
module should call `EvmTransactionService`, not the RPC layer.

## Error Handling

- JSON-RPC failures surface as `JSONRPCError`; `JSONRPCError+Presentable` maps them to user-facing
  copy. `JSONRPCError+Evm` adds EVM-specific decoding.
- Network errors are never swallowed: propagate through the wrapper and let the Interactor decide
  between a retry alert (`CommonRetryable`) and an inline error state.
- Do **not** implement reachability pre-checks. Attempt the request and handle the failure — the app
  has `Reachability` only for connection status UI (`NetworkAvailabilityLayer`).

## Hard Rules

1. **Connections come from `ChainRegistry`.** No ad-hoc `WebSocketEngine`/`HTTPEngine`.
2. **Decode with the chain's runtime coder factory.** Never assume a type layout.
3. **Storage paths and call factories are declared types**, not string tuples at the call site.
4. **URLs and keys are configuration**, never literals in a module.
5. **Parse at the boundary.** `Decodable` DTO in, domain model out.
6. **No custom retry/failover on top of the connection layer.**

## Related

- architecture/chain-registry.md — connections, runtime providers, sync modes
- code/concurrency.md — wrapping and executing these operations
- architecture/transactions.md — the extrinsic-specific network path

## Nova backend bearer authentication

`Packages/NovaAuth` owns profile-3 bootstrap, the single persisted bearer and bounded renewal; it
has no HTTP cache. App consumers inject `NovaAuthFacade.shared`; never build a per-feature auth
provider. Config is
fetched once per process, so `NovaAuthFacade` maps `infraUrl` to one memoised endpoint and nothing
observes config or context changes. Host
activation authorizes later demand-driven bootstrap; Bittensor requests use the default
user-driven intent.

Main-owner admission returns a usable bearer before issuance cooldown checks. Every actual
business send checks shared-origin protection before network access. Only business
429 and explicit 503 `attestation_unavailable` constrain that origin; ordinary business 5xx and
transport failures pass to domain retry handling. Success does not clear an active shared deadline.
Issuance Retry-After is memory-only; pending-probe cooldown persists. Failed authentication fails
the operation. A later independently created operation can retry after short auth backoff; proof
or policy denial preserves an existing binding rather than rotating its key. A refused registration
keeps the client ID and drops only its key. `NovaAuthRequest.intent` separates user-driven demands
(Bittensor, the default), which re-register at once, from `.background` ones (analytics), which wait
for a persisted 1 h / 6 h / 24 h refusal delay that resets on an app version or context change.

One origin/API-major bearer serves ordinary protected GET/HEAD and POST routes. Auth has no
business allowlist or flow/scope. Consumers own method/path/body validation and ordinary business retry policy. Bittensor uses `/v1/bittensor/...`.
The removed root-yield route returns unavailable/cache miss locally, its optional service returns
nil without networking, and alpha netuid 0 is rejected locally.

Only conclusive `invalid_token` permits one replay preserving method/path/query/body: same
expected HTTPS origin, 401 and the exact Bearer error header, plus a valid envelope for GET/POST.
HEAD uses status/header without a body. Ingress rejects before business execution; arbitrary
POST transport/5xx failures never replay. The NovaAuth session has no URL cache; any response
reuse belongs to the consumer and never extends credential lifetime. No refresh token
exists; renewal obtains a fresh token challenge and App Attest assertion. See
[NovaAuth](../../../Packages/NovaAuth/README.md) and the
[client diagrams](../architecture/novaauth-client-diagrams.md).
