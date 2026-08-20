# FMCW 激光雷达发射端架构与项目阻断项

## 1. 适用器件

本文按以下器件建立模型和风险结论：

- 激光器：BNLD-1550-11HSM-FA1，1550 nm DFB，线宽小于 100 kHz；
- 恒流驱动：Thorlabs LDC220C；
- 温控器：Thorlabs TED200C；
- 平衡探测器：Thorlabs PDB450C，InGaAs；
- MZI：PM 光纤延迟型 Mach-Zehnder 干涉仪；
- 数字部分：FPGA、DAC、ADC 和逐 chirp 校正 LUT。

注意：PDB450A 是 Si 探测器，工作范围为 320～1000 nm，不能用于 1550 nm。本项目的“450”必须确认完整型号为 PDB450C。

## 2. 推荐系统架构

```text
FPGA Chirp LUT -> 16 bit DAC -> 低噪声缩放级 -> LDC220C MOD IN
                                                |
TED200C -> 25 degC 慢速稳温 ----------------> DFB 激光器
                                                |
                   +----------------------------+------------------+
                   |                                               |
              主发射光路                                      0.01%监测抽头
                                                                   |
                                                           50 ns 延迟 MZI
                                                             |           |
                                                           OUT+         OUT-
                                                             |           |
                                                             +--PDB450C--+
                                                                    |
                                                                  ADC
                                                                    |
                                               NCO/IQ/CORDIC -> 误差LUT -> FPGA
```

MZI 和 PDB450C 必须位于低功率监测支路，不能串接在全部 150 mW 主发射光之后。

## 3. 当前设计参数

### 3.1 FMCW 波形

| 参数 | 数值 |
|---|---:|
| 扫频带宽 | 1 GHz |
| chirp 时间 | 50 us |
| 调频斜率 | 2e13 Hz/s |
| 激光器参考电流 | 650 mA |
| 电流调谐默认值 | 0.3 GHz/mA |
| 所需电流变化 | 3.333 mA |
| LDC220C MOD IN 所需电压变化 | 16.667 mV |

激光器手册只给出 0.2～0.4 GHz/mA，0.3 GHz/mA 是仿真默认值。实际 FPGA LUT 必须用 MZI 测量结果标定。

### 3.2 LDC220C

| 参数 | 手册值 |
|---|---:|
| 电流范围 | 0～2 A |
| 恒流制输出电压 | 大于 4 V |
| MOD IN 带宽 | DC～50 kHz |
| MOD IN 系数 | 200 mA/V，误差 ±5% |
| 电流噪声 | 小于 15 uA RMS |
| 纹波 | 小于 5 uA RMS |
| 分辨率 | 100 uA |
| 精度 | ±2 mA |
| 24小时漂移 | 小于 100 uA |
| 软启动时间 | 约 200 ms |

50 kHz 一阶等效时间常数约为 3.183 us。线性上扫段可以做预加重，但 sawtooth 回扫必须放在 idle time 内完成。旧方案的 300 us idle 足够，前提是 FPGA 在 idle 内预置起始电流并等待稳定。

### 3.3 TED200C

TED200C 只负责慢速稳温：

- 激光器工作点设为 25 degC；
- 激光器 10 kOhm NTC 使用 TED200C 的 20 kOhm 热敏电阻量程；
- TUNE IN 只能缓慢改变设定值，手册规定远小于 1 Hz；
- TED200C 不能参与 50 us chirp 的快速调频；
- 激光器手册没有 NTC 的 B 值或完整 R(T) 曲线，因此 25 degC、10 kOhm 以外的温度换算需要补充实测数据。

### 3.4 MZI

| 参数 | 当前设计 |
|---|---:|
| 延迟 | 50 ns |
| PM 光纤群折射率 | 1.468 |
| 光程差 | 约 10.211 m |
| 1 GHz/50 us 时的拍频 | 1 MHz |
| 每个 chirp 条纹数 | 50 |
| 监测抽头比例 | 0.01% |
| 插入功率传输 | 0.9 |

