// PoemListView.swift
import SwiftUI

struct PoemListView: View {
    @ObservedObject var viewModel: PoemViewModel

    // For editing
    @State private var poemToEdit: Poem? = nil

    // For sharing
    @State private var showingShareSheet = false
    @State private var showingPartialShareSheet = false
    
    // For controlling the sheet
    @State private var showAddSheet = false

    // Possibly an alert if we want to handle no-clipboard scenario
    @State private var showNoClipboardAlert = false
    // Possibly a toast or alert if no valid text
    @State private var showClipboardAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(PoemFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                TextField("Search by title...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)                   // show a “Done” button
                    .onSubmit {
                        // Dismiss keyboard
                        UIApplication.shared.endEditing()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                
                List {
                    ForEach(viewModel.filteredPoems) { poem in
                        PoemRow(
                            poem: poem,
                            multiSelectionMode: viewModel.multiSelectionMode,
                            isSelected: viewModel.selectedPoemIDs.contains(poem.id),
                            onToggleSelect: {
                                viewModel.toggleSelection(of: poem)
                            },
                            onAccept: {
                                viewModel.accept(poem)
                            },
                            onEditRequest: {
                                poemToEdit = poem
                            },
                            onDelete: {
                                viewModel.delete(poem)
                            },
                            onEvaluate: {
                                // THE NEW BUTTON: Evaluate
                                viewModel.evaluatePoem(poem)
                            },
                            onCopy: {
                                UIPasteboard.general.string = "\(poem.image)\n\(poem.response)"
                            }
                        )
                        .contextMenu {
                            Button("Copy") {
                                UIPasteboard.general.string = "\(poem.image)\n\(poem.response)"
                            }
                            Button("Edit") { poemToEdit = poem }
                            Button("Accept") { viewModel.accept(poem) }
                            Button(role: .destructive) {
                                viewModel.delete(poem)
                            } label: {
                                Text("Delete")
                            }
                            Divider()
                            Button("Evaluate") {
                                viewModel.evaluatePoem(poem)
                            }
                            Divider()
                            Button("Share Poem") {
                                shareSinglePoem(poem)
                            }
                        } preview: {
                            // The custom preview that appears above the menu
                            VStack(alignment: .leading, spacing: 12) {
                                Text(poem.image)
                                    .font(.title2)
                                    .bold()
                                ScrollView {
                                    Text(poem.response)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .presentationCompactAdaptation(.none)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively) // dismiss keyboard on scroll
                //            .refreshable {
                //                // If you want to reload default or do nothing
                ////                viewModel.loadDefaultPoems()
                //            }
                
                // Bottom toolbar
                HStack {
                    Button(viewModel.multiSelectionMode ? "Done" : "Select") {
                        viewModel.multiSelectionMode.toggle()
                        if !viewModel.multiSelectionMode {
                            viewModel.clearSelection()
                        }
                    }
                    Spacer()
                    if !viewModel.multiSelectionMode {
                        Button {
                            // Instead of viewModel.saveAllPoems()
                            // we do a new method that saves `displayedPoems` only:
                            viewModel.savePoemArray(viewModel.filteredPoems, to: "filtered_poems.json")
                        } label: {
                            Label("Save All", systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Evaluate All
                        Button {
                            evaluateAllDisplayed()
                        } label: {
                            Label("Evaluate All", systemImage: "brain.head.profile")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                        // disable if already in progress
                        .disabled(viewModel.isBulkEvaluationInProgress)
                        
                        Button {
                            showingShareSheet.toggle()
                        } label: {
                            Label("Share All", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .sheet(isPresented: $showingShareSheet) {
                            let shareURL = createTempJSONFile(from: viewModel.filteredPoems,
                                                              filename: "AllPoems.json")
                            ActivityViewControllerWrapper(activityItems: [shareURL])
                        }
                    } else {
                        if !viewModel.selectedPoemIDs.isEmpty {
                            Button {
                                viewModel.saveSelectedPoems()
                            } label: {
                                Text("Save Selected")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            Button {
                                showingPartialShareSheet.toggle()
                            } label: {
                                Text("Share Selected")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: $showingPartialShareSheet) {
                                let selected = viewModel.poems.filter {
                                    viewModel.selectedPoemIDs.contains($0.id)
                                }
                                let shareURL = createTempJSONFile(from: selected,
                                                                  filename: "SelectedPoems.json")
                                ActivityViewControllerWrapper(activityItems: [shareURL])
                            }
                        }
                    }
                }  // HStack
                .padding(.horizontal)
                .padding(.vertical, 6)
            } // VStack
//            .sheet(item: $poemToEdit) { poem in
//                EditPoemSheet(poem: poem) { oldPoem, newTitle, newBody in
//                    viewModel.edit(oldPoem, newTitle: newTitle, newBody: newBody)
//                }
//            }
            .navigationBarTitle("Poems", displayMode: .inline)
            .navigationBarItems(
                trailing: HStack(spacing: 16) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            )
        } // NavigationView
        // End of NavigationView

        // 1) The sheet for “Add Poem”
        .sheet(isPresented: $showAddSheet) {
            AddPoemSheet(
                onAddFromClipboard: {
                    let success = viewModel.addPoemFromClipboard()
                    if !success {
                        showNoClipboardAlert = true
                    }
                },
                onCreateManually: {
                    // If you do something here, or possibly call 'onRequestManualCreation'
                },
                onCancel: {
                    showAddSheet = false
                },
                onRequestManualCreation: {
                    showAddSheet = false
                    // Then present an empty poem
                    let newID = viewModel.generateNewID()
                    let blankPoem = Poem(
                        id: newID,
                        adaptor: "",
                        outer_idx: 0,
                        inner_idx: 0,
                        image: "",
                        response: "",
                        accepted: false,
                        deleted: false,
                        edited: false
                    )
                    poemToEdit = blankPoem // triggers the edit sheet
                }
            )
        }
        .alert("No valid text in clipboard", isPresented: $showNoClipboardAlert) {
            Button("OK", role: .cancel) {}
        }
        // 2) The sheet for editing/creating poem
        .sheet(item: $poemToEdit) { poem in
            EditPoemSheet(poem: poem) { oldPoem, newTitle, newBody in
                // If user saved, we add or update
                if let idx = viewModel.poems.firstIndex(where: { $0.id == oldPoem.id }) {
                    // existing poem => update
                    viewModel.edit(oldPoem, newTitle: newTitle, newBody: newBody)
                } else {
                    // brand-new poem => append
                    let newPoem = Poem(
                        id: oldPoem.id,
                        adaptor: "",
                        outer_idx: 0,
                        inner_idx: 0,
                        image: newTitle,
                        response: newBody,
                        accepted: false,
                        deleted: false,
                        edited: false
                    )
                    viewModel.poems.append(newPoem)
                }
            }
        }
    }
    
    
    private func evaluateAllDisplayed() {
        // The poems currently in the list, i.e. `displayedPoems`
        // which is typically `viewModel.filteredPoems`
        let poemsToEvaluate = viewModel.filteredPoems
        // Trigger the ViewModel to do it in chunks
        viewModel.evaluateAllInChunks(poems: poemsToEvaluate)
        // viewModel.evaluateAll(poems: poemsToEvaluate)
    }


    // Single poem share
    private func shareSinglePoem(_ poem: Poem) {
        let single = [poem]
        let shareURL = createTempJSONFile(from: single, filename: "SinglePoem.json")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    private func createTempJSONFile(from poems: [Poem], filename: String) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(poems)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error writing temp JSON file: \(error)")
        }
        return fileURL
    }
}

