import SwiftUI

/// Lets the user choose which languages appear on the keyboard (up to a maximum), in which
/// order. Persists to the shared App Group so the keyboard picks the change up on next appear.
struct LanguageSelectionView: View {
    @State private var selectedIDs: [String] = AppGroupStorage.shared.selectedLanguageIDs

    private let maxCount = Configuration.maxKeyboardLanguages

    private var selected: [TargetLanguage] { selectedIDs.compactMap(TargetLanguage.byID) }
    private var available: [TargetLanguage] {
        TargetLanguage.catalog.filter { !selectedIDs.contains($0.id) }
    }
    private var isFull: Bool { selectedIDs.count >= maxCount }

    var body: some View {
        List {
            Section {
                ForEach(selected) { row($0) }
                    .onDelete(perform: remove)
                    .onMove(perform: move)
                    .listRowBackground(KGColor.surface)
            } header: {
                Text("On the keyboard, \(selectedIDs.count)/\(maxCount)").kgEyebrow()
            } footer: {
                Text("Swipe to remove; tap Edit to reorder. They appear left-to-right on the keyboard. At least one is required.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink3)
            }

            Section {
                if isFull {
                    Text("Remove one to add another (max \(maxCount)).")
                        .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                        .listRowBackground(KGColor.surface)
                }
                ForEach(available) { language in
                    Button { add(language) } label: {
                        HStack {
                            row(language)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(isFull ? KGColor.ink3 : KGColor.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFull)
                    .listRowBackground(KGColor.surface)
                }
            } header: {
                Text("Add a language").kgEyebrow()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(KGColor.canvas)
        .navigationTitle("Keyboard Languages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onChange(of: selectedIDs) { _, ids in
            AppGroupStorage.shared.selectedLanguageIDs = ids
        }
    }

    private func row(_ language: TargetLanguage) -> some View {
        HStack(spacing: 12) {
            Text(language.flag).font(.title2)
            Text(language.name).font(KGFont.row).foregroundStyle(KGColor.ink)
        }
    }

    private func remove(at offsets: IndexSet) {
        guard selectedIDs.count > offsets.count else { return } // keep at least one
        selectedIDs.remove(atOffsets: offsets)
    }

    private func move(from source: IndexSet, to destination: Int) {
        selectedIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func add(_ language: TargetLanguage) {
        guard !isFull, !selectedIDs.contains(language.id) else { return }
        selectedIDs.append(language.id)
    }
}

#Preview {
    NavigationStack { LanguageSelectionView() }
}
