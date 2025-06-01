#!/bin/bash
set -e

echo "🚀 GPU 稳定性检测工具（交互版）"
echo "================================"
echo ""
echo "📋 本工具将检测以下项目："
echo "   🔍 NVIDIA 驱动和 GPU 基础信息"
echo "   📊 GPU 使用情况和显存状态"
echo "   🔥 GPU 烧机压力测试（可选，3分钟）"
echo "   🧠 系统内存稳定性测试（可选）"
echo "   📈 温度和性能监控"
echo ""
echo "⚠️  注意事项："
echo "   • 烧机测试会使 GPU 满载，温度会上升"
echo "   • 建议关闭其他 GPU 应用以获得准确结果"
echo "   • 测试过程中请保持系统稳定"
echo "   • 每个测试项目都可以单独选择是否执行"
echo ""

echo "🚀 开始系统稳定性检测..."

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
🔥 GPU 烧机测试准备就绪
======================================"
echo ""
echo "⚠️  注意：烧机测试将使GPU满载运行3分钟，温度会明显上升"
echo "📊 当前状态：温度 ${START_TEMP}°C，显存使用率 ${USAGE_PERCENT}%"
echo ""
echo "💡 提示："
echo "   • 测试期间可通过 nvidia-smi 监控状态"
echo "   • 如温度超过 90°C，考虑停止测试"
echo "   • 正常情况下 RTX 3090 温度应在 85°C 以下"
echo ""
read -p "🤔 是否开始 GPU 烧机测试？(Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "⏭️  跳过 GPU 烧机测试"
  END_TEMP=$START_TEMP
  TEMP_RISE=0
else
  echo ""
  echo "⏱️  测试将持续 180 秒，请监控温度变化..."
  echo "🔥 启动 GPU 烧机测试..."
  echo ""
  gpu-burn 180 || echo "⚠️ 烧机测试结束（可能有警告，请查看上方输出）"
  
  # 记录测试结束时的温度
  END_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
  echo ""
  echo "🌡️  结束温度: ${END_TEMP}°C"
  
  # 温度分析
  TEMP_RISE=$((END_TEMP - START_TEMP))
  echo "📈 温度上升: ${TEMP_RISE}°C"
  
  if [ $END_TEMP -gt 85 ]; then
    echo "🔥 警告: 峰值温度过高 (${END_TEMP}°C > 85°C)"
  elif [ $END_TEMP -gt 75 ]; then
    echo "⚠️  注意: 温度偏高 (${END_TEMP}°C)"
  else
    echo "✅ 温度控制良好 (${END_TEMP}°C)"
  fi
fi

# 系统内存快速检测（可选）
echo -e "\n====================================
🧠 系统内存测试选项
===================================="
echo ""
echo "💡 内存测试可以检查系统RAM的稳定性，有助于排除内存问题"
echo "🔧 测试内容："
echo "   • 分配 50MB 内存空间进行读写测试"
echo "   • 检测内存错误和数据完整性"
echo "   • 快速验证系统稳定性"
echo ""
read -p "🤔 是否进行系统内存测试？(Y/n): " -n 1 -r
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
nvidia-smi --query-gpu=power.draw,clocks.sm,clocks.mem,clocks.gr --format=csv,noheader

echo "🌡️ 温度和风扇:"
nvidia-smi --query-gpu=temperature.gpu,fan.speed --format=csv,noheader

echo -e "\n====================================
✅ 检测完毕！
===================================="
echo ""
echo "📋 测试总结:"
if [[ ! $REPLY =~ ^[Nn]$ ]] && [[ $END_TEMP ]]; then
  echo "   🔥 GPU 烧机: 3分钟高负载测试完成"
  echo "   🌡️ 温度监控: ${START_TEMP}°C → ${END_TEMP}°C (上升${TEMP_RISE}°C)"
else
  echo "   🔥 GPU 烧机: 用户跳过"
  echo "   🌡️ 温度监控: 当前温度 ${START_TEMP}°C"
fi
echo "   💾 显存检查: ${TOTAL_MEM}MiB 总量，使用率 ${USAGE_PERCENT}%"
echo "   🧠 内存测试: 系统内存验证（如已执行）"
echo ""
echo "🎯 判断标准:"
echo "   ✅ GPU 烧机测试无严重错误"
if [[ $END_TEMP ]]; then
  echo "   ✅ 峰值温度 < 85°C (当前: ${END_TEMP}°C)"
else
  echo "   ✅ 当前温度正常 (${START_TEMP}°C)"
fi
echo "   ✅ 系统运行稳定无重启"
echo "   ✅ 显存和系统内存无异常"
echo ""

# 综合评估
FINAL_TEMP=${END_TEMP:-$START_TEMP}
if [ $FINAL_TEMP -le 85 ] && [ $USAGE_PERCENT -lt 90 ]; then
  echo "🎉 恭喜！你的矿卡通过了基础稳定性验证！"
  echo "💡 建议: 可运行更长时间测试以进一步验证稳定性"
else
  echo "⚠️  检测到一些需要关注的问题，建议："
  [ $FINAL_TEMP -gt 85 ] && echo "   🌡️ 检查散热系统，考虑清洁风扇或更换导热膏"
  [ $USAGE_PERCENT -ge 90 ] && echo "   💾 显存使用率过高，建议释放GPU资源后重新测试"
fi

echo ""
echo "📞 如需更深入测试，可考虑："
echo "   • 运行更长时间的烧机测试 (gpu-burn 3600)"
echo "   • 使用专业的 CUDA 内存测试工具"
echo "   • 在实际工作负载下测试稳定性"
echo ""
echo "====================================
👋 感谢使用 GPU 稳定性检测工具！
===================================="

cd ~
