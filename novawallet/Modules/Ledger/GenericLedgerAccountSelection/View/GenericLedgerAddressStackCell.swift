import UIKit

final class GenericLedgerAddressStackCell: RowView<UIView> {
    private var detailsView: UIView?

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 52.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: GenericLedgerAddressViewModel, locale: Locale) {
        switch viewModel.existence {
        case let .found(found):
            bindFoundAddress(
                for: .init(
                    title: viewModel.title,
                    accessoryViewModel: .init(
                        details: found.address,
                        imageViewModel: found.icon
                    )
                )
            )
        case .notFound:
            bindNotFoundAddress(for: viewModel.title, locale: locale)
        }
    }
}

private extension GenericLedgerAddressStackCell {
    func getOrCreateDetailsView<T: UIView>() -> T {
        if let targetView = detailsView as? T {
            return targetView
        }

        detailsView?.removeFromSuperview()

        let targetView = T()

        rowContentView.addSubview(targetView)

        targetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        return targetView
    }

    func bindFoundAddress(for viewModel: GenericLedgerFoundAddressContentView.ViewModel) {
        let targetView: GenericLedgerFoundAddressContentView = getOrCreateDetailsView()

        targetView.bind(viewModel: viewModel)
    }

    func bindNotFoundAddress(for title: String, locale: Locale) {
        let targetView: GenericLedgerNotFoundAddressContentView = getOrCreateDetailsView()

        targetView.bind(title: title, locale: locale)
    }
}

extension GenericLedgerAddressStackCell: StackTableViewCellProtocol {}
