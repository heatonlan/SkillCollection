# SkillCollection

可复用的 Claude Code 技能集合。每个技能包含：

- `SKILL.md` — Claude Code 标准技能文件（YAML frontmatter + 指令），可直接放入 `~/.claude/skills/` 使用
- `README.md` — 面向人类的详细操作手册

## 使用方式

将技能目录复制到 `~/.claude/skills/` 即可在 Claude Code 中通过 `/技能名` 调用：

```bash
cp -r cloudflare-tunnel ~/.claude/skills/
cp -r verify-viewer ~/.claude/skills/
```

## 技能列表

| 技能 | 说明 |
|------|------|
| [cloudflare-tunnel](./cloudflare-tunnel/) | 用 Cloudflare Tunnel 将本地服务暴露到公网 |
| [verify-viewer](./verify-viewer/) | 通用项目验证框架，统一执行验证并展示结果 |
| [nxbuild](./nxbuild/) | NeoX 引擎构建 CLI，支持 Windows/Android/Web/Minigame |
