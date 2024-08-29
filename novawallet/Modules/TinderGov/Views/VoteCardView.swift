import SnapKit
import UIKit
import SoraUI

typealias ReportEvidenceAction = () -> Void
typealias SkipEvidenceAction = () -> Void

struct VoteCardModel {
    let viewModel: VoteCardView.ViewModel
    let voteAction: CaseVoteCompletion
    let reportAction: CaseReportCompletion
    let skipAction: CaseReportCompletion
}

final class VoteCardView: RoundedView {
    struct ViewModel {
        let caseIndex: MobRulePallet.CaseIndex
        let voteMedia: VoteMediaContainer.ViewModel
        let title: String
        let instructions: String
        let isSensitive: Bool
    }

    private enum Constants {
        static let topAnimationInset: CGFloat = -500
        static let bottomAnimationInset: CGFloat = -400
        static let hideInstructionsBottomInset: CGFloat = 36
        static let titleAndMediaSpacing: CGFloat = -24
        static let videoCountdownBottomInset: CGFloat = 16
        static let overlayAnimationDuration: TimeInterval = 0.3
    }

    private var isMinimumTimeWatched: Bool?
    private var showsReport: Bool = false
    private let title: UILabel = .create { view in
        view.apply(style: .titleLPrimary)
        view.textAlignment = .left
    }

    private lazy var expandableInstructions: ExpandableLabel = {
        let instructions = ExpandableLabel()
        instructions.apply(style: .body16Secondary)
        instructions.use(delegate: self)
        return instructions
    }()

    private let hideInstructions: DesignSystemButton = .create { view in
        view.apply(style: .fill6)
        view.setTitle(R.string.localizable.voteEvidenceActionHideText(), for: .normal)
    }

    private let votingButtonsContainer: VotingButtonsContainer = .init()
    private var mediaContainerTop: Constraint?
    private var titleAndMediaSpacing: Constraint?
    private var buttonsContainerBottom: Constraint?
    private var videoCountdownBottom: Constraint?
    private var hideInstructionsBottom: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func bind(action: @escaping VoteAction) {
        votingButtonsContainer.bind(action: action)
    }

    func bind(reportAction: @escaping ReportEvidenceAction) {
        reportButton.addAction(UIAction(handler: { _ in reportAction() }), for: .touchUpInside)
    }

    func bind(skipAction: @escaping SkipEvidenceAction) {
        nextEvidenceButton.addAction(UIAction(handler: { _ in skipAction() }), for: .touchUpInside)
    }

    func bind(viewModel: ViewModel) {
        mediaContainer.bind(viewModel: viewModel.voteMedia)
        title.text = viewModel.title
        expandableInstructions.fullText = viewModel.instructions
        mediaContainer.use(delegate: self)
        switch viewModel.voteMedia.media {
        case .image:
            ()
        case let .video(_, minimumWatchTime):
            isMinimumTimeWatched = false
            videoCountdown.text = String(minimumWatchTime)
            buttonsContainerBottom?.update(inset: Constants.bottomAnimationInset)
            videoCountdownView.isHidden = false
        }
        sensitiveContentView.isHidden = !viewModel.isSensitive
    }
}

extension VoteCardView: CardStackable {
    func didBecomeTopView() {
        mediaContainer.activateMedia()
    }

    func prepareForReuse() {
        mediaContainer.prepareForReuse()
        title.text = nil
        expandableInstructions.fullText = ""
        videoCountdownView.isHidden = true
        videoCountdown.text = nil
        isMinimumTimeWatched = nil
        showsReport = false
        reportView.isHidden = true
        sensitiveContentView.isHidden = true
        mediaContainerTop?.update(inset: 0)
        titleAndMediaSpacing?.isActive = true
        buttonsContainerBottom?.update(inset: 0)
        videoCountdownBottom?.update(inset: Constants.videoCountdownBottomInset)
        hideInstructionsBottom?.update(inset: Constants.bottomAnimationInset)
        reportButton.removeTarget(nil, action: nil, for: .allEvents)
        cancelReportButton.removeTarget(nil, action: nil, for: .allEvents)
        nextEvidenceButton.removeTarget(nil, action: nil, for: .allEvents)
        showSensitiveContentButton.removeTarget(nil, action: nil, for: .allEvents)
    }
}

extension VoteCardView: VoteVideoPreviewDelegate {
    func videoPlaybackTimeUpdated(timeRemaining remainingSeconds: Int) {
        videoCountdown.text = String(remainingSeconds)
        if remainingSeconds <= 0, isMinimumTimeWatched != true {
            isMinimumTimeWatched = true
            videoCountdown.text = String(remainingSeconds)
            UIView.animate(withDuration: 0.3) {
                self.buttonsContainerBottom?.update(inset: 0)
                self.videoCountdownBottom?.update(inset: Constants.bottomAnimationInset)
                self.layoutIfNeeded()
            } completion: { _ in
                self.videoCountdownView.isHidden = true
            }
        }
    }
}

