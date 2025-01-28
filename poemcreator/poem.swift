import SwiftUI

struct Poem: Identifiable, Codable, Equatable {
    let id: Int

    var adaptor: String
    var outer_idx: Int
    var inner_idx: Int

    // The poem's main title text
    var image: String

    // The poem's body text
    var response: String

    var accepted: Bool
    var deleted: Bool
    var edited: Bool
    
    // a static global counter to assign unique IDs
    private static var globalCounter = 1

    enum CodingKeys: String, CodingKey {
        case id
        case adaptor
        case outer_idx
        case inner_idx
        case image
        case title
        case response
        case body
        case accepted
        case deleted
        case edited
    }

    // MARK: - Custom decode fallback
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // read the JSON's 'id'
        let rawID = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        if rawID == 0 {
            // generate a unique new ID
            id = Poem.globalCounter
            Poem.globalCounter += 1
        } else {
            id = rawID
        }

        adaptor    = try container.decodeIfPresent(String.self, forKey: .adaptor) ?? ""
        outer_idx  = try container.decodeIfPresent(Int.self, forKey: .outer_idx) ?? 0
        inner_idx  = try container.decodeIfPresent(Int.self, forKey: .inner_idx) ?? 0

        // 'image' or fallback 'title'
        image = try container.decodeIfPresent(String.self, forKey: .image)
             ?? container.decodeIfPresent(String.self, forKey: .title)
             ?? "Untitled Poem"

        // 'response' or fallback 'body'
        response = try container.decodeIfPresent(String.self, forKey: .response)
                  ?? container.decodeIfPresent(String.self, forKey: .body)
                  ?? "No content"

        accepted = try container.decodeIfPresent(Bool.self, forKey: .accepted) ?? false
        deleted  = try container.decodeIfPresent(Bool.self, forKey: .deleted)  ?? false
        edited   = try container.decodeIfPresent(Bool.self, forKey: .edited)   ?? false
    }

    // MARK: - Encodable to keep it fully Codable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(adaptor, forKey: .adaptor)
        try container.encode(outer_idx, forKey: .outer_idx)
        try container.encode(inner_idx, forKey: .inner_idx)
        try container.encode(image, forKey: .image)       // we always store final 'image'
        try container.encode(response, forKey: .response) // we always store final 'response'
        try container.encode(accepted, forKey: .accepted)
        try container.encode(deleted, forKey: .deleted)
        try container.encode(edited, forKey: .edited)
    }

    // Optional manual init for new instances
    init(
        id: Int = 0,
        adaptor: String = "",
        outer_idx: Int = 0,
        inner_idx: Int = 0,
        image: String,
        response: String,
        accepted: Bool = false,
        deleted: Bool = false,
        edited: Bool = false
    ) {
        self.id        = id
        self.adaptor   = adaptor
        self.outer_idx = outer_idx
        self.inner_idx = inner_idx
        self.image     = image
        self.response  = response
        self.accepted  = accepted
        self.deleted   = deleted
        self.edited    = edited
    }
}

