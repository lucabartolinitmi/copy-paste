import Foundation

class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var selectedIndex: Int = 0
    @Published var searchText: String = ""
    @Published var activeFilter: ClipType = .all
    @Published var isSearchFocused: Bool = false

    private init() {}

    func reset() {
        selectedIndex = 0
        searchText = ""
        activeFilter = .all
        isSearchFocused = false
    }
}
