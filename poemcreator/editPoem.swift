import SwiftUI

struct EditPoemSheet: View {
    @Environment(\.presentationMode) var presentationMode

    let poem: Poem
    var onSave: (Poem, String, String) -> Void

    @State private var editTitle = true
    @State private var editBody = true

    @State private var titleInput: String
    @State private var bodyInput: String

    init(poem: Poem, onSave: @escaping (Poem, String, String) -> Void) {
        self.poem = poem
        self.onSave = onSave
        _titleInput = State(initialValue: poem.image)
        _bodyInput = State(initialValue: poem.response)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fields to Edit")) {
                    Toggle("Title", isOn: $editTitle)
                    Toggle("Body", isOn: $editBody)
                }

                if editTitle {
                    Section(header: Text("Title")) {
                        TextField("Title", text: $titleInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                if editBody {
                    Section(header: Text("Body")) {
                        TextEditor(text: $bodyInput)
                            .frame(minHeight: 120)
                    }
                }
            }
            .navigationTitle("Edit Poem")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let finalTitle = editTitle ? titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                               : poem.image
                    let finalBody = editBody ? bodyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                             : poem.response

                    guard !finalTitle.isEmpty, !finalBody.isEmpty else {
                        // Could show alert
                        return
                    }

                    onSave(poem, finalTitle, finalBody)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

