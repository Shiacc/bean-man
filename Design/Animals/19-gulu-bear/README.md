# 19 咕噜 · 小熊（Gulu）

**角色**：词库 / 词库管理。「囤词」像囤蜂蜜，交给一只慢慢吃的小熊。

**配色**：bear `#B08050`、bearDark `#8F6540`、muzzle `#F6E9D8`、描边 `#3A2A22`。

**比例**：头 `(512,512) r 248×220`；耳 `r 76` 画在头之前 + 耳内 `r 40`；口鼻椭圆 `118 × 90`；身体底 `y = 912`；描边 11px。

**文件**：`source/gulu.svg`、`render/gulu-master.png`、`Assets.xcassets/Animals/Gulu.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/19-gulu-bear/source/gulu.svg `
  --name Gulu --display "咕噜" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「词库在这儿」「再装一个？」「\(n) 个词」。

**待补**：表情三连、抱蜂蜜 idle、蜂蜜贴纸。