旧代码的 0.3 m 光程差只产生约 1.47 个条纹，单路余弦信号难以稳定恢复 chirp 相位，不建议继续使用。

### 3.5 PDB450C 增益档选择

PDB450C 在 1550 nm 的典型响应度为 1 A/W，具有可切换增益。当前选择 `1e5 V/A` 档：

| 高阻跨阻增益 | RF 带宽 | 是否适合 1 MHz MZI |
|---:|---:|---|
| 1e3 V/A | 150 MHz | 可用，但信号较小 |
| 1e4 V/A | 45 MHz | 可用 |
| 1e5 V/A | 4 MHz | 推荐 |
| 1e6 V/A | 0.3 MHz | 带宽不足 |
| 1e7 V/A | 0.1 MHz | 带宽不足 |

RF OUT 接 50 Ohm ADC 时，`1e5 V/A` 档等效增益约为 5e4 V/A，输出摆幅约为 ±2.3 V。由输出摆幅反算，该档差分光功率线性上限约为 46 uW。当前监测抽头仿真中每个光端口最大约 13.5 uW，RF 输出约 0.67 V，处于探测器和 2 Vpp ADC 的安全范围。

PDB450C 每个光电二极管的损伤阈值为 20 mW。150 mW 主光路直接接入会损坏探测器，即使平衡输出的直流分量能够抵消也不安全。

## 4. 项目阻断项

### 4.1 P0：完整探测器型号未确认

必须检查铭牌或采购单，确认是 PDB450C。若为 PDB450A，则在 1550 nm 无法工作，项目必须更换探测器后才能推进。

### 4.2 P0：主光路与监测光路未分离

必须配置低功率光纤抽头和必要的固定衰减器。首次联调应先用功率计确认 PDB450C 两个输入均处于几十微瓦量级，再连接探测器。

### 4.3 P0：硬件线性度指标与 LDC220C 噪声不匹配

按 0.3 GHz/mA 折算：

- 15 uA 电流噪声对应 4.5 MHz 光频噪声；
- 5 uA 纹波对应 1.5 MHz；
- 100 uA 漂移对应 30 MHz。

这些是手册值的等效折算，不等于实际样机测量值，但表明不能仅靠无噪声仿真宣称几十 kHz 的硬件线性度。若验收要求 RMS 误差小于 100 kHz，必须先测量实际 LDC220C 噪声；若实测达不到，需要更换低噪声、高带宽 OEM 电流驱动器。

### 4.4 P0：DAC 动态范围利用率过低

当前假设 16 bit、2 V 满量程 DAC：

- 1 LSB 为 30.52 uV；
- 经过 LDC220C 后为 6.10 uA；
- 对应约 1.83 MHz 光频步进；
- 整个 1 GHz chirp 只使用 16.667 mV，即不到 DAC 满量程的 1%。

建议增加低噪声模拟缩放级，将 DAC 的 2 V 范围映射成约 25～50 mV 的 MOD IN 范围。100 kHz 光频校正对应 MOD IN 电压约 1.67 uV。

### 4.5 P0：MZI 单路余弦不是唯一相位测量

PDB450C 单路 RF 输出满足 `V=A*cos(phi)`，存在符号和 `2*pi` 模糊。单向、始终为正拍频的 chirp 可以通过 NCO 正交下变频和 CORDIC 恢复相位；三角波双向扫频、拍频过零或深衰落时容易发生 cycle slip。

稳定工程方案优先选择：

1. 90 deg 光学混合器/IQ MZI；或
2. 3x3 耦合器 MZI；或
3. 单路 MZI 加 NCO-IQ、幅度门限、跳周检测和 chirp 状态机。

### 4.6 P1：延迟 MZI 不能提供唯一绝对光频率

