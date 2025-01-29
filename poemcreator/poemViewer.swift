import Foundation
import SwiftUI
import SwiftOpenAI

public let systemMessage = """
You are a Chinese poem evaluator tasked with determining the quality of a given poem and deciding whether it should be "accepted" or "deleted". Use the following criteria to evaluate the poem and provide your decision. 

Analysis Criteria as reference for example: Title, Tone, Style, Imagery, Symbolism, Themes, Structure, Poetic Techniques, Emotional Impact and so on. If mostly/generally positive, mark Accepted. If mostly negative, mark Deleted.

Author Background:
The author specializes in introspection and existential themes, using vivid natural imagery and a free-verse style. Their work explores life, identity, the tension between belonging and escape, and incorporates philosophical and spiritual elements.

Guidelines:
- Ensure the poem is written in Chinese.
- Ensure the poem has no missing or inconsistent phrases or sentences.
- Do not use parallelism (绝对不要排比！)
- Keep responses concise and brief (要尽量简短简洁，不要太长)
"""
//                "You are a poem evaluator. Decide if the poem is good or not. Mark Accepted or Deleted."


/// What we eventually want to know for the poem
struct EvaluationResult {
    let accepted: Bool
    let deleted: Bool
}

/// Directly matches the GPT response format from your JSON schema
struct EvaluateResponse: Decodable {
    let steps: [Step]
    let final_answer: String

    struct Step: Decodable {
        let Accepted: Bool
        let Deleted: Bool
    }
}

struct Config {
    static var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path),
              let config = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any],
              let key = config["API_KEY"] as? String else {
            fatalError("API_KEY not found in Config.plist")
        }
        return key
    }
}

public let apiKey = Config.apiKey
public let service = OpenAIServiceFactory.service(apiKey: apiKey)

class PoemViewModel: ObservableObject {
    @Published var poems: [Poem] = []
    
    /// Flag indicating if we're currently doing a big evaluate-all operation
    @Published var isBulkEvaluationInProgress = false

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
    
    // MARK: Evaluate a poem
    func evaluatePoem(_ poem: Poem) {
        Task {
            do {
                let prompt = """
                Title: \(poem.image)
                Body: \(poem.response)
                """

                // 1) Perform the async GPT call
                let evaluation = try await openAIEvaluatePoem(prompt: prompt, systemPrompt: systemMessage)

                // 2) Update the poem on main thread
                await MainActor.run {
                    if evaluation.accepted && !evaluation.deleted {
                        self.accept(poem)
                    } else if evaluation.deleted {
                        self.delete(poem)
                    } else {
                        print("No decision made, or conflicting results. (accepted=\(evaluation.accepted), deleted=\(evaluation.deleted))")
                    }
                }
            } catch {
                print("Error evaluating poem: \(error.localizedDescription)")
            }
        }
    }

    // MARK: The async GPT call (using your chat completion object)
    private func openAIEvaluatePoem(prompt: String, systemPrompt: String) async throws -> EvaluationResult {
        // We'll build the JSON schema parameters, etc.
        // Then call an async 'service.startChat(parameters:)' that returns ChatCompletionObject
        // and parse the first choice's message.content as JSON.

        // 1: JSON schema definitions
        // (You can keep them or store them outside if reused)
        let stepSchema = JSONSchema(
           type: .object,
           properties: [
              "Accepted": JSONSchema(type: .boolean),
              "Deleted": JSONSchema(type: .boolean)
           ],
           required: ["Accepted", "Deleted"],
           additionalProperties: false
        )

        let stepsArraySchema = JSONSchema(type: .array, items: stepSchema)
        let finalAnswerSchema = JSONSchema(type: .string)

        let responseFormatSchema = JSONSchemaResponseFormat(
           name: "evaluate",
           strict: true,
           schema: JSONSchema(
              type: .object,
              properties: [
                 "steps": stepsArraySchema,
                 "final_answer": finalAnswerSchema
              ],
              required: ["steps", "final_answer"],
              additionalProperties: false
           )
        )

        // 2) Build the ChatCompletionParameters
        let sysMessage = ChatCompletionParameters.Message(role: .system, content: .text(systemPrompt))
        let userMessage = ChatCompletionParameters.Message(role: .user, content: .text(prompt))
        let parameters = ChatCompletionParameters(
            messages: [sysMessage, userMessage],
            model: .gpt4o20241120,
            responseFormat: .jsonSchema(responseFormatSchema)
        )

        // 3) Make the network call, get ChatCompletionObject
        let chatResponse: ChatCompletionObject
        do {
            chatResponse = try await service.startChat(parameters: parameters)
        } catch {
            throw error
        }

        // 4) Get the first choice
        guard let firstChoice = chatResponse.choices.first else {
            throw NSError(domain: "PoemEval", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No choices returned from GPT"
            ])
        }

