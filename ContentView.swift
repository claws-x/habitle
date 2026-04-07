import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var habits: [Habit]
    @State private var selectedHabitID: Habit.ID?
    @State private var draft = HabitDraft.empty
    @State private var showingEditor = false

    init() {
        _habits = State(initialValue: HabitStore.load())
    }

    private var completedTodayCount: Int {
        habits.filter { $0.isCompleted(on: .now) }.count
    }

    private var strongestStreak: Int {
        habits.map { $0.currentStreak() }.max() ?? 0
    }

    private var completionRateText: String {
        guard !habits.isEmpty else {
            return "0%"
        }

        let rate = Double(completedTodayCount) / Double(habits.count)
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressHeroCard(
                        habitCount: habits.count,
                        completedTodayCount: completedTodayCount,
                        strongestStreak: strongestStreak,
                        completionRateText: completionRateText
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if habits.isEmpty {
                    Section("Why this app exists") {
                        EmptyStateCard {
                            showingEditor = true
                        }
                    }
                } else {
                    Section("Today") {
                        ForEach(habits) { habit in
                            HabitRow(
                                habit: habit,
                                onToggle: { toggleCompletion(for: habit.id) },
                                onEdit: { startEditing(habit) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    deleteHabit(id: habit.id)
                                }

                                Button("Edit") {
                                    startEditing(habit)
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteHabits)
                    }

                    Section("Positioning") {
                        ValuePropositionCard()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("HabitLite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startCreatingHabit()
                    } label: {
                        Label("Add Habit", systemImage: "plus")
                    }
                    .accessibilityHint("Create a new habit to track")
                }
            }
            .sheet(isPresented: $showingEditor) {
                HabitEditorView(
                    title: selectedHabitID == nil ? "New Habit" : "Edit Habit",
                    draft: $draft,
                    onCancel: resetEditor,
                    onSave: saveHabit
                )
            }
            .onChange(of: habits) { newValue in
                HabitStore.save(newValue)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    HabitStore.save(habits)
                }
            }
        }
    }

    private func startCreatingHabit() {
        selectedHabitID = nil
        draft = .empty
        showingEditor = true
    }

    private func startEditing(_ habit: Habit) {
        selectedHabitID = habit.id
        draft = HabitDraft(habit: habit)
        showingEditor = true
    }

    private func saveHabit() {
        let habit = draft.makeHabit(id: selectedHabitID)

        if let selectedHabitID,
           let index = habits.firstIndex(where: { $0.id == selectedHabitID }) {
            habits[index].name = habit.name
            habits[index].detail = habit.detail
            habits[index].symbol = habit.symbol
            habits[index].accentName = habit.accentName
        } else {
            habits.append(habit)
        }

        habits.sort { $0.createdAt < $1.createdAt }
        resetEditor()
    }

    private func resetEditor() {
        showingEditor = false
        selectedHabitID = nil
        draft = .empty
    }

    private func toggleCompletion(for id: Habit.ID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else {
            return
        }

        habits[index].toggleCompletion(on: .now)
    }

    private func deleteHabit(id: Habit.ID) {
        habits.removeAll { $0.id == id }
    }

    private func deleteHabits(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
    }
}

private struct ProgressHeroCard: View {
    let habitCount: Int
    let completedTodayCount: Int
    let strongestStreak: Int
    let completionRateText: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.17, blue: 0.28),
                            Color(red: 0.20, green: 0.41, blue: 0.52),
                            Color(red: 0.88, green: 0.56, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 18) {
                Text("A one-screen habit tracker for people who dislike managing habit apps.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    StatChip(title: "Today", value: "\(completedTodayCount)/\(habitCount)", systemImage: "checkmark.circle.fill")
                    StatChip(title: "Active streak", value: "\(strongestStreak)d", systemImage: "flame.fill")
                    StatChip(title: "Done", value: completionRateText, systemImage: "chart.bar.fill")
                }
            }
            .padding(24)
        }
        .frame(minHeight: 200)
        .padding(.horizontal, 20)
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EmptyStateCard: View {
    let createAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Track only the habits you actually care about.")
                .font(.headline)

            Text("HabitLite keeps the loop intentionally small: create a habit, mark today done, and keep the streak alive. No sign-in, no ads, no subscription prompts.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ValueBullet(systemImage: "checkmark.circle.fill", text: "One tap to mark today complete")
                ValueBullet(systemImage: "lock.shield.fill", text: "All data stays on this device")
                ValueBullet(systemImage: "rectangle.stack.fill.badge.plus", text: "New habits can include a short reason so the list stays intentional")
            }

            Button("Create your first habit", action: createAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}

private struct ValueBullet: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: habit.isCompleted(on: .now) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(habit.isCompleted(on: .now) ? habit.accent.color : .secondary)
                    .frame(width: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(habit.isCompleted(on: .now) ? "Mark incomplete" : "Mark complete")

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(habit.accent.color.opacity(0.14))

                Image(systemName: habit.symbol)
                    .font(.headline)
                    .foregroundStyle(habit.accent.color)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)

                Text(habit.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Label("\(habit.currentStreak())d", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("Best \(habit.bestStreak())d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .padding(.vertical, 4)
    }
}

private struct ValuePropositionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HabitLite is strongest when it stays small.")
                .font(.headline)

            Text("This app is positioned as a paid, privacy-first tracker for a short list of meaningful habits. It avoids ads, account setup, and overstimulation so the product has a clearer pay-once story than a generic checklist clone.")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct HabitEditorView: View {
    let title: String
    @Binding var draft: HabitDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $draft.name)
                    TextField("Why this matters", text: $draft.detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Symbol") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                        ForEach(HabitDraft.symbolChoices, id: \.self) { symbol in
                            SymbolChoiceCell(
                                symbol: symbol,
                                isSelected: draft.symbol == symbol,
                                color: HabitAccent(name: draft.accentName).color
                            ) {
                                draft.symbol = symbol
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Accent") {
                    HStack(spacing: 12) {
                        ForEach(HabitAccent.Name.allCases) { accentName in
                            AccentChoiceDot(
                                accent: HabitAccent(name: accentName),
                                isSelected: draft.accentName == accentName
                            ) {
                                draft.accentName = accentName
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(!draft.isValid)
                }
            }
        }
    }
}

private struct SymbolChoiceCell: View {
    let symbol: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AccentChoiceDot: View {
    let accent: HabitAccent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(accent.color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .padding(4)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? accent.color : Color.clear, lineWidth: 3)
                )
                .shadow(color: accent.color.opacity(0.22), radius: 6, y: 2)
                .accessibilityLabel(accent.title)
        }
        .buttonStyle(.plain)
    }
}