MZI适合测量调频斜率和 chirp 内非线性，不能唯一确定绝对起始频率和中心波长。若系统有绝对波长指标，需要增加波长计、吸收池或稳定参考腔。

### 4.7 P1：当前 MATLAB 闭环不是可综合 HDL

MATLAB 参考模型中的 FFT/Hilbert、`polyfit` 和 `movmean` 用于验证算法。FPGA 中应替换为：

```text
ADC -> 数字带通/限幅 -> NCO正交混频 -> I/Q低通 -> CORDIC atan2
    -> 相位展开 -> 理想相位相减 -> 学习系数 -> 校正LUT
```

恒流源逆滤波、LUT、饱和和延迟可直接定点化。

## 5. 推进顺序

1. 确认器件铭牌：LDC220C、TED200C、PDB450C；
2. 冻结验收指标：RMS非线性、峰值误差、扫频带宽误差、绝对中心频率；
3. 完成主光路/监测抽头设计，先用功率计确认探测器输入；
4. 将 PDB450C 设置为 `1e5 V/A` 档，RF OUT 接 50 Ohm ADC；
5. 实测 LDC220C 在 650 mA、16.667 mVpp 调制下的噪声、幅频和相频响应；
6. 验证 50 ns MZI 能稳定获得约 1 MHz、50 条纹/chirp 的信号；
7. 使用 300 us idle 完成回扫和起始电流预置；
8. 先运行逐 chirp 离线 ILC，再迁移到 FPGA 定点 NCO/CORDIC；
9. 完成噪声、温漂和多帧稳定性测试后，才可以给出实际线性度指标。

## 6. MATLAB 文件

```text
bnld1550_parameters.m
BNLD1550Laser.m
fmcw_transmitter_parameters.m
ldc220c_step.m
ted200c_step.m
mzi_pdb450c_step.m
fpga_predistort_chirp.m
fpga_mzi_phase_error.m
run_fmcw_transmitter.m
```

运行端到端确定性仿真：

```matlab
addpath('D:\project\FMCW\matlab');
result = run_fmcw_transmitter(true);
```

该结果只验证可重复传递函数的补偿能力，不包含真实 LDC220C 随机噪声、周期回扫瞬态和硬件模拟前端误差。


## 7. 已购器件处置和最小整改 BOM

### 7.1 可以保留

| 已购器件 | 处置 | 使用边界 |
|---|---|---|
| BNLD-1550 激光器 | 保留 | LDC 硬件限流设置不高于 0.8 A，严禁超过 0.9 A 绝对上限 |
| TED200C | 保留 | 只负责 25 degC 慢速稳温，不参与 chirp 快调制 |
| LM14S 系列安装座 | 保留但必须复核配置卡 | 按激光器 Type 1/Type 2 实际引脚逐针核对后才能插入激光器 |
| 1550 nm PM 隔离器 | 保留 | 放在激光器输出后的第一个无源器件，额定 300 mW 可覆盖 150 mW |
| 90:10 PM 耦合器 | 保留 | 用于原有发射/本振功率分配，不作为 MZI 监测抽头 |
| PDB450C-AC | 保留 | 选择 1e5 V/A 档测 1 MHz MZI；AC 耦合不影响该拍频 |
| BNC/SMA 线缆和转接头 | 保留 | 全部按 50 Ohm 端接，避免悬空和重复端接 |
| AD9643 ADC/FPGA 板 | 条件保留 | 必须确认模拟前端在 1 MHz 无明显衰减且输入不削顶 |

如果已购探测器完整型号是 PDB450A 而不是 PDB450C，则必须更换；Si 型 PDB450A 无法探测 1550 nm。

### 7.2 不建议现在立即报废，但可能必须更换

#### LDC220C

LDC220C 可以用于第一阶段原理样机：650 mA 偏置、16.667 mVpp 小信号调制、300 us idle 和逐 chirp ILC。它不能在未实测前被认定能实现亚 MHz 线性度。

