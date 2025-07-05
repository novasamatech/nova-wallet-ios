import UIKit
import UIKit_iOS

final class MultisigTxDetailsViewLayout: UIView {
    let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        return view
    }()

    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorContainerBackground()!
        view.highlightedFillColor = R.color.colorContainerBackground()!
        view.strokeColor = R.color.colorContainerBorder()!
        view.highlightedStrokeColor = R.color.colorContainerBorder()!
        view.strokeWidth = 0.5
        view.cornerRadius = 12.0
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: .sourceCodePrimary)
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        scrollView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.width.equalTo(self).offset(-32.0)
            make.bottom.equalToSuperview().inset(16.0)
        }

        backgroundView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(12.0)
        }
    }
}