extension VoteCardView: VotingCardDelegate {
    func didStart(vote: VoteResult) {
        mediaContainer.animateOverlay(for: vote)
    }

    func didCancel(vote _: VoteResult) {
        mediaContainer.resetVoteAnimation()
    }

    func didEnd(vote _: VoteResult) {}
}

extension VoteCardView: ExpandableLabelDelegate {
    func willExpandText() {
        mediaContainer.pauseMedia()
    }

    func didExpandText() {
        UIView.animate(withDuration: 0.3) {
            self.mediaContainerTop?.update(inset: Constants.topAnimationInset)
            self.titleAndMediaSpacing?.isActive = false
            self.hideInstructionsBottom?.update(inset: Constants.hideInstructionsBottomInset)
            if let isMinimumTimeWatched = self.isMinimumTimeWatched, isMinimumTimeWatched == false {
                self.videoCountdownBottom?.update(inset: Constants.bottomAnimationInset)
            } else {
                self.buttonsContainerBottom?.update(inset: Constants.bottomAnimationInset)
            }
            self.layoutIfNeeded()
        }
    }

    func didCollapsedText() {
        UIView.animate(withDuration: 0.3) {
            self.mediaContainerTop?.update(inset: 0)
            self.titleAndMediaSpacing?.isActive = true
            if let isMinimumTimeWatched = self.isMinimumTimeWatched, isMinimumTimeWatched == false {
                self.videoCountdownBottom?.update(inset: Constants.videoCountdownBottomInset)
            } else {
                self.buttonsContainerBottom?.update(inset: 0)
            }
            self.hideInstructionsBottom?.update(inset: Constants.bottomAnimationInset)
            self.layoutIfNeeded()
        }
    }
}

private extension VoteCardView {
    func setupLayout() {
        clipsToBounds = true
        applyBackgroundStyle(.color717A7C, cornerRadius: 24)
        layer.insertSublayer(gradientLayer, at: 0)

        addSubview(mediaContainer)
        addSubview(title)
        addSubview(expandableInstructions)
        addSubview(votingButtonsContainer)
        addSubview(videoCountdownView)
        addSubview(hideInstructions)
        addSubview(reportView)
        addSubview(sensitiveContentView)
        mediaContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            self.mediaContainerTop = make.top.equalToSuperview().constraint
            make.width.equalToSuperview()
            make.height.equalTo(mediaContainer.snp.width)
        }
        title.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(expandableInstructions.snp.top).inset(-16)
            self.titleAndMediaSpacing = make.top.equalTo(mediaContainer.snp.bottom)
                .inset(Constants.titleAndMediaSpacing).constraint
        }
        expandableInstructions.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(120)
        }
        votingButtonsContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            self.buttonsContainerBottom = make.bottom.equalToSuperview().constraint
        }
        videoCountdownView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            self.videoCountdownBottom = make.bottom.equalToSuperview().inset(Constants.videoCountdownBottomInset)
                .constraint
        }
        hideInstructions.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(24)
            self.hideInstructionsBottom = make.bottom.equalToSuperview().inset(Constants.bottomAnimationInset)
                .constraint
        }
        reportView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        sensitiveContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        votingButtonsContainer.set(delegate: self)
    }

    func setupActions() {
        hideInstructions.addTarget(self, action: #selector(collapseInstructions), for: .touchUpInside)
        mediaContainer.reportContent.addAction(toggleReportOverlay(), for: .touchUpInside)
        cancelReportButton.addAction(toggleReportOverlay(), for: .touchUpInside)
        showSensitiveContentButton.addAction(hideSensitiveOverlay(), for: .touchUpInside)
    }

    @objc
    func collapseInstructions() {
        expandableInstructions.collapse()
    }

    func toggleReportOverlay() -> UIAction {
        UIAction { [weak self] _ in
            guard let self else { return }
            showsReport.toggle()
            if showsReport {
                mediaContainer.pauseMedia()
            } else {
                mediaContainer.activateMedia()
            }
            UIView.animate(withDuration: Constants.overlayAnimationDuration) { [weak self] in
                guard let self else { return }
                reportView.isHidden = !showsReport
            }
        }
    }

    func hideSensitiveOverlay() -> UIAction {
        UIAction { [weak self] _ in
            guard let self else { return }
            UIView.animate(withDuration: Constants.overlayAnimationDuration) { [weak self] in
                self?.sensitiveContentView.isHidden = false
            }
        }
    }
}
