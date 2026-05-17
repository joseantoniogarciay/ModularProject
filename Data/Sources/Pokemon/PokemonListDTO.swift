import Core
import Foundation

struct PokemonListDTO: Decodable, Sendable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [PokemonListItemDTO]
}

struct PokemonListItemDTO: Decodable, Sendable {
    let name: String
    let url: String
}

extension PokemonListItemDTO {
    func toDomain() -> Pokemon? {
        guard let idString = url.split(separator: "/").last.map(String.init),
              let id = Int(idString)
        else { return nil }
        let imageURL = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
        return Pokemon(id: id, name: name, imageURL: imageURL)
    }
}
