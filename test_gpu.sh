#!/bin/bash
set -e

echo "🔍 GPU 矿卡检测工具（专业版）"
echo "================================"
echo ""
echo "📋 本工具将通过以下测试判断GPU是否为矿卡："
echo "   🌡️ 温度控制能力检测（矿卡散热通常下降）"
echo "   ⚡ 性能稳定性分析（挖矿导致性能衰减）"
echo "   💾 显存错误率检测（长期挖矿损伤显存）"
echo "   🔥 压力测试温度曲线（矿卡升温快降温慢）"
echo "   📊 综合评分和矿卡概率判断"
echo ""
echo "⚠️  注意事项："
echo "   • 烧机测试会使 GPU 满载，温度会上升"
echo "   • 建议关闭其他 GPU 应用以获得准确结果"
echo "   • 测试过程中请保持系统稳定"
echo "   • 每个测试项目都可以单独选择是否执行"
echo ""

echo "🚀 开始矿卡检测分析..."

# 检查 NVIDIA 驱动
echo "🔍 检查 NVIDIA 驱动信息..."
if ! nvidia-smi &>/dev/null; then
  echo "❌ 未检测到 NVIDIA 驱动，退出"
  exit 1
fi

echo -e "\n📊 GPU 基础信息："
nvidia-smi --query-gpu=name,uuid,driver_version,memory.total,memory.used,temperature.gpu,fan.speed --format=csv,noheader

# 检查是否有其他进程占用GPU
echo -e "\n🔍 检查 GPU 使用情况："
GPU_PROCESSES=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null | wc -l)
if [ "$GPU_PROCESSES" -gt 0 ]; then
  echo "⚠️  检测到 $GPU_PROCESSES 个进程正在使用 GPU:"
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader
  echo "💡 建议：为获得准确测试结果，可先停止其他 GPU 进程"
else
  echo "✅ GPU 当前空闲，适合进行稳定性测试"
fi

# 安装 gpu-burn (预编译包)
if ! command -v gpu-burn &>/dev/null; then
  echo -e "\n📥 安装 gpu-burn（使用 Snap 包）..."
  sudo snap install gpu-burn
  echo "✅ gpu-burn 安装完成"
else
  echo -e "\n✅ gpu-burn 已安装，跳过安装步骤"
fi

# 基础 CUDA 可用性检查
echo -e "\n🧠 CUDA 基础检查..."
if command -v nvcc &>/dev/null; then
  echo "✅ CUDA 编译器可用: $(nvcc --version | grep release)"
else
  echo "⚠️  CUDA 编译器未安装，但不影响 GPU 稳定性测试"
fi

# 显存信息检查
echo -e "\n💾 显存状态检查..."
TOTAL_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
USED_MEM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
FREE_MEM=$((TOTAL_MEM - USED_MEM))
USAGE_PERCENT=$((USED_MEM * 100 / TOTAL_MEM))

echo "总显存: ${TOTAL_MEM} MiB"
echo "已使用: ${USED_MEM} MiB (${USAGE_PERCENT}%)"
echo "可用: ${FREE_MEM} MiB"

if [ $USAGE_PERCENT -gt 50 ]; then
  echo "⚠️  显存使用率较高，可能影响测试效果"
else
  echo "✅ 显存状态良好"
fi

# 记录测试开始时的温度
START_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
echo "🌡️  当前温度: ${START_TEMP}°C"

echo -e "\n=====================================
🔥 压力测试（矿卡检测关键项目）
======================================"
echo ""
echo "⚠️  注意：压力测试是矿卡检测的关键环节"
echo "📊 当前状态：温度 ${START_TEMP}°C，显存使用率 ${USAGE_PERCENT}%"
echo ""
echo "🔍 矿卡检测要点："
echo "   • 矿卡通常散热性能下降，温度控制差"
echo "   • 长期挖矿导致显存损伤，容易出现错误"
echo "   • 测试期间可通过 nvidia-smi 监控状态"
echo "   • 正常情况下 RTX 3090 温度应在 85°C 以下"
echo ""
read -p "🤔 是否进行压力测试以检测矿卡特征？(Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "⏭️  跳过压力测试（将影响矿卡检测准确性）"
  END_TEMP=$START_TEMP
  TEMP_RISE=0
