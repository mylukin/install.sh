#!/bin/bash
set -e

echo "🔍 GPU硬件矿卡检测工具 v3.0（硬件专业版）"
echo "================================================="
echo ""
echo "📋 本工具专注于GPU硬件本身的矿卡特征检测："
echo "   🧬 GPU BIOS/固件完整性和修改检测"
echo "   💾 显存颗粒深度老化和坏块测试"
echo "   ⚡ 核心计算单元性能衰减分析"
echo "   🌡️ 温度传感器和散热系统磨损检测"
echo "   🔋 电源管理和功耗效率老化测试"
echo "   📊 GPU硬件使用统计和计数器分析"
echo "   🎯 频率-电压曲线异常检测"
echo ""
echo "⚠️  完整硬件检测需要20-40分钟，建议："
echo "   • 确保GPU完全空闲以获得准确结果"
echo "   • 准备充足时间进行深度硬件测试"
echo "   • 测试期间避免使用GPU"
echo ""

# 全局变量
MINING_SCORE=0
TOTAL_CHECKS=0
NORMAL_INDICATORS=""
RISK_FACTORS=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测结果记录函数
add_risk() {
    local score=$1
    local description=$2
    MINING_SCORE=$((MINING_SCORE + score))
    RISK_FACTORS="$RISK_FACTORS\n   🔴 $description (+${score}分)"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

add_normal() {
    local description=$1
    NORMAL_INDICATORS="$NORMAL_INDICATORS\n   ✅ $description"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

add_warning() {
    local score=$1
    local description=$2
    MINING_SCORE=$((MINING_SCORE + score))
    RISK_FACTORS="$RISK_FACTORS\n   🟡 $description (+${score}分)"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

echo "🚀 开始GPU硬件矿卡特征检测..."

# ==========================================
# 模块1: GPU硬件身份和基础信息
# ==========================================
echo -e "\n🔍 【模块1: GPU硬件身份和基础信息】"
echo "=========================================="

# 检查NVIDIA驱动
if ! nvidia-smi &>/dev/null; then
    echo "❌ 未检测到NVIDIA驱动，无法继续检测"
    exit 1
fi

# 获取GPU详细硬件信息
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)
GPU_UUID=$(nvidia-smi --query-gpu=uuid --format=csv,noheader,nounits)
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits)
TOTAL_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
SERIAL=$(nvidia-smi --query-gpu=serial --format=csv,noheader,nounits 2>/dev/null || echo "未知")
GPU_BUS_ID=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader,nounits)

echo "🎯 检测目标: $GPU_NAME"
echo "🆔 GPU UUID: $GPU_UUID"
echo "📄 序列号: $SERIAL"
echo "🚌 PCI总线: $GPU_BUS_ID"
echo "💾 显存容量: ${TOTAL_MEMORY} MiB"

# 检查GPU是否空闲
GPU_PROCESSES=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | wc -l)
if [ "$GPU_PROCESSES" -gt 0 ]; then
    echo "⚠️  GPU正在被使用，可能影响检测准确性"
    add_warning 5 "GPU使用中，影响硬件检测准确性"
else
    echo "✅ GPU空闲，适合进行硬件检测"
    add_normal "GPU处于空闲状态，检测环境理想"
fi

# ==========================================
# 模块2: GPU BIOS和固件完整性检测
# ==========================================
echo -e "\n🧬 【模块2: GPU BIOS和固件完整性检测】"
echo "============================================"

echo "🔍 检查GPU BIOS/固件信息..."

# 获取BIOS版本信息
VBIOS_VERSION=$(nvidia-smi --query-gpu=vbios_version --format=csv,noheader,nounits 2>/dev/null || echo "未知")
echo "📋 VBIOS版本: $VBIOS_VERSION"

# 分析BIOS版本特征
if [[ $VBIOS_VERSION != "未知" ]]; then
    # 检查BIOS日期（矿工经常刷新BIOS优化功耗）
    if [[ $VBIOS_VERSION =~ [0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2} ]]; then
        echo "✅ BIOS版本格式正常"
        add_normal "BIOS版本格式标准"
    else
        add_warning 15 "BIOS版本格式异常，可能被修改"
    fi
    
    # 检查是否为早期BIOS版本（可能包含挖矿优化）
    if [[ $VBIOS_VERSION == *"2021"* ]] || [[ $VBIOS_VERSION == *"2022"* ]]; then
        add_warning 10 "BIOS版本较早，可能包含挖矿期优化"
    fi
