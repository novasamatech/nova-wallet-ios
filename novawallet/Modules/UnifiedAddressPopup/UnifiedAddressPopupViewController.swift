import UIKit

final class UnifiedAddressPopupViewController: UIViewController, ViewHolder {
    typealias RootViewType = UnifiedAddressPopupViewLayout

    let presenter: UnifiedAddressPopupPresenterProtocol

    init(presenter: UnifiedAddressPopupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UnifiedAddressPopupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
        presenter.setup()
    }
}

// MARK: Private

private extension UnifiedAddressPopupViewController {
    func setupActions() {
        rootView.newAddressContainer.addTarget(
            self,
            action: #selector(actionNewAddress),
            for: .touchUpInside
        )
        rootView.legacyAddressContainer.addTarget(
            self,
            action: #selector(actionLegacyAddress),
            for: .touchUpInside
        )
        rootView.button.addTarget(
            self,
            action: #selector(actionButton),
            for: .touchUpInside
        )
        rootView.checkBoxImageView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(actionCheckBox)
            )
        )
    }

    @objc func actionNewAddress() {
        presenter.copyNewAddress()
    }

    @objc func actionLegacyAddress() {
        presenter.copyLegacyAddress()
    }

    @objc func actionButton() {
        presenter.close()
    }

    @objc func actionCheckBox() {
        presenter.toggleHide()
    }
}

// MARK: UnifiedAddressPopupViewProtocol

extension UnifiedAddressPopupViewController: UnifiedAddressPopupViewProtocol {
    func didReceive(_ viewModel: UnifiedAddressPopup.ViewModel) {
        rootView.bind(viewModel)
    }
}
