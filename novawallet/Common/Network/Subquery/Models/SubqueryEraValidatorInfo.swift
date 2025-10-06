import SubstrateSdk

struct SubqueryEraValidatorInfo {
    let address: AccountAddress
    let era: Staking.EraIndex

    init?(from json: JSON) {
        guard
            let era = json.era?.unsignedIntValue,
            let address = json.address?.stringValue
        else { return nil }

        self.era = Staking.EraIndex(era)
        self.address = address
    }
}
