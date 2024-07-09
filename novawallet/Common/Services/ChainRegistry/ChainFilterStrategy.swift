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
    
    var filter: Filter {
        switch self {
        case .enabledChains: { change in
                switch change {
                case .update where change.item?.syncMode.enabled() == true,
                     .insert,
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

    var transform: Transform? {
        if case .enabledChains = self {
            { change, currentChain in
                guard let changedChain = change.item else { return change }

                let currentSyncModeEnabled = currentChain.syncMode.enabled()
                let needsTransform = changedChain.syncMode.enabled() != currentSyncModeEnabled

                return switch needsTransform {
                case true where currentSyncModeEnabled:
                    DataProviderChange<ChainModel>.delete(deletedIdentifier: changedChain.chainId)
                case true where !currentSyncModeEnabled:
                    DataProviderChange<ChainModel>.insert(newItem: changedChain)
                default:
                    change
                }
            }
        } else {
            nil
        }
    }
}

// MARK: Array filter

extension Array where Element == DataProviderChange<ChainModel> {
    func filter(
        with strategy: ChainFilterStrategy,
        availableChains: [ChainModel.Id: ChainModel]
    ) -> Self {
        if case .noFilter = strategy {
            return self
        }

        let mapped = if let transform = strategy.transform {
            map { change in
                guard
                    let changedChain = change.item,
                    let currentChain = availableChains[changedChain.chainId]
                else {
                    return change
                }

                return transform(change, currentChain)
            }
        } else {
            self
        }

        return mapped.filter(strategy.filter)
    }
}
