import Foundation
import UIKit
import UIKit_iOS
import Foundation_iOS

protocol EstimatedCountdownViewModelFactoryProtocol {
    func createViewModel(
        from remainedInterval: TimeInterval,
        locale: Locale
    ) throws -> String
}

final class EstimatedCountdownViewModelFactory {
    let timeFormatter: TimeFormatterProtocol

    init(timeFormatter: TimeFormatterProtocol = TotalTimeFormatter()) {
        self.timeFormatter = timeFormatter
    }
}

extension EstimatedCountdownViewModelFactory: EstimatedCountdownViewModelFactoryProtocol {
    func createViewModel(
        from remainedInterval: TimeInterval,
        locale: Locale
    ) throws -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.commonEstimatedTimer(
            try timeFormatter.string(from: remainedInterval)
        )
    }
}

class MessageSheetTimerLabel: UILabel, MessageSheetContentProtocol {
    typealias ContentViewModel = CountdownTimerMediator

    private(set) var viewModel: ContentViewModel?
    private(set) var locale: Locale?

    private lazy var viewModelFactory: EstimatedCountdownViewModelFactoryProtocol = {
        EstimatedCountdownViewModelFactory(timeFormatter: MinuteSecondFormatter())
    }()

    func updateView() {
        guard
            let remainedInterval = viewModel?.remainedInterval,
            let locale,
            let text = try? viewModelFactory.createViewModel(from: remainedInterval, locale: locale)
        else {
            text = ""

            return
        }

        self.text = text

        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        apply(style: .footnoteSecondary)
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
