import Foundation

protocol StakingNoticesProviding: AnyObject {
    /// Returns the current notice for the given chain, if any. Reads from in-memory cache.
    func notice(for chainId: ChainModel.Id) -> StakingNotice?

    /// All currently-known notices keyed by chainId. Reads from in-memory cache.
    var allNotices: [ChainModel.Id: StakingNotice] { get }

    /// Trigger a refresh from the remote URL. Safe to call multiple times.
    func refresh()

    /// Register an observer that fires on the main queue whenever `allNotices` changes.
    /// The provider holds the observer weakly. Re-subscribing with the same target is a no-op.
    func subscribe(_ observer: AnyObject, callback: @escaping () -> Void)
    func unsubscribe(_ observer: AnyObject)
}
