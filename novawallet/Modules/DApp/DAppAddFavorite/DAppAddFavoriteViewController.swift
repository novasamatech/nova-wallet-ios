import UIKit
import SoraFoundation

final class DAppAddFavoriteViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppAddFavoriteViewLayout

    let presenter: DAppAddFavoritePresenterProtocol

    private var titleViewModel: InputViewModelProtocol?
    private var addressViewModel: InputViewModelProtocol?

    init(presenter: DAppAddFavoritePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAddFavoriteViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.saveButton.target = self
        rootView.saveButton.action = #selector(actionSave)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.dappFavoriteAddTitle(preferredLanguages: languages)

        rootView.saveButton.title = R.string.localizable.commonSave(preferredLanguages: languages)
        rootView.titleLabel.text = R.string.localizable.commonTitle(preferredLanguages: languages)
        rootView.addressLabel.text = R.string.localizable.commonAddress(preferredLanguages: languages)
    }

    private func updateSaveButton() {
        if
            let titleViewModel = titleViewModel, titleViewModel.inputHandler.completed,
            let addressViewModel = addressViewModel, addressViewModel.inputHandler.completed {
            rootView.saveButton.isEnabled = true
        } else {
            rootView.saveButton.isEnabled = false
        }
    }

    @objc private func actionSave() {
        presenter.save()
    }
}

extension DAppAddFavoriteViewController: DAppAddFavoriteViewProtocol {
    func didReceive(iconViewModel: ImageViewModelProtocol) {
        let size = DAppAddFavoriteViewLayout.Constants.iconDisplaySize
        rootView.iconView.bind(viewModel: iconViewModel, size: size)
    }

    func didReceive(titleViewModel: InputViewModelProtocol) {
        self.titleViewModel?.inputHandler.removeObserver(self)
        self.titleViewModel = titleViewModel

        titleViewModel.inputHandler.addObserver(self)

        updateSaveButton()
    }

    func didReceive(addressViewModel: InputViewModelProtocol) {
        self.addressViewModel?.inputHandler.removeObserver(self)
        self.addressViewModel = addressViewModel

        addressViewModel.inputHandler.addObserver(self)

        updateSaveButton()
    }
}

extension DAppAddFavoriteViewController: InputHandlingObserver {
    func didChangeInputValue(_ handler: InputHandling, from oldValue: String) {
        updateSaveButton()
    }
}

extension DAppAddFavoriteViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
