import Foundation

extension ProxyResolution {
    enum PathFinderError: Error {
        case noSolution
        case noAccount
    }

    struct PathFinderPath {
        struct Component {
            let account: MetaChainAccountResponse
            let proxyType: Proxy.ProxyType
        }

        let components: [Component]
    }

    struct PathFinderResult {
        let proxy: MetaChainAccountResponse
        let callToPath: [CallCodingPath: PathFinderPath]
    }

    final class PathFinder {
        struct CallProxyKey: Hashable {
            let callPath: CallCodingPath
            let proxy: AccountId
        }

        let accounts: [AccountId: [MetaChainAccountResponse]]
        let proxieds: [AccountId: MetaChainAccountResponse]

        init(accounts: [AccountId: [MetaChainAccountResponse]]) {
            self.accounts = accounts

            proxieds = accounts.reduce(into: [AccountId: MetaChainAccountResponse]()) { accum, keyValue in
                guard let account = keyValue.value.first(where: { $0.chainAccount.type == .proxied }) else {
                    return
                }

                accum[keyValue.key] = account
            }
        }

        private func buildResult(
            from callPaths: [CallCodingPath: [ProxyResolution.GraphPath]],
            accounts: [AccountId: MetaChainAccountResponse]
        ) throws -> PathFinderResult {
            let allCalls = Set(callPaths.keys)

            let callProxies = callPaths.reduce(into: [CallProxyKey: ProxyResolution.GraphPath]()) { accum, keyValue in
                let call = keyValue.key
                let paths = keyValue.value

                paths.forEach { path in
                    guard let proxy = path.components.last?.proxyAccountId else {
                        return
                    }

                    let key = CallProxyKey(callPath: call, proxy: proxy)

                    if let oldPath = accum[key], oldPath.components.count <= path.components.count {
                        return
                    }

                    accum[key] = path
                }
            }

            // prefer shorter path
            let optProxyKey = callProxies.keys.min { callPath1, callPath2 in
                let path1Length = callProxies[callPath1]?.components.count ?? Int.max
                let path2Length = callProxies[callPath2]?.components.count ?? Int.max

                return path1Length < path2Length
            }

            guard
                let proxyAccountId = optProxyKey?.proxy,
                let proxyAccount = accounts[proxyAccountId] else {
                throw PathFinderError.noAccount
            }

            let callToPath = try allCalls.reduce(into: [CallCodingPath: PathFinderPath]()) { accum, call in
                let key = CallProxyKey(callPath: call, proxy: proxyAccountId)

                guard let solution = callProxies[key] else {
                    throw PathFinderError.noSolution
                }

                let components = try solution.components.map { oldComponent in
                    let optAccount = accounts[oldComponent.proxyAccountId] ?? proxieds[oldComponent.proxyAccountId]

                    guard
                        let account = optAccount,
                        let proxyType = oldComponent.applicableTypes.first else {
                        throw PathFinderError.noAccount
                    }

                    return PathFinderPath.Component(account: account, proxyType: proxyType)
                }

                accum[call] = PathFinderPath(components: components)
            }

            return PathFinderResult(proxy: proxyAccount, callToPath: callToPath)
        }

        private func find(
            callPaths: [CallCodingPath: [ProxyResolution.GraphPath]],
            walletTypeFilter: (MetaAccountModelType) -> Bool
        ) -> ProxyResolution.PathFinderResult? {
            do {
                let accounts = accounts.reduce(into: [AccountId: MetaChainAccountResponse]()) { accum, keyValue in
                    guard let account = keyValue.value.first(where: { walletTypeFilter($0.chainAccount.type) }) else {
                        return
                    }

                    accum[keyValue.key] = account
                }

                let pathMerger = ProxyResolution.PathMerger()

                try callPaths.forEach { keyValue in
                    let paths = keyValue.value.filter { path in
                        guard
                            let proxyAccountId = path.components.last?.proxyAccountId,
                            let account = accounts[proxyAccountId] else {
                            return false
                        }

                        return walletTypeFilter(account.chainAccount.type)
                    }

                    try pathMerger.combine(callPath: keyValue.key, paths: paths)
                }

                return try buildResult(from: pathMerger.availablePaths, accounts: accounts)
            } catch {
                return nil
            }
        }

        func find(
            from paths: [CallCodingPath: ProxyResolution.GraphResult]
        ) throws -> ProxyResolution.PathFinderResult {
            if let secretBasedResult = find(callPaths: paths, walletTypeFilter: { $0 == .secrets }) {
                return secretBasedResult
            } else if let notWatchOnlyResult = find(
                callPaths: paths,
                walletTypeFilter: { $0 != .watchOnly && $0 != .proxied }
            ) {
                return notWatchOnlyResult
            } else {
                let accounts = accounts.reduce(into: [AccountId: MetaChainAccountResponse]()) { accum, keyValue in
                    guard let account = keyValue.value.first else {
                        return
                    }

                    accum[keyValue.key] = account
                }

                return try buildResult(from: paths, accounts: accounts)
            }
        }
    }
}
