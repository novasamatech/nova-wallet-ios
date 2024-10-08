import Foundation
import Operation_iOS

enum ChainFilterStrategy {
    typealias Filter = (DataProviderChange<ChainModel>) -> Bool
    typealias Transform = (DataProviderChange<ChainModel>, ChainModel?) -> DataProviderChange<ChainModel>

    case allSatisfies([ChainFilterStrategy])

    case enabledChains
    case hasProxy
    case chainId(ChainModel.Id)
    case genericLedger

    private var filter: Filter {
        switch self {
        case .enabledChains: { change in
                switch change {
                case .update where change.item?.syncMode.enabled() == true,
                     .insert where change.item?.syncMode.enabled() == true,
                     .delete:
                    true
                default:
                    false
                }
            }
        case .hasProxy: { change in
                if case .delete = change {
                    return true
                }

                #if F_RELEASE
                    return change.item?.hasProxy == true
                        && change.item?.isTestnet == false
                #else
                    return change.item?.hasProxy == true
                #endif
            }
        case let .chainId(chainId): { change in
                if case let .delete(deleteId) = change, deleteId == chainId {
                    return true
                }

                return change.item?.chainId == chainId
            }
        case let .allSatisfies(strategies): { change in strategies.allSatisfy { $0.filter(change) } }
        case .genericLedger: { change in
                switch change {
                case .update where change.item?.supportsGenericLedgerApp == true,
                     .insert where change.item?.supportsGenericLedgerApp == true,
                     .delete:
                    true
                default:
                    false
                }
            }
        }
    }

    private var transform: Transform? {
        switch self {
        case .enabledChains: { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentSyncModeEnabled = currentChain?.syncMode.enabled() == true
                let updatedSyncModeEnabled = changedChain.syncMode.enabled() == true

                return transform(
                    change,
                    for: currentSyncModeEnabled,
                    updatedSyncModeEnabled
                )
            }
        case .hasProxy: { change, currentChain in
                guard let changedChain = change.item else { return change }

                var currentHasProxy: Bool {
                    #if F_RELEASE
                        currentChain?.hasProxy == true
                            && currentChain?.isTestnet == false
                    #else
                        currentChain?.hasProxy == true
                    #endif
                }

                var updatedHasProxy: Bool {
                    #if F_RELEASE
                        changedChain.hasProxy == true
                            && changedChain.isTestnet == false
                    #else
                        changedChain.hasProxy == true
                    #endif
                }
                return transform(
                    change,
                    for: currentHasProxy,
                    updatedHasProxy
                )
            }
        case let .chainId(chainId): { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentChainIdEquals = currentChain?.chainId == chainId
                let updatedChainIdEquals = changedChain.chainId == chainId

                return transform(
                    change,
                    for: currentChainIdEquals,
                    updatedChainIdEquals
                )
            }
        case let .allSatisfies(strategies): { change, currentChain in
                strategies
                    .compactMap(\.transform)
                    .reduce(change) { $1($0, currentChain) }
            }
        case .genericLedger: { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentSupport = currentChain?.supportsGenericLedgerApp == true
                let updatedSupport = changedChain.supportsGenericLedgerApp == true

                return transform(
                    change,
                    for: currentSupport,
                    updatedSupport
                )
            }
        }
    }

    func filter(
        _ changes: [DataProviderChange<ChainModel>],
        using chainsBeforeChanges: [ChainModel.Id: ChainModel]
    ) -> [DataProviderChange<ChainModel>] {
        let mapped = if let transform {
            changes.map { transform($0, chainsBeforeChanges[$0.identifier]) }
        } else {
            changes
        }

        return mapped.filter(filter)
    }

    func transform(
        _ change: DataProviderChange<ChainModel>,
        for currentChainCondition: Bool,
        _ changedChainCondition: Bool
    ) -> DataProviderChange<ChainModel> {
        guard let changedChain = change.item else { return change }

        let needsTransform = changedChainCondition != currentChainCondition

        return if needsTransform, changedChainCondition {
            DataProviderChange<ChainModel>.insert(newItem: changedChain)
        } else if needsTransform, !changedChainCondition {
            DataProviderChange<ChainModel>.delete(deletedIdentifier: changedChain.chainId)
        } else {
            change
        }
    }
}
