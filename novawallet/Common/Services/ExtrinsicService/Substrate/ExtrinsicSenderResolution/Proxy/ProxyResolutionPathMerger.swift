import Foundation

extension ProxyResolution {
    enum PathMergerError: Error {
        case empthPaths(CallCodingPath)
        case disjointPaths(CallCodingPath)
    }

    final class PathMerger {
        private var availableProxies: Set<AccountId> = []
        private(set) var availablePaths: [CallCodingPath: ProxyResolution.GraphResult] = [:]

        func hasPaths(for call: CallCodingPath) -> Bool {
            availablePaths[call] != nil
        }

        func combine(callPath: CallCodingPath, paths: ProxyResolution.GraphResult) throws {
            let newProxies = Set(paths.compactMap(\.accountIds.last))

            guard !paths.isEmpty else {
                throw PathMergerError.empthPaths(callPath)
            }

            if !availableProxies.isEmpty {
                availableProxies = availableProxies.intersection(newProxies)
            } else {
                availableProxies = newProxies
            }

            guard !availableProxies.isEmpty else {
                throw PathMergerError.disjointPaths(callPath)
            }

            availablePaths[callPath] = paths

            availablePaths = availablePaths.mapValues { paths in
                paths.filter { path in
                    if let proxy = path.components.last?.proxyAccountId, availableProxies.contains(proxy) {
                        return true
                    } else {
                        return false
                    }
                }
            }

            try availablePaths.forEach { keyValue in
                if keyValue.value.isEmpty {
                    throw PathMergerError.disjointPaths(callPath)
                }
            }
        }
    }
}
