import SwiftUI

class PoemViewModel: ObservableObject {
    @Published var poems: [Poem] = []

    @Published var filter: PoemFilter = .all
    @Published var searchText: String = ""

    // For multi-selection in the list
    @Published var multiSelectionMode: Bool = false
    @Published var selectedPoemIDs: Set<Int> = []

    // MARK: Load Default
    func loadDefaultPoems() {
        do {
            let fileURL = getDocumentsDirectory().appendingPathComponent("overall_poems.json")
            if !FileManager.default.fileExists(atPath: fileURL.path),
               let bundleURL = Bundle.main.url(forResource: "overall_poems", withExtension: "json") {
                try FileManager.default.copyItem(at: bundleURL, to: fileURL)
            }
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([Poem].self, from: data)
            poems = loaded
            print("Loaded default \(poems.count) poems.")
        } catch {
            print("Error loading default poems: \(error)")
            poems = []  // fallback empty
        }
    }

    // MARK: Load Custom
    func loadCustomJSON(from fileURL: URL) {
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([Poem].self, from: data)
            poems = loaded
            print("Loaded custom \(poems.count) poems from \(fileURL.lastPathComponent).")
        } catch {
            print("Error loading custom poems: \(error)")
            loadDefaultPoems()
        }
    }

    // MARK: Apply Slice
    func applySlice(start: Int, end: Int) {
        guard !poems.isEmpty else { return }
        guard start >= 0, end < poems.count, start <= end else {
            print("Invalid slice range: \(start)..\(end). Available: 0..\(poems.count - 1).")
            return
        }
        poems = Array(poems[start...end])
        print("Sliced poems to range \(start)..\(end), now have \(poems.count).")
    }
    
    
// MARK: Save All & Partial
    func saveAllPoems() {
        savePoemArray(poems, to: "updated_overall_poems.json")
    }

    func saveSelectedPoems() {
        let selected = poems.filter { selectedPoemIDs.contains($0.id) }
        guard !selected.isEmpty else {
            print("No poems selected to save.")
            return
        }
        savePoemArray(selected, to: "partial_updated_overall_poems.json")
    }

    public func savePoemArray(_ array: [Poem], to filename: String) {
        do {
            let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
            let data = try JSONEncoder().encode(array)
            try data.write(to: fileURL)
            print("Saved \(array.count) poems to \(filename).")
        } catch {
            print("Error saving poems: \(error)")
        }
    }

    // MARK: FilteredPoems
    var filteredPoems: [Poem] {
        var items = poems
        switch filter {
        case .all: break
//            // Exclude deleted (and optionally exclude accepted if you want the deck to skip them)
//            items = items.filter { !$0.deleted && !$0.accepted }
        case .accepted:
            items = items.filter { $0.accepted && !$0.deleted }
        case .deleted:
            items = items.filter { $0.deleted }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.image.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    // MARK: Operations
    func accept(_ poem: Poem) {
        if let idx = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[idx].accepted = true
            poems[idx].deleted = false
        }
    }

    func delete(_ poem: Poem) {
        if let idx = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[idx].deleted = true
            poems[idx].accepted = false
        }
    }

    func edit(_ poem: Poem, newTitle: String, newBody: String) {
        if let idx = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[idx].image = newTitle
            poems[idx].response = newBody
            poems[idx].edited = true
        }
    }

    func toggleSelection(of poem: Poem) {
        if selectedPoemIDs.contains(poem.id) {
            selectedPoemIDs.remove(poem.id)
        } else {
            selectedPoemIDs.insert(poem.id)
        }
    }

    func clearSelection() {
        selectedPoemIDs.removeAll()
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

