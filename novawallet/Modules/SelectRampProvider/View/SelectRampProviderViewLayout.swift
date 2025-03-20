import UIKit

protocol SelectRampProviderViewLayoutDelegate: AnyObject {
    func didSelectProvider(with id: String)
}

final class SelectRampProviderViewLayout: ScrollableContainerLayoutView {
    weak var delegate: SelectRampProviderViewLayoutDelegate?

    let titleView: StackTableHeaderCell = .create { view in
        view.titleLabel.apply(style: .title3Primary)
        view.titleLabel.numberOfLines = 0
        view.contentInsets = .zero
    }

    let disclaimerView: StackTableHeaderCell = .create { view in
        view.titleLabel.apply(style: .caption1Secondary)
        view.titleLabel.numberOfLines = 0
        view.contentInsets = .zero
    }

    var providerViews: [RowView<RampProviderView>] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension SelectRampProviderViewLayout {
    func createProviderViews(
        for viewModels: [SelectRampProvider.ViewModel.ProviderViewModel]
    ) -> [RowView<RampProviderView>] {
        viewModels.map { providerModel in
            let view: RowView<RampProviderView> = .create { rowView in
                rowView.contentInsets = .init(inset: Constants.providerContainerContentInset)
                rowView.roundedBackgroundView.apply(style: .roundedLightCell)
            }

            view.rowContentView.bind(with: providerModel)

            view.addTarget(
                self,
                action: #selector(actionSelectProvider),
                for: .touchUpInside
            )

            return view
        }
    }

    @objc func actionSelectProvider(_ sender: UIControl) {
        guard
            let rowView = sender as? RowView<RampProviderView>,
            let viewModel = rowView.rowContentView.viewModel
        else { return }

        delegate?.didSelectProvider(with: viewModel.id)
    }
}

// MARK: Internal

extension SelectRampProviderViewLayout {
    func bind(with model: SelectRampProvider.ViewModel) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let providerViews = createProviderViews(for: model.providers)

        addArrangedSubview(titleView, spacingAfter: Constants.titleBottomInset)

        providerViews
            .enumerated()
            .forEach { index, providerView in
                let spacingAfter = index < providerViews.count - 1
                    ? Constants.providersSpacing
                    : Constants.providersBottomInset

                addArrangedSubview(
                    providerView,
                    spacingAfter: spacingAfter
                )
            }

        addArrangedSubview(disclaimerView)

        titleView.titleLabel.text = model.titleText
        disclaimerView.titleLabel.text = model.footerText
    }
}

// MARK: Constants

private extension SelectRampProviderViewLayout {
    enum Constants {
        static let titleTopInset: CGFloat = 16.0
        static let titleBottomInset: CGFloat = 16.0
        static let providersSpacing: CGFloat = 8.0
        static let providersBottomInset: CGFloat = 16.0
        static let providerContainerContentInset: CGFloat = 16.0
    }
}
