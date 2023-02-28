import UIKit
import SoraUI

@objc protocol DelegateGroupVotesHeaderDelegate: DelegateInfoDelegate {
    func didTapOnActionControl(sender: DelegateGroupVotesHeader)
}

final class DelegateGroupVotesHeader: UICollectionReusableView {
    typealias ContentView = GenericTitleValueView<DelegateInfoView, ActionTitleControl>

    let baseView = ContentView()

    var delegateInfoView: DelegateInfoView {
        baseView.titleView
    }

    var votesView: UILabel {
        actionTitleControl.titleLabel
    }

    var actionTitleControl: ActionTitleControl {
        baseView.valueView
    }

    var id: Int? {
        didSet {
            delegateInfoView.id = id
        }
    }

    weak var delegate: DelegateGroupVotesHeaderDelegate? {
        didSet {
            delegateInfoView.delegate = delegate
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(baseView)
        baseView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        actionTitleControl.addTarget(self, action: #selector(didTapOnActionControl), for: .touchUpInside)
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        actionTitleControl.deactivate(animated: false)
    }

    @objc private func didTapOnActionControl() {
        delegate?.didTapOnActionControl(sender: self)
    }

    private func applyStyle() {
        backgroundColor = .clear

        let tintColor = R.color.colorTextPrimary()!
        actionTitleControl.titleLabel.apply(style: .footnotePrimary)
        actionTitleControl.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        actionTitleControl.identityIconAngle = CGFloat.pi / 2.0
        actionTitleControl.activationIconAngle = -CGFloat.pi / 2.0
        actionTitleControl.titleLabel.apply(style: .footnotePrimary)
        actionTitleControl.horizontalSpacing = 0.0
        actionTitleControl.imageView.isUserInteractionEnabled = false
        actionTitleControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        delegateInfoView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}

extension DelegateGroupVotesHeader {
    struct Model: Equatable {
        let delegateInfo: DelegateInfoView.Model
        let votes: String
    }

    func bind(viewModel: Model) {
        delegateInfoView.bind(viewModel: viewModel.delegateInfo)
        votesView.text = viewModel.votes
        actionTitleControl.invalidateLayout()
        setNeedsLayout()
    }
}
