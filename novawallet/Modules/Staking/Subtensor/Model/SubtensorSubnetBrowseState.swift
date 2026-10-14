import Foundation

final class SubtensorSubnetBrowseState {
    var sort: SubtensorSubnetSort
    var filters: SubtensorSubnetFilters
    var orderedRefs: [SubtensorSubnetRef] = []

    init(order: SubtensorQuickPickOrder? = nil) {
        sort = order?.subnetSort ?? .sevenDayChange
        filters = SubtensorSubnetFilters(hideThinPools: order?.subnetSort != nil)
    }
}
