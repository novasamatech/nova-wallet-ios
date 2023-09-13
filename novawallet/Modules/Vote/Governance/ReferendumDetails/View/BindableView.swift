import UIKit

protocol BindableView: UIView {
    associatedtype TModel
    func bind(viewModel: TModel)
}

extension BindableView {
    func bindOrHide(viewModel: TModel?) {
        if let viewModel = viewModel {
            isHidden = false
            bind(viewModel: viewModel)
        } else {
            isHidden = true
        }
    }
}

extension StackTitleValueDiffCell: BindableView {
    func bind(viewModel: ReferendumLockTransitionViewModel) {
        rowContentView.bind(viewModel: viewModel)
    }
}