满足以下任一条件时，LDC220C 必须更换为 OEM 低噪声高速驱动器：

- 已冻结指标要求 RMS 调频非线性小于 1 MHz；
- 实测不可重复频率误差大于 1 MHz RMS，ILC 多次迭代后不下降；
- 50 us chirp 的有效区内仍存在无法预补偿的转折或振铃；
- 电流噪声导致 MZI 相位持续跳周；
- 最终产品要求板级集成，而不是台式仪器。

替代驱动器最低建议指标：

| 参数 | 最低建议 |
|---|---:|
| 直流输出范围 | 至少 0～0.8 A |
| 顺从电压 | 至少 3 V |
| 小信号调制带宽 | 至少 1 MHz |
| 电流噪声 | 小于 3 uA RMS；若目标 100 kHz，则需接近 0.3 uA RMS |
| 外部调制 | DC 耦合 |
| 安全 | 独立硬件限流、软启动、互锁、掉电关断 |

### 7.3 必须新增

| 新增项 | 建议规格 | 原因 |
|---|---|---|
| PM 监测抽头 | 99:1 或 99.9:0.1，1550 nm，FC/APC | 将主发射光与校准支路分离 |
| PM 可调/固定衰减 | 至少 20～40 dB 可调范围 | 把监测光调到每路约 10～15 uW；禁止只依赖耦合器标称分光比 |
| 50 ns PM 延迟 MZI | 约 10.21 m 光程差、双互补输出 | 产生约 1 MHz、50 条纹/chirp 的频率鉴别信号 |
| MZI 热/机械封装 | 保温盒、固定盘纤、应力释放 | 防止光程和偏振随机变化导致跳周 |
| 低噪声 DAC 缩放级 | 将 DAC 全量程映射为约 25～50 mV | 2 V 满量程直接输出时 1 LSB 约对应 1.83 MHz |
| DAC 输出保护 | 上电钳位、失锁归零、模拟限幅 | 防止 FPGA 错码经 200 mA/V MOD IN 产生危险电流 |
| ADC 输入匹配级 | 50 Ohm、输入限幅，必要时单端转差分 | 匹配 PDB450C SMA 输出和 AD9643 模拟输入 |
| 共同时钟与同步触发 | DAC、ADC、FPGA 同源时钟 | 避免 chirp 间随机相位漂移，使 ILC 误差可重复 |
| 光功率计测试口 | 可断开或 1% 测试端口 | 第一次接 PDB450C 前必须实测两路功率 |

如果现有 PDB450C-AC 原计划长期用于接收端零差探测，则发射端 MZI 反馈必须另加一只平衡探测器或专用双 InGaAs PD+TIA，不能在系统运行时共用同一只探测器。

### 7.4 必须修改

1. 将连续 sawtooth 改为“有效上扫 + 300 us idle 回扫/预置”，或改成三角波；不得把回扫瞬态算入有效 chirp。
2. FPGA 采用下一 chirp 的迭代学习控制，不做 LDC220C 上的同 chirp 高带宽闭环。
3. PDB450C-AC 使用 1e5 V/A 档；若 ADC 削顶，先降低监测光功率，不直接提高 ADC 限幅。
4. LDC220C 前面板硬件限流设置不高于 0.8 A，FPGA 输出再做独立限幅。
5. TED200C 固定 25 degC；温控稳定后才能开启激光电流。
6. MZI 两个互补输出分别接 PDB450C 的 INPUT+ 和 INPUT-，利用 MONITOR 两路先调平功率。
7. 先用示波器和离线 MATLAB 完成 ILC，再迁移 NCO、FIR、CORDIC 和双缓冲 LUT 到 FPGA。

## 8. 分阶段联调门槛

### 阶段 A：不上激光

- 验证 DAC 缩放后实际范围不超过设计的 25～50 mV；
- FPGA 失锁、复位和断电时 MOD IN 自动回零；
- DAC、ADC 和 chirp trigger 同步稳定。

