import UIKit
import UIKit_iOS

protocol SearchViewProtocol: UIView {
    var searchBar: CustomSearchBar { get }
    var optionalCancelButton: RoundedButton? { get }
}

extension CustomSearchView: SearchViewProtocol {
    var optionalCancelButton: RoundedButton? {
        cancelButton
    }
}

extension TopCustomSearchView: SearchViewProtocol {
    var optionalCancelButton: RoundedButton? {
        nil
    }
}
