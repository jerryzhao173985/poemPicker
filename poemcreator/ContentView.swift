import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel = PoemViewModel()

    // For the onboarding flow
    @State private var step: OnboardingStep = .chooseJSON
    @State private var showFilePicker = false

    // For partial slice
    @State private var startIndexInput = ""
    @State private var endIndexInput = ""

    var body: some View {
        switch step {
        case .chooseJSON:
            ChooseJSONView(
                onChooseDefault: {
                    // 1) Load default
                    viewModel.loadDefaultPoems()
                    // 2) Move to slice step
                    step = .chooseSlice
                },
                onChooseCustom: {
                    // 1) Show doc picker
                    showFilePicker = true
                }
            )
            .sheet(isPresented: $showFilePicker) {
                CustomFileLoader { url in
                    showFilePicker = false
                    guard let fileURL = url else {
                        print("Canceled picking file. Falling back to default.")
                        // fallback
                        viewModel.loadDefaultPoems()
                        step = .chooseSlice
                        return
                    }
                    viewModel.loadCustomJSON(from: fileURL)
                    step = .chooseSlice
                }
            }

        case .chooseSlice:
            ChooseSliceView(
                poemCount: viewModel.poems.count,
                startIndex: $startIndexInput,
                endIndex: $endIndexInput,
                onApplySlice: {
                    let s = Int(startIndexInput) ?? 0
                    let e = Int(endIndexInput) ?? (viewModel.poems.count - 1)
                    viewModel.applySlice(start: s, end: e)
                },
                onContinue: {
                    step = .mainUI
                }
            )

        case .mainUI:
            MainAppTabView(viewModel: viewModel)
        }
    }
}

// MARK: - Step Enum
enum OnboardingStep {
    case chooseJSON
    case chooseSlice
    case mainUI
}

// MARK: - 1) Choose JSON View
struct ChooseJSONView: View {
    let onChooseDefault: () -> Void
    let onChooseCustom: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Load JSON")
                .font(.title)
                .padding(.top, 40)

            Text("Pick a custom JSON file or use the default in the app bundle.")

            Spacer()

            Button("Use Default JSON") {
                onChooseDefault()
            }
            .font(.headline)
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)

            Button("Pick Custom JSON") {
                onChooseCustom()
            }
            .font(.headline)
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }
}

// MARK: - 2) Choose Slice View
struct ChooseSliceView: View {
    let poemCount: Int
    @Binding var startIndex: String
    @Binding var endIndex: String

    let onApplySlice: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Loaded \(poemCount) poems.")
                .font(.title3)
                .padding(.top, 30)

            Text("Optionally choose a slice range, or skip to use all data.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Start Index (0-based)", text: $startIndex)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding(.horizontal)

            TextField("End Index (<= \(poemCount-1))", text: $endIndex)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button("Apply Slice") {
                    onApplySlice()
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)

                Button("Continue") {
                    onApplySlice()
                    onContinue()
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - 3) Main UI TabView
struct MainAppTabView: View {
    @ObservedObject var viewModel: PoemViewModel

    var body: some View {
        TabView {
            // Card stack
            CardStackView(viewModel: viewModel)
                .tabItem {
                    Label("Cards", systemImage: "rectangle.stack.fill")
                }
            // List
            PoemListView(viewModel: viewModel)
                .tabItem {
                    Label("List", systemImage: "list.bullet.rectangle")
                }
        }
    }
}

// MARK: - Custom File Loader
struct CustomFileLoader: UIViewControllerRepresentable {
    let onFilePicked: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: CustomFileLoader
        init(_ parent: CustomFileLoader) {
            self.parent = parent
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onFilePicked(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onFilePicked(nil)
        }
    }
}

