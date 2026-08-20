# 本地PDF手册目录

设备模块双击后调用 `open_fmcwlidar_manual`。

查找顺序：

1. 本目录中的本地PDF；
2. 当前工程父目录下原有的 `器件用户手册及选型分析` PDF；
3. 厂商产品网页。

由于Thorlabs手册明确保留复制和再分发权利，本公共仓库不提交厂商PDF文件。需要让独立克隆脱离原工程后仍直接打开PDF时，请将合法获得的文件放到本目录，并使用以下文件名：

```text
LDC2xxCx_User_Guide_doc-104799.pdf
TED200C_Operation_Manual_15986-D04.pdf
BNLD1550_100kHz_DFB_Datasheet.pdf
PDB4xx_Balanced_Detector_Manual_21709-D02.pdf
```

这些PDF被 `.gitignore` 排除，不会意外发布到公共GitHub仓库。