### 阶段 B：激光开环

- TED200C 已稳定，LDC220C 硬件限流不高于 0.8 A；
- 从低电流开始，逐步升到 650 mA；
- 使用功率计确认 MZI/PDB450C 每路功率约 10～15 uW；
- PDB450C RF 输出峰值低于 ADC 满量程的 80%。

### 阶段 C：MZI 可观测性

- 50 us 有效 chirp 内约有 50 条纹；
- 拍频中心约 1 MHz，且位于 PDB450C 4 MHz 带宽内；
- 条纹无削顶、无消失，单 chirp 相位展开无跳周；
- 连续 1000 个 chirp 的相位误差具有可重复性。

### 阶段 D：ILC 收敛

建议第一版原型机验收门槛：

- 扫频带宽误差小于 0.1%，即小于 1 MHz；
- 有效 chirp 区 RMS 非线性小于 1 MHz；
- 峰值非线性小于 5 MHz；
- 6～10 次迭代内误差单调下降；
- LUT 固化后连续 1000 个 chirp 不发生 cycle slip。

如果阶段 C 通过而阶段 D 的不可重复误差仍大于 1 MHz RMS，优先判定 LDC220C/模拟输出噪声不足，而不是继续增加 FPGA 算法复杂度。

## 9. FPGA 算法仿真与 FIL 边界

`FMCW_FPGA_Algorithm_Sim.slx` 将数字控制器和光电被控对象分开。顶层
`FPGA Algorithm DUT` 是后续 FPGA-in-the-loop 的替换边界，包含 4 个输入：
`adcCode`、`enable`、`reset`、`faultIn`；包含 8 个输出：`dacCode`、
`chirpStart`、`chirpActive`、`lutWriteEnable`、`phaseErrorHz`、
`controllerState`、`chirpNumber`、`faultOut`。

控制器按 100 MHz 时钟运行，状态编码如下：

| 编码 | 状态 | 默认长度 |
|---:|---|---:|
| 1 | PRECHARGE | 2000 点，20 us |
| 2 | CHIRP | 5000 点，50 us |
| 3 | UPDATE | 5000 点，50 us |
| 4 | IDLE | 23000 点，230 us |
| 5 | FAULT | 保持至复位 |

`CHIRP + UPDATE + IDLE + PRECHARGE` 的重复周期为 350 us。DUT 使用 16 bit
offset-binary DAC 码和 14 bit 有符号 ADC 码；补偿 LUT 使用双存储区，在
UPDATE 状态逐地址写入，完成后切换活动存储区。

第一阶段宽带验证将DUT配置为3 GHz/50 us，同时保留50 ns MZI。MZI拍频由
1 MHz提高到3 MHz，仍位于PDB450C当前4 MHz带宽内；100 MHz FPGA时钟下，
NCO每拍前进3个100点ROM地址。该配置的理论距离分辨率为4.997 cm。

6个chirp的确定性联合仿真中，RMS非线性从22.772 MHz收敛到
0.16097 MHz，峰值误差收敛到0.74656 MHz，最终扫频带宽为
3.002217 GHz。带宽误差2.217 MHz，占3 GHz的0.074%；ADC、DAC、
激光器和PDB450C均未触发限幅或故障。

运行 6 个 chirp 的整数算法联合仿真：

```matlab
addpath('D:\project\FMCW\matlab');
result = run_fmcw_fpga_algorithm_simulink(true, 6);
```

当前 NCO、整数 I/Q 混频和 101 点滑动累加器用于周期级数据通路仿真；
`atan2` 是 CORDIC 的行为参考。进入 FIL 前，应由 RTL CORDIC 替换该行为参考，
并保持 DUT 的 4 输入/8 输出接口不变。FIL 只替换 `FPGA Algorithm DUT`，
LDC220C、激光器、MZI、PDB450C、ADC/DAC量化和测试探针继续留在 Simulink
测试平台一侧。