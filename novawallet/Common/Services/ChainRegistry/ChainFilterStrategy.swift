import Foundation
import Operation_iOS

// swiftlint:disable switch_case_alignment
enum ChainFilterStrategy {
    typealias Filter = (DataProviderChange<ChainModel>) -> Bool
    typealias Transform = (DataProviderChange<ChainModel>, ChainModel) -> DataProviderChange<ChainModel>

    case combined([ChainFilterStrategy])
    
    case enabledChains
    case hasProxy
    case chainId(ChainModel.Id)
    case noFilter
    
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
        case let .combined(strategies): { change in
            let resultSet = Set(strategies.map { $0.filter(change) })
            
            return !resultSet.contains(false)
        }
        case .noFilter: { _ in true }
        }
    }

    private var transform: Transform? {
        if case .enabledChains = self {
            { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentSyncModeEnabled = currentChain.syncMode.enabled()
                let updatedSyncModeEnabled = changedChain.syncMode.enabled()
                let needsTransform = updatedSyncModeEnabled != currentSyncModeEnabled

                return switch needsTransform {
                case true where updatedSyncModeEnabled:
                    DataProviderChange<ChainModel>.insert(newItem: changedChain)
                case true where !updatedSyncModeEnabled:
                    DataProviderChange<ChainModel>.delete(deletedIdentifier: changedChain.chainId)
                default:
                    change
                }
            }
        } else {
            nil
        }
    }
    
    func filter(
        _ changes: [DataProviderChange<ChainModel>], 
        using chainsBeforeChanges: [ChainModel.Id: ChainModel]
    ) -> [DataProviderChange<ChainModel>] {
        if case .noFilter = self {
            return changes
        }

        let mapped = if let transform {
            changes.map { change in
                guard
                    let changedChain = change.item,
                    let currentChain = chainsBeforeChanges[changedChain.chainId]
                else {
                    return change
                }

                return transform(change, currentChain)
            }
        } else {
            changes
        }

        return mapped.filter(filter)
    }
}
