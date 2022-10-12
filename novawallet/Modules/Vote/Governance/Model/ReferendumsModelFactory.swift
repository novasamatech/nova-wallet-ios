import Foundation
import SoraFoundation
import BigInt

struct ReferendumsModelFactoryInput {
    let referendums: [ReferendumLocal]
    let metadataMapping: [Referenda.ReferendumIndex: ReferendumMetadataLocal]?
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
    ) -> [UInt: StatusTimeModel?]
}

final class ReferendumsModelFactory {
    private typealias Input = ReferendumsModelFactoryInput
    private typealias Strings = R.string.localizable

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: NumberFormatter
    let referendumNumberFormatter: NumberFormatter
    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: NumberFormatter,
        referendumNumberFormatter: NumberFormatter
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.percentFormatter = percentFormatter
        self.referendumNumberFormatter = referendumNumberFormatter
    }

    private func provideCommonReferendumCellViewModel(
        status: ReferendumInfoView.Model.Status,
        metadata: ReferendumMetadataLocal?,
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
                status: status,
                time: nil,
                title: metadata?.name ?? "",
                track: nil
            ),
            progress: nil,
            yourVotes: yourVotesModel
        )
    }

    private func providePreparingReferendumCellViewModel(
        _ model: ReferendumStateLocal.Preparing,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
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
            let trackName = model.track.name.replacingSnakeCase().uppercased()
            let referendumNumber = referendumNumberFormatter.string(from: NSNumber(value: referendum.index))

            return .init(
                referendumInfo: .init(
                    status: .init(name: title.uppercased(), kind: .neutral),
                    time: timeModel?.viewModel,
                    title: metadata?.name ?? "",
                    track: .init(
                        titleIcon: .init(title: trackName, icon: nil),
                        referendumNumber: referendumNumber.map { "#" + $0 }
                    )
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
        metadata: ReferendumMetadataLocal?,
        chainInfo: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let timeModel: StatusTimeModel?
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
            let isPassing = supportAndVotes.isPassing(at: chainInfo.currentBlock)
            let statusName = isPassing ?
                Strings.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
                Strings.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)
            let statusKind: ReferendumInfoView.Model.StatusKind = isPassing ? .positive : .negative
            let yourVotesModel = createVotesViewModel(
                votes: votes,
                chainAsset: chainInfo.chain.utilityAsset(),
                locale: locale
            )
            let trackName = model.track.name.replacingSnakeCase().uppercased()
            let referendumNumber = referendumNumberFormatter.string(from: NSNumber(value: referendum.index))

            return .init(
                referendumInfo: .init(
                    status: .init(name: statusName.uppercased(), kind: statusKind),
                    time: timeModel?.viewModel,
                    title: metadata?.name,
                    track: .init(
                        titleIcon: .init(title: trackName, icon: nil),
                        referendumNumber: referendumNumber.map { "#" + $0 }
                    )
                ),
                progress: progressViewModel,
                yourVotes: yourVotesModel
            )
        }
    }

    private func provideApprovedReferendumCellViewModel(
        _ model: ReferendumStateLocal.Approved,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        chainInfo: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        let timeModel: StatusTimeModel?
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
                status: .init(name: title.uppercased(), kind: .positive),
                time: timeModel?.viewModel,
                title: metadata?.name,
                track: nil
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

            let image = isCompleted ?
                R.image.iconCheckmark()?.withTintColor(R.color.colorDarkGreen()!) :
                R.image.iconClose()?.withTintColor(R.color.colorRedFF3A69()!)
            let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.displayInfo)

            let targetThresholdString = targetThreshold.map {
                tokenFormatter.value(for: locale).stringFromDecimal($0) ?? ""
            } ?? ""
            let thresholdString = threshold.map(String.init) ?? ""
            let text = R.string.localizable.governanceReferendumsThreshold(thresholdString, targetThresholdString)
            thresholdModel = .init(
                titleIcon: .init(title: text, icon: image),
                value: supportAndVotes.supportFraction
            )
        } else {
            thresholdModel = nil
        }

        return .init(
            ayeProgress: "Aye: \(ayeProgress)",
            passProgress: "To pass: \(passProgress)",
            nayProgress: "Nay: \(nayProgress)",
            thresholdModel: thresholdModel,
            progress: supportAndVotes.approvalFraction
        )
    }

    private func createTimeModel(
        for referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> StatusTimeModel? {
        let strings = R.string.localizable.self
        switch referendum.state {
        case let .preparing(model):
            if model.deposit == nil {
                let title = strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
                let timeViewModel = ReferendumInfoView.Model.Time(
                    titleIcon: .init(title: title, icon: R.image.iconLightPending()),
                    isUrgent: false
                )

                return StatusTimeModel(viewModel: timeViewModel, timeInterval: nil) { _ in
                    timeViewModel
                }
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
        timeStringProvider: @escaping (String, [String]?) -> String,
        locale: Locale
    ) -> StatusTimeModel? {
        let time = calculateTime(
            block: atBlock,
            currentBlock: currentBlock,
            blockDuration: blockDuration
        )
        guard let timeModel = createTimeModel(
            time: time,
            timeStringProvider: timeStringProvider,
            state: state,
            locale: locale
        ) else {
            return nil
        }
        return .init(viewModel: timeModel, timeInterval: time) { [weak self] in
            self?.createTimeModel(
                time: $0,
                timeStringProvider: timeStringProvider,
                state: state,
                locale: locale
            )
        }
    }

    private func createTimeModel(
        time: TimeInterval,
        timeStringProvider: (String, [String]?) -> String,
        state: ReferendumStateLocal,
        locale: Locale
    ) -> ReferendumInfoView.Model.Time? {
        guard let localizedDaysHours = time.localizedDaysOrTime(for: locale) else {
            return nil
        }
        let timeString = timeStringProvider(localizedDaysHours, locale.rLanguages)
        let timeModel = isUrgent(state: state, time: time).map { isUrgent in
            ReferendumInfoView.Model.Time(
                titleIcon: .init(
                    title: timeString,
                    icon: isUrgent ? R.image.iconFire() : R.image.iconLightPending()
                ),
                isUrgent: isUrgent
            )
        }
        return timeModel
    }

    private func calculateTime(block: Moment, currentBlock: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        currentBlock.secondsTo(block: block, blockDuration: blockDuration)
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
    ) -> [UInt: StatusTimeModel?] {
        referendums.reduce(into: [UInt: StatusTimeModel?]()) { result, referendum in
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
            let metadata = input.metadataMapping?[index]
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
            let title = Strings.governanceReferendumsActive(preferredLanguages: input.locale.rLanguages)
            sections.append(.active(.loaded(value: title), active))
        }
        if !completed.isEmpty {
            let title = Strings.governanceReferendumsCompleted(preferredLanguages: input.locale.rLanguages)
            sections.append(.completed(.loaded(value: title), completed))
        }
        return sections
    }

    private func createReferendumsCellViewModel(
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        chainInformation: Input.ChainInformation,
        votes: ReferendumAccountVoteLocal?,
        locale: Locale
    ) -> ReferendumView.Model {
        let status: ReferendumInfoView.Model.Status
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
            let statusName = Strings.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName, kind: .negative)
        case .cancelled:
            let statusName = Strings.governanceReferendumsStatusCancelled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName, kind: .neutral)
        case .timedOut:
            let statusName = Strings.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName, kind: .neutral)
        case .killed:
            let statusName = Strings.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName, kind: .negative)
        case .executed:
            let statusName = Strings.governanceReferendumsStatusExecuted(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName, kind: .positive)
        }

        return provideCommonReferendumCellViewModel(
            status: status,
            metadata: metadata,
            votes: votes,
            chain: chainInformation.chain,
            locale: locale
        )
    }
}
