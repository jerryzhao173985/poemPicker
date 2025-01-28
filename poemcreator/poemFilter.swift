import Foundation

/// Filter: All, Accepted, or Deleted
enum PoemFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case accepted = "Accepted"
    case deleted = "Deleted"

    var id: String { self.rawValue }
}

