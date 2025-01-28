import SwiftUI

/// Represents a poem. Now has both `accepted` and `deleted`.
struct Poem: Identifiable, Codable, Equatable {
    var adaptor: String
    var outer_idx: Int
    var inner_idx: Int
    var image: String
    var response: String
    /// Whether this poem has been accepted
    var accepted: Bool
    var edited: Bool
    /// Whether this poem has been deleted
    var deleted: Bool
    let id: Int
    

    init(
        id: Int,
        adaptor: String,
        outer_idx: Int,
        inner_idx: Int,
        image: String,
        response: String,
        accepted: Bool,
        deleted: Bool,
        edited: Bool
    ) {
        self.id = id
        self.adaptor = adaptor
        self.outer_idx = outer_idx
        self.inner_idx = inner_idx
        self.image = image
        self.response = response
        self.accepted = accepted
        self.deleted = deleted
        self.edited = edited
    }
}

