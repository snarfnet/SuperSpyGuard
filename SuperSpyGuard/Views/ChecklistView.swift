import SwiftUI

struct ChecklistView: View {
    @State private var items: [ChecklistItem] = Self.defaultItems()
    @State private var newItemText = ""
    @State private var showAddField = false

    var checkedCount: Int { items.filter(\.isChecked).count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Progress header
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
                            items.remove(atOffsets: indices); saveItems()
                        }

                        if showAddField {
                            HStack {
                                TextField("チェック項目を入力", text: $newItemText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Button("追加") {
                                    let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        items.append(ChecklistItem(label: trimmed, isCustom: true))
                                        saveItems()
                                    }
                                    newItemText = ""
                                    showAddField = false
                                }
                                .font(AppTheme.labelFont)
                                .foregroundStyle(AppTheme.neonGreen)
                            }
                            .listRowBackground(AppTheme.surfaceHigh)
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
                    Button { showAddField.toggle() } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(AppTheme.neonGreen)
                    }
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
            "額縁・絵画・鏡の裏",
            "植木鉢・観葉植物",
            "テレビ・モニター周辺",
            "本棚・棚の隙間",
            "ソファ・クッションの下",
            "カーテンレール上部",
            "Wi-Fiルーター周辺",
            "充電器・USBアダプター",
            "ティッシュボックス周辺",
        ].map { ChecklistItem(label: $0) }
    }
}
