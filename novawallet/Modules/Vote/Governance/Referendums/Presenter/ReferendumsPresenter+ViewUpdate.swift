import Foundation

extension ReferendumsPresenter {
    func updateReferendumsView() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber,
              let blockTime = blockTime,
              let referendums = referendums,
              let chainModel = chain else {
            return
        }

        let referendumsSections = creaateReferendumsSections(
            for: referendums,
            accountVotes: voting?.value?.votes,
            chainInfo: .init(chain: chainModel, currentBlock: currentBlock, blockDuration: blockTime)
        )
        let activitySection = createActivitySection(
            chain: chainModel,
            currentBlock: currentBlock
        )
        let tinderGovSection = createTinderGovSection(
            for: referendums,
            accountVotes: voting?.value?.votes
        )
        let settingsSection = ReferendumsSection.settings(isFilterOn: filter != .all)
        let filteredReferendumsSections = filteredReferendumsSections(for: referendumsSections)

        let allSections = [
            activitySection,
            tinderGovSection,
            settingsSection
        ].compactMap { $0 } + filteredReferendumsSections

        view.update(model: .init(sections: allSections))
        observableViewState.state.cells = referendumsSections.flatMap(ReferendumsSection.Lens.referendums.get)
    }

    func updateTimerDisplay() {
        guard
            let view = view,
            let maxStatusTimeInterval = maxStatusTimeInterval,
            let remainedTimeInterval = countdownTimer?.remainedInterval,
            let timeModels = timeModels else {
            return
        }

        let elapsedTime = maxStatusTimeInterval >= remainedTimeInterval ?
            maxStatusTimeInterval - remainedTimeInterval : 0

        let updatedTimeModels = timeModels.reduce(into: timeModels) { result, model in
            guard let timeModel = model.value,
                  let time = timeModel.timeInterval else {
                return
            }

            guard time > elapsedTime else {
                result[model.key] = nil
                return
            }
            let remainedTime = time - elapsedTime
            guard let updatedViewModel = timeModel.updateModelClosure(remainedTime) else {
                result[model.key] = nil
                return
            }

            result[model.key] = .init(
                viewModel: updatedViewModel,
                timeInterval: time,
                updateModelClosure: timeModel.updateModelClosure
            )
        }

        updateTimeModels(
            with: updatedTimeModels,
            updatingMaxStatusTimeInterval: false
        )

        view.updateReferendums(time: updatedTimeModels)
    }

    func updateTimeModels() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber, let blockTime = blockTime, let referendums = referendums else {
            return
        }

        let timeModels = statusViewModelFactory.createTimeViewModels(
            referendums: referendums,
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: selectedLocale
        )

        updateTimeModels(
            with: timeModels,
            updatingMaxStatusTimeInterval: true
        )

        invalidateTimer()
        setupTimer()
        updateTimerDisplay()

        view.updateReferendums(time: timeModels)
    }

    func clearOnAssetSwitch() {
        invalidateTimer()
        clearState()

        view?.update(model: .init(sections: viewModelFactory.createLoadingViewModel()))
    }

    func provideChainBalance() {
        guard
            let chain = chain,
            let governanceType = governanceType,
            let asset = chain.utilityAsset() else {
            return
        }

        let viewModel = chainBalanceFactory.createViewModel(
            from: governanceType.title(for: chain),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: freeBalance,
            locale: selectedLocale
        )

        view?.didReceiveChainBalance(viewModel: viewModel)
    }
}
