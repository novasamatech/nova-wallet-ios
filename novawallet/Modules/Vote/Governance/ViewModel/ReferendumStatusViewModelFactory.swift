import Foundation

protocol ReferendumStatusViewModelFactoryProtocol {
    func createTimeViewModel(
        for referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel?
}

extension ReferendumStatusViewModelFactoryProtocol {
    func createTimeViewModels(
        referendums: [ReferendumLocal],
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> [UInt: StatusTimeViewModel?] {
        referendums.reduce(into: [UInt: StatusTimeViewModel?]()) { result, referendum in
            result[referendum.index] = createTimeViewModel(
                for: referendum,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                locale: locale
            )
        }
    }
}

final class ReferendumStatusViewModelFactory {
    // swiftlint:disable:next function_parameter_count
    private func createTimeViewModel(
        state: ReferendumStateLocal,
        atBlock: Moment,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        timeStringProvider: @escaping (String, [String]?) -> String,
        locale: Locale
    ) -> StatusTimeViewModel? {
        let time = calculateTime(
            block: atBlock,
            currentBlock: currentBlock,
            blockDuration: blockDuration
        )
        guard let timeModel = createTimeViewModel(
            time: time,
            timeStringProvider: timeStringProvider,
            state: state,
            locale: locale
        ) else {
            return nil
        }
        return .init(viewModel: timeModel, timeInterval: time) { [weak self] in
            self?.createTimeViewModel(
                time: $0,
                timeStringProvider: timeStringProvider,
                state: state,
                locale: locale
            )
        }
    }

    private func createTimeViewModel(
        time: TimeInterval,
        timeStringProvider: (String, [String]?) -> String,
        state: ReferendumStateLocal,
        locale: Locale
    ) -> ReferendumInfoView.Time? {
        guard let localizedDaysHours = time.localizedDaysOrTime(for: locale) else {
            return nil
        }
        let timeString = timeStringProvider(localizedDaysHours, locale.rLanguages)
        let timeModel = isUrgent(state: state, time: time).map { isUrgent in
            ReferendumInfoView.Time(
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
        case .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }
}

extension ReferendumStatusViewModelFactory: ReferendumStatusViewModelFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func createTimeViewModel(
        for referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel? {
        let strings = R.string.localizable.self
        switch referendum.state {
        case let .preparing(model):
            if model.deposit == nil {
                let title = strings.governanceReferendumsTimeWaitingDeposit(preferredLanguages: locale.rLanguages)
                let timeViewModel = ReferendumInfoView.Time(
                    titleIcon: .init(title: title, icon: R.image.iconLightPending()),
                    isUrgent: false
                )

                return StatusTimeViewModel(viewModel: timeViewModel, timeInterval: nil) { _ in
                    timeViewModel
                }
            } else if currentBlock >= model.preparingEnd {
                return createTimeViewModel(
                    state: referendum.state,
                    atBlock: max(currentBlock, model.timeoutAt),
                    currentBlock: currentBlock,
                    blockDuration: blockDuration,
                    timeStringProvider: strings.governanceReferendumsTimeTimeout,
                    locale: locale
                )
            } else {
                return createTimeViewModel(
                    state: referendum.state,
                    atBlock: model.preparingEnd,
                    currentBlock: currentBlock,
                    blockDuration: blockDuration,
                    timeStringProvider: strings.governanceReferendumsTimeDeciding,
                    locale: locale
                )
            }
        case let .deciding(model):
            switch model.voting {
            case let .supportAndVotes(supportAndVotes):
                if supportAndVotes.isPassing(at: currentBlock),
                   let confirmationUntil = model.confirmationUntil {
                    return createTimeViewModel(
                        state: referendum.state,
                        atBlock: confirmationUntil,
                        currentBlock: currentBlock,
                        blockDuration: blockDuration,
                        timeStringProvider: strings.governanceReferendumsTimeApprove,
                        locale: locale
                    )
                } else {
                    return createTimeViewModel(
                        state: referendum.state,
                        atBlock: model.rejectedAt,
                        currentBlock: currentBlock,
                        blockDuration: blockDuration,
                        timeStringProvider: strings.governanceReferendumsTimeReject,
                        locale: locale
                    )
                }
            }
        case let .approved(model):
            guard let whenEnactment = model.whenEnactment else {
                return nil
            }

            return createTimeViewModel(
                state: referendum.state,
                atBlock: whenEnactment,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                timeStringProvider: strings.governanceReferendumsTimeExecute,
                locale: locale
            )
        case .rejected, .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }
}
