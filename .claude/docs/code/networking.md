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

### Config mirror

Files of the nova-utils `master` branch are read from the nova-infra mirror
(`ApplicationConfig.configMirrorBaseURL`) first and from GitHub when the mirror attempt fails.
There is one hook for that, below every caller: `ConfigMirrorURLProtocol`, a `URLProtocol` that
handles a GET request when `ConfigMirrorURLResolver` maps its URL to the mirror. The caller keeps
requesting the GitHub URL and gets a response for that URL, so caches and files keyed by URL
(CoreData JSON providers, the Kingfisher image cache, stored XCM and types files) need no change.
Other repositories and branches are not mirrored and their requests are not touched.

The behaviour below is one policy shared with Android. Change it on both platforms or on neither.

`RootPresenterFactory.registerConfigMirror()` assembles the dependencies and is called once, first
thing in `createPresenter`. It covers `URLSession.shared` (what `NetworkOperation` uses, through
`ConfigMirrorURLProtocol.register(dependencies:)`) and the session of
`KingfisherManager.shared.downloader` (through `ImageDownloader.addProtocolClass`). **A nova-utils
file or image is mirrored only when it is requested through one of these two.** A session of your
own or another image downloader bypasses the mirror until the protocol class is added to its
configuration. The protocol handles nothing until it is registered; tests register their own
dependencies and call `ConfigMirrorURLProtocol.unregister()` afterwards.

- **Mapping.** Only `https://raw.githubusercontent.com/novasamatech/nova-utils/master/<path>` and
  `.../refs/heads/master/<path>` (`ApplicationConfig.configMirrorSources`) become
  `<mirror>/<path>`. The scheme and the host are compared exactly, a URL with a port or
  credentials is not mapped, the query and the fragment are dropped. A path with a dot segment
  (`.` or `..`, plain or percent-encoded) is not mapped and goes to GitHub untouched. **Build a
  nova-utils URL with `URL.appendingPathComponent`, never with `NSString` path helpers:** they
  collapse `https://` into `https:/`, such a URL has no host and is not mirrored.
- **Mirror attempt.** The whole attempt (connecting, headers, the full body) has one deadline:
  `ConfigMirrorConstants.attemptDeadline` (10 s) and never more than half of the request's own
  timeout. When it expires the attempt is cancelled and the original URL is read. The body of the
  mirror is always collected in full and checked before the caller gets any of it; there is no
  streaming from the mirror, so a failure at any point of the attempt can still fall back. For the
  caller's own (idle) timeout the mirror attempt is silence, which is why the deadline takes no
  more than half of it. The answer of the original URL is passed on as it arrives.
- **Accepted answer** (`ConfigMirrorAnswerValidator`). Status 200, an `X-Config-Commit` header, a
  non-empty body and, for a `.json` path, a body that parses as JSON. Anything else falls back for
  that request. The body is checked because callers such as `DataOperationFactory` decode after
  the request is over, when it is too late to fall back. A redirect from the mirror is not
  followed and counts as an unusable answer. `Content-Type` is not compared (the contract tells
  not to depend on it). The header is only required to be present: the mirror puts it on every
  200, so its absence tells a page of a network on the way (a captive portal, a proxy) from the
  mirror, also for an image. Its value is not read. This check is iOS-only at the moment: the
  shared policy lists only the status and the body.
- **Pause.** After a failure that is about the mirror as a whole — a network or TLS error,
  a timeout, the deadline, a status of 500 and above or 429 — `ConfigMirrorAvailability` makes
  requests skip the mirror: for 60 s first, twice as long after each failed probe, up to 30 min
  (`ConfigMirrorConstants`). A 404 and other 4xx, an unusable body, a redirect, a request cancelled
  by its caller and errors of the device's own connectivity (no internet, cellular data or roaming
  off, a call in progress) don't start it. When the pause ends exactly one request probes the
  mirror and the others keep reading GitHub until it reports: an answer over the network with any
  status that is not a pause trigger brings the mirror back for everyone and resets the length to
  60 s, a failure starts the next pause. A probe that learns nothing (cancelled, answered by the
  HTTP cache, the device is offline) gives its slot to the next request. While a pause is on, the
  results of the attempts that started before it are ignored. The state is in memory only: a
  launch starts with the mirror in use, so a cold start against a dead mirror costs one deadline.
  What counts as which is one exhaustive switch, `ConfigMirrorFailure.verdict`.
