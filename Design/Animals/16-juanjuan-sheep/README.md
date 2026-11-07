# 16 卷卷 · 小羊（Juanjuan）

**角色**：专注 / 番茄钟。毛一圈一圈，正好是「一圈一圈背下去」。

**配色**：wool `#E8E2D5`、woolShade `#D8D0BF`、face `#F6EFE4`、描边 `#3A2A22`。

**比例**：羊毛是**七个圆堆成的云**（每个圆单独描边，读起来是卷），主圆 `(512,640) r 196`；脸 `(512, ~506)`；腿必须画在羊毛**之前**（画之后会露成方块）；额头三团小羊毛 `r 52–58`；描边 11px。

**文件**：`source/juanjuan.svg`、`render/juanjuan-master.png`、`Assets.xcassets/Animals/Juanjuan.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/16-juanjuan-sheep/source/juanjuan.svg `
  --name Juanjuan --display "卷卷" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「专注 25 分钟」「一圈一圈来」。

**待补**：表情三连、羊毛轻抖 idle、云朵贴纸。