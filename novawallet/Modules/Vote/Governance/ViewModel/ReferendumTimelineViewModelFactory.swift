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

    private func makeCreatedViewModel(
        atBlock: BlockNumber?,
        currentBlock: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
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

        return .init(
            title: R.string.localizable.govTimelineCreated(preferredLanguages: locale.rLanguages),
            subtitle: subtitle,
            isLast: false
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

        switch model.voting {
        case let .supportAndVotes(votingModel):
            let isPassing = votingModel.isPassing(at: currentBlock)
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
}

extension ReferendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol {
    func createTimelineViewModel(
        for referendum: ReferendumLocal,
        metadata _: ReferendumMetadataLocal?,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> [ReferendumTimelineView.Model]? {
        let createdAt: BlockNumber?

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
            createdAt = nil

            let approved = createApproved(
                referendum: referendum,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [approved]
        case let .rejected(model):
            createdAt = nil

            let rejected = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages),
                atBlock: model.atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [rejected]
        case let .cancelled(model):
            createdAt = nil

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
            createdAt = nil

            let killed = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages),
                atBlock: atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [killed]
        case let .timedOut(model):
            createdAt = nil

            let timedOut = createVotedTerminal(
                status: R.string.localizable.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages),
                atBlock: model.atBlock,
                currentBlock: currentBlock,
                blockTime: blockDuration,
                locale: locale
            )

            models = [timedOut]
        case .executed:
            createdAt = nil

            let approved = ReferendumTimelineView.Model(
                title: createApprovedTitle(for: locale),
                subtitle: nil,
                isLast: false
            )

            let executed = ReferendumTimelineView.Model(
                title: R.string.localizable.governanceReferendumsStatusExecuted(
                    preferredLanguages: locale.rLanguages
                ).firstLetterCapitalized(),
                subtitle: nil,
                isLast: true
            )

            models = [approved, executed]
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
