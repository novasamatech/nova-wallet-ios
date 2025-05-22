import Foundation

extension DelegationResolution {
    enum PathMergerError: Error {
        case emptyPaths(CallCodingPath)
        case disjointPaths(CallCodingPath)
    }

    final class PathMerger {
        private var availableDelegateAccounts: Set<AccountId> = []
        private(set) var availablePaths: [CallCodingPath: DelegationResolution.GraphResult] = [:]

        func hasPaths(for call: CallCodingPath) -> Bool {
            availablePaths[call] != nil
        }

        func combine(
            callPath: CallCodingPath,
            paths: DelegationResolution.GraphResult
        ) throws {
            guard !paths.isEmpty else {
                throw PathMergerError.emptyPaths(callPath)
            }

            let newDelegateAccounts = Set(paths.compactMap(\.accountIds.last))

            if !availableDelegateAccounts.isEmpty {
                availableDelegateAccounts = availableDelegateAccounts.intersection(newDelegateAccounts)
            } else {
                availableDelegateAccounts = newDelegateAccounts
            }

            guard !availableDelegateAccounts.isEmpty else {
                throw PathMergerError.disjointPaths(callPath)
            }

            availablePaths[callPath] = paths

            availablePaths = availablePaths.mapValues { paths in
                paths.filter { path in
                    if let delegateAccount = path.components.last?.delegateId,
                       availableDelegateAccounts.contains(delegateAccount) {
                        true
                    } else {
                        false
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
