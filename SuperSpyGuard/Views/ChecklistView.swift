import SwiftUI

struct ChecklistView: View {
    @State private var items: [ChecklistItem] = Self.defaultItems()
    @State private var newItemText = ""
    @State private var showAddSheet = false

    private var checkedCount: Int { items.filter(\.isChecked).count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressHeader

                    List {
                        ForEach($items) { $item in
                            HStack(spacing: 12) {
                                Button {
                                    item.isChecked.toggle()
                                    saveItems()
                                } label: {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(item.isChecked ? AppTheme.neonGreen : AppTheme.textSecondary)
                                }
                                .buttonStyle(.plain)

                                Text(item.label)
                                    .font(.system(size: 14))
                                    .foregroundStyle(item.isChecked ? AppTheme.textSecondary : AppTheme.textPrimary)
                                    .strikethrough(item.isChecked, color: AppTheme.textSecondary)
                            }
                            .listRowBackground(AppTheme.surface)
                            .listRowSeparatorTint(AppTheme.neonGreen.opacity(0.15))
                        }
                        .onDelete { indices in
                            items.remove(atOffsets: indices)
                            saveItems()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("部屋チェック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.neonGreen)
                    }
                    .accessibilityLabel("チェック項目を追加")
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") {
                        for i in items.indices { items[i].isChecked = false }
                        saveItems()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear { loadItems() }
        .sheet(isPresented: $showAddSheet) {
            AddChecklistItemSheet(
                newItemText: $newItemText,
                onCancel: {
                    newItemText = ""
                    showAddSheet = false
                },
                onAdd: addCustomItem
            )
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(checkedCount) / \(items.count) チェック完了")
                    .font(AppTheme.labelFont)
                    .foregroundStyle(AppTheme.neonGreen)
                Spacer()
                if checkedCount == items.count {
                    Label("完了！", systemImage: "checkmark.seal.fill")
                        .font(AppTheme.labelFont)
                        .foregroundStyle(AppTheme.gold)
                }
            }

            ProgressView(value: Double(checkedCount), total: Double(max(items.count, 1)))
                .tint(AppTheme.neonGreen)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
    }

    private func addCustomItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items.append(ChecklistItem(label: trimmed, isCustom: true))
        saveItems()
        newItemText = ""
        showAddSheet = false
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "ssg_checklist")
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: "ssg_checklist"),
              let saved = try? JSONDecoder().decode([ChecklistItem].self, from: data) else { return }
        items = saved
    }

    static func defaultItems() -> [ChecklistItem] {
        [
            "コンセント・電源タップ",
            "時計（壁掛け・置き時計）",
            "煙感知器・火災報知器",
            "エアコン・換気口",
            "照明器具・ダウンライト",
            "額縁・絵画・壁の装飾",
            "鏡・観葉植物",
            "テレビ・モニター周辺",
            "本棚・棚の隙間",
            "ソファ・クッションの裏",
            "カーテンレール上部",
            "Wi-Fiルーター周辺",
            "充電器・USBアダプター",
            "ティッシュボックス周辺"
        ].map { ChecklistItem(label: $0) }
    }
}

private struct AddChecklistItemSheet: View {
    @Binding var newItemText: String
    let onCancel: () -> Void
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("チェック項目")
                        .font(AppTheme.labelFont)
                        .foregroundStyle(AppTheme.textSecondary)

                    TextField("例: ベッド下を確認", text: $newItemText)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(14)
                        .background(AppTheme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.done)
                        .onSubmit { onAdd() }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("項目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { onAdd() }
                        .fontWeight(.semibold)
                        .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundStyle(AppTheme.neonGreen)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}
