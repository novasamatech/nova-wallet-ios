import Foundation
import Operation_iOS

enum ChainFilterStrategy {
    typealias Filter = (DataProviderChange<ChainModel>) -> Bool
    
    case combined([ChainFilterStrategy])
    
    case enabledChains
    case hasProxy
    case chainId(ChainModel.Id)
    case noFilter
    
    var filter: Filter {
        switch self {
        case .enabledChains: { $0.item?.syncMode.enabled() == true }
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
}
