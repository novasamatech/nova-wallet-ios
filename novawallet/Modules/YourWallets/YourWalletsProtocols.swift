import UIKit
protocol YourWalletsViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [YourWalletsViewSectionModel])
}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
    func didSelect(viewModel: YourWalletsViewModelCell.CommonModel)
}

protocol YourWalletsWireframeProtocol: AnyObject {}

protocol YourWalletsDelegate: AnyObject {
    func selectWallet(address: AccountAddress)
}

struct YourWalletsViewSectionModel: Hashable, SectionProtocol {
    let header: HeaderModel?
    var cells: [YourWalletsViewModelCell]

    struct HeaderModel: Hashable {
        let title: String
        let icon: UIImage?
    }
}

enum YourWalletsViewModelCell: Hashable {
    case common(CommonModel)
    case notFound(NotFoundModel)
}

extension YourWalletsViewModelCell {
    struct NotFoundModel: Hashable {
        let name: String?
        let imageViewModel: DrawableIconViewModel?
        
        func hash(into hasher: inout Hasher) {
            //TODO
        }
        
        static func == (lhs: NotFoundModel, rhs: NotFoundModel) -> Bool {
            rhs.name == lhs.name
        }
    }
    
    struct CommonModel: Hashable {
        let displayAddress: DisplayAddress
        let imageViewModel: DrawableIconViewModel?
        let isSelected: Bool
        
        func hash(into hasher: inout Hasher) {
            //TODO
        }
        
        static func == (lhs: CommonModel, rhs: CommonModel) -> Bool {
            rhs.displayAddress == lhs.displayAddress && rhs.isSelected == lhs.isSelected
        }
    }
}

extension DisplayAddress: Hashable {
    func hash(into hasher: inout Hasher) {
        //TODO
    }
    
    static func == (lhs: DisplayAddress, rhs: DisplayAddress) -> Bool {
        lhs.address == rhs.address && lhs.username == rhs.username
    }
}
