import Foundation

public struct PokemonDetail: Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let imageURL: URL?
    public let types: [String]
    public let heightDecimetres: Int
    public let weightHectograms: Int
    public let stats: [PokemonStat]

    public init(
        id: Int,
        name: String,
        imageURL: URL?,
        types: [String],
        heightDecimetres: Int,
        weightHectograms: Int,
        stats: [PokemonStat]
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.types = types
        self.heightDecimetres = heightDecimetres
        self.weightHectograms = weightHectograms
        self.stats = stats
    }
}

public struct PokemonStat: Sendable, Hashable {
    public let name: String
    public let baseValue: Int

    public init(name: String, baseValue: Int) {
        self.name = name
        self.baseValue = baseValue
    }
}
