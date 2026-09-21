# Swaps & Asset Exchange

`novawallet/Common/Services/AssetExchange/` implements cross-DEX, cross-chain swapping.
`novawallet/Modules/Swaps/` is the UI on top of it.

## The Graph Model

Swapping is modelled as a **graph problem**, not as a per-DEX integration:

- **Node** — a `ChainAssetId` (a specific asset on a specific chain).
- **Edge** — `AssetExchangableGraphEdge`: a way to get from one asset to another (a DEX pool, an XCM
  transfer, an asset conversion).
- **Route** — a path of edges from the source asset to the destination asset, possibly crossing
  chains.

Key types:

| Type                                | Role                                                            |
|-------------------------------------|-----------------------------------------------------------------|
| `AssetsExchangeProtocol`            | One exchange provider; yields its direct swap edges              |
| `AssetsExchangeGraph`               | The assembled graph of all edges                                 |
| `AssetsExchangeGraphProvider`       | Builds/refreshes the graph, notifies subscribers                 |
| `AssetsExchangeRouteManager`        | Enumerates and ranks routes between two assets                   |
| `AssetsExchangePathCostEstimator`   | Scores routes so the cheapest is chosen                          |
| `AssetExchangeOperationPrototype`   | A planned step, before quoting                                   |
| `*MetaOperation` / `*AtomicOperation`| A resolved step ready to quote/execute                          |
| `AssetExchangeExecutionManager`     | Executes the route step by step, tracking each on-chain result   |
| `AssetsExchangeService`             | Facade used by the Swaps modules (quote, fee, execute)           |
| `AssetExchangeFacade`               | Builds the whole stack with its dependencies                     |

Route search is bounded (max routes / per-exchange priority) — those limits are tuned in
`AssetsExchange.swift` and exercised by `novawalletIntegrationTests/AssetsExchange/`.

## Exchange Providers

| Provider              | Directory              | Covers                                                    |
|-----------------------|------------------------|-----------------------------------------------------------|
| AssetHub              | `AssetHubExchange/`    | `assetConversion` pallet pools                            |
| Hydration             | `HydraExchange/`       | `Omnipool`, `Stableswap`, `XYKPool`, `AavePool`           |
| Cross-chain           | `CrosschainExchange/`  | XCM transfers as graph edges                              |

Hydration quoting goes through `hydra-math-swift` (`HydraMathApi`) bindings rather than
reimplementing the pool maths in Swift.

Each provider supplies: an edge type, an operation prototype, a meta/atomic operation pair, an
extrinsic converter, and an event matcher used to confirm the swap actually happened on chain.
Adding a new DEX means adding all of those — the rest of the pipeline is generic.

## Fees

`FeeEstimating/` and `FeeCapability/` handle the awkward part: each hop may charge in a different
asset, and some chains allow paying fees in non-native assets.

- `AssetExchangeFee` describes the total cost, broken down per operation.
- `AssetExchangeFee+InitialAmount` back-computes the input amount needed for a desired output.
- Fee capability per chain decides whether a hop can pay in the asset being moved.
- `Price/` converts fees into fiat for display.

`FeeViaSwap` in the extrinsic layer (`Common/Services/ExtrinsicService/Substrate/FeeManaging/FeeViaSwap/`)
is the reverse direction: paying an ordinary extrinsic's fee in a non-native asset by swapping.

## Execution

`AssetExchangeExecutionManager` runs the route:

1. Quote each atomic operation with current on-chain state.
2. Submit the operation's extrinsic through the normal `ExtrinsicService` path.
3. Match the resulting events (`*EventParser` / `*EventsMatching`) to learn the actual received
   amount.
4. Feed that amount into the next hop.

Cross-chain hops additionally wait for arrival on the destination chain via
`XcmDepositMonitoringService` / `XcmTokensArrivalDetector` (see architecture/transactions.md).

Because amounts change between hops, **never carry the user's requested amount forward** — always use
the measured output of the previous step.

## Swaps UI

`Modules/Swaps/`:

- `Base/SwapBaseInteractor` — shared quoting/fee/subscription logic for setup and confirm screens.
- Setup, confirm, asset selection, route/details screens build on top of it.
- Quotes are debounced and keyed; a late quote for stale input must be discarded (the base
  interactor already does this — reuse it rather than adding a parallel quoting path).

## Hard Rules

1. **Add capabilities as graph edges.** A new DEX or bridge should not add a special case to the
   Swaps modules; implement the provider protocols so the router picks it up.
2. **Never hardcode a route or a pool address.** Everything is discovered from chain state and the
   chain registry.
3. **Quote before executing each hop.** State moves between quoting and execution; the manager
   re-quotes deliberately.
4. **Confirm swaps by matching events**, not by assuming the extrinsic's success implies the expected
   amount.
5. **Integration tests are the safety net** — `novawalletIntegrationTests/AssetsExchange/` and
   `HydraDx/` must be updated with routing or maths changes.

## Related

- architecture/transactions.md — extrinsic submission, XCM, fee payment modes
- architecture/chain-registry.md — chain/asset identity used as graph nodes
