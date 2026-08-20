# SIL 器件模块接口

所有连续量使用 SI 单位。默认离散采样周期为 `10e-9 s`，对应 100 MHz 软件仿真时钟。

## 模块内说明书入口

双击 `LDC220CModel`、`TED200CModel`、`BNLD1550Laser` 或
`PDB450CModel` 模块会调用 `open_fmcwlidar_manual`，并使用系统默认PDF
阅读器打开对应说明书。右键模块并选择 **Block Parameters (MATLAB System)**
可继续修改模型参数。MZI、ADC、DAC和FPGA模块没有独立厂商PDF，双击后打开
本接口文档。

## FPGAOffsetBinaryDAC

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `dacCode` | `uint16` | 16 bit offset-binary DAC 码 |
| 输出 | `voltageV` | `double`, V | 双极性模拟输出 |

默认满量程为 2 V，对应约 -1 V 至 +1 V。

## LDC220CModel

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `modulationVoltageV` | `double`, V | MOD IN 电压 |
| 输出 | `driveCurrentA` | `double`, A | 激光器驱动电流 |
| 输出 | `limited` | `logical` | 请求电流达到模型边界 |

默认偏置电流650 mA、调制增益206 mA/V、模拟带宽50 kHz。模型包含一阶带宽和电流限幅。

## TED200CModel

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `setpointC` | `double`, degC | 温度设定值 |
| 输出 | `laserTemperatureC` | `double`, degC | 激光器温度 |
| 输出 | `withinRange` | `logical` | 设定值和环境温度是否在边界内 |

默认热时间常数2 s。该模块用于慢速温控，不用于50 us chirp调谐。

## BNLD1550Laser

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `driveCurrentA` | `double`, A | 激光器驱动电流 |
| 输入 | `temperatureC` | `double`, degC | 激光器温度 |
| 输入 | `sampleTimeS` | `double`, s | 离散采样周期 |
| 输入 | `phaseNoiseUnit` | `double` | 单位高斯相位噪声；置零关闭 |
| 输入 | `resetPhase` | `logical` | 复包络相位复位 |
| 输出 | `opticalField` | `complex double`, sqrt(W) | 1550 nm参考频率下的复包络 |
| 输出 | `opticalPowerW` | `double`, W | 瞬时光功率 |
| 输出 | `frequencyHz` | `double`, Hz | 绝对光频率 |
| 输出 | `wavelengthM` | `double`, m | 瞬时波长 |
| 输出 | `monitorCurrentA` | `double`, A | 内置监测PD电流 |
| 输出 | `phaseRad` | `double`, rad | 复包络相位 |
| 输出 | `withinOperatingRange` | `logical` | 电流、温度和采样周期是否安全 |

默认电流调谐系数为 -0.3 GHz/mA，线宽100 kHz，最大建模光功率150 mW。

## MZIInterferometerModel

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `opticalField` | `complex double`, sqrt(W) | 激光复包络 |
| 输出 | `powerPlusW` | `double`, W | MZI互补端口+ |
| 输出 | `powerMinusW` | `double`, W | MZI互补端口- |

默认延迟50 ns、抽头比例 `1e-4`、插入透射率0.90。3 GHz/50 us扫频对应3 MHz MZI拍频。

## PDB450CModel

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `powerPlusW` | `double`, W | 平衡探测器正端口光功率 |
| 输入 | `powerMinusW` | `double`, W | 平衡探测器负端口光功率 |
| 输出 | `rfVoltageV` | `double`, V | 平衡RF输出 |
| 输出 | `saturated` | `logical` | 差分饱和、单端损伤或输出摆幅越界 |

当前使用50 kV/A加载增益和4 MHz一阶带宽。

## FPGASignedADC

| 方向 | 端口 | 类型/单位 | 含义 |
|---|---|---|---|
| 输入 | `voltageV` | `double`, V | 双极性ADC输入 |
| 输出 | `adcCode` | `int16` | 14 bit有符号码 |
| 输出 | `clipped` | `logical` | ADC削顶状态 |

## FMCWFPGAController

| 方向 | 端口 | 类型 | 含义 |
|---|---|---|---|
| 输入 | `adcCode` | `int16` | MZI反馈ADC码 |
| 输入 | `enable` | `logical` | 控制器使能 |
| 输入 | `reset` | `logical` | 状态与LUT复位 |
| 输入 | `faultIn` | `logical` | 外部故障输入 |
| 输出 | `dacCode` | `uint16` | DAC扫频码 |
| 输出 | `chirpStart` | `logical` | chirp首拍脉冲 |
| 输出 | `chirpActive` | `logical` | chirp有效窗口 |
| 输出 | `lutWriteEnable` | `logical` | 非活动LUT写使能 |
| 输出 | `phaseErrorHz` | `int32` | MZI相位换算频率误差 |
| 输出 | `controllerState` | `uint8` | 1预置、2扫频、3更新、4空闲、5故障 |
| 输出 | `chirpNumber` | `uint8` | chirp序号 |
| 输出 | `faultOut` | `logical` | 锁存故障 |

控制器使用双缓冲LUT、100点NCO ROM、整数I/Q混频和101点滑动累加。`atan2`仍是未来RTL CORDIC的行为参考。
