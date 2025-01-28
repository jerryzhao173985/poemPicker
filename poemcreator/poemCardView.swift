// PoemCardView.swift
import SwiftUI

enum SwipeAction {
    case none, accept, delete
}

struct PoemCardView: View {
    let poem: Poem
    let onAccept: (Poem) -> Void
    let onDelete: (Poem) -> Void
    let onEdit: (Poem) -> Void

    @State private var offset: CGSize = .zero
    @State private var swipeAction: SwipeAction = .none

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(radius: 6)

            VStack(spacing: 12) {
                Text(poem.image)
                    .font(.title2).bold()
                    .padding(.top, 16)

                Text(poem.response)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)

                Spacer()

                HStack(spacing: 24) {
                    Button("Delete") { handleDelete() }
                        .foregroundColor(.red)
                    Button("Edit") { onEdit(poem) }
                        .foregroundColor(.blue)
                    Button("Accept") { handleAccept() }
                        .foregroundColor(.green)
                }
                .padding(.bottom, 16)
            }

            // Overlays
            overlayLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                    if offset.width > 50 {
                        swipeAction = .accept
                    } else if offset.width < -50 {
                        swipeAction = .delete
                    } else {
                        swipeAction = .none
                    }
                }
                .onEnded { gesture in
                    if offset.width > 100 {
                        handleAccept()
                    } else if offset.width < -100 {
                        handleDelete()
                    } else {
                        withAnimation { offset = .zero; swipeAction = .none }
                    }
                }
        )
        .animation(.spring(), value: offset)
    }

    @ViewBuilder
    private var overlayLabel: some View {
        if swipeAction == .accept {
            topCornerLabel("ACCEPT", color: .green)
        } else if swipeAction == .delete {
            topCornerLabel("DELETE", color: .red)
        }
    }

    private func topCornerLabel(_ text: String, color: Color) -> some View {
        VStack {
            Text(text)
                .font(.headline).bold()
                .foregroundColor(.white)
                .padding()
                .background(color.opacity(0.8))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: text == "ACCEPT" ? .leading : .trailing)
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }

    private func handleAccept() {
        withAnimation {
            offset = CGSize(width: 1000, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onAccept(poem)
        }
    }

    private func handleDelete() {
        withAnimation {
            offset = CGSize(width: -1000, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete(poem)
        }
    }
}

