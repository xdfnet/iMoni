# iMoni Makefile
# 版本号 VERSION 文件为唯一来源，构建时注入 pbxproj。

.PHONY: help debug install release push package bump-patch bump-minor bump-major clean

# =============================================================================
# 项目配置
# =============================================================================

PROJECT_NAME = iMoni
SCHEME_NAME = iMoni
XCODEPROJ = $(PROJECT_NAME).xcodeproj
BUILD_DIR = build
INSTALL_DIR = /Applications
PACKAGE_DIR = build/packages

# 颜色
R = \033[0;31m
G = \033[0;32m
Y = \033[0;33m
B = \033[0;34m
C = \033[0;36m
N = \033[0m

# =============================================================================
# 默认目标
# =============================================================================

.DEFAULT_GOAL := help

help:
	@echo "$(C)iMoni 构建系统$(N)"
	@echo "$(C)=================$(N)\n"
	@echo "$(G)构建:$(N)"
	@echo "  $(Y)make debug$(N)          - Debug 构建并启动"
	@echo "  $(Y)make release$(N)         - Release 构建 + 安装到 /Applications"
	@echo "  $(Y)make install$(N)         - 安装已构建的 Release 到 /Applications（自动构建）"
	@echo "  $(Y)make package$(N)         - 打包已安装的版本为 zip"
	@echo ""
	@echo "$(G)版本管理:$(N)"
	@echo "  $(Y)make bump-patch$(N)      - 递增修订号 (1.3.2 → 1.3.3)"
	@echo "  $(Y)make bump-minor$(N)      - 递增次版本 (1.3.2 → 1.4.0)"
	@echo "  $(Y)make bump-major$(N)      - 递增主版本 (1.3.2 → 2.0.0)"
	@echo "  $(Y)echo $(shell cat VERSION)$(N)           - 当前版本"
	@echo ""
	@echo "$(G)发布:$(N)"
	@echo "  $(Y)make push MSG=\"msg\"$(N)    - release + package + 提交 + 推送 + GitHub Release"
	@echo "  $(Y)make push MSG=\"msg\" V=1.5.0$(N)  - 指定版本发布"
	@echo ""
	@echo "$(G)工具:$(N)"
	@echo "  $(Y)make clean$(N)          - 清理构建文件\n"

# =============================================================================
# 辅助函数
# =============================================================================

# 当前版本（执行时从 VERSION 文件读）
version = $(shell cat VERSION)
# 构建号（时间戳）
build_number = $(shell date +%Y%m%d%H%M%S)

# =============================================================================
# 构建
# =============================================================================

debug:
	@echo "$(B)Debug 构建...$(N)"
	@pkill -f "$(PROJECT_NAME)" 2>/dev/null || true
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*
	@xcodebuild \
		-project $(XCODEPROJ) \
		-scheme $(SCHEME_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		MARKETING_VERSION=$(version) \
		CURRENT_PROJECT_VERSION=$(build_number) \
		build
	@APP=$$(find $(BUILD_DIR) -name "$(PROJECT_NAME).app" -type d | head -1); \
	if [ -n "$$APP" ]; then open "$$APP"; echo "$(G)已启动$(N)"; \
	else echo "$(R)找不到 App$(N)"; exit 1; fi

release:
	@echo "$(B)Release 构建...$(N)"
	@$(MAKE) build-release
	@$(MAKE) install
	@echo "$(APP_PATH)" > /dev/null

build-release:
	@echo "$(B)Release 构建...$(N)"
	@pkill -f "$(PROJECT_NAME)" 2>/dev/null || true
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*
	@xcodebuild \
		-project $(XCODEPROJ) \
		-scheme $(SCHEME_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		MARKETING_VERSION=$(version) \
		CURRENT_PROJECT_VERSION=$(build_number) \
		build

install:
	@echo "$(B)安装到 /Applications...$(N)"
	@pkill -f "$(PROJECT_NAME)" 2>/dev/null || true
	$(MAKE) build-release
	@rm -rf "$(INSTALL_DIR)/$(PROJECT_NAME).app" 2>/dev/null || true
	@APP=$$(find $(BUILD_DIR) -name "$(PROJECT_NAME).app" -type d | head -1); \
	if [ -n "$$APP" ]; then \
		cp -R "$$APP" $(INSTALL_DIR)/; \
		echo "$(G)已安装: $(INSTALL_DIR)/$(PROJECT_NAME).app$(N)"; \
	else echo "$(R)构建失败$(N)"; exit 1; fi

package:
	@echo "$(B)打包 zip...$(N)"
	@mkdir -p "$(PACKAGE_DIR)"
	@V=$$(cat VERSION); \
	B=$$(plutil -extract CFBundleVersion raw "/Applications/$(PROJECT_NAME).app/Contents/Info.plist" 2>/dev/null || echo "0"); \
	ZIP="$(PACKAGE_DIR)/$(PROJECT_NAME)-$$V-$$B.zip"; \
	rm -f "$$ZIP"; \
	ditto -c -k --keepParent "/Applications/$(PROJECT_NAME).app" "$$ZIP"; \
	echo "$(G)已创建: $$ZIP$(N)"

# =============================================================================
# 版本号管理
# =============================================================================

# bump-xxx: 读取 VERSION → 递增指定位 → 写回 VERSION
# 不提交不构建，只管改版本号。

define bump_version
	@V=$$(cat VERSION); \
	MAJ=$$(echo $$V | cut -d. -f1); \
	MIN=$$(echo $$V | cut -d. -f2); \
	PAT=$$(echo $$V | cut -d. -f3); \
	case "$(1)" in \
		major) MAJ=$$((MAJ + 1)); MIN=0; PAT=0 ;; \
		minor) MIN=$$((MIN + 1)); PAT=0 ;; \
		patch) PAT=$$((PAT + 1)) ;; \
	esac; \
	NEW="$$MAJ.$$MIN.$$PAT"; \
	echo "$$NEW" > VERSION; \
	echo "$(C)$$V $(N)→$(C) $$NEW$(N)"
endef

bump-patch:
	$(call bump_version,patch)

bump-minor:
	$(call bump_version,minor)

bump-major:
	$(call bump_version,major)

# =============================================================================
# 发布流程
# =============================================================================

push:
	@MSG="$(MSG)"; \
	if [ -z "$$MSG" ]; then \
		echo "$(R)错误: 请提供 MSG=\"提交信息\"$(N)"; exit 1; \
	fi; \
	V="$(V)"; \
	if [ -n "$$V" ]; then \
		echo "$$V" > VERSION; \
		echo "$(Y)版本覆盖 → $$V$(N)"; \
	fi; \
	V=$$(cat VERSION)
	@echo "$(B)发布 v$$(cat VERSION)$(N)"
	@$(MAKE) release
	@$(MAKE) package
	@V=$$(cat VERSION); \
	ZIP=$$(find $(PACKAGE_DIR) -name "$(PROJECT_NAME)-$$V-*.zip" -type f | head -1); \
	git add .; \
	git commit -m "$$MSG"; \
	echo "$(G)已提交: $$MSG$(N)"; \
	git push; \
	echo "$(G)已推送$(N)"; \
	gh release create "v$$V" --title "iMoni v$$V" --notes "$$MSG"; \
	if [ -n "$$ZIP" ]; then gh release upload "v$$V" "$$ZIP"; fi; \
	echo "$(G)Release: https://github.com/xdfnet/iMoni/releases/tag/v$$V$(N)"

# =============================================================================
# 清理
# =============================================================================

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT_NAME)-*
	@echo "$(G)清理完成$(N)"