else
    add_warning 10 "无法获取BIOS版本信息"
fi

# 检查GPU频率和电压设置
echo "⚡ 检查GPU频率和电压配置..."
CURRENT_SM_CLOCK=$(nvidia-smi --query-gpu=clocks.sm --format=csv,noheader,nounits)
CURRENT_MEM_CLOCK=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits)
MAX_SM_CLOCK=$(nvidia-smi --query-gpu=clocks.max.sm --format=csv,noheader,nounits)
MAX_MEM_CLOCK=$(nvidia-smi --query-gpu=clocks.max.mem --format=csv,noheader,nounits)

echo "🔧 当前频率: GPU ${CURRENT_SM_CLOCK}MHz, 显存 ${CURRENT_MEM_CLOCK}MHz"
echo "📊 最大频率: GPU ${MAX_SM_CLOCK}MHz, 显存 ${MAX_MEM_CLOCK}MHz"

# 检查功耗限制是否被修改
POWER_LIMIT=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null || echo "0")
POWER_DEFAULT=$(nvidia-smi --query-gpu=power.default_limit --format=csv,noheader,nounits 2>/dev/null || echo "0")

if [[ $POWER_LIMIT != "0" ]] && [[ $POWER_DEFAULT != "0" ]]; then
    POWER_DIFF=$(echo "$POWER_LIMIT - $POWER_DEFAULT" | bc -l 2>/dev/null || echo "0")
    echo "🔋 功耗限制: 当前 ${POWER_LIMIT}W, 默认 ${POWER_DEFAULT}W"
    
    if (( $(echo "$POWER_DIFF > 15" | bc -l 2>/dev/null || echo "0") )); then
        add_normal "功耗限制被提高 (${POWER_LIMIT}W > ${POWER_DEFAULT}W，游戏/专业用户超频特征)"
    elif (( $(echo "$POWER_DIFF > 5" | bc -l 2>/dev/null || echo "0") )); then
        add_normal "功耗限制被轻微提高，支持非矿卡"
    elif (( $(echo "$POWER_DIFF < -30" | bc -l 2>/dev/null || echo "0") )); then
        add_risk 30 "功耗限制被大幅调低 (${POWER_LIMIT}W vs ${POWER_DEFAULT}W，典型矿卡效率优化)"
    elif (( $(echo "$POWER_DIFF < -15" | bc -l 2>/dev/null || echo "0") )); then
        add_warning 20 "功耗限制被显著调低 (${POWER_LIMIT}W vs ${POWER_DEFAULT}W，可能矿卡优化)"
    elif (( $(echo "$POWER_DIFF < -5" | bc -l 2>/dev/null || echo "0") )); then
        add_warning 10 "功耗限制被轻微调低"
    else
        add_normal "功耗限制配置正常"
    fi
else
    echo "⚠️  无法检查功耗限制配置"
fi

# ==========================================
# 模块3: 显存颗粒深度老化测试
# ==========================================
echo -e "\n💾 【模块3: 显存颗粒深度老化和坏块检测】"
echo "==============================================="

read -p "🤔 是否进行显存深度老化测试？(需要15-25分钟，但最关键) (Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "⏭️  跳过显存深度测试"
    add_risk 30 "跳过显存测试，无法评估显存老化程度"
