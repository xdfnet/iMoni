//
//  ServiceManager.swift
//  Moni
//
//  Created by Moni Team
//  Copyright © 2025 Moni App. All rights reserved.
//
//  服务配置管理
//
//  功能说明：
//  - ServiceManager 负责管理内置的 AI 服务端点配置
//  - 支持按类别分组，便于菜单分类显示
//  - 使用 SharedTypes.swift 中定义的 AppConstants 和 ServiceEndpoint
//  - 支持端点验证和配置重载
//
import Foundation

// MARK: - 服务类别
enum ServiceCategory: String, CaseIterable {
    case aiServices = "AI Services"
    case ideServices = "IDE Services"  // 新增IDE Services分类
    case development = "Development"
    case network = "Network"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 带类别的服务端点
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
        // AI 服务
        let aiServices = [
            ServiceEndpoint(name: "Claude", host: "api.anthropic.com", port: 443),
            ServiceEndpoint(name: "Gemini", host: "generativelanguage.googleapis.com", port: 443),
            ServiceEndpoint(name: "OpenAI", host: "api.openai.com", port: 443),
            ServiceEndpoint(name: "DeepSeek", host: "api.deepseek.com", port: 443),
            ServiceEndpoint(name: "GLM", host: "open.bigmodel.cn", port: 443),
            ServiceEndpoint(name: "Qwen", host: "dashscope.aliyuncs.com", port: 443),
            ServiceEndpoint(name: "Kimi", host: "api.moonshot.cn", port: 443),
        ]

        // IDE Services
        let ideServices = [
            ServiceEndpoint(name: "Cursor", host: "api.cursor.sh", port: 443),
            ServiceEndpoint(name: "Visual Studio Code", host: "marketplace.visualstudio.com", port: 443),
            ServiceEndpoint(name: "Windsurf", host: "api.windsurf.sh", port: 443),
        ]

        // Development — Homebrew 与 NPM 相关
        let developmentServices = [
            ServiceEndpoint(name: "Homebrew", host: "formulae.brew.sh", port: 443),
            ServiceEndpoint(name: "NPM", host: "registry.npmjs.org", port: 443),
            ServiceEndpoint(name: "PyPI", host: "pypi.org", port: 443),
            ServiceEndpoint(name: "Maven", host: "repo1.maven.org", port: 443),
        ]
        
        // Network / Container 服务
        let networkServices = [
            ServiceEndpoint(name: "Docker Hub", host: "registry-1.docker.io", port: 443),
        ]

        // 构建分类结构
        categorizedEndpoints = [
            CategorizedServiceEndpoint(category: .aiServices, endpoints: aiServices),
            CategorizedServiceEndpoint(category: .ideServices, endpoints: ideServices),
            CategorizedServiceEndpoint(category: .development, endpoints: developmentServices),
            CategorizedServiceEndpoint(category: .network, endpoints: networkServices)
        ]
        
        // 扁平列表
        allEndpoints = aiServices + ideServices + developmentServices + networkServices
    }
    
    // MARK: - 分类访问方法
    func getEndpoints(for category: ServiceCategory) -> [ServiceEndpoint] {
        return categorizedEndpoints.first { $0.category == category }?.endpoints ?? []
    }
    
    var categories: [ServiceCategory] {
        return ServiceCategory.allCases
    }
    
    // MARK: - 向后兼容
    var endpoints: [ServiceEndpoint] {
        return allEndpoints
    }
    

}
