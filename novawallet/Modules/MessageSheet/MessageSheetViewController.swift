import UIKit
import SoraFoundation
import SoraUI

final class MessageSheetViewController<
    I: UIView & MessageSheetGraphicsProtocol,
    C: UIView & MessageSheetContentProtocol
>: UIViewController, ViewHolder {
    typealias RootViewType = MessageSheetViewLayout<I, C>

    let presenter: MessageSheetPresenterProtocol
    let viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>

    var allowsSwipeDown: Bool = true
    var closeOnSwipeDownClosure: (() -> Void)?

    init(
        presenter: MessageSheetPresenterProtocol,
        viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MessageSheetViewLayout<I, C>()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
    }

    private func setupLocalization() {
        rootView.graphicsView.bind(messageSheetGraphics: viewModel.graphics, locale: selectedLocale)
        rootView.contentView.bind(messageSheetContent: viewModel.content, locale: selectedLocale)

        rootView.titleLabel.text = viewModel.title.value(for: selectedLocale)
        rootView.detailsLabel.text = viewModel.message.value(for: selectedLocale)

        if let action = viewModel.mainAction {
            rootView.mainActionButton?.imageWithTitleView?.title = action.title.value(for: selectedLocale)
            rootView.mainActionButton?.invalidateLayout()
        }

        if let action = viewModel.secondaryAction {
            rootView.secondaryActionButton?.imageWithTitleView?.title = action.title.value(for: selectedLocale)
            rootView.secondaryActionButton?.invalidateLayout()
        }
    }

    private func setupHandlers() {
        if viewModel.mainAction != nil {
            rootView.setupMainActionButton()
            rootView.mainActionButton?.addTarget(self, action: #selector(actionMain), for: .touchUpInside)
        }

        if viewModel.secondaryAction != nil {
            rootView.setupSecondaryActionButton()
            rootView.secondaryActionButton?.addTarget(self, action: #selector(actionSecondary), for: .touchUpInside)
        }
    }

    @objc private func actionMain() {
        presenter.goBack(with: viewModel.mainAction)
    }

    @objc private func actionSecondary() {
        presenter.goBack(with: viewModel.secondaryAction)
    }
}

extension MessageSheetViewController: MessageSheetViewProtocol {}

extension MessageSheetViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool {
        allowsSwipeDown
    }

    func presenterDidHide(_: ModalPresenterProtocol) {
        closeOnSwipeDownClosure?()
    }
}

extension MessageSheetViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
