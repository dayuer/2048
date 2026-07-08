import Foundation
import Testing
@testable import Game2048

@Suite struct GameRegistryTests {
    @Test func registryNotEmpty() {
        #expect(!GameRegistry.all.isEmpty)
    }

    @Test func idsAreUnique() {
        let ids = GameRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func pluginsHaveAgentPresentation() {
        for plugin in GameRegistry.all {
            #expect(!plugin.tagline.isEmpty)
            #expect(!plugin.tags.isEmpty)
        }
    }

    @Test func has2048Plugin() {
        let plugin = GameRegistry.all.first { $0.id == "game2048" }
        #expect(plugin != nil)
        #expect(plugin?.supportsVersus == true)
    }
}
