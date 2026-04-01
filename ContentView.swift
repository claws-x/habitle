//
//  ContentView.swift
//  HabitLite
//
//  Created by AI Agent on 2026-03-29.
//

import SwiftUI

struct ContentView: View {
    @State private var habits: [Habit] = [
        Habit(name: "早起", icon: "sunrise.fill", streak: 7, completed: false),
        Habit(name: "运动", icon: "figure.run", streak: 5, completed: true),
        Habit(name: "阅读", icon: "book.fill", streak: 12, completed: false),
        Habit(name: "喝水", icon: "drop.fill", streak: 3, completed: false)
    ]
    @State private var showingAddHabit = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach($habits) { $habit in
                        HabitRow(habit: habit)
                    }
                }
                .listStyle(.plain)
                
                Button(action: { showingAddHabit = true }) {
                    Label("添加习惯", systemImage: "plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("极简习惯")
        }
    }
}

struct Habit: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var streak: Int
    var completed: Bool
}

struct HabitRow: View {
    @State var habit: Habit
    
    var body: some View {
        HStack {
            Image(systemName: habit.icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(.headline)
                Text("连续 \(habit.streak) 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: habit.completed ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundColor(habit.completed ? .green : .gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
