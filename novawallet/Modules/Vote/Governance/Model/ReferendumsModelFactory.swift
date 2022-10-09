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

final class ReferendumsModelFactory {
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter.percent
        formatter.roundingMode = .halfEven
        return formatter
    }()

    let tokenFormatter: LocalizableResource<TokenFormatter>

    init(tokenFormatter: LocalizableResource<TokenFormatter>) {
        self.tokenFormatter = tokenFormatter
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
            let timeModel: ReferendumInfoView.Model.Time?
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
                    let targetThresholdString = targetThreshold.map {
                        tokenFormatter.value(for: locale).stringFromDecimal($0) ?? ""
                    } ?? ""
                    let thresholdString = threshold.map(String.init) ?? ""
                    let text = strings.governanceReferendumsThreshold(thresholdString, targetThresholdString)
                    thresholdModel = .init(
                        image: image,
                        text: text,
                        value: supportAndVotes.supportFraction
                    )
                } else {
                    thresholdModel = nil
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
                    progress: .init(
                        ayeProgress: ayeProgress,
                        passProgress: passProgress,
                        nayProgress: nayProgress,
                        thresholdModel: thresholdModel,
                        progress: supportAndVotes.approvalFraction
                    ),
                    yourVotes: nil
                )
            }

        case let .deciding(model):
            // TODO:
            fatalError()
        case let .approved(model):
            // TODO:
            fatalError()
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
