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

## Nova Commission

A configured swap route charges Nova's commission **once**, on the last eligible DEX edge.

- `Commission/AssetExchangeCommissionConstants` holds the rate (0.85%), the Hydration beneficiary
  and the per-chain Asset Hub enablement map. That map is **empty until a chain passes the launch
  checks**; rotated addresses move to the historical map so history keeps recognising them.
- `AssetExchangeCommissionPolicy` scans the path in reverse: `.hydraSwap` always charges,
  `.assetHubSwap` charges only on a configured chain, `.crossChain` never does. A mixed route in
  either order is still charged exactly once.
- Amounts are output based. For gross output `G` the charge is `C = floor(G * 85 / 10085)` and the
  user sees `N = G - C`. For a buy of net target `T` the route is quoted for
  `G = T + floor(T * 85 / 10000)`.
- `Common/AssetExchangeMetaOperationFactory` is the single grouping implementation. Both the UI
  quote and `AssetsExchangeRouteManager`'s ranking use it, so candidates are compared by **net**
  output (sell) and by the input each candidate needs for the grossed-up target (buy).
- The internal `AssetExchangeGraphProxy` used by `FeeViaSwap` passes `commissionPolicy: nil` — fee
  swaps are never charged.

On Asset Hub the collection rides inside the swap's own extrinsic:

- `AssetHubExchangeExtrinsicParamsFactory` prepares one `AssetHubExchangeSwapParams` reused by fee
  estimation, execution and delayed submission, so all three agree on the exact calls and amount.
  It rejects invalid slippage, a commission that is not smaller than the output, a beneficiary equal
  to the swap receiver, a missing runtime call, and a net output below the output token's minimum.
- `AssetHubExchangeCommissionRecipientFactory` requires native free balance ≥ native ED and
  `providers > 0` for every positive collection, including Assets/ForeignAssets outputs. Token
  outputs additionally need a live receivable treasury token account funded to its `minBalance`.
  A sufficient-only token account does not satisfy this conservative native-provider policy.
  Missing readiness rejects the charged swap; there is no silent waiver.
- Before enabling a chain, provision/check the native account and every eligible output account.
  Repeat the asset check whenever remote configuration adds an output token. This ongoing rollout
  dependency must be addressed before enablement; the chain map is currently empty.
  During rotation/disablement, preserve all prior recipients in the historical map first.
- `AssetHubExchangeExtrinsicConverter` appends the swap then a keep-alive transfer and **seals them
  into exactly one `Utility.batch_all` before sender resolution**. A proxy or multisig must wrap the
  batch (`proxy(batch_all([...]))`), not each leaf, or an inner failure would not roll the swap back.
- The pallet bound stays gross: a sell asks for `netMinimum + C` so that subtracting `C` afterwards
  satisfies the net minimum shown in the UI.
- `AssetHubExchangeDelegationPermission` resolves that batch by its `AssetConversion` leaf, so the
  innermost proxy needs the swap-compatible permission (which also permits the transfer) rather than
  a type that merely allows the outer `Utility` wrapper.

Measured output and history:

- `AssetConversionEventParser` matches the one swap event that belongs to the signed call plus the
  one matching transfer to the configured beneficiary, and returns `measuredGross - verifiedTransfer`.
  Missing, ambiguous or mismatching events throw rather than degrade to zero.
- `AssetHubCommissionTopology` + `AssetHubCommissionHistoryParser` recognise the collection in
  `ExtrinsicProcessor` **before** the generic nested mapper flattens the batch, so included swap
  history stores measured net output. This flow currently creates no local pending swap row:
  `PersistentExtrinsicService.saveSwap` has no callers. The matcher distinguishes an unrelated call from
  an unresolved swap: only an unrelated call continues to transfer/other history matchers.
  Pending approvals, parsing errors and ambiguous commissioned calls produce no record.
- Commission history supports a direct atomic pair with a linear proxy/multisig wrapper chain.
  An additional Utility ancestor leaves a known commissioned candidate unresolved, because
  matching sibling events by origin/path/amount cannot prove which child executed.
- Wrapper execution markers are checked outside inward in reverse event order. A correlated
  failure is final even when undispatched descendants have no markers; successful ancestors
  still require their descendants' execution markers. Multisig results must match the approver,
  derived account and inner call hash. Threshold-1 multisig dispatch propagates its call result:
  on runtimes without its own execution marker, inherit the successful enclosing dispatch result
  and still check inner wrappers. On runtimes emitting a marker, validate and consume it normally.
- Collection event matching uses the prepared output storage's actual pallet. Delegation and
  commissioned topology accept configured statemine pallet names as well as the standard ones.

A multi-operation buy keeps its existing semantics: the execution manager switches to exact-in after
the first operation and rescales limits, so exact net target delivery is a single-operation
guarantee.

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
