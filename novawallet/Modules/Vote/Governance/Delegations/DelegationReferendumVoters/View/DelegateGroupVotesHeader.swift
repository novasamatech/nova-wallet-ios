import UIKit
import UIKit_iOS

@objc protocol DelegateGroupVotesHeaderDelegate: DelegateInfoDelegate {
    func didTapOnActionControl(sender: DelegateGroupVotesHeader)
}

final class DelegateGroupVotesHeader: UICollectionReusableView {
    let delegateInfoView = DelegateInfoView()
    let actionTitleControl = DelegateGroupActionTitleControl()

    var votesView: UILabel {
        actionTitleControl.titleLabel
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

        setupLayout()
        applyStyle()
        actionTitleControl.addTarget(self, action: #selector(didTapOnActionControl), for: .touchUpInside)
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

    private func setupLayout() {
        addSubview(delegateInfoView)
        delegateInfoView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(actionTitleControl)
        actionTitleControl.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(delegateInfoView.snp.trailing).offset(8)
        }
    }

    private func applyStyle() {
        backgroundColor = .clear
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
