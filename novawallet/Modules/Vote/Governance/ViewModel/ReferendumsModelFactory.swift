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
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol

    init(
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        indexFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.statusViewModelFactory = statusViewModelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        localizedPercentFormatter = percentFormatter
        localizedIndexFormatter = indexFormatter
    }

    private func provideCommonReferendumCellViewModel(
        status: ReferendumInfoView.Model.Status,
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

        return .init(
            referendumInfo: .init(
                status: status,
                time: nil,
                title: params.metadata?.name ?? "",
                track: nil,
                referendumNumber: referendumNumber
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
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

        let title = model.inQueue ?
            Strings.governanceReferendumsStatusPreparingInqueue(preferredLanguages: locale.rLanguages) :
            Strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)

        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let progressViewModel = createVotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: params.chainInfo.chain,
                currentBlock: params.chainInfo.currentBlock,
                locale: locale
            )
            let yourVotesModel = createVotesViewModel(
                votes: params.votes,
                chainAsset: params.chainInfo.chain.utilityAsset(),
                locale: locale
            )

            let track = ReferendumTrackType.createViewModel(
                from: model.track.name,
                chain: params.chainInfo.chain,
                locale: locale
            )

            let referendumNumber = localizedIndexFormatter.value(for: locale).string(
                from: NSNumber(value: params.referendum.index)
            )

            return .init(
                referendumInfo: .init(
                    status: .init(name: title.uppercased(), kind: .neutral),
                    time: timeModel?.viewModel,
                    title: params.metadata?.name ?? "",
                    track: track,
                    referendumNumber: referendumNumber
                ),
                progress: progressViewModel,
                yourVotes: yourVotesModel
            )
        }
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

    private func provideDecidingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Deciding,
        params: StatusParams,
        locale: Locale
    ) -> ReferendumView.Model {
        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let timeModel = statusViewModelFactory.createTimeViewModel(
                for: params.referendum,
                currentBlock: params.chainInfo.currentBlock,
                blockDuration: params.chainInfo.blockDuration,
                locale: locale
            )

            let progressViewModel = createVotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: params.chainInfo.chain,
                currentBlock: params.chainInfo.currentBlock,
                locale: locale
            )
            let isPassing = supportAndVotes.isPassing(at: params.chainInfo.currentBlock)
            let statusName = isPassing ?
                Strings.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
                Strings.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)
            let statusKind: ReferendumInfoView.Model.StatusKind = isPassing ? .positive : .negative
            let yourVotesModel = createVotesViewModel(
                votes: params.votes,
                chainAsset: params.chainInfo.chain.utilityAsset(),
                locale: locale
            )

            let track = ReferendumTrackType.createViewModel(
                from: model.track.name,
                chain: params.chainInfo.chain,
                locale: locale
            )

            let indexFormatter = localizedIndexFormatter.value(for: locale)
            let referendumNumber = indexFormatter.string(from: NSNumber(value: params.referendum.index))

            return .init(
                referendumInfo: .init(
                    status: .init(name: statusName.uppercased(), kind: statusKind),
                    time: timeModel?.viewModel,
                    title: params.metadata?.name,
                    track: track,
                    referendumNumber: referendumNumber
                ),
                progress: progressViewModel,
                yourVotes: yourVotesModel
            )
        }
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

        return .init(
            referendumInfo: .init(
                status: .init(name: title.uppercased(), kind: .positive),
                time: timeModel?.viewModel,
                title: params.metadata?.name,
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
            R.image.iconCheckmark()?.tinted(with: R.color.colorGreen15CF37()!) :
            R.image.iconClose()?.tinted(with: R.color.colorRedFF3A69()!)

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

    private func createVotingProgressViewModel(
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
}

extension ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
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
        if !active.isEmpty {
            let title = Strings.governanceReferendumsActive(preferredLanguages: input.locale.rLanguages)
            sections.append(.active(.loaded(value: title), active))
        }
        if !completed.isEmpty {
            let title = Strings.governanceReferendumsCompleted(preferredLanguages: input.locale.rLanguages)
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
        let status: ReferendumInfoView.Model.Status
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
