# poemPicker
### Repeated first element when loading json because of not unique id (Int) in FOrEach loop in swift

You’re seeing **“the ID 0 occurs multiple times within the collection”** because **multiple poems** all have `id=0` (or the same `id`) in your data. SwiftUI’s `ForEach` requires each item to have a **unique** `id` to properly differentiate them; otherwise you get duplication or undefined results.

Your JSON might be missing or ignoring the `id` field, so each poem defaults to `id=0`. Even though your fallback decoding logic works (it loads different `title`/`body` for each poem), **SwiftUI** sees the same `id=0` for all, so it complains about duplicates.

---

# How to Fix It

## Option A) Use a Separate Unique ID (Recommended)

1. Keep the user’s `id` (from JSON) as is, or default it to 0 if absent.  
2. Add **another** unique property in Swift (e.g. `swiftID = UUID()`) for SwiftUI’s `id`.  
3. In your `ForEach`, use that **unique** property (like `\.swiftID`) so each item is truly distinct.

### Example

```swift
import SwiftUI

struct Poem: Equatable, Codable {
    // The user’s "id" from JSON
    let jsonID: Int
    
    // A unique ID for Swift’s ForEach
    let swiftID = UUID()
    
    var adaptor: String
    var outer_idx: Int
    var inner_idx: Int
    var image: String
    var response: String
    var accepted: Bool
    var deleted: Bool
    var edited: Bool

    // same CodingKeys and init(from:) logic as before
    // decode `jsonID` from "id" 
    // plus fallback for "image"/"title", etc.

    // no need for `Identifiable`, because we’ll supply `id: \.swiftID` in ForEach
}

// Then in your CardStackView / PoemListView:
ForEach(viewModel.poems, id: \.swiftID) { poem in
    // ...
}
```

**Why?**  
- Each `Poem` always gets a random `swiftID = UUID()`.  
- Even if many poems have `jsonID=0`, SwiftUI sees different `swiftID`s.  
- You still preserve the user’s integer ID in `jsonID` for logic or display, but it’s not used as SwiftUI’s unique identifier.

Result: **no** more “the ID 0 occurs multiple times,” and you still decode fallback JSON correctly.

---

## Option B) Generate a Unique Integer ID if JSON’s `id` is 0

If you really want your `id` property to remain an `Int` (not a UUID), you can do something like:

```swift
struct Poem: Identifiable, Codable, Equatable {
    // This is used by SwiftUI:
    var id: Int
    
    // rest of your properties...
    
    // a static global counter to assign unique IDs
    private static var globalCounter = 1

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // read the JSON's 'id'
        let rawID = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        if rawID == 0 {
            // generate a unique new ID
            self.id = Poem.globalCounter
            Poem.globalCounter += 1
        } else {
            self.id = rawID
        }

        // decode or fallback for 'image' etc.
        // ...
    }
}
```

In that snippet, **any** poem that has `id=0` in JSON automatically gets assigned a unique integer from a global counter. So they won’t all conflict. Then you can do:

```swift
ForEach(viewModel.poems) { poem in
    // ...
}
```
and SwiftUI sees unique `id` across all poems.

**Downside**: a global static counter can keep incrementing if you load multiple sets. Or if you reload the file, you might shift IDs. Usually that’s not a big deal if you only do it once per app launch or have no stable ID requirement.

---

## Option C) Use `.id(\.self)` in `ForEach` (Less Recommended)

Another approach is:

```swift
ForEach(viewModel.poems, id: \.self) { poem in
    ...
}
```
**but** then `Poem` must conform to `Hashable` in a way that uniquely identifies each instance. If your `Poem` includes strings, booleans, etc., you can `Poem: Hashable`. This still might cause confusion if two poems are identical in content, so it’s not as safe as generating a guaranteed-unique property.

---

## Summary

You’re seeing repeated “ID 0” warnings and repeated items because **your JSON** lacks a unique integer for each poem, so they all decode to `id=0`. SwiftUI’s `ForEach` sees collisions.

**Solve** by giving each poem a truly **unique** ID:

- **A**) Keep user’s `id` as `jsonID`, add a new `swiftID = UUID()`, then do `.id(\.swiftID)`.  
- **B**) If user’s `id` is 0, generate a new integer for each poem.  
- **C**) Provide `.id(\.self)` if you want hashing (less ideal).

This ensures the deck and list each get distinct items instead of repeated ID collisions.

# Async GPT request Chunk (following rate limit)
Below is a **revised** chunk-based evaluation approach that **guarantees** your `"Evaluate All"` button becomes **re-enabled** after all chunks have completed. The key is to ensure you set `isBulkEvaluationInProgress = false` at the **end** of your final Task, so the UI sees that the process is finished.

---

## 1) Why the Button Might Remain Disabled

If your code sets `isBulkEvaluationInProgress = true` at the start and never resets it to `false` at the end, or if you do reset it but on the **wrong thread** or after returning from a `Task` prematurely, the UI never sees `isBulkEvaluationInProgress = false`. Hence, the button remains disabled.

