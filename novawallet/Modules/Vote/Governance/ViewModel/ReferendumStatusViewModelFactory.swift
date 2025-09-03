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
    ) -> [ReferendumIdLocal: StatusTimeViewModel?] {
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

final class ReferendumStatusViewModelFactory: ReferendumStatusViewModelFactoryProtocol {
    func createTimeViewModel(
        for referendum: ReferendumLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel? {
        switch referendum.state {
        case let .preparing(model):
            createPreparingTimeModel(
                with: model,
                for: referendum.state,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                locale: locale
            )
        case let .deciding(model):
            createDecidingTimeModel(
                with: model,
                for: referendum.state,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                locale: locale
            )
        case let .approved(model):
            createApprovedTimeModel(
                with: model,
                for: referendum.state,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                locale: locale
            )
        case .rejected, .cancelled, .timedOut, .killed, .executed:
            nil
        }
    }
}

// MARK: Private

private extension ReferendumStatusViewModelFactory {
    func createPreparingTimeModel(
        with model: ReferendumStateLocal.Preparing,
        for referendumState: ReferendumStateLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self

        if model.deposit == nil || currentBlock >= model.preparingEnd {
            return createTimeViewModel(
                state: referendumState,
                atBlock: max(currentBlock, model.timeoutAt),
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                timeStringProvider: { value in
                    strings.governanceReferendumsTimeTimeout(value)
                },
                locale: locale
            )
        } else {
            return createTimeViewModel(
                state: referendumState,
                atBlock: model.preparingEnd,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                timeStringProvider: { value in
                    strings.governanceReferendumsTimeDeciding(value)
                },
                locale: locale
            )
        }
    }

    func createDecidingTimeModel(
        with model: ReferendumStateLocal.Deciding,
        for referendumState: ReferendumStateLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self

        if model.isPassing(for: currentBlock), let confirmationUntil = model.confirmationUntil {
            return createTimeViewModel(
                state: referendumState,
                atBlock: confirmationUntil,
                currentBlock: currentBlock,
                blockDuration: blockDuration,
                timeStringProvider: { value in
                    strings.governanceReferendumsTimeApprove(value)
                },
                locale: locale
            )
        } else {
            return switch model.projectPassing(for: currentBlock) {
            case let .passing(approvalBlock):
                createTimeViewModel(
                    state: referendumState,
                    atBlock: approvalBlock,
                    currentBlock: currentBlock,
                    blockDuration: blockDuration,
                    timeStringProvider: { value in
                        strings.governanceReferendumsTimeApprove(value)
                    },
                    locale: locale
                )
            case .notPassing:
                createTimeViewModel(
                    state: referendumState,
                    atBlock: model.rejectedAt,
                    currentBlock: currentBlock,
                    blockDuration: blockDuration,
                    timeStringProvider: { value in
                        strings.governanceReferendumsTimeReject(value)
                    },
                    locale: locale
                )
            }
        }
    }

    func createApprovedTimeModel(
        with model: ReferendumStateLocal.Approved,
        for referendumState: ReferendumStateLocal,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        locale: Locale
    ) -> StatusTimeViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self

        guard let whenEnactment = model.whenEnactment else {
            return nil
        }

        return createTimeViewModel(
            state: referendumState,
            atBlock: whenEnactment,
            currentBlock: currentBlock,
            blockDuration: blockDuration,
            timeStringProvider: { value in
                strings.governanceReferendumsTimeExecute(value)
            },
            locale: locale
        )
    }

    // swiftlint:disable:next function_parameter_count
    func createTimeViewModel(
        state: ReferendumStateLocal,
        atBlock: Moment,
        currentBlock: BlockNumber,
        blockDuration: UInt64,
        timeStringProvider: @escaping (String) -> String,
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

    func createTimeViewModel(
        time: TimeInterval,
        timeStringProvider: (String) -> String,
        state: ReferendumStateLocal,
        locale: Locale
    ) -> ReferendumInfoView.Time? {
        guard let localizedDaysHours = time.localizedDaysHoursOrTime(for: locale) else {
            return nil
        }

        let timeString = timeStringProvider(localizedDaysHours)
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

    func calculateTime(block: Moment, currentBlock: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        currentBlock.secondsTo(block: block, blockDuration: blockDuration)
    }

    func isUrgent(state: ReferendumStateLocal, time: TimeInterval) -> Bool? {
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
