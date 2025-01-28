import SwiftUI

struct PoemRow: View {
    let poem: Poem

    // For multi-selection
    let multiSelectionMode: Bool
    let isSelected: Bool
    let onToggleSelect: () -> Void

    let onAccept: () -> Void
    let onEditRequest: () -> Void
    let onDelete: () -> Void

    let onEvaluate: () -> Void
    
    var body: some View {
        HStack {
            if multiSelectionMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .padding(.trailing, 6)
                    .onTapGesture {
                        onToggleSelect()
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(poem.image)
                    .font(.headline)

                Text(poem.response)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if poem.accepted && !poem.deleted {
                        Text("Accepted")
                            .font(.caption)
                            .bold()
                            .padding(4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if poem.deleted {
                        Text("Deleted")
                            .font(.caption)
                            .bold()
                            .padding(4)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()

            // If not multi-select, show quick actions
            if !multiSelectionMode {
                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.plain)

                Button {
                    onEditRequest()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                // The new Evaluate button
                Button(action: onEvaluate) {
                    Image(systemName: "brain.head.profile") // or another SF Symbol
                }
                .buttonStyle(.plain)
            }
        }
//        .contentShape(Rectangle())
        .if(multiSelectionMode) { view in
            // Only apply onTapGesture to the entire row if multiSelection is true
            view.onTapGesture {
                onToggleSelect()
            }
        }
        .padding(.vertical, 6)
    }
}


extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                              transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


