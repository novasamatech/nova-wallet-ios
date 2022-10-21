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

extension RowView: BindableView where T: BindableView {
    typealias TModel = T.TModel

    func bind(viewModel: TModel) {
        rowContentView.bind(viewModel: viewModel)
    }
}
