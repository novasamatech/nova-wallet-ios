import Foundation
import SoraFoundation
import BigInt

struct ReferendumsModelFactoryInput {
    let referendums: [ReferendumLocal]
    let metadataMapping: [ReferendumIdLocal: ReferendumMetadataLocal]?
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let chainInfo: ChainInformation
    let locale: Locale

    struct ChainInformation {
        let chain: ChainModel
        let currentBlock: BlockNumber
        let blockDuration: UInt64
    }
}

protocol ReferendumsModelFactoryProtocol {
    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection]

    func createViewModel(
        from referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        vote: ReferendumAccountVoteLocal?,
        chainInfo: ReferendumsModelFactoryInput.ChainInformation,
        selectedLocale: Locale
    ) -> ReferendumView.Model

    func createLoadingViewModel() -> [ReferendumsSection]
}

final class ReferendumsModelFactory {
    private typealias Input = ReferendumsModelFactoryInput
    private typealias Strings = R.string.localizable

    private struct StatusParams {
        let referendum: ReferendumLocal
        let metadata: ReferendumMetadataLocal?
        let chainInfo: Input.ChainInformation
        let votes: ReferendumAccountVoteLocal?
    }

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let localizedPercentFormatter: LocalizableResource<NumberFormatter>
    let localizedIndexFormatter: LocalizableResource<NumberFormatter>
    let localizedQuantityFormatter: LocalizableResource<NumberFormatter>
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol

    init(
        referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        indexFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        localizedPercentFormatter = percentFormatter
        localizedIndexFormatter = indexFormatter
        localizedQuantityFormatter = quantityFormatter
    }

