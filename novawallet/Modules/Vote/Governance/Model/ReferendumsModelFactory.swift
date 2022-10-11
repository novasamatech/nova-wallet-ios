import Foundation
import SoraFoundation
import BigInt

struct ReferendumsModelFactoryInput {
    let referendums: [ReferendumLocal]
    let metadataMapping: [Referenda.ReferendumIndex: ReferendumMetadataLocal]
    let votes: [Referenda.ReferendumIndex: ReferendumAccountVoteLocal]
    let chainInfo: ChainInformation
    let locale: Locale

    struct ChainInformation {
        let chain: ChainModel
        let currentBlock: BlockNumber
        let blockDurartion: UInt64
    }
}

protocol ReferendumsModelFactoryProtocol {
    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection]

    func createTimeModels(
        referendums: [ReferendumLocal],
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> [UInt: ReferendumInfoView.Model.Time?]
}

final class ReferendumsModelFactory {
    private typealias Input = ReferendumsModelFactoryInput
    private typealias Strings = R.string.localizable

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: NumberFormatter

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: NumberFormatter
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.percentFormatter = percentFormatter
    }

    private func provideCommonReferendumCellViewModel(
        title: String,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        votes: ReferendumAccountVoteLocal?,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumView.Model {
        let yourVotesModel = createVotesViewModel(
            votes: votes,
            chainAsset: chain.utilityAsset(),
            locale: locale
        )
        return .init(
            referendumInfo: .init(
                status: title,
                time: nil,
                title: metadata.details,
                trackName: metadata.name,
                trackImage: nil,
                number: "#\(referendum.index)"
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
    }

    private func providePreparingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Preparing,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        votes: ReferendumAccountVoteLocal?,
        chainInfo: Input.ChainInformation,
        locale: Locale
    ) -> ReferendumView.Model {
        let timeModel = createTimeModel(
            for: referendum,
            currentBlock: chainInfo.currentBlock,
            blockDurartion: chainInfo.blockDurartion,
            locale: locale
        )

        let title = model.inQueue ?
            Strings.governanceReferendumsStatusPreparingInqueue(preferredLanguages: locale.rLanguages) :
            Strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)

        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let progressViewModel = createVotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: chainInfo.chain,
                currentBlock: chainInfo.currentBlock,
                locale: locale
            )
            let yourVotesModel = createVotesViewModel(
                votes: votes,
                chainAsset: chainInfo.chain.utilityAsset(),
                locale: locale
            )
            return .init(
                referendumInfo: .init(
                    status: title,
                    time: timeModel,
                    title: metadata.details,
                    trackName: metadata.name,
                    trackImage: nil,
                    number: "#\(referendum.index)"
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
        guard let votes = votes,
              let chainAsset = chainAsset,
              votes.ayes + votes.nays > 0 else {
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
        let ayesModel = votes.ayes > 0 ? YourVoteView.Model(
            title: "AYE",
            description: formatVotes(votes.ayes)
        ) : nil
        let naysModel = votes.nays > 0 ? YourVoteView.Model(
            title: "NAY",
            description: formatVotes(votes.nays)
        ) : nil
        return .init(
            aye: ayesModel,
            nay: naysModel
        )
    }

    private func provideDecidingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Deciding,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        chainInfo: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let timeModel: ReferendumInfoView.Model.Time?
            if supportAndVotes.isPassing(at: chainInfo.currentBlock),
               let confirmationUntil = model.confirmationUntil {
                timeModel = createTimeModel(
                    state: referendum.state,
                    atBlock: confirmationUntil,
                    currentBlock: chainInfo.currentBlock,
                    blockDuration: chainInfo.blockDurartion,
                    timeStringProvider: Strings.governanceReferendumsTimeApprove,
                    locale: locale
                )
            } else {
                timeModel = createTimeModel(
                    state: referendum.state,
                    atBlock: model.period,
                    currentBlock: chainInfo.currentBlock,
                    blockDuration: chainInfo.blockDurartion,
                    timeStringProvider: Strings.governanceReferendumsTimeReject,
                    locale: locale
                )
            }

            let progressViewModel = createVotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: chainInfo.chain,
                currentBlock: chainInfo.currentBlock,
                locale: locale
            )
            let title = supportAndVotes.isPassing(at: chainInfo.currentBlock) ?
                Strings.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
                Strings.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)
            let yourVotesModel = createVotesViewModel(
                votes: votes,
                chainAsset: chainInfo.chain.utilityAsset(),
                locale: locale
            )
            return .init(
                referendumInfo: .init(
                    status: title,
                    time: timeModel,
                    title: metadata.details,
                    trackName: metadata.name,
                    trackImage: nil,
                    number: "#\(referendum.index)"
                ),
                progress: progressViewModel,
                yourVotes: yourVotesModel
            )
        }
    }

    private func provideApprovedReferendumCellViewModel(
        _ model: ReferendumStateLocal.Approved,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        chainInfo: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        let timeModel: ReferendumInfoView.Model.Time?
        if let whenEnactment = model.whenEnactment {
            timeModel = createTimeModel(
                state: referendum.state,
                atBlock: whenEnactment,
                currentBlock: chainInfo.currentBlock,
                blockDuration: chainInfo.blockDurartion,
                timeStringProvider: Strings.governanceReferendumsTimeExecute,
                locale: locale
            )
        } else {
            timeModel = nil
        }

        let title = Strings.governanceReferendumsStatusApproved(preferredLanguages: locale.rLanguages)
        let yourVotesModel = createVotesViewModel(
            votes: votes,
            chainAsset: chainInfo.chain.utilityAsset(),
            locale: locale
        )
        return .init(
            referendumInfo: .init(
                status: title,
                time: timeModel,
                title: metadata.details,
                trackName: metadata.name,
                trackImage: nil,
                number: "#\(referendum.index)"
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
    }

    private func createVotingProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.Model {
        let ayeProgress = percentFormatter.stringFromDecimal(supportAndVotes.approvalFraction) ?? ""
        let nayProgress = percentFormatter.stringFromDecimal(1 - supportAndVotes.approvalFraction) ?? ""
        let passProgress = percentFormatter.stringFromDecimal(supportAndVotes.supportFraction) ?? ""
        let thresholdModel: VotingProgressView.ThresholdModel?
        if let chainAsset = chain.utilityAsset(),
           let supportThreshold = supportAndVotes.supportFunction?.calculateThreshold(for: currentBlock) {
            let targetThreshold = Decimal.fromSubstrateAmount(
                supportAndVotes.totalIssuance,
                precision: Int16(chainAsset.precision)
            )
            let threshold = Decimal.fromSubstrateAmount(
                supportAndVotes.support,
                precision: Int16(chainAsset.precision)
            )
            let isCompleted = supportAndVotes.supportFraction >= supportThreshold

            let image = isCompleted ? R.image.iconCheckmark() : R.image.iconClose()
            let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.displayInfo)

            let targetThresholdString = targetThreshold.map {
                tokenFormatter.value(for: locale).stringFromDecimal($0) ?? ""
            } ?? ""
            let thresholdString = threshold.map(String.init) ?? ""
            let text = R.string.localizable.governanceReferendumsThreshold(thresholdString, targetThresholdString)
            thresholdModel = .init(
                image: image,
                text: text,
                value: supportAndVotes.supportFraction
            )
        } else {
            thresholdModel = nil
        }

        return .init(
            ayeProgress: ayeProgress,
            passProgress: passProgress,
            nayProgress: nayProgress,
            thresholdModel: thresholdModel,
            progress: supportAndVotes.approvalFraction
        )
    }

    private func createTimeModel(
        for referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> ReferendumInfoView.Model.Time? {
        let strings = R.string.localizable.self
        switch referendum.state {
        case let .preparing(model):
            if model.deposit == nil {
                let title = strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
                return ReferendumInfoView.Model.Time(
                    title: title,
                    image: R.image.iconLightPending(),
                    isUrgent: false
                )
            } else {
                return createTimeModel(
                    state: referendum.state,
                    atBlock: model.since,
                    currentBlock: currentBlock,
                    blockDuration: blockDurartion,
                    timeStringProvider: strings.governanceReferendumsTimeDeciding,
                    locale: locale
                )
            }
        case let .deciding(model):
            switch model.voting {
            case let .supportAndVotes(supportAndVotes):
                if supportAndVotes.isPassing(at: currentBlock),
                   let confirmationUntil = model.confirmationUntil {
                    return createTimeModel(
                        state: referendum.state,
                        atBlock: confirmationUntil,
                        currentBlock: currentBlock,
                        blockDuration: blockDurartion,
                        timeStringProvider: strings.governanceReferendumsTimeApprove,
                        locale: locale
                    )
                } else {
                    return createTimeModel(
                        state: referendum.state,
                        atBlock: model.period,
                        currentBlock: currentBlock,
                        blockDuration: blockDurartion,
                        timeStringProvider: strings.governanceReferendumsTimeReject,
                        locale: locale
                    )
                }
            }
        case let .approved(model):
            guard let whenEnactment = model.whenEnactment else {
                return nil
            }
            return createTimeModel(
                state: referendum.state,
                atBlock: whenEnactment,
                currentBlock: currentBlock,
                blockDuration: blockDurartion,
                timeStringProvider: strings.governanceReferendumsTimeExecute,
                locale: locale
            )
        case .rejected, .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }

    private func createTimeModel(
        state: ReferendumStateLocal,
        atBlock: Moment,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        timeStringProvider: (String, [String]?) -> String,
        locale: Locale
    ) -> ReferendumInfoView.Model.Time? {
        let time = calculateTime(
            block: atBlock,
            currentBlock: currentBlock,
            blockDuration: blockDuration
        )
        let localizedDaysHours = time.localizedDaysHours(for: locale)
        let timeString = timeStringProvider(localizedDaysHours, locale.rLanguages)
        let timeModel = isUrgent(state: state, time: time).map {
            ReferendumInfoView.Model.Time(
                title: timeString,
                image: $0 ? R.image.iconFire() : R.image.iconLightPending(),
                isUrgent: $0
            )
        }
        return timeModel
    }

    private func calculateTime(block: Moment, currentBlock: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        block.secondsTo(block: currentBlock, blockDuration: blockDuration)
    }

    private func isUrgent(state: ReferendumStateLocal, time: TimeInterval) -> Bool? {
        switch state {
        case .preparing:
            return time.hoursFromSeconds <= 3
        case .deciding:
            return time.daysFromSeconds < 1
        case .approved:
            return time.daysFromSeconds < 1
        case .rejected:
            return time.daysFromSeconds < 1
        case .cancelled, .timedOut, .killed, .executed: return nil
        }
    }
}

extension ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
    func createTimeModels(
        referendums: [ReferendumLocal],
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> [UInt: ReferendumInfoView.Model.Time?] {
        referendums.reduce(into: [UInt: ReferendumInfoView.Model.Time?]()) { result, referendum in
            result[referendum.index] = createTimeModel(
                for: referendum,
                currentBlock: currentBlock,
                blockDurartion: blockDurartion,
                locale: locale
            )
        }
    }

    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection] {
        var active: [ReferendumsCellViewModel] = []
        var completed: [ReferendumsCellViewModel] = []

        input.referendums.forEach { referendum in
            let index = Referenda.ReferendumIndex(referendum.index)
            guard let metadata = input.metadataMapping[index] else {
                return
            }
            let model = createReferendumsCellViewModel(
                referendum: referendum,
                metadata: metadata,
                chainInformation: input.chainInfo,
                votes: input.votes[index],
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
            sections.append(.active(.loaded(value: "Ongoing"), active))
        }
        if !completed.isEmpty {
            sections.append(.completed(.loaded(value: "Completed"), completed))
        }
        return sections
    }

    private func createReferendumsCellViewModel(
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        chainInformation: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        let title: String
        switch referendum.state {
        case let .preparing(model):
            return providePreparingReferendumCellViewModel(
                model,
                referendum: referendum,
                metadata: metadata,
                votes: votes,
                chainInfo: chainInformation,
                locale: locale
            )
        case let .deciding(model):
            return provideDecidingReferendumCellViewModel(
                model,
                referendum: referendum,
                metadata: metadata,
                chainInfo: chainInformation,
                votes: votes,
                locale: locale
            )
        case let .approved(model):
            return provideApprovedReferendumCellViewModel(
                model,
                referendum: referendum,
                metadata: metadata,
                chainInfo: chainInformation,
                votes: votes,
                locale: locale
            )
        case .rejected:
            title = Strings.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages)
        case .cancelled:
            title = Strings.governanceReferendumsStatusCancelled(preferredLanguages: locale.rLanguages)
        case .timedOut:
            title = Strings.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages)
        case .killed:
            title = Strings.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages)
        case .executed:
            title = Strings.governanceReferendumsStatusExecuted(preferredLanguages: locale.rLanguages)
        }

        return provideCommonReferendumCellViewModel(
            title: title,
            referendum: referendum,
            metadata: metadata,
            votes: votes,
            chain: chainInformation.chain,
            locale: locale
        )
    }
}
