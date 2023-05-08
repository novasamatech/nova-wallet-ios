import Foundation

struct DAppChainsResolution {
    let resolved: Set<ChainModel>
    let unresolved: Set<String>

    var hasResolved: Bool { !resolved.isEmpty }
    var hasUnresolved: Bool { !unresolved.isEmpty }

    var hasChains: Bool { hasResolved || hasUnresolved }

    init(resolved: Set<ChainModel> = [], unresolved: Set<String> = []) {
        self.resolved = resolved
        self.unresolved = unresolved
    }

    init(wcResolution: WalletConnectChainsResolution) {
        resolved = Set(wcResolution.resolved.values)
        unresolved = wcResolution.unresolved
    }

    func merging(with resolution: DAppChainsResolution) -> DAppChainsResolution {
        let newResolved = resolved.union(resolution.resolved)
        let newUnresolved = unresolved.union(resolution.unresolved)

        return .init(resolved: newResolved, unresolved: newUnresolved)
    }
}
