import Foundation
import NovaAnalytics

final class SubtensorValidationReporter: AnalyticsTracking {
    let flow: StakingFlow
    let stage: StakingValidationStage
    let target: StakingAnalyticsTarget?
    let walletType: AnalyticsWalletType?

    private var pendingKind: StakingValidationKind?

    init(
        flow: StakingFlow,
        stage: StakingValidationStage,
        target: StakingAnalyticsTarget?,
        walletType: AnalyticsWalletType?
    ) {
        self.flow = flow
        self.stage = stage
        self.target = target
        self.walletType = walletType
    }

    deinit {
        if let pendingKind {
            report(pendingKind, outcome: .cancelled)
        }
    }

    func blocked(_ kind: StakingValidationKind) {
        report(kind, outcome: .blocked)
    }

    func shown(_ kind: StakingValidationKind) {
        guard pendingKind != kind else {
            return
        }

        if let pendingKind {
            report(pendingKind, outcome: .cancelled)
        }

        pendingKind = kind
    }

    func proceeded() {
        guard let pendingKind else {
            return
        }

        self.pendingKind = nil
        report(pendingKind, outcome: .proceeded)
    }

    func tradesUnavailable() {
        trackAnalytics(
            .subtensorStakingBlocked(flow: flow, reason: .tradesUnavailable, walletType: walletType, target: target)
        )
    }

    private func report(_ kind: StakingValidationKind, outcome: StakingValidationOutcome) {
        trackAnalytics(
            .subtensorValidationShown(flow: flow, kind: kind, stage: stage, outcome: outcome, target: target)
        )
    }
}

extension DataValidating {
    func reporting(_ kind: StakingValidationKind, to reporter: SubtensorValidationReporter?) -> DataValidating {
        guard let reporter else {
            return self
        }

        return SubtensorReportingValidation(
            inner: self,
            reporter: reporter,
            onError: { $0.blocked(kind) },
            onWarning: { $0.shown(kind) }
        )
    }

    func reportingTradesUnavailable(to reporter: SubtensorValidationReporter?) -> DataValidating {
        guard let reporter else {
            return self
        }

        return SubtensorReportingValidation(
            inner: self,
            reporter: reporter,
            onError: { $0.tradesUnavailable() },
            onWarning: { _ in }
        )
    }
}

extension SubtensorQuoteValidatingContext {
    func reporting(to reporter: SubtensorValidationReporter?) -> SubtensorQuoteValidatingContext {
        guard let reporter else {
            return self
        }

        var context = self
        context.onRateUpdateShown = { reporter.shown(.rateUpdated) }
        context.onLiquidityShown = { reporter.blocked(.liquidity) }
        return context
    }
}

private final class SubtensorReportingValidation: DataValidating {
    let inner: DataValidating
    let reporter: SubtensorValidationReporter
    let onError: (SubtensorValidationReporter) -> Void
    let onWarning: (SubtensorValidationReporter) -> Void

    init(
        inner: DataValidating,
        reporter: SubtensorValidationReporter,
        onError: @escaping (SubtensorValidationReporter) -> Void,
        onWarning: @escaping (SubtensorValidationReporter) -> Void
    ) {
        self.inner = inner
        self.reporter = reporter
        self.onError = onError
        self.onWarning = onWarning
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        let problem = inner.validate(notifying: SubtensorReportingDelegate(delegate: delegate, reporter: reporter))

        switch problem {
        case .error:
            onError(reporter)
        case .warning:
            onWarning(reporter)
        case .asyncProcess, .none:
            break
        }

        return problem
    }
}

private final class SubtensorReportingDelegate: DataValidatingDelegate {
    let delegate: DataValidatingDelegate
    let reporter: SubtensorValidationReporter

    init(delegate: DataValidatingDelegate, reporter: SubtensorValidationReporter) {
        self.delegate = delegate
        self.reporter = reporter
    }

    func didCompleteWarningHandling() {
        reporter.proceeded()
        delegate.didCompleteWarningHandling()
    }

    func didCompleteAsyncHandling() {
        reporter.proceeded()
        delegate.didCompleteAsyncHandling()
    }
}
