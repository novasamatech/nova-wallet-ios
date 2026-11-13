import UIKit
import Foundation_iOS

final class GetTokenOptionsViewController: ModalPickerViewController<
    TokenOperationTableViewCell,
    TokenOperationTableViewCell.Model
> {
    let operationPresenter: GetTokenOptionsPresenterProtocol

    init(operationPresenter: GetTokenOptionsPresenterProtocol) {
        self.operationPresenter = operationPresenter

        let nib = R.nib.modalPickerViewController
        super.init(nibName: nib.name, bundle: nib.bundle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        operationPresenter.setup()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard viewModels[indexPath.row].value(for: selectedLocale).isActive else {
            return
        }

        operationPresenter.selectOption(at: indexPath.row)
    }
}

extension GetTokenOptionsViewController {
    func updatePreferredHeight(rowsCount: Int) {
        let height = headerHeight + CGFloat(rowsCount) * cellHeight + footerHeight

        guard preferredContentSize.height != height else {
            return
        }

        preferredContentSize = CGSize(width: 0.0, height: height)

        guard
            viewIfLoaded?.window != nil,
            let presentationController,
            let containerView = presentationController.containerView else {
            return
        }

        UIView.animate(withDuration: 0.25) {
            self.view.frame = presentationController.frameOfPresentedViewInContainerView
            containerView.layoutIfNeeded()
        }
    }
}

extension GetTokenOptionsViewController: GetTokenOptionsViewProtocol {
    func didReceive(viewModels: [LocalizableResource<TokenOperationTableViewCell.Model>]) {
        self.viewModels = viewModels

        reload()
        updatePreferredHeight(rowsCount: viewModels.count)
    }
}