    private func provideCommonReferendumCellViewModel(
        status: ReferendumInfoView.Status,
        params: StatusParams,
        locale: Locale
    ) -> ReferendumView.Model {
        let yourVotesModel = createVotesViewModel(
            votes: params.votes,
            chainAsset: params.chainInfo.chain.utilityAsset(),
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

    private func createInQueueFormatting(
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

    private func createPreparingStatus(for model: ReferendumStateLocal.Preparing, locale: Locale) -> String {
        if model.inQueue {
            return createInQueueFormatting(for: model.inQueuePosition, locale: locale)
        } else if model.deposit == nil {
            return Strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
        } else {
            return Strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)
        }
    }

    private func providePreparingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Preparing,
        params: StatusParams,
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
            votes: params.votes,
            chainAsset: params.chainInfo.chain.utilityAsset(),
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

    private func createVotesViewModel(
        votes: ReferendumAccountVoteLocal?,
        chainAsset: AssetModel?,
        locale: Locale
    ) -> YourVotesView.Model? {
        guard let votes = votes, let chainAsset = chainAsset else {
            return nil
        }

        let inputFormatter = assetBalanceFormatterFactory.createInputFormatter(for: chainAsset.displayInfo)

        let formatVotes: (BigUInt) -> String = { votesInPlank in
            guard let votes = Decimal.fromSubstrateAmount(
                votesInPlank,
                precision: Int16(chainAsset.precision)
            ) else {
                return ""
            }
            let votesString = inputFormatter.value(for: locale).stringFromDecimal(votes) ?? ""
            return Strings.governanceReferendumsYourVote(
                votesString,
                preferredLanguages: locale.rLanguages
            )
        }
        let ayesModel = votes.hasAyeVotes ? YourVoteView.Model(
            title: Strings.governanceAye(preferredLanguages: locale.rLanguages).uppercased(),
            description: formatVotes(votes.ayes),
            style: .aye
        ) : nil
        let naysModel = votes.hasNayVotes ? YourVoteView.Model(
            title: Strings.governanceNay(preferredLanguages: locale.rLanguages).uppercased(),
            description: formatVotes(votes.nays),
            style: .nay
        ) : nil
        return .init(
            aye: ayesModel,
            nay: naysModel
        )
    }

    private func createTrackViewModel(
        from track: GovernanceTrackLocal,
        params: StatusParams,
        locale: Locale
    ) -> ReferendumInfoView.Track? {
        // display track name if more than 1 track in the network
        guard track.totalTracksCount > 1 else {
            return nil
        }

        return ReferendumTrackType.createViewModel(from: track.name, chain: params.chainInfo.chain, locale: locale)
    }

    private func provideDecidingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Deciding,
        params: StatusParams,
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
            Strings.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)

        let statusKind: ReferendumInfoView.StatusKind = isPassing ? .positive : .negative
        let yourVotesModel = createVotesViewModel(
            votes: params.votes,
            chainAsset: params.chainInfo.chain.utilityAsset(),
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

    private func provideApprovedReferendumCellViewModel(
        params: StatusParams,
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
            votes: params.votes,
            chainAsset: params.chainInfo.chain.utilityAsset(),
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

    private func createVotingSupportProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.SupportModel? {
        guard
            let chainAsset = chain.utilityAsset(),
            let supportThreshold = supportAndVotes.supportFunction?.calculateThreshold(for: currentBlock) else {
            return nil
        }

        let totalIssuanceDecimal = Decimal.fromSubstrateAmount(
            supportAndVotes.totalIssuance,
            precision: Int16(chainAsset.precision)
        ) ?? 0

        let targetThreshold = totalIssuanceDecimal * supportThreshold

        let threshold = Decimal.fromSubstrateAmount(
            supportAndVotes.support,
            precision: Int16(chainAsset.precision)
        )
        let isCompleted = supportAndVotes.supportFraction >= supportThreshold

        let image = isCompleted ?
            R.image.iconCheckmark()?.tinted(with: R.color.colorIconPositive()!) :
            R.image.iconClose()?.tinted(with: R.color.colorIconNegative()!)

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.displayInfo)
        let amountFormatter = assetBalanceFormatterFactory.createDisplayFormatter(for: chainAsset.displayInfo)

        let targetThresholdString = tokenFormatter.value(for: locale).stringFromDecimal(targetThreshold) ?? ""

        let thresholdString = threshold.map {
            amountFormatter.value(for: locale).stringFromDecimal($0) ?? ""
        } ?? ""

        let text = R.string.localizable.governanceReferendumsThreshold(
            thresholdString,
            targetThresholdString,
            preferredLanguages: locale.rLanguages
        )

        let titleIcon = TitleIconViewModel(title: text, icon: image)

        return .init(titleIcon: titleIcon, completed: isCompleted)
    }

    private func createVotingApprovalProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.ApprovalModel {
        let ayeProgressString: String
        let nayProgressString: String

        let percentFormatter = localizedPercentFormatter.value(for: locale)

        if let approvalFraction = supportAndVotes.approvalFraction {
            ayeProgressString = percentFormatter.stringFromDecimal(approvalFraction) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(1 - approvalFraction) ?? ""
        } else {
            ayeProgressString = percentFormatter.stringFromDecimal(0) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(0) ?? ""
        }

        let passThreshold = supportAndVotes.approvalFunction?.calculateThreshold(for: currentBlock) ?? 0
        let passThresholdString = percentFormatter.stringFromDecimal(passThreshold) ?? ""

        return .init(
            passThreshold: passThreshold,
            ayeProgress: supportAndVotes.approvalFraction,
            ayeMessage: Strings.governanceAyesFormat(ayeProgressString, preferredLanguages: locale.rLanguages),
            passMessage: Strings.governanceToPassFormat(passThresholdString, preferredLanguages: locale.rLanguages),
            nayMessage: Strings.governanceNaysFormat(nayProgressString, preferredLanguages: locale.rLanguages)
        )
    }

    private func createVotingThresholdProgressViewModel(
        for votingThreshold: VotingThresholdLocal,
        locale: Locale
    ) -> VotingProgressView.ApprovalModel {
        let ayeProgressString: String
        let nayProgressString: String

        let percentFormatter = localizedPercentFormatter.value(for: locale)

        if let approvalFraction = votingThreshold.approvalFraction {
            ayeProgressString = percentFormatter.stringFromDecimal(approvalFraction) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(1 - approvalFraction) ?? ""
        } else {
            ayeProgressString = percentFormatter.stringFromDecimal(0) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(0) ?? ""
        }

        let passThreshold = votingThreshold.calculateThreshold() ?? 0
        let passThresholdString = percentFormatter.stringFromDecimal(passThreshold) ?? ""

        return .init(
            passThreshold: passThreshold,
            ayeProgress: votingThreshold.approvalFraction,
            ayeMessage: Strings.governanceAyesFormat(ayeProgressString, preferredLanguages: locale.rLanguages),
            passMessage: Strings.governanceToPassFormat(passThresholdString, preferredLanguages: locale.rLanguages),
            nayMessage: Strings.governanceNaysFormat(nayProgressString, preferredLanguages: locale.rLanguages)
        )
    }

    private func createGov2VotingProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.Model {
        let supportModel = createVotingSupportProgressViewModel(
            supportAndVotes: supportAndVotes,
            chain: chain,
            currentBlock: currentBlock,
            locale: locale
        )

        let approvalModel = createVotingApprovalProgressViewModel(
            supportAndVotes: supportAndVotes,
            currentBlock: currentBlock,
            locale: locale
        )

        return .init(support: supportModel, approval: approvalModel)
    }

    private func createGov1VotingProgressViewModel(
        votingThreshold: VotingThresholdLocal,
        locale: Locale
    ) -> VotingProgressView.Model {
        let thresholdViewModel = createVotingThresholdProgressViewModel(for: votingThreshold, locale: locale)

        return .init(support: nil, approval: thresholdViewModel)
    }
}

extension ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
    func createLoadingViewModel() -> [ReferendumsSection] {
        let cells: [ReferendumsCellViewModel] = (0 ..< 10).map {
            ReferendumsCellViewModel(
                referendumIndex: UInt($0),
                viewModel: .loading
            )
        }
        return [ReferendumsSection.active(.loading, cells)]
    }

    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection] {
        var active: [ReferendumsCellViewModel] = []
        var completed: [ReferendumsCellViewModel] = []

        input.referendums.forEach { referendum in
            let metadata = input.metadataMapping?[referendum.index]

            let params = StatusParams(
                referendum: referendum,
                metadata: metadata,
                chainInfo: input.chainInfo,
                votes: input.votes[referendum.index]
            )

            let model = createReferendumCellViewModel(
                state: referendum.state,
                params: params,
                locale: input.locale
            )

            let viewModel = ReferendumsCellViewModel(
                referendumIndex: referendum.index,
                viewModel: .loaded(value: model)
            )

            referendum.state.completed ? completed.append(viewModel) : active.append(viewModel)
        }
        var sections: [ReferendumsSection] = []
        if !active.isEmpty || completed.isEmpty {
            // still add empty section to display empty state
            let title = Strings.governanceReferendumsActive(preferredLanguages: input.locale.rLanguages)
            sections.append(.active(.loaded(value: title), active))
        }
        if !completed.isEmpty {
            let title = Strings.commonCompleted(preferredLanguages: input.locale.rLanguages)
            sections.append(.completed(.loaded(value: title), completed))
        }
        return sections
    }

