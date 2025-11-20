#!/bin/bash

# iMoni 网络断开测试脚本

echo "=== iMoni 网络断开测试 ==="
echo "测试时间: $(date)"
echo

# 检查应用是否在运行
echo "1. 检查应用状态:"
if pgrep -f "iMoni.app" > /dev/null; then
    echo "✅ iMoni 应用正在运行"
    PID=$(pgrep -f "iMoni.app")
    echo "   进程 ID: $PID"
else
    echo "❌ iMoni 应用未运行"
    exit 1
fi

echo

# 测试网络连接
echo "2. 测试网络连接状态:"

# 测试正常连接
echo "   测试正常连接 (google.com):"
if timeout 3 nc -zv google.com 443 2>/dev/null; then
    echo "   ✅ google.com:443 - 连接成功"
else
    echo "   ❌ google.com:443 - 连接失败"
fi

echo "   测试正常连接 (api.anthropic.com):"
if timeout 3 nc -zv api.anthropic.com 443 2>/dev/null; then
    echo "   ✅ api.anthropic.com:443 - 连接成功"
else
    echo "   ❌ api.anthropic.com:443 - 连接失败"
fi

# 测试失败连接
echo "   测试失败连接 (不可达地址):"
if timeout 3 nc -zv 10.255.255.1 443 2>/dev/null; then
    echo "   ❌ 10.255.255.1:443 - 意外连接成功"
else
    echo "   ✅ 10.255.255.1:443 - 连接失败（预期行为）"
fi

echo

# 检查应用的网络活动
echo "3. 检查应用网络活动:"

# 使用 lsof 检查网络连接
echo "   检查网络连接:"
NETWORK_CONNECTIONS=$(lsof -p $(pgrep -f "iMoni.app") -i 2>/dev/null | grep -v "COMMAND")
if [ -n "$NETWORK_CONNECTIONS" ]; then
    echo "   发现网络连接:"
    echo "$NETWORK_CONNECTIONS"
else
    echo "   没有发现活动的网络连接"
fi

echo

echo "4. 建议观察事项:"
echo "   📊 检查菜单栏图标是否显示警告状态 ⚠️"
echo "   📊 检查是否显示 '--' 而不是具体延迟数值"
echo "   📊 检查工具提示是否显示 'Status: Disconnected'"
echo "   📊 观察网络流量监控是否显示 0.000 MB/s"

echo
echo "=== 测试完成 ==="
echo "请手动检查菜单栏显示状态以确认应用是否正确处理网络断开"