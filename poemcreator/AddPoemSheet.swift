import SwiftUI

struct AddPoemSheet: View {
    // Callbacks for the parent view to handle the actions
    let onAddFromClipboard: () -> Void
    let onCreateManually: () -> Void
    let onCancel: () -> Void
    let onRequestManualCreation: () -> Void
    
    // Possibly state for showing a sample preview of the clipboard
    @State private var clipboardPreview: String = ""
    
    @Environment(\.presentationMode) var presentationMode

    // We store the entire clipboard text for the preview
    @State private var clipboardText: String = "Clipboard empty."

    var body: some View {
        NavigationView {
            List {
                Section {
                   // 1) Paste from Clipboard row
                   pasteRow
                   // 2) Create Manually row
                   createManuallyRow
                } header: {
                    Text("Create a new Poem")
                } footer: {
                    Text("Long-press to preview the entire clipboard text before pasting.")
                }
            }
            .navigationTitle("Add Poem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Grab the full clipboard text
                if let ctext = UIPasteboard.general.string,
                   !ctext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    clipboardText = ctext
                } else {
                    clipboardText = "Clipboard empty."
                }
                
                // Optionally show a short preview of the clipboard if any
                if let ctext = UIPasteboard.general.string {
                    // Show first ~50 chars
                    let lines = ctext.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if let firstLine = lines.first {
                        // Show a short sample
                        clipboardPreview = "\(firstLine.prefix(50))..."
                    }
                } else {
                    clipboardPreview = "Clipboard empty."
                }
                
            } // onAppear
        }
    }
    
    private var pasteRow: some View {
        // A single row for “Paste from Clipboard”
        HStack {
            Image(systemName: "doc.on.doc")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
               Text("Paste from Clipboard")
               if !clipboardPreview.isEmpty {
                  Text("“\(clipboardPreview)”").font(.caption).foregroundColor(.secondary)
               }
            }
        }
        // iOS 17 context menu with preview
        .contextMenu {
            // The menu action:
            Button("Paste Now") {
                onAddFromClipboard()
                presentationMode.wrappedValue.dismiss()
            }
        } preview: {
            // Show the entire text in a scroll view
            VStack(alignment: .leading, spacing: 8) {
                Text("Clipboard Preview")
                    .font(.headline)
                ScrollView {
                    Text(clipboardText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .presentationCompactAdaptation(.none)
        }
    }
    
    // 2) “Create Manually” row
    private var createManuallyRow: some View {
        HStack {
            Image(systemName: "square.and.pencil")
                .foregroundColor(.orange)
            Text("Create Manually")
        }
        .onTapGesture {
            onRequestManualCreation()
            presentationMode.wrappedValue.dismiss()
        }
    }
}

