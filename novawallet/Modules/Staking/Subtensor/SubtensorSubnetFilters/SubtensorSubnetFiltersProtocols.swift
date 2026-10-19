import Foundation

struct SubtensorSubnetFiltersViewModel {
    let title: String
    let thinPoolsTitle: String
    let thinPoolsDetails: String
    let filters: SubtensorSubnetFilters
    let actionTitle: String
    let isLoading: Bool
}

protocol SubtensorSubnetFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorSubnetFiltersViewModel)
}

protocol SubtensorSubnetFiltersPresenterProtocol: AnyObject {
    func setup()
    func setHidesThinPools(_ value: Bool)
    func apply()
}

protocol SubtensorSubnetFiltersWireframeProtocol: AnyObject {
    func close(view: SubtensorSubnetFiltersViewProtocol?, completion: @escaping () -> Void)
}

protocol SubtensorSubnetFiltersDelegate: AnyObject {
    func countSubnets(matching filters: SubtensorSubnetFilters) -> Int?
    func didReceiveSubnet(filters: SubtensorSubnetFilters)
}
