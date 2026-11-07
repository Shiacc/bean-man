# 14 啊呜 · 小恐龙（Awu）

**角色**：成就。解锁时想「啊呜」一口吃掉整个成就。

**配色**：dino `#6BA292`、dark `#528477`、belly `#E8F1EC`、spike `#F2C14E`、描边 `#3A2A22`。

**比例**：头 `(512,500) r 242×212`；头顶三片黄刺 apex `y ≈ 254`；背侧三片刺在**身体轮廓之外**（底边埋进身体，v1.0 被身体挡住只剩一点）；尾巴从 `(668,820)` 向右下伸出；描边 11px。

**文件**：`source/awu.svg`、`render/awu-master.png`、`Assets.xcassets/Animals/Awu.imageset`。

**重新生成**

```powershell
$env:PYTHONIOENCODING="utf-8"
python Scripts/animal_pipeline.py sheet `
  --svg Design/Animals/14-awu-dino/source/awu.svg `
  --name Awu --display "啊呜" `
  --out BeanMan/Resources/Assets.xcassets/Animals
```

**文案**：「解锁了」「第 \(n) 个成就」「啊呜一口」。

**待补**：表情三连、咬一口动作、闪光贴纸。