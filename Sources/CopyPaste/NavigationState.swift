import Foundation

class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var selectedIndex: Int = 0
    /// Tracks which item is selected by ID so selection survives pin-reorders
    @Published var selectedID: UUID? = nil
    @Published var searchText: String = ""
    @Published var activeFilter: ClipType = .all
    @Published var isSearchFocused: Bool = false

    private init() {}

    func reset() {
        selectedIndex = 0
        selectedID = nil
        searchText = ""
        activeFilter = .all
        isSearchFocused = false
    }
}