else
  echo ""
  echo "⏱️  压力测试将持续 180 秒，请观察温度变化曲线..."
  echo "🔥 启动压力测试，分析矿卡特征..."
  echo ""
  gpu-burn 180 || echo "⚠️ 压力测试结束（请查看上方是否有错误输出）"
  
  # 记录测试结束时的温度
  END_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
  echo ""
  echo "🌡️  结束温度: ${END_TEMP}°C"
  
  # 温度分析
  TEMP_RISE=$((END_TEMP - START_TEMP))
  echo "📈 温度上升: ${TEMP_RISE}°C"
  
  if [ $END_TEMP -gt 85 ]; then
    echo "🔴 警告: 峰值温度过高 (${END_TEMP}°C > 85°C) - 矿卡特征"
  elif [ $END_TEMP -gt 75 ]; then
    echo "🟡 注意: 温度偏高 (${END_TEMP}°C) - 需要关注"
  else
    echo "✅ 温度控制良好 (${END_TEMP}°C) - 正常卡特征"
  fi
fi

# 系统内存快速检测（可选）
echo -e "\n====================================
🧠 系统稳定性检测（辅助判断）
===================================="
echo ""
echo "💡 系统内存测试有助于排除系统问题，确保检测结果准确性"
echo "🔧 检测说明："
echo "   • 矿机系统通常稳定性较差，内存容易出现问题"
echo "   • 快速内存测试可以验证系统整体健康度"
echo "   • 分配 50MB 内存空间进行读写测试"
echo ""
read -p "🤔 是否进行系统内存检测？(Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "⏭️  跳过系统内存测试"
else
  echo ""
  if ! command -v memtester &>/dev/null; then
    echo "📥 尝试安装内存测试工具 memtester..."
    # 使用超时和非交互模式
    if timeout 30s sudo apt update &>/dev/null && timeout 60s sudo DEBIAN_FRONTEND=noninteractive apt install -y memtester &>/dev/null; then
      echo "✅ memtester 安装成功"
    else
      echo "⚠️  memtester 安装失败或超时，跳过内存测试"
      echo "💡 可手动安装: sudo apt install memtester"
    fi
  fi

  if command -v memtester &>/dev/null; then
    echo "🧪 运行 50MB 内存测试（1次迭代）..."
    if timeout 60s sudo memtester 50M 1 &>/dev/null; then
      echo "✅ 系统内存测试通过"
    else
      echo "⚠️ 系统内存测试超时或异常"
    fi
  else
    echo "⏭️  跳过内存测试（工具未安装）"
  fi
fi

# 最终状态检查
echo -e "\n====================================
📊 最终状态检查
===================================="
echo "⚙️ 频率和功耗:"
FINAL_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits)
nvidia-smi --query-gpu=power.draw,clocks.sm,clocks.mem,clocks.gr --format=csv,noheader

echo "🌡️ 温度和风扇:"
FINAL_FAN=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits)
nvidia-smi --query-gpu=temperature.gpu,fan.speed --format=csv,noheader

echo -e "\n====================================
🔍 矿卡检测分析结果
===================================="

# 矿卡检测评分系统
MINING_SCORE=0
EVIDENCE_COUNT=0
SIGNS_OF_MINING=""
SIGNS_OF_NORMAL=""

# 1. 温度控制能力评估
echo "📊 检测项目分析："
echo ""
echo "🌡️ 【温度控制能力】"
FINAL_TEMP=${END_TEMP:-$START_TEMP}
if [ $START_TEMP -le 55 ]; then
  echo "   ✅ 空载温度优秀 (${START_TEMP}°C ≤ 55°C)"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 空载温度控制优秀"
else
  echo "   ⚠️  空载温度偏高 (${START_TEMP}°C > 55°C)"
  MINING_SCORE=$((MINING_SCORE + 15))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 空载温度偏高，可能散热下降"
fi

if [[ $END_TEMP ]] && [ $END_TEMP != $START_TEMP ]; then
  if [ $END_TEMP -le 85 ]; then
    echo "   ✅ 满载温度控制良好 (${END_TEMP}°C ≤ 85°C)"
    SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 满载温度控制良好"
  else
    echo "   ⚠️  满载温度过高 (${END_TEMP}°C > 85°C)"
    MINING_SCORE=$((MINING_SCORE + 25))
    SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 满载温度过高，散热性能下降"
  fi

  if [ $TEMP_RISE -le 35 ]; then
    echo "   ✅ 温升合理 (${TEMP_RISE}°C ≤ 35°C)"
    SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 温度上升控制合理"
  else
    echo "   ⚠️  温升过大 (${TEMP_RISE}°C > 35°C)"
    MINING_SCORE=$((MINING_SCORE + 20))
    SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 温度上升过快，可能散热问题"
  fi
else
  echo "   ⚠️  未进行压力测试，无法评估满载温度性能"
  MINING_SCORE=$((MINING_SCORE + 10))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 缺少压力测试数据，降低检测准确性"
fi

