struct GenericLens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
}