        // 5) The actual JSON is in firstChoice.message.content
        guard let content = firstChoice.message.content, !content.isEmpty else {
            throw NSError(domain: "PoemEval", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "GPT returned empty content"
            ])
        }

        // 6) Parse the JSON string into EvaluateResponse
        let data = Data(content.utf8)
        let evaluateResponse: EvaluateResponse
        do {
            evaluateResponse = try JSONDecoder().decode(EvaluateResponse.self, from: data)
        } catch {
            throw NSError(domain: "PoemEval", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse EvaluateResponse: \(error)"
            ])
        }

        // 7) Extract accepted/deleted from the first step
        guard let firstStep = evaluateResponse.steps.first else {
            return EvaluationResult(accepted: false, deleted: false)
        }
        let accepted = firstStep.Accepted
        let deleted = firstStep.Deleted
        print("Evaluation from GPT: accepted=\(accepted), deleted=\(deleted), final=\(evaluateResponse.final_answer)")

        // 8) Return our local result
        return EvaluationResult(accepted: accepted, deleted: deleted)
    }
    
    /// Evaluate all poems in parallel. Each poem spawns a child task calling GPT.
    func evaluateAll(poems: [Poem]) {
        Task {
            // 1) Create a task group that returns (poem, result) for each poem
            await withTaskGroup(of: (Poem, Result<EvaluationResult, Error>).self) { group in

                // 2) For each poem, add a child task
                for poem in poems {
                    group.addTask {
                        do {
                            let evaluation = try await self.openAIEvaluatePoem(
                                prompt: """
                                Title: \(poem.image)
                                Body: \(poem.response)
                                """,
                                systemPrompt: systemMessage
//                                    "You are a poem evaluator. Decide if the poem is good or not. Mark Accepted or Deleted."
                            )
                            // Return success result
                            return (poem, .success(evaluation))
                        } catch {
                            // Return failure result
                            return (poem, .failure(error))
                        }
                    }
                }

                // 3) Process each child’s result as soon as it finishes
                for await (poem, outcome) in group {
                    switch outcome {
                    case .success(let evaluation):
                        // Update poem on the main actor
                        await MainActor.run {
                            if evaluation.accepted && !evaluation.deleted {
                                self.accept(poem)
                            } else if evaluation.deleted {
                                self.delete(poem)
                            } else {
                                print("No decision for poem id=\(poem.id)")
                            }
                        }

                    case .failure(let error):
                        print("Error evaluating poem id \(poem.id): \(error)")
                    }
                }
            }
        }
    }
    
    /// Evaluate all poems in parallel, in chunks of 100.
    /// After each chunk, wait 60 seconds to respect rate limit.
    func evaluateAllInChunks(poems: [Poem]) {
        // 1) If already in progress, do nothing
        if isBulkEvaluationInProgress {
            print("Bulk evaluation is already running.")
            return
        }

        // 2) Mark the flag
        isBulkEvaluationInProgress = true

        Task {
            var offset = 0
//            let chunkSize = 100
            
            let poemSize = poems.count
            var chunkSize = 100  // Default chunk size

            // Calculate the number of runs required
            var numRuns = poemSize / chunkSize
            if poemSize % chunkSize != 0 {
                numRuns += 1
            }

            // Adjust the chunk size for each run, ensuring it doesn't exceed 100
            chunkSize = poemSize / numRuns
            if poemSize % numRuns != 0 {
                chunkSize += 1
            }

            print("Total poems: \(poemSize), Runs required: \(numRuns), Chunk size: \(chunkSize)")

            // If no poems, just finish
            guard !poems.isEmpty else {
                self.isBulkEvaluationInProgress = false
                return
            }

            while offset < poems.count {
                // 3) Build the chunk
                let endIndex = min(offset + chunkSize, poems.count)
                let chunk = Array(poems[offset..<endIndex])
                print("Evaluating chunk from \(offset) to \(endIndex-1) (\(chunk.count) poems).")

                // 4) Evaluate this chunk in parallel
                await evaluateChunkParallel(chunk)

                offset += chunkSize

                // 5) If we still have more poems, sleep 60 seconds
                if offset < poems.count {
                    print("Finished a chunk; waiting 60s for rate limit cooldown.")
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
            }

            // Done all chunks
            print("All chunks completed.")
            self.isBulkEvaluationInProgress = false
        }
    }

    /// Evaluate a chunk of poems in parallel withTaskGroup
    private func evaluateChunkParallel(_ chunk: [Poem]) async {
        await withTaskGroup(of: (Poem, Result<EvaluationResult, Error>).self) { group in
            // spawn child tasks in parallel
            for poem in chunk {
                group.addTask {
                    do {
                        let evaluation = try await self.openAIEvaluatePoem(
                            prompt: """
                            Title: \(poem.image)
                            Body: \(poem.response)
                            """,
                            systemPrompt: systemMessage
                        )
                        return (poem, .success(evaluation))
                    } catch {
                        return (poem, .failure(error))
                    }
                }
            }

            // handle each child as it completes
            for await (poem, outcome) in group {
                switch outcome {
                case .success(let evaluation):
                    await MainActor.run {
                        if evaluation.accepted && !evaluation.deleted {
                            self.accept(poem)
                        } else if evaluation.deleted {
                            self.delete(poem)
                        } else {
                            print("No decision made for poem ID \(poem.id)")
                        }
                    }
                case .failure(let error):
                    print("Error evaluating poem id \(poem.id): \(error)")
                }
            }
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
    
    
    @discardableResult
    func addPoemFromClipboard() -> Bool {
        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }

        // Split lines, first line => image, rest => response
        let lines = clipboardText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return false }

        let newTitle = lines[0]
        let newBody = lines.dropFirst().joined(separator: "\n")

        let newId = generateNewID()
        let newPoem = Poem(
            id: newId,
            adaptor: "",
            outer_idx: 0,
            inner_idx: 0,
            image: newTitle,
            response: newBody,
            accepted: false,
            deleted: false,
            edited: false
        )

        poems.append(newPoem)
        return true
    }

    func generateNewID() -> Int {
        let maxID = poems.map(\.id).max() ?? 0
        return maxID + 1
    }
    
    
}

