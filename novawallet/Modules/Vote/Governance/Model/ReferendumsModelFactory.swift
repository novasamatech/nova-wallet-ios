import Foundation
import SoraFoundation

protocol ReferendumsModelFactoryProtocol {
    func createSections(
        chain: ChainModel,
        referendums: [ReferendumLocal],
        metaDataMapping: [Referenda.ReferendumIndex: ReferendumMetadataLocal],
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> [ReferendumsSection]
}

final class ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let formatter: NumberFormatter

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: NumberFormatter
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        formatter = percentFormatter
    }

    func createSections(
        chain: ChainModel,
        referendums: [ReferendumLocal],
        metaDataMapping: [Referenda.ReferendumIndex: ReferendumMetadataLocal],
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> [ReferendumsSection] {
        var active: [LoadableViewModelState<ReferendumsCellViewModel>] = []
        var completed: [LoadableViewModelState<ReferendumsCellViewModel>] = []

        referendums.forEach { referendum in
            guard let metadata = metaDataMapping[Referenda.ReferendumIndex(referendum.index)] else {
                return
            }
            let model = createReferendumsCellViewModel(
                chain: chain,
                referendum: referendum,
                metadata: metadata,
                currentBlock: currentBlock,
                blockDurartion: blockDurartion,
                locale: locale
            )
            referendum.state.completed ? completed.append(.loaded(value: model)) : active.append(.loaded(value: model))
        }

        return [
            .active(.loaded(value: "Ongoing"), active),
            .completed(.loaded(value: "Completed"), completed)
        ]
    }

    func createReferendumsCellViewModel(
        chain: ChainModel,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> ReferendumsCellViewModel {
        let status = title(state: referendum.state, currentBlock: currentBlock).value(for: locale)
        let strings = R.string.localizable.self

        switch referendum.state {
        case let .preparing(model):
            return provideModel(
                preparing: model,
                chain: chain,
                referendum: referendum,
                metadata: metadata,
                currentBlock: currentBlock,
                blockDurartion: blockDurartion,
                locale: locale
            )
        case let .deciding(model):
            switch model.voting {
            case let .supportAndVotes(supportAndVotes):
                let timeModel: ReferendumInfoView.Model.Time?
                if supportAndVotes.isPassing(at: currentBlock), let confirmationUntil = model.confirmationUntil {
                    timeModel = createTimeModel(
                        state: referendum.state,
                        atBlock: confirmationUntil,
                        currentBlock: currentBlock,
                        blockDuration: blockDurartion,
                        timeStringProvider: strings.governanceReferendumsTimeApprove,
                        locale: locale
                    )
                } else {
                    timeModel = createTimeModel(
                        state: referendum.state,
                        atBlock: model.period,
                        currentBlock: currentBlock,
                        blockDuration: blockDurartion,
                        timeStringProvider: strings.governanceReferendumsTimeReject,
                        locale: locale
                    )
                }

                let progressViewModel = createVotingProgressViewModel(
                    supportAndVotes: supportAndVotes,
                    chain: chain,
                    currentBlock: currentBlock,
                    locale: locale
                )
                return .init(
                    referendumInfo: .init(
                        status: status,
                        time: timeModel,
                        title: metadata.details,
                        trackName: metadata.name,
                        trackImage: nil,
                        number: "#\(referendum.index)"
                    ),
                    progress: progressViewModel,
                    yourVotes: nil
                )
            }
        case let .approved(model):
            let timeModel: ReferendumInfoView.Model.Time?
            if let whenEnactment = model.whenEnactment {
                timeModel = createTimeModel(
                    state: referendum.state,
                    atBlock: whenEnactment,
                    currentBlock: currentBlock,
                    blockDuration: blockDurartion,
                    timeStringProvider: strings.governanceReferendumsTimeExecute,
                    locale: locale
                )
            } else {
                timeModel = nil
            }
            return .init(
                referendumInfo: .init(
                    status: status,
                    time: timeModel,
                    title: metadata.details,
                    trackName: metadata.name,
                    trackImage: nil,
                    number: "#\(referendum.index)"
                ),
                progress: nil,
                yourVotes: nil
            )
        case .rejected,
             .cancelled,
             .timedOut,
             .killed,
             .executed:
            return .init(
                referendumInfo: .init(
                    status: status,
                    time: nil,
                    title: metadata.details,
                    trackName: metadata.name,
                    trackImage: nil,
                    number: "#\(referendum.index)"
                ),
                progress: nil,
                yourVotes: nil
            )
        }
    }

    private func provideModel(
        preparing model: ReferendumStateLocal.Preparing,
        chain: ChainModel,
        referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal,
        currentBlock: BlockNumber,
        blockDurartion: UInt64,
        locale: Locale
    ) -> ReferendumsCellViewModel {
        let strings = R.string.localizable.self
        let timeModel: ReferendumInfoView.Model.Time?
        let title = model.inQueue ?
            strings.governanceReferendumsStatusPreparingInqueue(preferredLanguages: locale.rLanguages) :
            strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)
        if model.deposit == nil {
            let title = strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
            timeModel = ReferendumInfoView.Model.Time(
                title: title,
                image: R.image.iconLightPending(),
                isUrgent: false
            )
        } else {
            timeModel = createTimeModel(
                state: referendum.state,
                atBlock: model.since,
                currentBlock: currentBlock,
                blockDuration: blockDurartion,
                timeStringProvider: strings.governanceReferendumsTimeDeciding,
                locale: locale
            )
        }

        switch model.voting {
        case let .supportAndVotes(supportAndVotes):
            let progressViewModel = createVotingProgressViewModel(
                supportAndVotes: supportAndVotes,
                chain: chain,
                currentBlock: currentBlock,
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
                yourVotes: nil
            )
        }
    }

    private func createVotingProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.Model {
        let ayeProgress = formatter.stringFromDecimal(supportAndVotes.approvalFraction) ?? ""
        let nayProgress = formatter.stringFromDecimal(1 - supportAndVotes.approvalFraction) ?? ""
        let passProgress = formatter.stringFromDecimal(supportAndVotes.supportFraction) ?? ""
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

    private func title(state: ReferendumStateLocal, currentBlock: BlockNumber) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let strings = R.string.localizable.self
            switch state {
            case let .preparing(model):
                return model.inQueue ?
                    strings.governanceReferendumsStatusPreparingInqueue(preferredLanguages: locale.rLanguages) :
                    strings.governanceReferendumsStatusPreparing(preferredLanguages: locale.rLanguages)
            case let .deciding(model):
                switch model.voting {
                case let .supportAndVotes(supportAndVotes):
                    return supportAndVotes.isPassing(at: currentBlock) ?
                        strings.governanceReferendumsStatusPassing(preferredLanguages: locale.rLanguages) :
                        strings.governanceReferendumsStatusNotPassing(preferredLanguages: locale.rLanguages)
                }
            case .approved:
                return strings.governanceReferendumsStatusApproved(preferredLanguages: locale.rLanguages)
            case .rejected:
                return strings.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages)
            case .cancelled:
                return strings.governanceReferendumsStatusCancelled(preferredLanguages: locale.rLanguages)
            case .timedOut:
                return strings.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages)
            case .killed:
                return strings.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages)
            case .executed:
                return strings.governanceReferendumsStatusExecuted(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
