import Foundation
import SoraFoundation

protocol ReferendumTimelineViewModelFactoryProtocol {
    func createTimelineViewModel(
        for referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> [ReferendumTimelineView.Model]?
}

final class ReferendumTimelineViewModelFactory {
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let timeFormatter: LocalizableResource<DateFormatter>

    init(
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        timeFormatter: LocalizableResource<DateFormatter>
    ) {
        self.statusViewModelFactory = statusViewModelFactory
        self.timeFormatter = timeFormatter
    }

    private func createPreviousTime(
        atBlock: BlockNumber,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> String? {
        let date: Date

        if atBlock < currentBlock {
            let timeInterval = atBlock.secondsTo(block: currentBlock, blockDuration: blockTime)

            date = Date().addingTimeInterval(-timeInterval)
        } else {
            date = Date()
        }

        return timeFormatter.value(for: locale).string(from: date)
    }

    private func makeTimeViewModel(
        title: String,
        atBlock: BlockNumber?,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale,
        isLast: Bool = false
    ) -> ReferendumTimelineView.Model {
        let subtitle: ReferendumTimelineView.StatusSubtitle?

        if
            let atBlock = atBlock,
            let date = createPreviousTime(
                atBlock: atBlock,
                currentBlock: currentBlock,
                blockTime: blockTime,
                locale: locale
            ) {
            subtitle = .date(date)
        } else {
            subtitle = nil
        }

        return .init(title: title, subtitle: subtitle, isLast: isLast)
    }

    private func makeCreatedViewModel(
        atBlock: BlockNumber?,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        makeTimeViewModel(
            title: R.string.localizable.govTimelineCreated(preferredLanguages: locale.rLanguages),
            atBlock: atBlock,
            currentBlock: currentBlock,
            blockTime: blockTime,
            locale: locale
        )
    }

    private func createPreparing(
        model: ReferendumStateLocal.Preparing,
        referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        let status = statusViewModelFactory.createTimeViewModel(
            for: referendum,
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: locale
        )

        let votingTitle: String = model.inQueue ?
            R.string.localizable.governanceReferendumsStatusPreparingInqueue(preferredLanguages: locale.rLanguages) :
            R.string.localizable.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)

        let title = R.string.localizable.govTimelineVotingFormat(
            votingTitle.lowercased().firstLetterCapitalized(),
            preferredLanguages: locale.rLanguages
        )

        let subtitle = status.map { ReferendumTimelineView.StatusSubtitle.interval($0.viewModel) }

        return .init(
            title: title,
            subtitle: subtitle,
            isLast: false
        )
    }

    private func createDeciding(
        model: ReferendumStateLocal.Deciding,
        referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        let status = statusViewModelFactory.createTimeViewModel(
            for: referendum,
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: locale
        )

        let isPassing: Bool
        switch model.voting {
        case let .supportAndVotes(votingModel):
            isPassing = votingModel.isPassing(at: currentBlock)
        case let .threshold(votingModel):
            isPassing = votingModel.isPassing()
        }

        let votingTitle = isPassing ?
            R.string.localizable.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
            R.string.localizable.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)

        let title = R.string.localizable.govTimelineVotingFormat(
            votingTitle.lowercased().firstLetterCapitalized(),
            preferredLanguages: locale.rLanguages
        )

        let subtitle = status.map { ReferendumTimelineView.StatusSubtitle.interval($0.viewModel) }

        return .init(
            title: title,
            subtitle: subtitle,
            isLast: false
        )
    }

    private func createApprovedTitle(for locale: Locale) -> String {
        let votingTitle = R.string.localizable.governanceReferendumsStatusApproved(
            preferredLanguages: locale.rLanguages
        )

        return R.string.localizable.govTimelineVotedFormat(
            votingTitle.lowercased().firstLetterCapitalized(),
            preferredLanguages: locale.rLanguages
        )
    }

    private func createApproved(
        atBlock: BlockNumber?,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        let title = createApprovedTitle(for: locale)

        return makeTimeViewModel(
            title: title,
            atBlock: atBlock,
            currentBlock: currentBlock,
            blockTime: blockTime,
            locale: locale
        )
    }

    private func createApproved(
        referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        let status = statusViewModelFactory.createTimeViewModel(
            for: referendum,
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: locale
        )

        let title = createApprovedTitle(for: locale)

        let subtitle = status.map { ReferendumTimelineView.StatusSubtitle.interval($0.viewModel) }

        return .init(
            title: title,
            subtitle: subtitle,
            isLast: false
        )
    }

    private func createVotedTerminal(
        status: String,
        atBlock: BlockNumber,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumTimelineView.Model {
        let date = createPreviousTime(
            atBlock: atBlock,
            currentBlock: currentBlock,
            blockTime: blockTime,
            locale: locale
        )

        let title = R.string.localizable.govTimelineVotedFormat(
            status.lowercased().firstLetterCapitalized(),
            preferredLanguages: locale.rLanguages
        )

        let subtitle = date.map { ReferendumTimelineView.StatusSubtitle.date($0) }

        return .init(title: title, subtitle: subtitle, isLast: true)
    }

    private func createExecutedViewModels(
        metadata: ReferendumMetadataLocal?,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> [ReferendumTimelineView.Model] {
        let approvedBlock = metadata?.timeline?.first(
            where: { $0.status == ReferendumMetadataStatus.passed.rawValue }
        )?.block

        let approved = createApproved(
            atBlock: approvedBlock,
            currentBlock: currentBlock,
            blockTime: blockTime,
            locale: locale
        )

        let executedBlock = metadata?.timeline?.first(
            where: { $0.status == ReferendumMetadataStatus.executed.rawValue }
        )?.block

        let executedTitle = R.string.localizable.governanceReferendumsStatusExecuted(
            preferredLanguages: locale.rLanguages
        ).firstLetterCapitalized()

        let executed = makeTimeViewModel(
            title: executedTitle,
            atBlock: executedBlock,
            currentBlock: currentBlock,
            blockTime: blockTime,
            locale: locale,
            isLast: true
        )

        return [approved, executed]
    }
}

extension ReferendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func createTimelineViewModel(
        for referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> [ReferendumTimelineView.Model]? {
        var createdAt: BlockNumber?

        let models: [ReferendumTimelineView.Model]

        switch referendum.state {
        case let .preparing(model):
            createdAt = model.since

            let preparing = createPreparing(
                model: model,
                referendum: referendum,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [preparing]
        case let .deciding(model):
            createdAt = model.submitted

            let deciding = createDeciding(
                model: model,
                referendum: referendum,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [deciding]
        case .approved:
            let approved = createApproved(
                referendum: referendum,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [approved]
        case let .rejected(model):
            let rejected = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages),
                atBlock: model.atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [rejected]
        case let .cancelled(model):
            let cancelled = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusCancelled(
                    preferredLanguages: locale.rLanguages
                ),
                atBlock: model.atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [cancelled]
        case let .killed(atBlock):
            let killed = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages),
                atBlock: atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [killed]
        case let .timedOut(model):
            let timedOut = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages),
                atBlock: model.atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [timedOut]
        case .executed:
            models = createExecutedViewModels(
                metadata: metadata,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )
        }

        if createdAt == nil {
            createdAt = metadata?.timeline?.first(
                where: { $0.status == ReferendumMetadataStatus.started.rawValue }
            )?.block
        }

        let created = makeCreatedViewModel(
            atBlock: createdAt,
            currentBlock: currentBlock,
            blockTime: blockDuration,
            locale: locale
        )

        return [created] + models
    }
}
