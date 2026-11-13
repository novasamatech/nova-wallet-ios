import UIKit

final class SwapTokenSelectChipsView: UIView {
    var onSelect: ((SwapTokenSelectChipViewModel.Kind) -> Void)?

    let scrollView: UIScrollView = .create { view in
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )
    }

    let stackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = Constants.spacing
    }

    private var chipViews: [SwapTokenSelectChipView] = []

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModels: [SwapTokenSelectChipViewModel]) {
        adjustChipViews(count: viewModels.count)

        zip(chipViews, viewModels).forEach { chipView, viewModel in
            chipView.bind(viewModel: viewModel)
        }
    }

    func scrollToStart() {
        scrollView.setContentOffset(
            CGPoint(x: -scrollView.contentInset.left, y: 0),
            animated: false
        )
    }
}

// MARK: Private

private extension SwapTokenSelectChipsView {
    func setupLayout() {
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.topInset)
            make.height.equalTo(Constants.chipHeight)
        }

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
    }

    func adjustChipViews(count: Int) {
        while chipViews.count > count {
            chipViews.removeLast().removeFromSuperview()
        }

        while chipViews.count < count {
            let chipView = SwapTokenSelectChipView()
            chipView.addTarget(self, action: #selector(actionChip(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(chipView)
            chipViews.append(chipView)
        }
    }

    @objc func actionChip(_ sender: SwapTokenSelectChipView) {
        scrollView.scrollRectToVisible(sender.frame, animated: true)
        onSelect?(sender.kind)
    }
}

// MARK: Constants

private extension SwapTokenSelectChipsView {
    enum Constants {
        static let height: CGFloat = 52
        static let topInset: CGFloat = 12
        static let chipHeight: CGFloat = 36
        static let spacing: CGFloat = 8
    }
}
