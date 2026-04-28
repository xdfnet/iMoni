import Foundation

enum ServiceCategory: String, CaseIterable {
    case aiServices = "AI Services"
    case ideServices = "IDE Services"
    case development = "Development"
    case network = "Network"

    var displayName: String { rawValue }
}

struct CategorizedServiceEndpoint {
    let category: ServiceCategory
    let endpoints: [ServiceEndpoint]
}

class ServiceManager {
    static let shared = ServiceManager()

    private(set) var categorizedEndpoints: [CategorizedServiceEndpoint] = []
    private(set) var allEndpoints: [ServiceEndpoint] = []

    private init() {
        loadEndpoints()
    }

    private func loadEndpoints() {
        let aiServices = [
            ServiceEndpoint(name: "Claude", host: "api.anthropic.com", port: 443),
            ServiceEndpoint(name: "Gemini", host: "generativelanguage.googleapis.com", port: 443),
            ServiceEndpoint(name: "OpenAI", host: "api.openai.com", port: 443),
            ServiceEndpoint(name: "DeepSeek", host: "api.deepseek.com", port: 443),
            ServiceEndpoint(name: "GLM", host: "open.bigmodel.cn", port: 443),
            ServiceEndpoint(name: "Qwen", host: "dashscope.aliyuncs.com", port: 443),
            ServiceEndpoint(name: "Kimi", host: "api.moonshot.cn", port: 443),
        ]

        let ideServices = [
            ServiceEndpoint(name: "Cursor", host: "api.cursor.sh", port: 443),
            ServiceEndpoint(name: "Visual Studio Code", host: "marketplace.visualstudio.com", port: 443),
            ServiceEndpoint(name: "Windsurf", host: "api.windsurf.sh", port: 443),
        ]

        let developmentServices = [
            ServiceEndpoint(name: "Homebrew", host: "formulae.brew.sh", port: 443),
            ServiceEndpoint(name: "NPM", host: "registry.npmjs.org", port: 443),
            ServiceEndpoint(name: "PyPI", host: "pypi.org", port: 443),
            ServiceEndpoint(name: "Maven", host: "repo1.maven.org", port: 443),
        ]

        let networkServices = [
            ServiceEndpoint(name: "Docker Hub", host: "registry-1.docker.io", port: 443),
        ]

        categorizedEndpoints = [
            CategorizedServiceEndpoint(category: .aiServices, endpoints: aiServices),
            CategorizedServiceEndpoint(category: .ideServices, endpoints: ideServices),
            CategorizedServiceEndpoint(category: .development, endpoints: developmentServices),
            CategorizedServiceEndpoint(category: .network, endpoints: networkServices),
        ]
        allEndpoints = aiServices + ideServices + developmentServices + networkServices
    }

    func getEndpoints(for category: ServiceCategory) -> [ServiceEndpoint] {
        categorizedEndpoints.first { $0.category == category }?.endpoints ?? []
    }

    var categories: [ServiceCategory] { ServiceCategory.allCases }
    var endpoints: [ServiceEndpoint] { allEndpoints }
}
