import UIKit
import SoraFoundation
import SoraUI

final class ExportGenericViewController: UIViewController, ImportantViewProtocol, ViewHolder {
    typealias RootViewType = ExportGenericViewLayout

    private enum Constants {
        static let verticalSpacing: CGFloat = 16.0
        static let topInset: CGFloat = 12.0
    }

    let presenter: ExportGenericPresenterProtocol

    let exportTitle: LocalizableResource<String>
    let exportSubtitle: LocalizableResource<String>?
    let exportHint: LocalizableResource<String>?
    let sourceTitle: LocalizableResource<String>
    let sourceHint: LocalizableResource<String>?
    let actionTitle: LocalizableResource<String>?
    let isSourceMultiline: Bool

    init(
        presenter: ExportGenericPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        exportTitle: LocalizableResource<String>,
        exportSubtitle: LocalizableResource<String>?,
        exportHint: LocalizableResource<String>?,
        sourceTitle: LocalizableResource<String>,
        sourceHint: LocalizableResource<String>?,
        actionTitle: LocalizableResource<String>?,
        isSourceMultiline: Bool
    ) {
        self.presenter = presenter
        self.exportTitle = exportTitle
        self.exportSubtitle = exportSubtitle
        self.exportHint = exportHint
        self.sourceTitle = sourceTitle
        self.sourceHint = sourceHint
        self.actionTitle = actionTitle
        self.isSourceMultiline = isSourceMultiline

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ExportGenericViewLayout()

        if actionTitle != nil {
            rootView.setupActionButton()
        }

        if isSourceMultiline {
            rootView.sourceDetailsLabel.numberOfLines = 0
        } else {
            rootView.sourceDetailsLabel.numberOfLines = 1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = exportTitle.value(for: selectedLocale)
        rootView.subtitleLabel.text = exportSubtitle?.value(for: selectedLocale)
        rootView.sourceTitleLabel.text = sourceTitle.value(for: selectedLocale)
        rootView.sourceHintLabel.text = sourceHint?.value(for: selectedLocale)
        rootView.hintLabel.text = exportHint?.value(for: selectedLocale)

        if let actionTitle = actionTitle?.value(for: selectedLocale) {
            rootView.actionButton?.imageWithTitleView?.title = actionTitle
        }
    }

    private func setupHandlers() {
        if let actionButton = rootView.actionButton {
            actionButton.addTarget(self, action: #selector(actionMain), for: .touchUpInside)
        }

        let advancedItem = UIBarButtonItem(
            image: R.image.iconOptions(),
            style: .plain,
            target: self,
            action: #selector(actionAdvancedSettings)
        )

        navigationItem.rightBarButtonItem = advancedItem
    }

    @objc private func actionAdvancedSettings() {
        presenter.activateAdvancedSettings()
    }

    @objc private func actionMain() {
        presenter.activateExport()
    }
}

extension ExportGenericViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension ExportGenericViewController: ExportGenericViewProtocol {
    func set(viewModel: ExportGenericViewModel) {
        rootView.sourceDetailsLabel.text = viewModel.sourceDetails
        view.setNeedsLayout()
    }
}
