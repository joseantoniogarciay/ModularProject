import Core
import Foundation

struct PokemonListResponseDTO: Decodable, Sendable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [PokemonListItemDTO]
}

struct PokemonListItemDTO: Decodable, Sendable {
    let name: String
    let url: String
}

struct PokemonDetailDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: SpritesDTO
    let types: [PokemonTypeSlotDTO]
    let stats: [PokemonStatDTO]
}

struct SpritesDTO: Decodable, Sendable {
    let frontDefault: String?
    let other: OtherSpritesDTO?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case other
    }
}

struct OtherSpritesDTO: Decodable, Sendable {
    let officialArtwork: ArtworkDTO?

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct ArtworkDTO: Decodable, Sendable {
    let frontDefault: String?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
    }
}

struct PokemonTypeSlotDTO: Decodable, Sendable {
    let slot: Int
    let type: NamedReferenceDTO
}

struct PokemonStatDTO: Decodable, Sendable {
    let baseStat: Int
    let stat: NamedReferenceDTO

    enum CodingKeys: String, CodingKey {
        case baseStat = "base_stat"
        case stat
    }
}

struct NamedReferenceDTO: Decodable, Sendable {
    let name: String
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

extension PokemonDetailDTO {
    func toDomain() -> PokemonDetail {
        let artwork = sprites.other?.officialArtwork?.frontDefault
        let fallback = sprites.frontDefault
        let imageURL = (artwork ?? fallback).flatMap { URL(string: $0) }
        return PokemonDetail(
            id: id,
            name: name,
            imageURL: imageURL,
            types: types.sorted { $0.slot < $1.slot }.map { $0.type.name },
            heightDecimetres: height,
            weightHectograms: weight,
            stats: stats.map { PokemonStat(name: $0.stat.name, baseValue: $0.baseStat) }
        )
    }
}