private struct HabitDraft {
    var name: String
    var detail: String
    var symbol: String
    var accentName: HabitAccent.Name

    static let symbolChoices = [
        "sun.max.fill",
        "figure.walk",
        "drop.fill",
        "book.fill",
        "moon.zzz.fill",
        "brain.head.profile",
        "leaf.fill",
        "heart.fill"
    ]

    static let empty = HabitDraft(
        name: "",
        detail: "",
        symbol: "sun.max.fill",
        accentName: .ocean
    )

    init(name: String, detail: String, symbol: String, accentName: HabitAccent.Name) {
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.accentName = accentName
    }

    init(habit: Habit) {
        self.name = habit.name
        self.detail = habit.detail
        self.symbol = habit.symbol
        self.accentName = habit.accentName
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeHabit(id: Habit.ID?) -> Habit {
        Habit(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol,
            accentName: accentName
        )
    }
}

#Preview {
    ContentView()
}

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var detail: String
    var symbol: String
    var accentName: HabitAccent.Name
    var createdAt: Date
    var completedDayKeys: [String]

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        symbol: String,
        accentName: HabitAccent.Name,
        createdAt: Date = .now,
        completedDayKeys: [String] = []
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.accentName = accentName
        self.createdAt = createdAt
        self.completedDayKeys = completedDayKeys
    }

    var accent: HabitAccent {
        HabitAccent(name: accentName)
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDayKeys.contains(Self.dayKey(for: date, calendar: calendar))
    }

    mutating func toggleCompletion(on date: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(for: date, calendar: calendar)

        if completedDayKeys.contains(key) {
            completedDayKeys.removeAll { $0 == key }
        } else {
            completedDayKeys.append(key)
            completedDayKeys.sort()
        }
    }

    func currentStreak(referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let keys = Set(completedDayKeys)
        let todayKey = Self.dayKey(for: referenceDate, calendar: calendar)

        if !keys.contains(todayKey),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           !keys.contains(Self.dayKey(for: yesterday, calendar: calendar)) {
            return 0
        }

        var streak = 0
        var cursor = referenceDate

        if !keys.contains(todayKey),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) {
            cursor = yesterday
        }

        while keys.contains(Self.dayKey(for: cursor, calendar: calendar)) {
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }

            cursor = previousDay
        }

        return streak
    }

    func bestStreak(calendar: Calendar = .current) -> Int {
        let sortedDates = completedDayKeys.compactMap { key in
            Self.date(from: key, calendar: calendar)
        }.sorted()

        guard let firstDate = sortedDates.first else {
            return 0
        }

        var best = 1
        var running = 1
        var previous = firstDate

        for date in sortedDates.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: date).day ?? 0

            if gap == 1 {
                running += 1
                best = max(best, running)
            } else if gap > 1 {
                running = 1
            }

            previous = date
        }

        return best
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(from dayKey: String, calendar: Calendar = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}

struct HabitAccent: Identifiable, Hashable {
    enum Name: String, Codable, CaseIterable, Identifiable {
        case sunrise
        case ocean
        case meadow
        case berry
        case ember

        var id: String { rawValue }
    }

    let name: Name

    var id: String { name.rawValue }

    var title: String {
        switch name {
        case .sunrise:
            return "Sunrise"
        case .ocean:
            return "Ocean"
        case .meadow:
            return "Meadow"
        case .berry:
            return "Berry"
        case .ember:
            return "Ember"
        }
    }

    var color: Color {
        switch name {
        case .sunrise:
            return Color(red: 0.95, green: 0.56, blue: 0.26)
        case .ocean:
            return Color(red: 0.18, green: 0.50, blue: 0.89)
        case .meadow:
            return Color(red: 0.24, green: 0.63, blue: 0.41)
        case .berry:
            return Color(red: 0.75, green: 0.31, blue: 0.53)
        case .ember:
            return Color(red: 0.84, green: 0.30, blue: 0.24)
        }
    }
}

enum HabitStore {
    private static let fileName = "habits.json"

    static func load() -> [Habit] {
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url),
              let habits = try? JSONDecoder().decode([Habit].self, from: data) else {
            return []
        }

        return habits.sorted { $0.createdAt < $1.createdAt }
    }

    static func save(_ habits: [Habit]) {
        guard let url = storageURL() else {
            return
        }

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(habits)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save habits: \(error.localizedDescription)")
        }
    }

    private static func storageURL() -> URL? {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return appSupport?
            .appendingPathComponent("HabitLite", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