- **HTTP cache.** The protocol performs its requests through `ConfigMirrorLoader`, a session of
  its own that uses `URLCache.shared`. The mirror answer is cached under the mirror URL and the
  GitHub one under the GitHub URL, by their own headers and the caller's cache policy. A mirror
  answer that the validator rejects is not stored. Nothing is stored for a request whose cache
  policy ignores the local cache, such as the image downloader's: that caller keeps the answer
  itself. The answer handed to the caller is not stored a second time. The lifetime the mirror
  sets in `Cache-Control` is followed as it is (see Trust).
- **Logging.** Every fallback is logged at `warning` with the mirror path and the failure, and so
  is the start of a pause with its length. A mirror that keeps failing is otherwise invisible,
  because the app goes on working from GitHub. `GlobalConfigProvider.shared` logs an `error` when
  the host of `infraUrl` in the loaded global config differs from the mirror host
  (`ConfigMirrorHostChecker`): the mirror address is a compile-time constant, because the global
  config is itself read through the mirror.
- **Trust.** The mirror is trusted the way GitHub is. Its answer is not checked for integrity or
  freshness: no signature, no comparison with GitHub, no bound on the age of the copy or on the
  cache lifetime it asks for, and files read separately may come from different commits. This is
  an accepted decision, not an omission.
- **Time.** Pauses are measured with `MonotonicClock` (`Common/Helpers/`), which ignores changes
  of the device clock and keeps counting while the device sleeps. Use it for any interval that
  must not follow the wall clock.

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
provider. `BittensorApiResponseCache` is the app-owned max-age store: a fresh decoded body
short-circuits before admission, an expired one stays only as a stale display seed, `no-store`
bodies are never kept, account `operations/search` pages (sent `private`) are kept like any other
max-age body, and own trades drop those pages (a page fetched before the drop is not kept). On a miss Bittensor completes auth admission, then authorizes again
before the request. There is no request coalescing, negative availability TTL or client TTL.
Older recommendation generations return `generationStale`, preserving a newer seed without refetch.
Endpoint admissions carry the auth scope (origin + generation); the store keeps seeds per scope
and drops them all, including the cost-basis pages, when a different scope is admitted. Config is
fetched once per process, so `NovaAuthFacade` maps `infraUrl` to one memoised endpoint and nothing
observes config or context changes. Chain data is never cached client-side. Host
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

Bittensor maps bootstrap `401 attestation_failed`, `403 app_not_allowed` and
`403 binding_not_allowed` to `deviceBound` with no user retry. `409 client_already_registered` and
`403 insufficient_scope` map to non-device-bound `rejected`, also without retry. Invalid challenge,
503 and transport errors remain retryable.

The dashboard max APY is one burst: `GET /recommendations` joined with the alpha yields of each
recommended netuid and the root d30, with no spacing, retries or memo. A netuid whose yields fail
is skipped; the burst fails with the first error only when no rate is left. No result is kept
between requests, so nothing can mask authentication recovery in the same context.
Alpha yield rows carry `rateReliability` (ADR-0045 of nova-infrastructure); an `UNRELIABLE` rate
is treated as absent everywhere (not shown, not ranked, excluded from the max APY), an absent
verdict is trusted and logged, and any other value fails the page as a contract violation.

One origin/API-major bearer serves ordinary protected GET/HEAD and POST routes. Auth has no
business allowlist or flow/scope. Consumers own method/path/body validation and ordinary business retry policy. Bittensor uses `/v1/bittensor/...`.
Root yields come from `GET /root/validators` (per-hotkey `stakeYield.d30.apy`, served by the
yield service as netuid 0) and `GET /root/overview` (`stakeIndex.stakeYield.d30.apy`); alpha
netuid 0 is rejected locally.

Only conclusive `invalid_token` permits one replay preserving method/path/query/body: same
expected HTTPS origin, 401 and the exact Bearer error header, plus a valid envelope for GET/POST.
HEAD uses status/header without a body. Ingress rejects before business execution; arbitrary
POST transport/5xx failures never replay. The NovaAuth session has no URL cache; any response
reuse belongs to the consumer and never extends credential lifetime. No refresh token
exists; renewal obtains a fresh token challenge and App Attest assertion. See
[NovaAuth](../../../Packages/NovaAuth/README.md) and the
[client diagrams](../architecture/novaauth-client-diagrams.md).
