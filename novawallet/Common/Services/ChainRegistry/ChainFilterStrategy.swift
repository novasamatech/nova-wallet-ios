import Foundation
import Operation_iOS

// swiftlint:disable switch_case_alignment
enum ChainFilterStrategy {
    typealias Filter = (DataProviderChange<ChainModel>) -> Bool
    typealias Transform = (DataProviderChange<ChainModel>, ChainModel?) -> DataProviderChange<ChainModel>

    case allSatisfies([ChainFilterStrategy])

    case enabledChains
    case hasProxy
    case chainId(ChainModel.Id)

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
            #if F_RELEASE
                return change.item?.hasProxy == true
                    && change.item?.isTestnet == false
            #else
                return change.item?.hasProxy == true
            #endif
        }
        case let .chainId(chainId): { $0.item?.chainId == chainId }
        case let .allSatisfies(strategies): { change in strategies.allSatisfy { $0.filter(change) } }
        }
    }

    private var transform: Transform? {
        switch self {
        case .enabledChains: { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentSyncModeEnabled = currentChain?.syncMode.enabled()
                let updatedSyncModeEnabled = changedChain.syncMode.enabled()
                let needsTransform = updatedSyncModeEnabled != currentSyncModeEnabled

                return if needsTransform, updatedSyncModeEnabled {
                    DataProviderChange<ChainModel>.insert(newItem: changedChain)
                } else if needsTransform, !updatedSyncModeEnabled {
                    DataProviderChange<ChainModel>.delete(deletedIdentifier: changedChain.chainId)
                } else {
                    change
                }
            }
        case let .allSatisfies(strategies): { change, currentChain in
                strategies
                    .compactMap(\.transform)
                    .reduce(change) { $1($0, currentChain) }
            }
        default:
            nil
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
}
