import Foundation
import BigInt
import Foundation_iOS

extension ReferendumsModelFactory {
    func provideCommonReferendumCellViewModel(
        status: ReferendumInfoView.Status,
        params: StatusParams,
        voterName: String?,
        locale: Locale
    ) -> ReferendumView.Model {
        let yourVotesModel = createVotesViewModel(
            from: params.onchainVotes,
            offchainVotes: params.offchainVotes,
            chain: params.chainInfo.chain,
            voterName: voterName,
            locale: locale
        )

        let referendumNumber = localizedIndexFormatter.value(for: locale).string(
            from: NSNumber(value: params.referendum.index)
        )

        let referendumTitle = referendumMetadataViewModelFactory.createTitle(
            for: params.referendum,
            metadata: params.metadata,
            locale: locale
        )

        return .init(
            referendumInfo: .init(
                status: status,
                time: nil,
                title: referendumTitle,
                track: nil,
                referendumNumber: referendumNumber
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
    }

    func createInQueueFormatting(
        for position: ReferendumStateLocal.InQueuePosition?,
        locale: Locale
    ) -> String {
        if let position = position {
            let formatter = localizedQuantityFormatter.value(for: locale)
            let positionString = formatter.string(from: (position.index + 1) as NSNumber) ?? ""
            let totalString = formatter.string(from: position.total as NSNumber) ?? ""

            let queueString = R.string.localizable.govInQueueCounter(
                positionString,
                totalString,
                preferredLanguages: locale.rLanguages
            )

            let prefixTitle = R.string.localizable.governanceReferendumsStatusPreparingInqueue(
                preferredLanguages: locale.rLanguages
            )

            return prefixTitle + " " + queueString
        } else {
            return R.string.localizable.governanceReferendumsStatusPreparingInqueue(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createPreparingStatus(for model: ReferendumStateLocal.Preparing, locale: Locale) -> String {
        if model.inQueue {
            return createInQueueFormatting(for: model.inQueuePosition, locale: locale)
        } else if model.deposit == nil {
            return Strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
        } else {
            return Strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)
        }
    }

    func providePreparingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Preparing,
        params: StatusParams,
        voterName: String?,
        locale: Locale
    ) -> ReferendumView.Model {
        let timeModel = statusViewModelFactory.createTimeViewModel(
            for: params.referendum,
            currentBlock: params.chainInfo.currentBlock,
            blockDuration: params.chainInfo.blockDuration,
            locale: locale
        )

        let title = createPreparingStatus(for: model, locale: locale)

        let votingProgressViewModel: VotingProgressView.Model

        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            votingProgressViewModel = createGov2VotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: params.chainInfo.chain,
                currentBlock: params.chainInfo.currentBlock,
                locale: locale
            )
        case let .threshold(threshold):
            votingProgressViewModel = createGov1VotingProgressViewModel(votingThreshold: threshold, locale: locale)
        }

        let yourVotesModel = createVotesViewModel(
            from: params.onchainVotes,
            offchainVotes: params.offchainVotes,
            chain: params.chainInfo.chain,
            voterName: voterName,
            locale: locale
        )

        let track = createTrackViewModel(from: model.track, params: params, locale: locale)

        let referendumNumber = localizedIndexFormatter.value(for: locale).string(
            from: NSNumber(value: params.referendum.index)
        )

        let referendumTitle = referendumMetadataViewModelFactory.createTitle(
            for: params.referendum,
            metadata: params.metadata,
            locale: locale
        )

        return .init(
            referendumInfo: .init(
                status: .init(name: title.uppercased(), kind: .neutral),
                time: timeModel?.viewModel,
                title: referendumTitle,
                track: track,
                referendumNumber: referendumNumber
            ),
            progress: votingProgressViewModel,
            yourVotes: yourVotesModel
        )
    }

    func provideDecidingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Deciding,
        params: StatusParams,
        voterName: String?,
        locale: Locale
    ) -> ReferendumView.Model {
        let votingProgressViewModel: VotingProgressView.Model
        let isPassing: Bool

        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            votingProgressViewModel = createGov2VotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: params.chainInfo.chain,
                currentBlock: params.chainInfo.currentBlock,
                locale: locale
            )

            isPassing = supportAndVotes.isPassing(at: params.chainInfo.currentBlock)
        case let .threshold(threshold):
            votingProgressViewModel = createGov1VotingProgressViewModel(votingThreshold: threshold, locale: locale)

            isPassing = threshold.isPassing()
        }

        let timeModel = statusViewModelFactory.createTimeViewModel(
            for: params.referendum,
            currentBlock: params.chainInfo.currentBlock,
            blockDuration: params.chainInfo.blockDuration,
            locale: locale
        )

        let statusName = isPassing ?
            Strings.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
            Strings.governanceReferendumsStatusDeciding(preferredLanguages: locale.rLanguages)

        let statusKind: ReferendumInfoView.StatusKind = isPassing ? .positive : .neutral
        let yourVotesModel = createVotesViewModel(
            from: params.onchainVotes,
            offchainVotes: params.offchainVotes,
            chain: params.chainInfo.chain,
            voterName: voterName,
            locale: locale
        )

        let track = createTrackViewModel(from: model.track, params: params, locale: locale)

        let indexFormatter = localizedIndexFormatter.value(for: locale)
        let referendumNumber = indexFormatter.string(from: NSNumber(value: params.referendum.index))

        let referendumTitle = referendumMetadataViewModelFactory.createTitle(
            for: params.referendum,
            metadata: params.metadata,
            locale: locale
        )

        return .init(
            referendumInfo: .init(
                status: .init(name: statusName.uppercased(), kind: statusKind),
                time: timeModel?.viewModel,
                title: referendumTitle,
                track: track,
                referendumNumber: referendumNumber
            ),
            progress: votingProgressViewModel,
            yourVotes: yourVotesModel
        )
    }

    func provideApprovedReferendumCellViewModel(
        params: StatusParams,
        voterName: String?,
        locale: Locale
    ) -> ReferendumView.Model {
        let timeModel = statusViewModelFactory.createTimeViewModel(
            for: params.referendum,
            currentBlock: params.chainInfo.currentBlock,
            blockDuration: params.chainInfo.blockDuration,
            locale: locale
        )

        let title = Strings.governanceReferendumsStatusApproved(preferredLanguages: locale.rLanguages)

        let yourVotesModel = createVotesViewModel(
            from: params.onchainVotes,
            offchainVotes: params.offchainVotes,
            chain: params.chainInfo.chain,
            voterName: voterName,
            locale: locale
        )

        let referendumNumber = localizedIndexFormatter.value(for: locale).string(
            from: NSNumber(value: params.referendum.index)
        )

        let referendumTitle = referendumMetadataViewModelFactory.createTitle(
            for: params.referendum,
            metadata: params.metadata,
            locale: locale
        )

        return .init(
            referendumInfo: .init(
                status: .init(name: title.uppercased(), kind: .positive),
                time: timeModel?.viewModel,
                title: referendumTitle,
                track: nil,
                referendumNumber: referendumNumber
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
    }
}
