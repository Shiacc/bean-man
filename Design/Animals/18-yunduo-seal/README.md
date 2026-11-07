# 18 云朵 · 海豹（Yunduo）

**角色**：加载 / 等待。翻页、导入、生词本刷新时出现。

**配色**：seal `#BFD3E0`、sealDark `#9FB9CA`、cream `#F7FBFD`、描边 `#3A2A22`。

**比例**：身体 `(512,640) rx/ry 244×228`（几乎就是个球）；肚子 `164 × 150`；侧鳍从 `(300,620)` 向外下；尾鳍从 `y = 830` 向下张开，**必须与身体重叠**（v1.0 太小像掉的零件）；描边 11px。

**文件**：`source/yunduo.svg`、`render/yunduo-master.png`、`Assets.xcassets/Animals/Yunduo.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/18-yunduo-seal/source/yunduo.svg `
  --name Yunduo --display "云朵" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「马上好」「正在整理」「等一秒」。

**待补**：表情三连、拍手 idle、水泡贴纸。