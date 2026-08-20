# SIL 状态与验证边界

## 已完成

- 分立器件 MATLAB System 模型
- 可拖放的独立 Simulink 模块库
- 14 bit ADC 与16 bit DAC整数边界
- 100 MHz控制器状态机
- 3 MHz NCO、整数I/Q混频和101点滑动累加
- 双缓冲5000点chirp LUT
- FPGA控制器到光电被控对象再回ADC的联合SIL闭环
- 3 GHz、50 us、六chirp确定性收敛验证

## 已验证结果

```text
理论距离分辨率：4.997 cm
MZI拍频：3.000 MHz
第一chirp RMS误差：22.772 MHz
第六chirp RMS误差：0.16097 MHz
第六chirp峰值误差：0.74656 MHz
第六chirp扫频带宽：3.002217 GHz
最终带宽相对误差：0.0739%
ADC/DAC/器件限幅：无
FPGA fault：无
```

## 尚未完成

- 可综合RTL
- CORDIC实际流水线和延迟
- BRAM初始化及真实读写延迟
- 250 MHz ADC域到100 MHz算法域的CDC/FIFO
- Vivado综合、实现、资源和时序验证
- FPGA-in-the-loop
- 随机电流噪声、ADC噪声、时钟抖动联合蒙特卡洛
- 真实器件和实验室目标回波验证

## 解释限制

当前SIL证明控制拓扑、信号方向、整数边界和确定性补偿策略可以闭环工作。它不能证明目标FPGA满足100 MHz时序，也不能证明真实BNLD1550在10 mA动态范围内保持0.3 GHz/mA调谐系数和100 kHz线宽。
