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

`Packages/NovaAuth` owns profile-3 bootstrap, the single persisted bearer, bounded renewal and
native URLCache. App consumers inject `NovaAuthFacade.shared`; never build a per-feature auth
provider. Bittensor completes auth admission before domain coalescing or negative availability
lookups, then authorizes again before the native request. `BittensorApiResponseCache` stores only
decoded stale presentation seeds and in-flight waiters, never successful HTTP freshness. Older
recommendation generations return `generationStale`, preserving a newer seed without refetch.
Endpoint admissions carry an immutable facade invalidation revision. The decoded cache advances
its revision floor monotonically and reconciles the latest revision before participation,
completion and peek. Delayed or duplicate notifications preserve current-revision state;
old admissions/completions remain fenced. Same-origin readiness does not invalidate the cache.
Auth origin/generation changes also clear derived max-APY, cost-basis and
validator-directory state. Their pending completions cannot restore a prior context's memo or
return a directory enriched after that context was invalidated. Host activation authorizes
later demand-driven bootstrap; catalogue requests carry no authentication intent.

Main-owner admission returns a usable bearer before issuance cooldown checks. Every actual
business send checks shared-origin protection before native cache/network access. Only business
429 and explicit 503 `attestation_unavailable` constrain that origin; ordinary business 5xx and
transport failures pass to domain retry handling. Success does not clear an active shared deadline.
Issuance Retry-After is memory-only; pending-probe cooldown persists. Failed authentication fails
the operation. A later independently created operation can retry after short auth backoff; proof
or policy denial preserves an existing binding rather than rotating its key.

Bittensor bootstrap `401 attestation_failed` maps to device-bound `attestationRejected` with
no user retry. `409 client_already_registered` maps to non-device-bound `bindingConflict`, also
without retry. `403 insufficient_scope` maps to generic `invalidRequest` without retry before
the generic 401/403 branch. Invalid challenge, 503 and transport errors remain retryable.

The max-APY walk propagates authentication-wide refusals and final token denial immediately,
without another outer retry or a cached nil/partial result. Local unsupported/configuration
failures also terminate it. Route/data gaps retain per-target skipping, and transient failures
retain bounded retries. No walk result is kept between requests, so nothing can mask
authentication recovery in the same context.

One origin/API-major bearer serves ordinary protected GET/HEAD and POST routes. Auth has no
business allowlist or flow/scope. Consumers own method/path/body validation and ordinary business retry policy. Bittensor uses `/v1/bittensor/...`.
The root-yield route and its client plumbing are removed, and alpha netuid 0 is rejected locally.

Only conclusive `invalid_token` permits one replay preserving method/path/query/body: same
expected HTTPS origin, 401 and the exact Bearer error header, plus a valid envelope for GET/POST.
HEAD uses status/header without a body. Ingress rejects before business execution; arbitrary
POST transport/5xx failures never replay. Native GET/HEAD caching follows server-owned public,
max-age and must-revalidate headers, without extending credential lifetime. No refresh token
exists; renewal obtains a fresh token challenge and App Attest assertion. See
[NovaAuth](../../../Packages/NovaAuth/README.md) and the
[client diagrams](../architecture/novaauth-client-diagrams.md).
