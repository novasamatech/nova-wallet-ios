# Chain Registry — Chains, Connections, Runtime

`ChainRegistry` is the single source of truth for which chains exist, how to reach them, and how to
decode their data. Everything chain-related in a feature starts here.

Location: `novawallet/Common/Services/ChainRegistry/`
Access: `ChainRegistryFacade.sharedRegistry` (singleton, built by `ChainRegistryFactory`).

## Responsibilities

`ChainRegistry` owns and coordinates:

| Collaborator                | Role                                                              |
|-----------------------------|-------------------------------------------------------------------|
| `ChainSyncService`          | Downloads the remote chain list, diffs it into local CoreData      |
| `chainProvider`             | `StreamableProvider<ChainModel>` over the local chain store        |
| `ConnectionPool`            | One WebSocket `ChainConnection` per enabled chain, with node autobalancing |
| `RuntimeProviderPool`       | One `RuntimeProvider` per chain with a Substrate runtime           |
| `RuntimeSyncService`        | Fetches/refreshes runtime metadata per chain                       |
| `CommonTypesSyncService`    | Fetches the shared type definitions used by the coders             |
| `SpecVersionSubscription`   | Watches `state_subscribeRuntimeVersion` and triggers runtime resync |

The registry subscribes to `chainProvider` and reacts to every `DataProviderChange<ChainModel>`:
inserts/updates re-apply the chain's sync mode; deletes tear down the connection, runtime provider,
and version subscription.

## Chain Sync Modes

`ChainModel.syncMode` is `ChainSyncMode`:

| Mode       | Connection | Runtime metadata | Meaning                                       |
|------------|------------|------------------|-----------------------------------------------|
| `.full`    | yes        | yes              | Normal operation                              |
| `.light`   | yes        | no               | Connected, but no runtime handling            |
| `.disabled`| no         | no               | Chain switched off by the user                |

`switchSync(mode:chainId:)` updates the in-memory chain, re-applies the sync mode, and persists the
change through `ChainSyncService.updateLocal(chain:)`. `ChainSyncModeUpdateService` adjusts modes
automatically based on the selected wallet (a wallet with no account on a chain does not need a full
sync).

## Using ChainRegistry from a Feature

```swift
// Synchronous look-ups — return nil if the chain is not (yet) available
let chain = chainRegistry.getChain(for: chainId)
let connection = chainRegistry.getConnection(for: chainId)
let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId)

// One-shot connection for a single request without joining the pool
let engine = chainRegistry.getOneShotConnection(for: chainId)
```

Interactors that must react to chain-list changes subscribe instead:

```swift
chainRegistry.chainsSubscribe(
    self,
    runningInQueue: .main,
    filterStrategy: .enabledChains
) { [weak self] changes in
    self?.handle(changes: changes)
}
```

- Always `chainsUnsubscribe(self)` when the Interactor's inputs change or it is torn down.
- Use `ChainFilterStrategy` (`.enabledChains`, `.hasProxy`, `.allSatisfies([...])`, …) instead of
  filtering the whole list by hand in the Interactor.
- `ChainRegistry+Get.swift` and `ChainRegistry+AsyncWait.swift` hold convenience accessors — check
  them before writing a new "wait until the chain/runtime is ready" helper.

## Models

| Type                | Meaning                                                                    |
|---------------------|----------------------------------------------------------------------------|
| `ChainModel`        | Local chain record: id, name, assets, nodes, options, external APIs, syncMode |
| `AssetModel`        | An asset on a chain: `assetId`, symbol, precision, `type` + `typeExtras`     |
| `ChainAsset`        | `(chain, asset)` pair — the identity used everywhere for balances/operations |
| `ChainAssetId`      | `(chainId, assetId)` — the persistable/compact form                          |
| `ChainNodeModel`    | One RPC endpoint, possibly requiring an API key                              |
| `RemoteChainModel`  | The JSON shape fetched from the chains list; mapped in `ChainModelConversion` |

Models live in `Common/Model/ChainRegistry/` split into `LocalChain/` and `RemoteChain/`.
`ChainModel+Additional.swift` and `AssetModel+*` carry the derived helpers (`hasSubstrateRuntime`,
`chainFormat`, staking flags, asset search).

## Runtime & Coding

`RuntimeProvider` exposes a `RuntimeSnapshot` (metadata + type registry) and a
`RuntimeCodingServiceProtocol` used to build SCALE coders:

```swift
let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
```

Rules:
- Never decode chain data without a coding factory from the chain's own runtime provider.
- Runtime constants are read through `RuntimeConstantFetching` (`Common/Protocols/`), not by
  hand-rolling storage requests.
- Metadata shortening for hardware-wallet signing goes through `MetadataHashOperationFactory` /
  `metadata-shortener-ios`.

### Metadata versions

`RuntimeFetchOperationFactory` asks the runtime which metadata versions it has
(`Metadata_metadata_versions`) and takes the newest one up to `latestSupportedVersion` (16); a runtime
that can't list versions is read with `state_getMetadata`. `RuntimeTypeRegistryFactory` types v14, v15
and v16 the same way. v16 adds what v15 can't say: the extrinsic formats the runtime accepts, the
transaction extensions of each extension version, and view functions.

- A runtime may list an unstable version as `u32::MAX` (Mythos, peaq); the limit leaves it out.
- With v16 `getSignedExtensions()` returns the extensions of every extension version. The set of a
  legacy (v4) extrinsic is `getSignedExtensions(forExtensionVersion: 0)`.
- **The metadata hash is defined over v15** (RFC-78), whatever the app decodes with.
  `MetadataHashOperationFactory` and `ExtrinsicProofOperationFactory` take the bytes from
  `MetadataHashSourceProvider`: the stored item while it is v15 or older, otherwise v15 of the stored
  spec version, fetched once at a pinned block and kept by `RuntimeFilesOperationFactory`
  (`<chainId>-metadata-hash-source`, the spec version in front of the bytes). Never hand the stored
  metadata to the shortener directly.
- Changing what is requested needs `RuntimeLocalVersion.latest` raised: `RuntimeSyncService` refetches
  every item saved with an older value when the node next reports its runtime version (on connect),
  and the app keeps decoding with the cached item until the new one is saved.

## Connections

`ConnectionPool` creates one `ChainConnection` (a `WebSocketEngine`) per enabled chain, sharing it
across all consumers. Nodes come from `ChainNodeModel`; API keys are injected by
`ConnectionApiKeys`. Node autobalancing and reconnection are handled inside the engine — features
must not implement their own retry/failover on top of a connection.

Connection state can be observed:

```swift
chainRegistry.subscribeChainState(self, chainId: chainId)   // ConnectionStateSubscription
```

## Hard Rules

1. **No hardcoded node URLs, genesis hashes, or asset ids in feature code.** `KnownChainIds.swift`
   holds the few well-known ids that logic legitimately branches on.
2. **Never construct `ChainAsset` by hand from strings.** Resolve it from the registry
   (`chain.chainAsset(for:)`, `chainRegistry.getChain(...)`).
3. **Treat missing chain/connection/runtime as a normal state**, not a programming error — return
   nil or throw a typed error and let the UI show a retry.
4. **One registry.** Do not build a second `ChainRegistry` outside tests; use
   `ChainRegistryFacade.sharedRegistry`.
5. **Unsubscribe.** `chainsSubscribe`/`subscribeChainState` are refcounted by target object; leaking
   a subscription keeps a chain's connection alive.

## Related

- code/networking.md — issuing storage queries and runtime calls over a connection
- architecture/data-flow.md — turning chain data into local subscriptions
- architecture/services-lifecycle.md — who starts the registry and when