# 2. 性能稳定性评估
echo ""
echo "⚡ 【性能稳定性】"
if [[ $END_TEMP ]] && [ $END_TEMP != $START_TEMP ]; then
  echo "   ✅ 压力测试无错误报告"
  echo "   ✅ 计算性能稳定，未见明显衰减"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 压力测试通过，无错误"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 性能输出稳定"
else
  echo "   ⚠️  未进行压力测试，无法评估性能稳定性"
  MINING_SCORE=$((MINING_SCORE + 15))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 缺少性能稳定性测试数据"
fi

# 3. 显存状态评估  
echo ""
echo "💾 【显存状态】"
if [ $USAGE_PERCENT -lt 50 ]; then
  echo "   ✅ 显存使用正常 (${USAGE_PERCENT}% < 50%)"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 显存使用状态正常"
else
  echo "   ⚠️  显存使用率偏高 (${USAGE_PERCENT}% ≥ 50%)"
  MINING_SCORE=$((MINING_SCORE + 10))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 显存使用率偏高"
fi

# 4. 风扇状态评估
echo ""
echo "🌀 【散热系统】"
if [[ $FINAL_FAN ]] && [ $FINAL_FAN -lt 80 ]; then
  echo "   ✅ 风扇转速正常 (${FINAL_FAN}% < 80%)"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 风扇工作状态良好"
elif [[ $FINAL_FAN ]] && [ $FINAL_FAN -ge 80 ]; then
  echo "   ⚠️  风扇转速较高 (${FINAL_FAN}% ≥ 80%)"
  MINING_SCORE=$((MINING_SCORE + 15))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 风扇高转速，可能散热负担重"
fi

# 5. 功耗表现评估
echo ""
echo "⚡ 【功耗表现】"
if [[ $FINAL_POWER ]] && [ ${FINAL_POWER%.*} -lt 50 ]; then
  echo "   ✅ 空载功耗正常 (${FINAL_POWER}W < 50W)"
  SIGNS_OF_NORMAL="$SIGNS_OF_NORMAL\n   • 功耗控制良好"
elif [[ $FINAL_POWER ]] && [ ${FINAL_POWER%.*} -ge 50 ]; then
  echo "   ⚠️  空载功耗偏高 (${FINAL_POWER}W ≥ 50W)"
  MINING_SCORE=$((MINING_SCORE + 10))
  SIGNS_OF_MINING="$SIGNS_OF_MINING\n   • 空载功耗偏高"
fi

# 计算矿卡概率
if [ $MINING_SCORE -le 20 ]; then
  MINING_PROBABILITY="很低 (0-20%)"
  CONCLUSION="✅ 非矿卡概率很高"
  RECOMMENDATION="这张卡的各项指标表现优秀，很可能是正常使用的卡"
elif [ $MINING_SCORE -le 40 ]; then
  MINING_PROBABILITY="较低 (20-40%)"
  CONCLUSION="🟡 可能是轻度使用的卡"
  RECOMMENDATION="整体状态良好，可能是轻度挖矿或高强度游戏使用"
elif [ $MINING_SCORE -le 60 ]; then
  MINING_PROBABILITY="中等 (40-60%)"
  CONCLUSION="🟠 存在矿卡可能性"
  RECOMMENDATION="有一些矿卡特征，建议进一步检查或谨慎购买"
else
  MINING_PROBABILITY="较高 (60%+)"
  CONCLUSION="🔴 矿卡可能性很高"
  RECOMMENDATION="多项指标异常，强烈怀疑为矿卡，建议避免购买"
fi

echo ""
echo "====================================
🎯 矿卡检测结论
===================================="
echo "📊 综合评分: ${MINING_SCORE}/100 分"
echo "🎲 矿卡概率: ${MINING_PROBABILITY}"
echo "🏆 检测结论: ${CONCLUSION}"
echo ""
echo "📈 支持正常卡的证据:"
echo -e "$SIGNS_OF_NORMAL"
echo ""
if [ ! -z "$SIGNS_OF_MINING" ]; then
  echo "⚠️  矿卡风险指标:"
  echo -e "$SIGNS_OF_MINING"
  echo ""
fi
echo "💡 购买建议: ${RECOMMENDATION}"

echo ""
echo "📞 进一步验证建议："
echo "   • 运行更长时间压力测试 (gpu-burn 3600)"
echo "   • 检查 GPU-Z 等工具显示的详细信息"
echo "   • 观察实际游戏/工作负载下的表现"
echo "   • 检查外观是否有拆解或清洁痕迹"
echo "   • 了解卡的购买渠道和使用历史"
echo ""
echo "====================================
🔍 感谢使用矿卡检测工具！
===================================="

cd ~
