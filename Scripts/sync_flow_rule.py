"""把「Flow ≠ 原型」这条规则写进四份规则正文（幂等）。

- 三份英文副本：插在 `## 5. Reactions` 与 `## 6. Dead-end audit` 之间，标题 `## 5b. Flows`。
- 中文版：插在 `### 6.4 断头审计` 之后、`### 6.6 遗缺审计` 之前，标题 `### 6.5 Flow（放映起点）`。
- 每份都在「验收」清单里加一条（若该文件有对应小节）。
"""

from __future__ import annotations

import sys
from pathlib import Path

EN_BLOCK = """## 5b. Flows (presentation entry points)

A **flow** is not a prototype. Reactions on nodes make the prototype; a flow is a *named entry
point* - one starting frame id plus a name - that Presentation lists and plays from. The first
flow is what the play button opens; a page with zero flows opens nowhere, which reads as "the
prototype is broken / nothing is clickable".

- `update_flows({ pageId, flows: [{ nodeId, name }], remove, order })`. Flows are addressed by the
  starting frame's `nodeId`, never by name; `order` moves them to the front and the first one
  becomes the default.
- `{ ok: true }` is not proof. Read back with `get_pages` (it lists every page's flows) or the
  `update_flows` response (it returns the full list). Measured 2026-11-08: an `update_flows` that
  returned `ok` left `flowStartingPoints` empty, and the page played nowhere.
- Verify reactions with **`get_reactions`**, never `get_node`: `get_node` serialises children and
  geometry but **not** `reactions`, so a `get_node`-based check reports "no reactions" on a file
  that is wired correctly.
- A flow can only start on a visible top-level frame / component / instance - directly on the page
  or inside a section. A hidden, grouped or frame-nested starting frame silently drops out of the
  list and cannot be read, renamed or removed until it is top-level again.
- Repeated wiring calls append auto-named `Flow 2`, `Flow 3`, ... for frames that already carry
  reactions. After every wiring pass run `remove: [extra ids]` + `order: [keep ...]`.
- New screens inherit nothing: re-run the wiring pass, then assert `linked == screens` from
  `get_reactions` and `flows.length` from `get_pages`.

"""

ZH_BLOCK = """### 6.5 Flow（放映起点）与原型不是一回事

- **原型** = 节点上的 reactions（触发 + 动作 + 转场），决定「点这里去哪」。
- **Flow** = 一条**命名的放映起点**（起点画框 nodeId + 名字），Figma 的 Presentation 左侧列出来，第一条是默认，点播放就从它开始。**没有 Flow 的页面，放映没有入口**，表现就是「点不动、连不起来」。
- 写入：`update_flows({ pageId, flows: [{ nodeId, name }], remove, order })`；flow 只按**起点 nodeId** 定位，名字独立于画框名；`order` 把它们移到最前，第一条即默认。
- **`{ ok: true }` 不等于已写入**。必须回读：`get_pages` 会列出每个页面的 flows，`update_flows` 的返回也是写完后的完整列表。（2026-11-08 实测：一次返回 ok 的 `update_flows` 之后 `flowStartingPoints` 仍为空，页面放映无处可去。）
- **读 reactions 必须用 `get_reactions`，不能用 `get_node`**：`get_node` 只序列化子节点与几何，**不返回 `reactions`**，用它检查会把「已连好的文件」误判成「没连线」。
- Flow 的起点必须是**可见的顶层** frame / component / instance（直接在页面上或在 section 里）。被隐藏、被 group、或被嵌进另一个 frame 的起点会**静默消失**，在它恢复顶层可见之前读不到、改不了、删不掉。
- 反复调用会为「已挂过 reaction 的画框」自动追加 `Flow 2`、`Flow 3`…；每轮连线后要用 `remove: [多余 id]` + `order: [保留 id]` 清一遍。
- 新增屏幕不会继承任何连线：重连之后要断言 `get_reactions` 的 `linked == 屏数`、`get_pages` 的 `flows.length` 符合预期。

"""

TARGETS = [
    Path(r"C:\Users\lenovo\.dsh\skills\figwright-rules\SKILL.md"),
    Path(r"C:\Users\lenovo\.claude\skills\figwright-rules\SKILL.md"),
    Path("/mnt/c/Users/lenovo/.dsh/skills/figwright-rules/SKILL.md"),
    Path("/mnt/c/Users/lenovo/.claude/skills/figwright-rules/SKILL.md"),
    Path("/home/test/repo/1_claude/skill/mcp/figwright/skills/figwright-rules/SKILL.md"),
]
ZH = Path("/mnt/d/repos/time/docs/设计/figwright 使用规则.md")

EN_ANCHOR = "## 6. Dead-end audit"
ZH_ANCHOR = "### 6.6 遗缺审计"


def insert_before(text: str, anchor: str, block: str, marker: str) -> tuple[str, bool]:
    if marker in text:
        return text, False
    idx = text.find(anchor)
    if idx < 0:
        return text, False
    return text[:idx] + block + text[idx:], True


def main() -> int:
    changed = []
    for path in TARGETS:
        if not path.exists():
            print("miss", path)
            continue
        text = path.read_text(encoding="utf-8")
        new, did = insert_before(text, EN_ANCHOR, EN_BLOCK, "## 5b. Flows")
        if did:
            path.write_text(new, encoding="utf-8")
            changed.append(str(path))

    if ZH.exists():
        text = ZH.read_text(encoding="utf-8")
        new, did = insert_before(text, ZH_ANCHOR, ZH_BLOCK, "### 6.5 Flow")
        if did:
            ZH.write_text(new, encoding="utf-8")
            changed.append(str(ZH))

    print("changed:", len(changed))
    for c in changed:
        print("  ", c)
    return 0


if __name__ == "__main__":
    sys.exit(main())