struct GenericLens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole

    func then<Subpart>(_ to: GenericLens<Part, Subpart>) -> GenericLens<Whole, Subpart> {
        GenericLens<Whole, Subpart>(
            get: { to.get(get($0)) },
            set: { set(to.set($0, get($1)), $1) }
        )
    }
}
