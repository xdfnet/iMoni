#!/bin/bash
#
#  code_quality_check.sh
#  iMoni
#
#  Created by iMoni Team
#  Copyright © 2025 iMoni App. All rights reserved.
#
#  代码质量检查脚本
#
#  功能说明：
#  - 用于检查 Swift 代码的常见问题和改进建议
#  - 自动检查文件命名、类命名、MARK 注释等规范
#  - 集成 SwiftLint 进行更详细的代码检查
#  - 提供代码质量评分和改进建议
#

echo "🔍 开始代码质量检查..."
echo "=================================="

# 检查目录
PROJECT_DIR="iMoni"
SWIFT_FILES=$(find "$PROJECT_DIR" -name "*.swift" -type f)

# 计数器
TOTAL_ISSUES=0
WARNING_COUNT=0
ERROR_COUNT=0

echo "📁 扫描目录: $PROJECT_DIR"
echo "📄 找到 Swift 文件: $(echo "$SWIFT_FILES" | wc -l)"
echo ""

# 1. 检查文件命名规范
echo "📋 检查文件命名规范..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if [[ ! "$filename" =~ ^[A-Z][a-zA-Z0-9]*\.swift$ ]]; then
        echo "  ⚠️  文件命名不规范: $filename"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 2. 检查类命名规范
echo ""
echo "📋 检查类命名规范..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file" .swift)
    if grep -q "class $filename" "$file" || grep -q "struct $filename" "$file"; then
        # 类名与文件名匹配，检查是否符合 PascalCase
        if [[ ! "$filename" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
            echo "  ⚠️  类名不符合 PascalCase: $filename"
            ((WARNING_COUNT++))
            ((TOTAL_ISSUES++))
        fi
    fi
done

# 3. 检查 MARK 注释使用
echo ""
echo "📋 检查 MARK 注释使用..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if ! grep -q "// MARK:" "$file"; then
        echo "  💡 建议添加 MARK 注释: $filename"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 4. 检查文档注释
echo ""
echo "📋 检查文档注释..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    # 检查是否有文件头注释
    if ! head -5 "$file" | grep -q "//.*$filename"; then
        echo "  💡 建议添加文件头注释: $filename"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 5. 检查错误处理
echo ""
echo "📋 检查错误处理..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if grep -q "fatalError\|assertionFailure" "$file"; then
        echo "  ⚠️  发现致命错误调用: $filename"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 6. 检查内存管理
echo ""
echo "📋 检查内存管理..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if grep -q "unowned\|weak" "$file"; then
        # 检查是否有适当的 weak self 使用
        if grep -q "\[weak self\]" "$file"; then
            echo "  ✅ 正确使用 weak self: $filename"
        else
            echo "  💡 建议检查 weak/unowned 使用: $filename"
            ((WARNING_COUNT++))
            ((TOTAL_ISSUES++))
        fi
    fi
done

# 7. 检查代码复杂度
echo ""
echo "📋 检查代码复杂度..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    line_count=$(wc -l < "$file")
    if [ "$line_count" -gt 300 ]; then
        echo "  💡 文件较长，建议拆分: $filename ($line_count 行)"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 8. 检查硬编码值
echo ""
echo "📋 检查硬编码值..."
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if grep -q "[0-9]\{2,\}" "$file" | grep -v "//" | grep -v "import"; then
        echo "  💡 建议将硬编码值提取为常量: $filename"
        ((WARNING_COUNT++))
        ((TOTAL_ISSUES++))
    fi
done

# 9. 检查 SwiftLint 规则（如果安装了）
if command -v swiftlint &> /dev/null; then
    echo ""
    echo "📋 运行 SwiftLint 检查..."
    swiftlint lint --path "$PROJECT_DIR" --quiet
    if [ $? -eq 0 ]; then
        echo "  ✅ SwiftLint 检查通过"
    else
        echo "  ❌ SwiftLint 检查发现问题"
        ((ERROR_COUNT++))
        ((TOTAL_ISSUES++))
    fi
else
    echo ""
    echo "💡 建议安装 SwiftLint 进行更详细的代码检查"
    echo "   brew install swiftlint"
fi

# 10. 检查项目结构
echo ""
echo "📋 检查项目结构..."
if [ ! -f "$PROJECT_DIR/Info.plist" ]; then
    echo "  ❌ 缺少 Info.plist 文件"
    ((ERROR_COUNT++))
    ((TOTAL_ISSUES++))
fi

if [ ! -f "$PROJECT_DIR/App.swift" ]; then
    echo "  ❌ 缺少主入口文件 App.swift"
    ((ERROR_COUNT++))
    ((TOTAL_ISSUES++))
fi

# 总结
echo ""
echo "=================================="
echo "📊 代码质量检查完成"
echo "总问题数: $TOTAL_ISSUES"
echo "警告: $WARNING_COUNT"
echo "错误: $ERROR_COUNT"

if [ $TOTAL_ISSUES -eq 0 ]; then
    echo "🎉 恭喜！代码质量优秀"
    exit 0
elif [ $ERROR_COUNT -eq 0 ]; then
    echo "⚠️  有一些建议可以改进代码质量"
    exit 0
else
    echo "❌ 发现严重问题，需要修复"
    exit 1
fi