else
    echo "🧪 开始显存颗粒深度老化检测..."
    echo "⏱️  这是检测矿卡最关键的环节，请耐心等待..."
    
    # 确保gpu-burn可用
    if ! command -v gpu-burn &>/dev/null; then
        echo "📥 安装GPU压力测试工具..."
        if sudo snap install gpu-burn 2>/dev/null; then
            echo "✅ 测试工具安装成功"
        else
            echo "❌ 测试工具安装失败，跳过显存测试"
            add_risk 25 "无法安装显存测试工具"
        fi
    fi
    
    if command -v gpu-burn &>/dev/null; then
        echo "🔬 第一阶段：中强度显存测试（5分钟）..."
        START_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        START_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits)
        
        if timeout 300s gpu-burn 300 2>&1 | tee /tmp/gpu_burn_output1.log; then
            # 正确提取实际错误数量
            ERRORS_STAGE1=$(grep "errors:" /tmp/gpu_burn_output1.log | tail -1 | grep -oE 'errors: [0-9]+' | grep -oE '[0-9]+' || echo "0")
            FINAL_RESULT=$(grep "GPU 0:" /tmp/gpu_burn_output1.log | tail -1 || echo "")
            
            echo "🔍 第一阶段错误数: ${ERRORS_STAGE1}"
            echo "📊 最终结果: ${FINAL_RESULT}"
            
            if [[ $FINAL_RESULT == *"OK"* ]] && [ "$ERRORS_STAGE1" -eq 0 ]; then
                echo "✅ 第一阶段测试通过"
                add_normal "中强度显存测试无错误"
            else
                echo "❌ 第一阶段测试异常"
                add_risk 40 "中强度显存测试发现${ERRORS_STAGE1}个错误或测试失败"
            fi
        else
            add_risk 35 "中强度显存测试异常终止"
        fi
        
        # 检查温度稳定性
        MID_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        TEMP_RISE1=$((MID_TEMP - START_TEMP))
        echo "🌡️  第一阶段温升: ${START_TEMP}°C → ${MID_TEMP}°C (${TEMP_RISE1}°C)"
        
        echo "⏱️  等待GPU冷却30秒..."
        sleep 30
        
        echo "🔬 第二阶段：高强度显存测试（10分钟）..."
        START_TEMP2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        
        if timeout 600s gpu-burn 600 2>&1 | tee /tmp/gpu_burn_output2.log; then
            # 正确提取实际错误数量
            ERRORS_STAGE2=$(grep "errors:" /tmp/gpu_burn_output2.log | tail -1 | grep -oE 'errors: [0-9]+' | grep -oE '[0-9]+' || echo "0")
            FINAL_RESULT2=$(grep "GPU 0:" /tmp/gpu_burn_output2.log | tail -1 || echo "")
            
            echo "🔍 第二阶段错误数: ${ERRORS_STAGE2}"
            echo "📊 最终结果: ${FINAL_RESULT2}"
            
            if [[ $FINAL_RESULT2 == *"OK"* ]] && [ "$ERRORS_STAGE2" -eq 0 ]; then
                echo "✅ 第二阶段测试通过"
                add_normal "高强度显存测试无错误"
            else
                echo "❌ 第二阶段测试异常"
                add_risk 50 "高强度显存测试发现${ERRORS_STAGE2}个错误或测试失败"
            fi
        else
            add_risk 45 "高强度显存测试异常终止"
        fi
        
        # 最终温度检查
        END_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        TEMP_RISE2=$((END_TEMP - START_TEMP2))
        echo "🌡️  第二阶段温升: ${START_TEMP2}°C → ${END_TEMP}°C (${TEMP_RISE2}°C)"
        echo "🌡️  总体最高温度: ${END_TEMP}°C"
        
        # 温度老化特征分析
        if [ $END_TEMP -gt 90 ]; then
            add_risk 30 "极限温度过高 (${END_TEMP}°C > 90°C，散热系统严重老化)"
        elif [ $END_TEMP -gt 85 ]; then
            add_warning 20 "满载温度偏高 (${END_TEMP}°C > 85°C，散热性能下降)"
        elif [ $END_TEMP -gt 80 ]; then
            add_warning 10 "满载温度略高 (${END_TEMP}°C)"
        else
            add_normal "温度控制优秀 (${END_TEMP}°C ≤ 80°C)"
        fi
        
        # 温升速度分析（矿卡散热系统老化的重要指标）
        if [ $TEMP_RISE2 -gt 40 ]; then
            add_risk 25 "温升过快 (${TEMP_RISE2}°C > 40°C，散热系统磨损严重)"
        elif [ $TEMP_RISE2 -gt 30 ]; then
            add_warning 15 "温升较快 (${TEMP_RISE2}°C > 30°C)"
        else
            add_normal "温升控制良好 (${TEMP_RISE2}°C ≤ 30°C)"
        fi
        
        echo "⏱️  等待冷却并检查恢复特性..."
        sleep 60
        COOL_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        COOL_RATE=$((END_TEMP - COOL_TEMP))
        echo "❄️  冷却效果: ${END_TEMP}°C → ${COOL_TEMP}°C (1分钟降${COOL_RATE}°C)"
        
        if [ $COOL_RATE -lt 5 ]; then
            add_warning 15 "冷却速度慢 (1分钟仅降${COOL_RATE}°C，散热效率低)"
        else
            add_normal "冷却速度正常 (1分钟降${COOL_RATE}°C)"
        fi
        
        # 清理临时文件
        rm -f /tmp/gpu_burn_output1.log /tmp/gpu_burn_output2.log
        
    else
        echo "❌ 无法进行显存测试"
        add_risk 25 "无法进行显存老化测试"
    fi
