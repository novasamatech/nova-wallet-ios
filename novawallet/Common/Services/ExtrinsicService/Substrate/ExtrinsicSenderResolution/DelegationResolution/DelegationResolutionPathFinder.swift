import Foundation
import SubstrateSdk

protocol AccountDelegationPathValue {
    func wrapCall(
        _ call: JSON,
        delegation: DelegationResolution.DelegationKey,
        context: RuntimeJsonContext
    ) throws -> JSON

    var delegationType: DelegationType { get }
}

extension DelegationResolution {
    enum PathFinderError: Error {
        case noSolution
        case noAccount
    }

    struct PathFinderPath {
        struct Component {
            let account: MetaChainAccountResponse
            let delegationValue: AccountDelegationPathValue
        }

        let components: [Component]
    }

    struct PathFinderResult {
        let delegate: MetaChainAccountResponse
        let callToPath: [CallCodingPath: PathFinderPath]
    }

    final class PathFinder {
        struct CallDelegateKey: Hashable {
            let callPath: CallCodingPath
            let delegate: AccountId
        }

        let accounts: [AccountId: [MetaChainAccountResponse]]
        let delegatedAccounts: [AccountId: MetaChainAccountResponse]

        init(accounts: [AccountId: [MetaChainAccountResponse]]) {
            self.accounts = accounts

            delegatedAccounts = accounts.reduce(into: [AccountId: MetaChainAccountResponse]()) { accum, keyValue in
                guard let account = keyValue.value.first(where: { $0.chainAccount.delegated }) else {
                    return
                }

                accum[keyValue.key] = account
            }
        }

        private func buildResult(
            from callPaths: [CallCodingPath: [DelegationResolution.GraphPath]],
            accounts: [AccountId: MetaChainAccountResponse]
        ) throws -> PathFinderResult {
            let allCalls = Set(callPaths.keys)

            let callDelegates = callPaths.reduce(
                into: [CallDelegateKey: DelegationResolution.GraphPath]()
            ) { accum, keyValue in
                let call = keyValue.key
                let paths = keyValue.value

                paths.forEach { path in
                    guard let delegateAccountId = path.components.last?.delegateId else {
                        return
                    }

                    let key = CallDelegateKey(callPath: call, delegate: delegateAccountId)

                    if let oldPath = accum[key], oldPath.components.count <= path.components.count {
                        return
                    }

                    accum[key] = path
                }
            }

            // prefer shorter path
            let optDelegateKey = callDelegates.keys.min { callPath1, callPath2 in
                let path1Length = callDelegates[callPath1]?.components.count ?? Int.max
                let path2Length = callDelegates[callPath2]?.components.count ?? Int.max

                return path1Length < path2Length
            }

            guard
                let delegateAccountId = optDelegateKey?.delegate,
                let delegateAccount = accounts[delegateAccountId] else {
                throw PathFinderError.noAccount
            }

            let callToPath = try allCalls.reduce(into: [CallCodingPath: PathFinderPath]()) { accum, call in
                let key = CallDelegateKey(callPath: call, delegate: delegateAccountId)

                guard let solution = callDelegates[key] else {
                    throw PathFinderError.noSolution
                }

                let components = try solution.components.map { oldComponent in
                    let optAccount = accounts[oldComponent.delegateId] ?? delegatedAccounts[oldComponent.delegateId]

                    guard
                        let account = optAccount,
                        let delegationValue = oldComponent.delegationValue.pathDelegationValue() else {
                        throw PathFinderError.noAccount
                    }

                    return PathFinderPath.Component(
                        account: account,
                        delegationValue: delegationValue
                    )
                }

                accum[call] = PathFinderPath(components: components)
            }

            return PathFinderResult(
                delegate: delegateAccount,
                callToPath: callToPath
            )
        }

        private func find(
            callPaths: [CallCodingPath: [DelegationResolution.GraphPath]],
            walletTypeFilter: (MetaAccountModelType) -> Bool
        ) -> DelegationResolution.PathFinderResult? {
            do {
                let accounts = accounts.reduce(into: [AccountId: MetaChainAccountResponse]()) { accum, keyValue in
                    guard let account = keyValue.value.first(where: { walletTypeFilter($0.chainAccount.type) }) else {
                        return
                    }

                    accum[keyValue.key] = account
                }

                let pathMerger = DelegationResolution.PathMerger()

                try callPaths.forEach { keyValue in
                    let paths = keyValue.value.filter { path in
                        guard
                            let delegateAccountId = path.components.last?.delegateId,
                            let account = accounts[delegateAccountId] else {
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
            from paths: [CallCodingPath: DelegationResolution.GraphResult]
        ) throws -> DelegationResolution.PathFinderResult {
            if let secretBasedResult = find(callPaths: paths, walletTypeFilter: { $0 == .secrets }) {
                return secretBasedResult
            } else if let notWatchOnlyResult = find(
                callPaths: paths,
                walletTypeFilter: { $0 != .watchOnly && !$0.isDelegated }
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

extension DelegationResolution.PathFinder {
    struct ProxyDelegationValue: AccountDelegationPathValue {
        let proxyType: Proxy.ProxyType

        var delegationType: DelegationType {
            .proxy(proxyType)
        }

        func wrapCall(
            _ call: JSON,
            delegation: DelegationResolution.DelegationKey,
            context: RuntimeJsonContext
        ) throws -> JSON {
            try Proxy.ProxyCall(
                real: .accoundId(delegation.delegate),
                forceProxyType: proxyType,
                call: call
            )
            .runtimeCall()
            .toScaleCompatibleJSON(with: context.toRawContext())
        }
    }

    struct MultisigDelegationValue: AccountDelegationPathValue {
        let threshold: UInt16
        let signatories: [AccountId]

        var delegationType: DelegationType {
            .multisig
        }

        func wrapCall(
            _ call: JSON,
            delegation: DelegationResolution.DelegationKey,
            context: RuntimeJsonContext
        ) throws -> JSON {
            let otherSignatories = signatories
                .filter { $0 != delegation.delegate }
                .map { BytesCodable(wrappedValue: $0) }

            return if threshold == 1 {
                try MultisigPallet.AsMultiThreshold1Call(
                    otherSignatories: otherSignatories,
                    call: call
                )
                .runtimeCall()
                .toScaleCompatibleJSON(with: context.toRawContext())
            } else {
                try MultisigPallet.AsMultiCall(
                    threshold: threshold,
                    otherSignatories: otherSignatories,
                    maybeTimepoint: nil,
                    call: call,
                    maxWeight: .zero
                )
                .runtimeCall()
                .toScaleCompatibleJSON(with: context.toRawContext())
            }
        }
    }
}
