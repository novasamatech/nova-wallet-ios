extension StakingSharedState {
    func setupServices() {
        eraValidatorService?.setup()
        rewardCalculationService?.setup()
        blockTimeService?.setup()
    }

    func throttleServices() {
        eraValidatorService?.throttle()
        rewardCalculationService?.throttle()
        blockTimeService?.throttle()
    }
}