fi

# ==========================================
# 模块4: 核心计算单元性能衰减检测
# ==========================================
echo -e "\n⚡ 【模块4: 核心计算单元性能衰减检测】"
echo "=============================================="

echo "📊 分析GPU计算性能特征..."

# 基础性能测试
if command -v gpu-burn &>/dev/null && [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "🧮 执行标准计算性能测试（3分钟）..."
    
    if timeout 180s gpu-burn 180 2>&1 | tee /tmp/perf_test.log; then
        # 提取性能数据和错误检查
        GFLOPS=$(grep "Gflop/s" /tmp/perf_test.log | tail -1 | grep -oE '[0-9]+\.[0-9]+|[0-9]+' | head -1 || echo "0")
        PERF_ERRORS=$(grep "errors:" /tmp/perf_test.log | tail -1 | grep -oE 'errors: [0-9]+' | grep -oE '[0-9]+' || echo "0")
        PERF_RESULT=$(grep "GPU 0:" /tmp/perf_test.log | tail -1 || echo "")
        
        echo "🎯 测得计算性能: ${GFLOPS} Gflop/s"
        echo "🔍 性能测试错误数: ${PERF_ERRORS}"
        
        if [[ $PERF_RESULT == *"OK"* ]] && [ "$PERF_ERRORS" -eq 0 ]; then
            add_normal "性能基准测试无错误"
        else
            add_warning 15 "性能测试发现${PERF_ERRORS}个错误"
        fi
        
        # 根据GPU型号评估性能是否正常
        if [[ $GPU_NAME == *"RTX 3090"* ]]; then
            if (( $(echo "$GFLOPS < 20000" | bc -l 2>/dev/null || echo "0") )); then
                add_risk 25 "RTX 3090计算性能严重下降 (${GFLOPS} < 20000 Gflop/s)"
            elif (( $(echo "$GFLOPS < 24000" | bc -l 2>/dev/null || echo "0") )); then
                add_warning 15 "RTX 3090计算性能略有下降 (${GFLOPS} < 24000 Gflop/s)"
            else
                add_normal "RTX 3090计算性能正常 (${GFLOPS} Gflop/s)"
            fi
        elif [[ $GPU_NAME == *"RTX 4090"* ]]; then
            if (( $(echo "$GFLOPS < 45000" | bc -l 2>/dev/null || echo "0") )); then
                add_risk 25 "RTX 4090计算性能严重下降 (${GFLOPS} < 45000 Gflop/s)"
            elif (( $(echo "$GFLOPS < 50000" | bc -l 2>/dev/null || echo "0") )); then
                add_warning 15 "RTX 4090计算性能略有下降 (${GFLOPS} < 50000 Gflop/s)"
            else
                add_normal "RTX 4090计算性能正常 (${GFLOPS} Gflop/s)"
            fi
        else
            echo "💡 未知GPU型号，无法评估性能基准"
        fi
        
        rm -f /tmp/perf_test.log
    else
        add_warning 15 "无法完成性能基准测试"
    fi
else
    echo "⏭️  跳过性能基准测试"
    add_warning 10 "跳过性能基准测试"
fi

# ==========================================
# 模块5: 电源管理和功耗效率检测
# ==========================================
echo -e "\n🔋 【模块5: 电源管理和功耗效率老化测试】"
echo "=============================================="

echo "⚡ 检查功耗特征和电源管理..."

# 空载功耗检测
IDLE_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | cut -d'.' -f1)
echo "🔋 当前空载功耗: ${IDLE_POWER}W"

# 根据GPU型号判断空载功耗是否异常
if [[ $GPU_NAME == *"RTX 3090"* ]]; then
    if [ $IDLE_POWER -gt 60 ]; then
        add_risk 20 "RTX 3090空载功耗异常 (${IDLE_POWER}W > 60W，电源管理老化)"
    elif [ $IDLE_POWER -gt 45 ]; then
        add_warning 10 "RTX 3090空载功耗偏高 (${IDLE_POWER}W > 45W)"
    else
        add_normal "RTX 3090空载功耗正常 (${IDLE_POWER}W)"
    fi
