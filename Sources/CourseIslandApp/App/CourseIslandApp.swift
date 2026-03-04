import SwiftUI

@main
struct CourseIslandApp: App {
    @StateObject private var store: AppStore
    @StateObject private var coordinator: AppCoordinator

    init() {
        let store = AppStore()
        _store = StateObject(wrappedValue: store)
        _coordinator = StateObject(wrappedValue: AppCoordinator(store: store))
    }

    var body: some Scene {
        WindowGroup("课程岛") {
            AppShellView()
                .environmentObject(store)
                .environmentObject(coordinator)
                .task {
                    coordinator.bootstrap()
                }
        }
        .defaultSize(width: 1440, height: 940)

        MenuBarExtra {
            MenuBarQuickView()
                .environmentObject(store)
                .environmentObject(coordinator)
        } label: {
            Label(coordinator.islandSummary, systemImage: "capsule.bottomhalf.filled")
        }
        .menuBarExtraStyle(.window)
    }
}
