extension ParachainStakingSharedState {
    func setupServices() {
        collatorService?.setup()
        rewardCalculationService?.setup()
        blockTimeService?.setup()
    }

    func throttleServices() {
        collatorService?.throttle()
        rewardCalculationService?.throttle()
        blockTimeService?.throttle()
    }
}