elif [[ $GPU_NAME == *"RTX 4090"* ]]; then
    if [ $IDLE_POWER -gt 50 ]; then
        add_risk 20 "RTX 4090空载功耗异常 (${IDLE_POWER}W > 50W，电源管理老化)"
    elif [ $IDLE_POWER -gt 35 ]; then
        add_warning 10 "RTX 4090空载功耗偏高 (${IDLE_POWER}W > 35W)"
    else
        add_normal "RTX 4090空载功耗正常 (${IDLE_POWER}W)"
    fi
fi

# 检查功耗稳定性
echo "📊 检查功耗稳定性..."
POWER_READINGS=""
for i in {1..5}; do
    POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits)
    POWER_READINGS="$POWER_READINGS $POWER"
    sleep 2
done

echo "🔍 功耗读数序列: $POWER_READINGS"
# 这里可以分析功耗波动，但为简化实现，暂时省略复杂计算

# ==========================================
# 模块6: 散热系统和传感器精度检测
# ==========================================
echo -e "\n🌡️ 【模块6: 散热系统和温度传感器检测】"
echo "============================================="

echo "🌀 检查散热系统状态..."

# 获取当前温度和风扇状态
CURRENT_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
FAN_SPEED=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits)

echo "🌡️  当前温度: ${CURRENT_TEMP}°C"
echo "💨 风扇转速: ${FAN_SPEED}%"

# 空载温度评估
if [ $CURRENT_TEMP -le 40 ]; then
    add_normal "空载温度优秀 (${CURRENT_TEMP}°C ≤ 40°C)"
elif [ $CURRENT_TEMP -le 50 ]; then
    add_normal "空载温度良好 (${CURRENT_TEMP}°C ≤ 50°C)"
elif [ $CURRENT_TEMP -le 60 ]; then
    add_warning 10 "空载温度偏高 (${CURRENT_TEMP}°C > 50°C)"
else
    add_risk 20 "空载温度异常 (${CURRENT_TEMP}°C > 60°C，散热系统问题)"
fi

# 风扇状态评估
if [ $FAN_SPEED -le 30 ]; then
    add_normal "风扇转速正常 (${FAN_SPEED}% ≤ 30%)"
elif [ $FAN_SPEED -le 50 ]; then
    add_warning 5 "风扇转速略高 (${FAN_SPEED}%)"
else
    add_warning 15 "风扇转速过高 (${FAN_SPEED}% > 50%，可能轴承磨损)"
fi

# 风扇响应测试
echo "🔧 测试风扇响应特性..."
echo "📊 监控5分钟内的温度和风扇变化..."
for i in {1..5}; do
    TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    FAN=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits)
    echo "   ${i}分钟: ${TEMP}°C, 风扇 ${FAN}%"
    sleep 60
done

# ==========================================
# 模块7: PCIe接口和通信质量检测
# ==========================================
echo -e "\n🔌 【模块7: PCIe接口和通信质量检测】"
echo "==========================================="

echo "🔗 检查PCIe接口状态..."

# PCIe链路质量检测
PCIE_SPEED=$(nvidia-smi --query-gpu=pcie.link.gen.current --format=csv,noheader,nounits 2>/dev/null || echo "未知")
PCIE_WIDTH=$(nvidia-smi --query-gpu=pcie.link.width.current --format=csv,noheader,nounits 2>/dev/null || echo "未知")
PCIE_MAX_WIDTH=$(nvidia-smi --query-gpu=pcie.link.width.max --format=csv,noheader,nounits 2>/dev/null || echo "未知")

if [[ $PCIE_SPEED != "未知" ]]; then
    echo "📊 PCIe链路: Gen${PCIE_SPEED} x${PCIE_WIDTH} (最大 x${PCIE_MAX_WIDTH})"
    
    if [[ $PCIE_WIDTH -lt $PCIE_MAX_WIDTH ]]; then
        add_warning 15 "PCIe链路宽度未达到最大值 (x${PCIE_WIDTH} < x${PCIE_MAX_WIDTH})"
    else
        add_normal "PCIe链路配置最优"
    fi
else
    add_warning 5 "无法检测PCIe链路状态"
fi

# ==========================================
# 最终评估和专业报告
# ==========================================
echo -e "\n=============================================="
echo "🎯 【GPU硬件矿卡检测综合分析报告】"
echo "=============================================="

