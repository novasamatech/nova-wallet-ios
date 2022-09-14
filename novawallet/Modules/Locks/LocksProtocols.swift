import UIKit

protocol LocksViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [LocksViewSectionModel])
    func updateHeader(title: String, value: String)
    func calculateEstimatedHeight(sections: Int, items: Int) -> CGFloat
}

protocol LocksPresenterProtocol: AnyObject {
    func setup()
    func didTapOnCell()
}

protocol LocksWireframeProtocol: AnyObject {
    func close(view: LocksViewProtocol?)
}

struct LocksViewSectionModel: SectionProtocol, Hashable {
    let header: HeaderViewModel
    var cells: [CellViewModel]

    struct HeaderViewModel: Hashable {
        let icon: UIImage?
        let title: String
        let details: String
        let value: String
    }

    struct CellViewModel: Hashable {
        let id: String
        let title: String
        let value: String
        let price: Decimal
    }
}
