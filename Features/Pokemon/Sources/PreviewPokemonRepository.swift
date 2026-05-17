#if DEBUG
import Core
import Foundation

struct PreviewPokemonRepository: PokemonRepository {
    func list(offset: Int, limit: Int) async throws -> [Pokemon] {
        Self.samplePokemons
    }

    func detail(id: Int) async throws -> PokemonDetail {
        let sample = Self.samplePokemons.first(where: { $0.id == id })
        return PokemonDetail(
            id: id,
            name: sample?.name ?? "Preview",
            imageURL: sample?.imageURL,
            types: ["grass", "poison"],
            heightDecimetres: 7,
            weightHectograms: 69,
            stats: [
                PokemonStat(name: "hp", baseValue: 45),
                PokemonStat(name: "attack", baseValue: 49),
                PokemonStat(name: "defense", baseValue: 49),
                PokemonStat(name: "special-attack", baseValue: 65),
                PokemonStat(name: "special-defense", baseValue: 65),
                PokemonStat(name: "speed", baseValue: 45),
            ]
        )
    }

    static let samplePokemons: [Pokemon] = {
        let names: [String] = [
            "Bulbasaur", "Ivysaur", "Venusaur",
            "Charmander", "Charmeleon", "Charizard",
            "Squirtle", "Wartortle", "Blastoise",
            "Caterpie", "Metapod", "Butterfree",
        ]
        var result: [Pokemon] = []
        for (index, name) in names.enumerated() {
            let id: Int = index + 1
            let urlString: String = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png"
            let url: URL? = URL(string: urlString)
            result.append(Pokemon(id: id, name: name, imageURL: url))
        }
        return result
    }()
}
#endif
