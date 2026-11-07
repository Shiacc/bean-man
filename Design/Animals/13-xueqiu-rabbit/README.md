# 13 雪球 · 白兔（Xueqiu）

**角色**：空状态 / 全空。什么都没有的时候，陪着你的是最安静的那只。

**配色**：fur `#EDE7DD`、inner `#F6C1B4`、尾/肚子 `#FFFFFF`、描边 `#3A2A22`、腮红 `#F3A183`（55%）。

**比例**：头 `(512,530) r 238×204`；立耳 apex `y ≈ 138`（画在头之前，否则描边穿脸）；门牙两小颗；尾球 `(676,844) r 42`；描边 11px。

**文件**：`source/xueqiu.svg`、`render/xueqiu-master.png`、`Assets.xcassets/Animals/Xueqiu.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/13-xueqiu-rabbit/source/xueqiu.svg `
  --name Xueqiu --display "雪球" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「今天没有要背的词」「这里还是空的」「慢慢来」。

**待补**：表情三连、耳朵轻晃 idle、星星贴纸。