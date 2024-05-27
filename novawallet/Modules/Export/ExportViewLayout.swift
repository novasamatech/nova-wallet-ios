import UIKit

final class ExportViewLayout: ScrollableContainerLayoutView {
    lazy var networkView = AssetListChainView()
    lazy var networkContainerView: UIView = .create { [weak self] view in
        guard let self else { return }

        view.addSubview(networkView)

        networkView.snp.makeConstraints { make in
            make.leading.bottom.top.equalToSuperview()
        }
    }

    func bind(with viewModel: Model) {
        viewModel.sections.forEach { section in
            switch section {
            case let .networkView(model):
                addNetworkView(with: model)
            case let .headerTitle(text):
                addHeader(with: text, style: .boldTitle3Primary, spacingAfter: 12)
            case let .headerMessage(text):
                addHeader(with: text, style: .regularSubhedlineSecondary, spacingAfter: 32)
            case let .network(model):
                addArrangedSubviews(for: model)
            }
        }
    }

    func showSecret(
        _ secret: String,
        for chainName: String
    ) {
        let secretView = stackView
            .arrangedSubviews
            .compactMap { $0 as? ExportRowView }
            .first { view in
                guard case let .chainSecret(rowChainName) = view.type else {
                    return false
                }

                return chainName == rowChainName
            }

        secretView?.setShowingContent()
        secretView?.mainContentLabel.text = secret
    }
}

// MARK: Private

private extension ExportViewLayout {
    func addNetworkView(with viewModel: NetworkViewModel) {
        addArrangedSubview(networkContainerView, spacingAfter: 16)
        networkView.bind(viewModel: viewModel)
    }

    func addHeader(
        with text: String,
        style: UILabel.Style,
        spacingAfter: CGFloat
    ) {
        let header = createHeaderLabel(with: style, text: text)
        header.text = text
        addArrangedSubview(header, spacingAfter: spacingAfter)
    }

    func addArrangedSubviews(for network: NetworkModel) {
        addArrangedSubview(
            createHeaderLabel(with: .boldTitle3Primary, text: network.name),
            spacingAfter: 16
        )

        network.blocks.forEach { block in
            let resultView: UIView
            switch block {
            case let .secret(model):
                resultView = createSecretRow(with: model)
            case let .cryptoType(model):
                resultView = createCryptoTypeRow(with: model)
            case let .derivationPath(model):
                resultView = createDerivationPathRow(with: model)
            case let .jsonExport(model):
                resultView = createJSONExportRow(for: model)
            }

            addArrangedSubview(resultView, spacingAfter: 16)
        }
    }

    func createSecretRow(with model: NetworkModel.Secret) -> ExportRowView {
        .create { view in
            view.setContentSingleLabel()
            view.mainContentLabel.apply(style: .regularSubhedlinePrimary)
            view.leftTitle.text = model.blockLeftTitle
            view.rightTitle.text = model.blockRightTitle
            view.mainContentLabel.text = model.secret
            view.type = .chainSecret(chainName: model.chainName)
            view.coverView = createBlurCoverView(for: model)

            if model.hidden {
                view.setHiddenContent()
                view.isUserInteractionEnabled = true
            } else {
                view.isUserInteractionEnabled = false
            }
        }
    }

    func createCryptoTypeRow(with model: NetworkModel.CryptoType) -> ExportRowView {
        .create { view in
            view.setContentStackedLabels()
            view.mainContentLabel.text = model.contentMainText
            view.secondaryContentLabel.text = model.contentSecondaryText
            view.leftTitle.text = model.blockLeftTitle
        }
    }

    func createDerivationPathRow(with model: NetworkModel.DerivationPath) -> ExportRowView {
        .create { view in
            view.setContentSingleLabel()
            view.leftTitle.text = model.blockLeftTitle
            view.mainContentLabel.text = model.content
            view.isUserInteractionEnabled = false
        }
    }

    func createJSONExportRow(for model: NetworkModel.ExportJSON) -> ExportRowView {
        .create { view in
            view.setupButtonStyle()
            view.leftTitle.text = model.blockLeftTitle
            view.mainContentLabel.text = model.buttonTitle

            let tapGesture = BindableGestureRecognizer(action: model.action)
            view.addGestureRecognizer(tapGesture)
        }
    }

    func createBlurCoverView(for secretModel: NetworkModel.Secret) -> UIView {
        let imageView: UIImageView = .create { view in
            view.image = R.image.rawSeedBlur()
        }

        let titleView: UILabel = .create { view in
            view.apply(style: .semiboldFootnotePrimary)
            view.textAlignment = .center
            view.text = secretModel.coverText
        }

        imageView.addSubview(titleView)

        titleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        imageView.isUserInteractionEnabled = true
        let tapGesture = BindableGestureRecognizer(action: secretModel.onCoverTap)
        imageView.addGestureRecognizer(tapGesture)

        return imageView
    }

    func createHeaderLabel(
        with style: UILabel.Style,
        text: String
    ) -> UILabel {
        .create { view in
            view.apply(style: style)
            view.numberOfLines = 0
            view.textAlignment = .left
            view.text = text
        }
    }
}

// MARK: Model

extension ExportViewLayout {
    struct NetworkModel {
        enum Block {
            case secret(model: Secret)
            case jsonExport(model: ExportJSON)
            case cryptoType(model: CryptoType)
            case derivationPath(model: DerivationPath)
        }

        struct Secret {
            let blockLeftTitle: String
            let blockRightTitle: String?
            let hidden: Bool
            let coverText: String?
            let onCoverTap: () -> Void
            let secret: String?
            let chainName: String
        }

        struct ExportJSON {
            let blockLeftTitle: String
            let buttonTitle: String
            let action: () -> Void
        }

        struct CryptoType {
            let blockLeftTitle: String
            let contentMainText: String
            let contentSecondaryText: String
        }

        struct DerivationPath {
            let blockLeftTitle: String
            let content: String?
        }

        let name: String
        let blocks: [Block]
    }

    enum Section {
        case networkView(NetworkViewModel)
        case headerTitle(text: String)
        case headerMessage(text: String)
        case network(model: NetworkModel)
    }

    struct Model {
        let sections: [Section]
    }
}
