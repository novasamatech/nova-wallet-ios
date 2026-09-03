# Concurrency — Operation-iOS

**This codebase does not use Swift structured concurrency.** There are no actors, no `AsyncStream`,
effectively no `async`/`await`, and Combine is used in two isolated places. All asynchronous work is
`Operation`-based via the `Operation_iOS` package. Match that — do not introduce async/await into
existing paths.

## Core Types

| Type                            | Meaning                                                          |
|---------------------------------|------------------------------------------------------------------|
| `BaseOperation<T>`              | A unit of work producing `Result<T, Error>`                       |
| `ClosureOperation<T>`           | Synchronous closure wrapped as an operation                       |
| `AsyncClosureOperation<T>`      | Callback-based work (network, subscriptions) as an operation      |
| `CompoundOperationWrapper<T>`   | `targetOperation` + `dependencies` — the unit passed between layers |
| `OperationManager` / `OperationQueue` | Executes operations                                        |
| `CancellableCall`               | Anything cancellable (an operation or a wrapper)                  |

The dominant idiom: a factory returns a `CompoundOperationWrapper<T>`; the caller composes it with
other wrappers and finally schedules it on a queue.

## Building Wrappers

```swift
func createSomethingWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Something> {
    let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

    let fetchWrapper = requestFactory.queryItems(...)
    fetchWrapper.addDependency(operations: [codingFactoryOperation])

    let mapOperation = ClosureOperation<Something> {
        let raw = try fetchWrapper.targetOperation.extractNoCancellableResultData()
        return Something(raw)
    }

    mapOperation.addDependency(fetchWrapper.targetOperation)

    return fetchWrapper.insertingTail(operation: mapOperation)
}
```

Conventions:

- **`extractNoCancellableResultData()`** is how you read a dependency's result. It throws the
  dependency's error, which propagates through the wrapper. Never use `result` + force unwrap.
- **Compose with the helpers** — `insertingHead(operations:)`, `insertingTail(operation:)`,
  `addDependency(operations:)`, `addDependency(wrapper:)`, `OperationCombiningService` (for merging a
  dynamic number of wrappers) — instead of hand-assembling `allOperations` arrays.
- `CompoundOperationWrapper.createWithResult(_:)` / `.createWithError(_:)` for the trivial cases;
  they are used ~300 times and are the right answer for early returns.
- Name factories `*OperationFactory` and their methods `create…Wrapper` / `create…Operation`.

## Executing

Never call `operationQueue.addOperations` directly from an Interactor. Use the helpers in
`Common/Helpers/CancellableCallHelper.swift`:

```swift
// fire and forget
execute(
    wrapper: wrapper,
    inOperationQueue: operationQueue,
    runningCallbackIn: .main
) { [weak self] result in
    switch result {
    case let .success(value): self?.presenter?.didReceive(value: value)
    case let .failure(error): self?.presenter?.didReceive(error: .something(error))
    }
}

// cancellable, replaces any in-flight call
executeCancellable(
    wrapper: wrapper,
    inOperationQueue: operationQueue,
    backingCallIn: callStore,
    runningCallbackIn: .main
) { [weak self] result in ... }
```

`CancellableCallStore` keeps one in-flight call per logical request:

```swift
private let feeCallStore = CancellableCallStore()

func refreshFee() {
    feeCallStore.cancel()          // drop the previous request
    executeCancellable(..., backingCallIn: feeCallStore, ...)
}

func teardown() { feeCallStore.cancel() }
```

The store also drops **late callbacks** — `clearIfMatches(call:)` means a response for a cancelled
request never reaches the Presenter. That is the mechanism that prevents stale fees/quotes from
overwriting fresh ones; use it for anything the user can re-trigger.

## Queues

`OperationManagerFacade` exposes named queues. Use the one that matches the work — don't create ad-hoc
`OperationQueue`s in a module:

| Queue                     | For                                              |
|---------------------------|--------------------------------------------------|
| `sharedDefaultQueue`      | General feature work (the default choice)         |
| `runtimeBuildingQueue`    | Building runtime type registries                  |
| `runtimeSyncQueue`        | Runtime metadata sync                             |
| `assetsSyncQueue`         | Balance/asset background sync                     |
| `assetsRepositoryQueue`   | Asset repository writes                           |
| `fileDownloadQueue`       | File downloads                                    |
| `nftQueue`                | NFT sync and media                                |
| `cloudBackupQueue`        | iCloud backup work                                |
| `pendingMultisigQueue`    | Multisig operation sync                           |
| `analyticsQueue`          | Analytics event persistence — **serial**          |
| `sharedManager`           | `OperationManager` over `sharedDefaultQueue`      |

Queues are injected through the ViewFactory so tests can substitute a synchronous queue.

## Callback Threading

- `runningCallbackIn: .main` for anything that reaches the Presenter/View.
- `dispatchInQueueWhenPossible(_:locking:)` (`Common/Helpers/DispatchQueueHelper.swift`) runs
  immediately if already on the target queue, otherwise dispatches — used by the execute helpers.
- Services that keep mutable state guard it with an `NSLock` (`BaseSyncService`, `ChainRegistry`,
  `BaseLocalSubscriptionFactory` all do). Follow that pattern rather than inventing a queue-confined
  design.

## Retries, Debounce, Timers

- Background sync retry: subclass `BaseSyncService`; it already implements exponential backoff via
  `ExponentialReconnection` and the `Scheduler`.
- User-driven retry: `CommonRetryable` / `FeeRetryable` wireframe mix-ins present the standard alert.
- Debounce: `Debouncer` (`Common/Helpers/Debouncer.swift`) for rapidly changing inputs (search
  fields, amount → fee).
- Countdowns: `CountdownTimerMediator`, not raw `Timer` in a Presenter.

## Hard Rules

1. **No `async`/`await` in the app target.** Wrap callback APIs in `AsyncClosureOperation` instead.
2. **Every cancellable request gets a `CancellableCallStore`** and is cancelled on teardown and
   before re-issuing.
3. **`[weak self]` in every operation callback.** Operations outlive screens.
4. **Errors propagate through `extractNoCancellableResultData()`** — no `try?` that turns a failure
   into a silent `nil`.
5. **Don't block.** Never `waitUntilFinished: true` on the main thread.
6. **One queue per concern.** Reuse `OperationManagerFacade`'s queues; injected, not hardcoded.