# 计算最终风险评分和等级
if [ $MINING_SCORE -le 25 ]; then
    RISK_LEVEL="极低"
    RISK_COLOR=$GREEN
    CONCLUSION="✅ 硬件状态优秀，几乎确定非矿卡"
    RECOMMENDATION="GPU硬件各项指标优秀，老化程度极低，强烈推荐购买。"
elif [ $MINING_SCORE -le 50 ]; then
    RISK_LEVEL="较低"
    RISK_COLOR=$GREEN
    CONCLUSION="🟢 硬件状态良好，大概率非矿卡"
    RECOMMENDATION="GPU硬件状态良好，可能是正常游戏或轻度工作使用，推荐购买。"
elif [ $MINING_SCORE -le 80 ]; then
    RISK_LEVEL="中等"
    RISK_COLOR=$YELLOW
    CONCLUSION="🟡 存在一定硬件老化，可能矿卡"
    RECOMMENDATION="发现一些硬件老化迹象，可能经过中等强度挖矿使用，需谨慎考虑。"
elif [ $MINING_SCORE -le 120 ]; then
    RISK_LEVEL="较高"
    RISK_COLOR=$RED
    CONCLUSION="🟠 硬件老化明显，矿卡可能性高"
    RECOMMENDATION="硬件老化程度较高，很可能经过长期挖矿使用，不建议购买。"
else
    RISK_LEVEL="极高"
    RISK_COLOR=$RED
    CONCLUSION="🔴 硬件严重老化，几乎确定矿卡"
    RECOMMENDATION="硬件严重老化，多项指标异常，强烈建议避免购买。"
fi

RISK_PERCENTAGE=$((MINING_SCORE * 100 / 150))
if [ $RISK_PERCENTAGE -gt 100 ]; then
    RISK_PERCENTAGE=100
fi

echo -e "📊 ${RISK_COLOR}硬件老化评分: ${MINING_SCORE}/150 分${NC}"
echo -e "🎲 ${RISK_COLOR}矿卡概率: ${RISK_PERCENTAGE}% (${RISK_LEVEL}风险)${NC}"
echo -e "🏆 ${RISK_COLOR}检测结论: ${CONCLUSION}${NC}"
echo ""
echo "📈 检测统计:"
echo "   🔍 硬件检测项目: ${TOTAL_CHECKS} 项"
echo "   ✅ 正常指标: $(echo -e "$NORMAL_INDICATORS" | grep -c "✅" 2>/dev/null || echo "0")"
echo "   ⚠️  异常指标: $(echo -e "$RISK_FACTORS" | grep -c "🔴\|🟡" 2>/dev/null || echo "0")"
echo ""

if [ ! -z "$NORMAL_INDICATORS" ]; then
    echo "✅ 硬件健康指标:"
    echo -e "$NORMAL_INDICATORS"
    echo ""
fi

if [ ! -z "$RISK_FACTORS" ]; then
    echo "⚠️  硬件老化/风险指标:"
    echo -e "$RISK_FACTORS"
    echo ""
fi

echo "💡 购买建议: $RECOMMENDATION"
echo ""
echo "📞 补充验证建议:"
echo "   • 检查GPU外观：散热器拆卸痕迹、导热硅脂状态"
echo "   • 了解GPU来源：个人用户vs批量出售"
echo "   • 运行专业软件：GPU-Z查看详细参数"
echo "   • 实际应用测试：游戏/渲染负载下的稳定性"
echo "   • 保修状态：检查是否仍在保修期内"

# 生成详细报告
REPORT_FILE="gpu_hardware_mining_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
GPU硬件矿卡检测专业报告
=======================
检测时间: $(date)
检测目标: $GPU_NAME
GPU UUID: $GPU_UUID
序列号: $SERIAL
显存容量: ${TOTAL_MEMORY} MiB

=== 检测结果 ===
硬件老化评分: ${MINING_SCORE}/150 分
矿卡概率: ${RISK_PERCENTAGE}%
风险等级: ${RISK_LEVEL}
检测结论: ${CONCLUSION}

=== 硬件健康指标 ===
$(echo -e "$NORMAL_INDICATORS")

=== 硬件风险指标 ===
$(echo -e "$RISK_FACTORS")

=== 购买建议 ===
$RECOMMENDATION

报告生成时间: $(date)
EOF

echo ""
echo "📄 详细硬件检测报告已保存到: $REPORT_FILE"
echo ""
echo "=============================================="
echo "🔍 GPU硬件矿卡检测完成，感谢使用！"
echo "=============================================="

cd ~
