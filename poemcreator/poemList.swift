// PoemListView.swift
import SwiftUI

struct PoemListView: View {
    @ObservedObject var viewModel: PoemViewModel

    // For editing
    @State private var poemToEdit: Poem? = nil

    // For sharing
    @State private var showingShareSheet = false
    @State private var showingPartialShareSheet = false

    var body: some View {
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
                        }
                    )
                    .contextMenu {
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
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .sheet(item: $poemToEdit) { poem in
            EditPoemSheet(poem: poem) { oldPoem, newTitle, newBody in
                viewModel.edit(oldPoem, newTitle: newTitle, newBody: newBody)
            }
        }
    }
    
    private func evaluateAllDisplayed() {
        // The poems currently in the list, i.e. `displayedPoems`
        // which is typically `viewModel.filteredPoems`
        let poemsToEvaluate = viewModel.filteredPoems
        viewModel.evaluateAll(poems: poemsToEvaluate)
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

