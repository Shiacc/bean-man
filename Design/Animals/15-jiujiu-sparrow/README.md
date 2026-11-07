# 15 啾啾 · 麻雀（Jiujiu）

**角色**：通知 / 提醒送达。「啾」一声，比推送横幅亲切。

**配色**：blue `#9BB4C9`、dark `#7E9AB3`、cream `#F6EFE4`、beak `#E8A24A`、描边 `#3A2A22`。

**比例**：头 `(470,470) r 196`、身体 `(500,700) rx/ry 196`、翅膀完全落在身体内部（画到边缘外会变成独立色块）、尾巴只露尖端、喙为三角、描边 11px。

**文件**：`source/jiujiu.svg`、`render/jiujiu-master.png`、`Assets.xcassets/Animals/Jiujiu.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/15-jiujiu-sparrow/source/jiujiu.svg `
  --name Jiujiu --display "啾啾" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「啾，到点了」「还有 \(n) 个到期词」。

**待补**：表情三连、啾啾张嘴 idle、音符贴纸。