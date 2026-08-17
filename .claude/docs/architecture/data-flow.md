# Data Flow — Subscriptions, Providers, Events

Chain data reaches the UI through a three-stage pipeline. Understand which stage you are touching
before adding code.

```
chain node ──(remote subscription)──> CoreData ──(local subscription)──> Interactor ──> Presenter
                     ▲                                                        ▲
             WebSocket storage sub                                     EventCenter (side channel)
```

1. **Remote subscription** — a background service subscribes to on-chain storage over the chain's
   WebSocket connection and writes decoded results into CoreData.
2. **Local subscription** — the Interactor observes a CoreData-backed provider and receives
   `DataProviderChange` batches on the main queue.
3. **EventCenter** — a lightweight in-app bus for cross-cutting notifications that are *not* data
   streams (wallet switched, era changed, balances changed, runtime ready).

Screens read from CoreData, never directly from the chain. A screen that queries the chain directly
(one-shot storage request) is doing it because the data is not persisted — that's the exception, and
it goes through an operation factory (see code/networking.md).

## Local Subscriptions

Each domain has a factory + a subscriber trait + a handler protocol, in
`Common/DataProvider/`:

| Piece                                 | Example                                        |
|---------------------------------------|------------------------------------------------|
| `*LocalSubscriptionFactoryProtocol`   | `WalletLocalSubscriptionFactoryProtocol`       |
| `*LocalStorageSubscriber` (trait)     | `WalletListLocalStorageSubscriber`             |
| `*LocalSubscriptionHandler` (callbacks)| `WalletListLocalSubscriptionHandler`           |

An Interactor opts in by conforming to the subscriber trait and the handler, then calling the
subscribe method:

```swift
extension SomeInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        // update state, notify presenter
    }
}

// in setup():
walletsProvider = subscribeAllWalletsProvider()
```

The trait's default implementation resolves the provider from the factory, installs an observer with
`StreamableProviderObserverOptions`, and routes success/failure into the handler. The
`where Self: SomeHandler` extension makes the Interactor its own handler.

Rules:

- **Hold the returned provider.** The factory keeps providers in a `WeakWrapper` map
  (`BaseLocalSubscriptionFactory`); if you drop the reference the stream dies.
- **Clear before re-subscribing.** When the selected wallet/chain/asset changes, clear the old
  provider before subscribing again, otherwise you get interleaved callbacks from two subscriptions.
  Conform to `AnyProviderAutoCleaning` and use `clear(streamableProvider: &provider)` /
  `clear(dataProvider:)` / `clear(singleValueProvider:)` — they remove the observer and nil the
  reference in one step.
- **Handle `.failure` explicitly.** Every handler receives a `Result`; log and surface an error state
  rather than silently ignoring it.
- **Reduce change batches with the shared helpers** — `changes.reduceToLastChange()`,
  `DataChangesDiffCalculator`, `ListReducing` — not with hand-written loops.

Provider types come from `Operation_iOS`:

| Type                       | Use                                                        |
|----------------------------|------------------------------------------------------------|
| `StreamableProvider<T>`    | A collection that changes over time (wallets, balances)     |
| `SingleValueProvider<T>`   | One value refreshed from a remote source (prices, JSON)     |
| `AnyDataProvider<T>`       | Type-erased decoded chain storage item                      |

`Common/DataProvider/Sources/` holds the custom provider sources; `Triggers/` holds the update
triggers that decide when a provider refreshes.

## Remote Subscriptions

`Common/Services/RemoteSubscription/` contains the services that keep CoreData populated:

| Area                       | Service                                                     |
|----------------------------|-------------------------------------------------------------|
| Substrate balances         | `SubstrateAssetsUpdatingService`, `WalletRemoteSubscription` |
| EVM balances/history       | `EvmAssetBalanceUpdatingService`, `EvmNativeBalanceUpdatingService` |
| ORML on Hydration EVM      | `OrmlHydrationEvmWalletSyncService`                          |
| Equilibrium                | `EquilibriumAssetBalanceUpdatingService`                     |
| Staking                    | `StakingRemoteSubscriptionService`, `StakingAccountUpdatingService` |
| Block number               | `BlockNumberRemoteSubscription`                              |

Subscriptions are **refcounted by key**: `attachToX(...)` returns a `UUID` and `detachFromX(...)`
releases it. Two screens subscribing to the same storage share one on-chain subscription. Always
keep the returned id and detach in the Interactor's teardown.

`ObservableSubscriptionSyncService` / `ObservableSubscriptionStateStore` are the base types for
services that expose a snapshot of subscribed state to consumers.

## EventCenter

`Common/EventCenter/` — a visitor-based event bus.

```swift
struct WalletsChanged: EventProtocol {
    let source: WalletsChangeSource
    func accept(visitor: EventVisitorProtocol) { visitor.processWalletsChanged(event: self) }
}

// observer
eventCenter.add(observer: self, dispatchIn: .main)

extension SomeInteractor: EventVisitorProtocol {
    func processWalletsChanged(event: WalletsChanged) { ... }
}

// producer
eventCenter.notify(with: WalletsChanged(source: .byUserManually))
```

- `EventVisitorProtocol` has a default empty implementation for **every** method, so observers only
  override what they care about. Adding a new event means: a struct in `EventCenter/Events/`, a
  `process…` method on `EventVisitorProtocol`, and an empty default in the protocol extension.
- Observers are held **weakly** and deduplicated; `remove(observer:)` on teardown is still correct
  practice.
- Notification is asynchronous on an internal serial queue; pass `dispatchIn: .main` when the
  observer touches UI state.

**Use EventCenter for notifications, not for data delivery.** If consumers need the value itself,
add a provider/subscription; the event should only say "this changed".

## Choosing the Right Mechanism

| Need                                                  | Use                                              |
|-------------------------------------------------------|--------------------------------------------------|
| Persisted collection that several screens observe      | Local subscription (factory + subscriber trait)  |
| Fresh on-chain value nobody persists                   | One-shot storage request via operation factory   |
| Keep CoreData in sync with chain state                 | Remote subscription service                      |
| "Something changed, re-read your source"               | EventCenter event                                |
| Value shared across screens of one flow                | Feature shared state (see architecture/viper.md) |
| User preference                                        | `SettingsManager` + `SettingsSubscriber`         |

## Hard Rules

1. **Never write chain data to CoreData from a module.** That is the remote subscription services'
   job; modules read.
2. **One subscription per input combination.** Re-subscribing without clearing is the most common
   source of duplicated/flickering UI in this codebase.
3. **Deliver on `.main` for anything the Presenter consumes**, and keep heavy decoding on the
   operation queue.
4. **Don't poll.** If you find yourself scheduling a repeated fetch, look for an existing remote
   subscription or a `BaseSyncService` subclass.
5. **Events carry identity, not payload state.** Keep event structs minimal (ids, chain ids), so
   consumers re-read from their own source of truth.

## Related

- code/data-persistence.md — repositories, mappers, and the CoreData stores behind the providers
- code/concurrency.md — operation queues and cancellation for the fetch side
- architecture/chain-registry.md — where connections and runtime coders come from
