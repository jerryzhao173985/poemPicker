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
