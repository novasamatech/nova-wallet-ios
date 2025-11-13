import Foundation

struct GiftFeeDescription {
    let createFee: ExtrinsicFeeProtocol
    let claimFee: ExtrinsicFeeProtocol

    func createAccumulatedFee(multiplier: Int = 1) throws -> ExtrinsicFeeProtocol {
        let builder = AccumulatedFeeBuilder()

        return try builder
            .adding(fee: createFee)
            .adding(fee: claimFee)
            .multiplied(by: multiplier)
            .build()
    }
}

struct GiftFeeDescriptionBuilder {
    let createFee: ExtrinsicFeeProtocol?
    let claimFee: ExtrinsicFeeProtocol?

    init(
        createFee: ExtrinsicFeeProtocol? = nil,
        claimFee: ExtrinsicFeeProtocol? = nil
    ) {
        self.createFee = createFee
        self.claimFee = claimFee
    }

    func with(createFee: ExtrinsicFeeProtocol) -> GiftFeeDescriptionBuilder {
        GiftFeeDescriptionBuilder(
            createFee: createFee,
            claimFee: claimFee
        )
    }

    func with(claimFee: ExtrinsicFeeProtocol) -> GiftFeeDescriptionBuilder {
        GiftFeeDescriptionBuilder(
            createFee: createFee,
            claimFee: claimFee
        )
    }

    func build() -> GiftFeeDescription? {
        guard let createFee, let claimFee else { return nil }

        return GiftFeeDescription(
            createFee: createFee,
            claimFee: claimFee
        )
    }
}
