import UIKit
import SoraFoundation

final class MessageSheetTimerLabel: UILabel, MessageSheetContentProtocol {
    typealias ContentViewModel = CountdownTimerMediator

    private lazy var viewModelFactory = TxExpirationViewModelFactory()
    private var viewModel: ContentViewModel?
    private var locale: Locale?

    private func updateView() {
        if
            let remainedInterval = viewModel?.remainedInterval,
            let locale = locale,
            let viewModel = try? viewModelFactory.createViewModel(from: remainedInterval) {
            bindTransaction(viewModel: viewModel, locale: locale)
        } else {
            text = ""
        }

        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        font = .regularFootnote
        textAlignment = .center
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(messageSheetContent: CountdownTimerMediator?, locale: Locale) {
        viewModel?.removeObserver(self)

        viewModel = messageSheetContent
        self.locale = locale
        messageSheetContent?.addObserver(self)

        updateView()
    }
}

extension MessageSheetTimerLabel: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateView()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateView()
    }

    func didStop(with _: TimeInterval) {
        updateView()
    }
}