---

## 2) Example of a Corrected `evaluateAllInChunks` Approach

Here's a **complete** snippet showing how to do chunk-based evaluation and definitely revert `isBulkEvaluationInProgress` when done:

```swift
extension PoemViewModel {
    /// Evaluate all poems in parallel, in chunks of up to 100. 
    /// After each chunk, wait 55 seconds for rate limit. 
    /// Re-enable the 'Evaluate All' button after finishing.
    func evaluateAllInChunks(poems: [Poem]) {
        // 1) If already in progress, do nothing
        if isBulkEvaluationInProgress {
            print("Bulk evaluation is already running.")
            return
        }

        // 2) Mark the flag
        isBulkEvaluationInProgress = true

        Task {
            do {
                try await internalEvaluateChunks(poems: poems)
            } catch {
                print("Unexpected error in chunk evaluation: \(error)")
            }
            // Regardless of success or failure, we must revert the flag
            await MainActor.run {
                self.isBulkEvaluationInProgress = false
            }
            print("Evaluate All finished. isBulkEvaluationInProgress set to false.")
        }
    }

    /// The internal chunk logic
    private func internalEvaluateChunks(poems: [Poem]) async throws {
        let chunkSize = 100
        var offset = 0

        guard !poems.isEmpty else { return }

        while offset < poems.count {
            let endIndex = min(offset + chunkSize, poems.count)
            let chunk = Array(poems[offset..<endIndex])
            print("Evaluating chunk from \(offset) to \(endIndex-1).")

            // Evaluate this chunk in parallel
            await evaluateChunkParallel(chunk)
            
            offset += chunkSize
            if offset < poems.count {
                // Wait 55 seconds before next chunk
                print("Finished chunk; waiting 55s to avoid rate limit.")
                try await Task.sleep(nanoseconds: 55_000_000_000)
            }
        }
        print("All chunks completed.")
    }

    /// Evaluate a chunk of poems in parallel
    private func evaluateChunkParallel(_ chunk: [Poem]) async {
        await withTaskGroup(of: (Poem, Result<EvaluationResult, Error>).self) { group in
            for poem in chunk {
                group.addTask {
                    do {
                        let evaluation = try await self.openAIEvaluatePoem(
                            prompt: """
                            Title: \(poem.image)
                            Body: \(poem.response)
                            """,
                            systemPrompt: "You are a poem evaluator. Decide if the poem is good or not. Mark Accepted or Deleted."
                        )
                        return (poem, .success(evaluation))
                    } catch {
                        return (poem, .failure(error))
                    }
                }
            }

            for await (poem, outcome) in group {
                switch outcome {
                case .success(let evaluation):
                    await MainActor.run {
                        if evaluation.accepted && !evaluation.deleted {
                            self.accept(poem)
                        } else if evaluation.deleted {
                            self.delete(poem)
                        } else {
                            print("No decision made for poem ID \(poem.id).")
                        }
                    }
                case .failure(let error):
                    print("Error evaluating poem id \(poem.id): \(error)")
                }
            }
        }
    }
    
    // Example single-call GPT function
    private func openAIEvaluatePoem(prompt: String, systemPrompt: String) async throws -> EvaluationResult {
        // ...
    }
}
```

### Highlights

1. **`evaluateAllInChunks`** sets `isBulkEvaluationInProgress = true`, then spawns a `Task`.  
2. **Inside** that Task, we call `internalEvaluateChunks(poems:)`. If it completes **or** throws, we catch the error, then **finally** do `await MainActor.run { self.isBulkEvaluationInProgress = false }`.  
3. With that, the UI sees `isBulkEvaluationInProgress = false`, so the button is re-enabled.  
4. We **must** do `MainActor.run { ... }` or do `DispatchQueue.main.async` to ensure the property is updated on the main thread.

---

## 3) Disabling the Button in the List

In your `PoemListView`:

```swift
Button {
    viewModel.evaluateAllInChunks(poems: displayedPoems)
} label: {
    Label("Evaluate All", systemImage: "brain.head.profile")
}
.disabled(viewModel.isBulkEvaluationInProgress)
```

**Now**:

- If not in progress, user can click → sets `isBulkEvaluationInProgress = true`, button becomes disabled.  
- When all chunks done, we set `isBulkEvaluationInProgress = false`, button re-enables automatically.

---

## 4) Confirming the Flow

1. **User** clicks “Evaluate All.”  
2. Code sets `isBulkEvaluationInProgress = true`. The button is disabled.  
3. The chunk logic runs: 100 parallel tasks, wait 55s, next chunk, etc.  
4. On finishing or error, we do `isBulkEvaluationInProgress = false`.  
5. The button reappears enabled, letting the user run “Evaluate All” again if they want.

**Thus** your “Evaluate All” is disabled only while the chunk process is ongoing, and re-enabled when “All chunks completed.”

