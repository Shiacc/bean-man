# 20 小柚 · 狐狸（Youzi）

**角色**：设置 / 偏好。最聪明的一只，负责「你自己定」。

**配色**：fur `#D97742`、furDark `#B85E30`、cream `#FFF4EA`、耳尖 `#3A2A22`、描边 `#3A2A22`。

**比例**：头 `(512,510) r 240×206`；大尖耳 apex `y ≈ 178`，**耳尖要单独一块深色三角**；胸腹奶油椭圆 `104 × 98`，`(512,772)`（比身体小一圈，画大了会溢出身体轮廓）；尾巴从 `(640,760)` 向右下，尾尖白色；描边 11px。

**文件**：`source/youzi.svg`、`render/youzi-master.png`、`Assets.xcassets/Animals/Youzi.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/20-youzi-fox/source/youzi.svg `
  --name Youzi --display "小柚" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「都在这里改」「每天几个？」「随你」。

**待补**：表情三连、尾巴扫 idle、齿轮贴纸。