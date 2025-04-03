import UIKit
import Foundation_iOS

final class TransferNetworkSelectionViewController: ModalPickerViewController<
    TransferNetworkSelectionCell, TransferNetworkSelectionViewModel
> {
    let viewModelPresenter: TransferNetworkSelectionPresenterProtocol

    init(viewModelPresenter: TransferNetworkSelectionPresenterProtocol) {
        self.viewModelPresenter = viewModelPresenter

        let nib = R.nib.modalPickerViewController
        super.init(nibName: nib.name, bundle: nib.bundle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModelPresenter.setup()
    }
}

extension TransferNetworkSelectionViewController: TransferNetworkSelectionViewProtocol {
    func didReceive(viewModels: [LocalizableResource<TransferNetworkSelectionViewModel>]) {
        self.viewModels = viewModels

        reload()
    }
}
