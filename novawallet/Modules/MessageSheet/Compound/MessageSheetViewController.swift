import UIKit
import Foundation_iOS
import UIKit_iOS
import Keystore_iOS

class MessageSheetViewController<
    I: UIView & MessageSheetGraphicsProtocol,
    C: UIView & MessageSheetContentProtocol
>: UIViewController, ViewHolder {
    typealias RootViewType = MessageSheetViewLayout<I, C>

    let basePresenter: MessageSheetPresenterProtocol
    let viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>

    var allowsSwipeDown: Bool = true
    var closeOnSwipeDownClosure: (() -> Void)?

    init(
        presenter: MessageSheetPresenterProtocol,
        viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>,
        localizationManager: LocalizationManagerProtocol
    ) {
        basePresenter = presenter
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

        let text = viewModel.message.value(for: selectedLocale)

        switch text {
        case let .raw(rawString):
            rootView.detailsLabel.text = rawString
        case let .attributed(text):
            rootView.detailsLabel.attributedText = text
        }

        if let action = viewModel.mainAction {
            rootView.mainActionButton?.imageWithTitleView?.title = action.title.value(for: selectedLocale)
            rootView.mainActionButton?.invalidateLayout()
        }

        if let action = viewModel.secondaryAction {
            rootView.secondaryActionButton?.imageWithTitleView?.title = action.title.value(for: selectedLocale)
            rootView.secondaryActionButton?.invalidateLayout()
        }
    }

    func setupHandlers() {
        if let mainAction = viewModel.mainAction {
            rootView.setupMainActionButton(for: mainAction.actionType)
            rootView.mainActionButton?.addTarget(self, action: #selector(actionMain), for: .touchUpInside)
        }

        if viewModel.secondaryAction != nil {
            rootView.setupSecondaryActionButton()
            rootView.secondaryActionButton?.addTarget(self, action: #selector(actionSecondary), for: .touchUpInside)
        }
    }

    @objc func actionMain() {
        basePresenter.goBack(with: viewModel.mainAction)
    }

    @objc func actionSecondary() {
        basePresenter.goBack(with: viewModel.secondaryAction)
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
