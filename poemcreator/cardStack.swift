// CardStackView.swift
import SwiftUI

struct CardStackView: View {
    @ObservedObject var viewModel: PoemViewModel
    @State private var cardDeck: [Poem] = []
    @State private var poemToEdit: Poem? = nil

    var body: some View {
        ZStack {
            if cardDeck.isEmpty {
                Text("No more poems in this filter!")
                    .foregroundColor(.secondary)
                    .font(.headline)
            } else {
                ForEach(cardDeck, id: \.id) { poem in
                    PoemCardView(
                        poem: poem,
                        onAccept: { p in
                            viewModel.accept(p)
                            removeFromDeck(p)
                        },
                        onDelete: { p in
                            viewModel.delete(p)
                            removeFromDeck(p)
                        },
                        onEdit: { p in
                            poemToEdit = p
                        }
                    )
                    .zIndex(Double(deckIndex(of: poem)))
                }
            }
        }
        .sheet(item: $poemToEdit) { poem in
            EditPoemSheet(poem: poem) { oldPoem, newTitle, newBody in
                viewModel.edit(oldPoem, newTitle: newTitle, newBody: newBody)
            }
        }
        .onAppear {
            refreshDeck()
        }
//        // The critical piece: whenever filteredPoems changes, update cardDeck
        .onChange(of: viewModel.filteredPoems) { _ in
            refreshDeck()
        }
    }


    private func refreshDeck() {
        // Always exclude accepted/deleted
        cardDeck = viewModel.poems
            .filter { !$0.accepted && !$0.deleted }
            .sorted { $0.id < $1.id }
    }


    private func removeFromDeck(_ poem: Poem) {
        if let idx = cardDeck.firstIndex(where: { $0.id == poem.id }) {
            cardDeck.remove(at: idx)
        }
    }

    private func deckIndex(of poem: Poem) -> Int {
        cardDeck.firstIndex(where: { $0.id == poem.id }) ?? 0
    }
}