    func createViewModel(
        from referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        vote: ReferendumAccountVoteLocal?,
        chainInfo: ReferendumsModelFactoryInput.ChainInformation,
        selectedLocale: Locale
    ) -> ReferendumView.Model {
        let params = StatusParams(
            referendum: referendum,
            metadata: metadata,
            chainInfo: chainInfo,
            votes: vote
        )

        return createReferendumCellViewModel(state: referendum.state, params: params, locale: selectedLocale)
    }

    private func createReferendumCellViewModel(
        state: ReferendumStateLocal,
        params: StatusParams,
        locale: Locale
    ) -> ReferendumView.Model {
        let status: ReferendumInfoView.Status
        switch state {
        case let .preparing(model):
            return providePreparingReferendumCellViewModel(model, params: params, locale: locale)
        case let .deciding(model):
            return provideDecidingReferendumCellViewModel(model, params: params, locale: locale)
        case .approved:
            return provideApprovedReferendumCellViewModel(params: params, locale: locale)
        case .rejected:
            let statusName = Strings.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .cancelled:
            let statusName = Strings.governanceReferendumsStatusCancelled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .timedOut:
            let statusName = Strings.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .killed:
            let statusName = Strings.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .executed:
            let statusName = Strings.governanceReferendumsStatusExecuted(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .positive)
        }

        return provideCommonReferendumCellViewModel(status: status, params: params, locale: locale)
    }
}
