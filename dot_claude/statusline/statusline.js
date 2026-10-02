// p10k 風格 statusline（rainbow / lean / classic）。所有選項見 config.json（缺的欄位用下面的 DEFAULTS）。
// 色票預設讀自 Windows Terminal 目前的 colorScheme，讀不到就用 Vesper 備援值。
// bun statusline.js --print-config [preset]  印出某個 preset 合併後的完整設定
const fs = require("fs"), path = require("path"), os = require("os");
const { execFileSync } = require("child_process");

const DEFAULTS = {
  preset: "vesper", // vesper | lean | rainbow | classic，見下方 PRESETS；config.json 的欄位再疊在 preset 上
  style: "lean", // rainbow | lean | classic | all（all＝三種疊成三行，只拿來比較）
  icons: true, // false＝全部拿掉 Nerd Font 圖示
  scheme: "auto", // auto＝Windows Terminal 預設 profile 的配色；builtin＝內建 Vesper；或直接指定配色名稱
  palette: {}, // 覆寫色票，例如 { "brightGreen": "#99FFE4" }
  margin: 4, // 右側保留的格數（尺規實測：COLUMNS-4 剛好貼邊）
  gap: 1, // lean：區塊之間的空格數
  thresholds: { warn: 60, crit: 85 }, // context／用量百分比的警示門檻
  colors: { warn: "brightYellow", crit: "brightRed", dim: "brightBlack", ink: "black" },
  ground: { mid: "#2A2A2A", low: "#1E1E1E" }, // rainbow／classic 資訊區塊的底色
  // 版面：每個物件是一行；left 靠左、right 靠右，區塊照陣列順序排，同一個區塊可以放在任何一行任何位置
  // 窄視窗放不下時，從每一行最後面開始丟（先右側由右往左，再左側由右往左，至少留一個），所以不重要的放後面
  // 區塊：model cwd git context cache usage cost session dirs lines duration clock；沒有資料的區塊會自動略過
  layout: [
    // 單行：左＝位置（cwd、額外目錄）與程式碼狀態（git、行數）；右＝模型與額度、花費與快取、時間、session 名稱
    { left: ["cwd", "dirs", "git", "lines"], right: ["model", "context", "cache", "usage", "cost", "clock"] },
  ],
  blocks: {
    // show 顯示；fade 顏色濃度 0~1（1＝原色，越小越接近終端機背景色）；icon true/false/自訂字元；lead 區塊前的短語（只有 lean 用）
    // color 色票名稱或 #rrggbb；fill rainbow 是否用 color 當底色；ground 資訊底色 mid/low
    // effort：顯示格式（{level} 會換成 high 等；空字串＝不顯示，例如 "({level})"）；effortDim＝用淡色，不靠標點區分
    model: { show: true, fade: 1, icon: true, lead: "", color: "brightGreen", fill: true, ground: "mid", effort: "{level}", effortDim: true },
    cwd: { show: true, fade: 1, icon: false, lead: "", color: "blue", fill: true, ground: "mid", depth: 3 },
    git: { show: true, fade: 1, icon: false, lead: "", color: "green", dirtyColor: "brightYellow", fill: true, ground: "mid" },
    context: { show: true, fade: 1, icon: true, lead: "", color: "purple", fill: false, ground: "mid" },
    cache: { show: true, fade: 1, icon: true, lead: "", color: "brightBlue", fill: false, ground: "low", misses: true }, // misses：有 miss 時多顯示次數（警示色）
    usage: { show: true, fade: 1, icon: true, lead: "", color: "green", fill: false, ground: "mid", sep: " · ", reset: true }, // reset：顯示距離重置的剩餘時間（與數值同色的淡色）
    cost: { show: true, fade: 1, icon: true, lead: "", color: "yellow", fill: false, ground: "low" },
    session: { show: true, fade: 1, icon: false, lead: "", color: "brightPurple", fill: false, ground: "mid", maxLen: 24 }, // maxLen：最多佔幾格（中文算 2 格），超過截斷
    dirs: { show: true, fade: 1, icon: false, lead: "", color: "brightBlack", fill: false, ground: "low" }, // /add-dir 加入的目錄數
    lines: { show: true, fade: 1, icon: false, lead: "·", color: "green", addedColor: "green", removedColor: "red", fill: false, ground: "mid" }, // git 未 commit 的行數變更（git diff --numstat HEAD：已暫存＋未暫存）；不在儲存庫或沒有變更時不顯示
    duration: { show: true, fade: 1, icon: true, lead: "", color: "white", fill: false, ground: "low" }, // 本 session 時長
    clock: { show: true, fade: 1, icon: true, lead: "", color: "white", fill: false, ground: "mid" }, // 現在時間 HH:MM
  },
};
// preset：一整套設定，疊在 DEFAULTS 上。vesper＝DEFAULTS 本身（這份腳本調出來的樣子）；
// lean / rainbow / classic＝p10k 原版三種風格的樣子（目錄與分支有圖示、連接詞 on / took / at），顏色仍取自色票
const p10k = (style, blocks) => ({
  style,
  layout: [{ left: ["cwd", "git"], right: ["model", "context", "usage", "cost", "duration", "clock"] }],
  blocks: {
    cwd: { icon: true },
    git: { icon: true, lead: "on" },
    duration: { lead: "took", color: "yellow" },
    clock: { lead: "at" },
    ...blocks,
  },
});
const PRESETS = {
  vesper: {},
  lean: p10k("lean"),
  classic: p10k("classic"),
  // rainbow：每塊都用自己的顏色當底色（usage 內含多色文字，維持灰底）
  rainbow: p10k("rainbow", {
    cwd: { icon: true, fill: true },
    git: { icon: true, fill: true },
    context: { fill: true },
    cost: { fill: true, color: "brightPurple" },
    duration: { fill: true, color: "yellow" },
    clock: { fill: true, color: "white" },
  }),
};
const GLYPH = { session: "", dirs: "", lines: "", duration: "", clock: "", model: "", cwd: "", git: "", context: "", cache: "", usage: "", cost: "", fast: "" };
const ARROW = "", ARROW_R = "", THIN = "", THIN_R = "";


// ---------- 設定 ----------
const isObj = (x) => x && typeof x === "object" && !Array.isArray(x);
const merge = (a, b) =>
  b === undefined ? a : isObj(a) && isObj(b) ? Object.fromEntries([...new Set([...Object.keys(a), ...Object.keys(b)])].map((k) => [k, merge(a[k], b[k])])) : b;

// DEFAULTS → preset → config.json
function withPreset(user) {
  const name = user.preset ?? DEFAULTS.preset;
  if (!PRESETS[name]) throw new Error(`unknown preset "${name}" (${Object.keys(PRESETS).join("|")})`);
  return merge(merge(DEFAULTS, PRESETS[name]), user);
}

function loadConfig() {
  const p = process.env.CC_STATUSLINE_CONFIG ?? path.join(__dirname, "config.json");
  if (!fs.existsSync(p)) return withPreset({});
  let user;
  try { user = JSON.parse(fs.readFileSync(p, "utf8").replace(/^﻿/, "")); }
  catch (e) { throw new Error(`config.json: ${e.message}`); }
  return withPreset(user);
}

if (process.argv[2] === "--print-config") {
  console.log(JSON.stringify(withPreset({ preset: process.argv[3] }), null, 2));
  process.exit(0);
}

// ---------- 色票 ----------
const VESPER = {
  black: "#101010", white: "#A0A0A0", brightBlack: "#7E7E7E", brightWhite: "#FFFFFF",
  red: "#F5A191", green: "#90B99F", yellow: "#E6B99D", blue: "#ACA1CF", purple: "#E29ECA",
  brightRed: "#FF8080", brightGreen: "#99FFE4", brightYellow: "#FFC799", brightBlue: "#B9AEDA", brightPurple: "#ECAAD6",
};
function loadPalette(cfg) {
  let scheme = {};
  if (cfg.scheme !== "builtin") {
    try {
      const p = path.join(process.env.LOCALAPPDATA, "Packages", "Microsoft.WindowsTerminal_8wekyb3d8bbwe", "LocalState", "settings.json");
      const j = JSON.parse(fs.readFileSync(p, "utf8").replace(/^\s*\/\/.*$/gm, "").replace(/,(\s*[}\]])/g, "$1"));
      const n = j.profiles?.defaults?.colorScheme;
      const name = cfg.scheme === "auto" ? (typeof n === "string" ? n : n?.dark) : cfg.scheme;
      scheme = (j.schemes || []).find((s) => s.name === name) ?? {};
      if (cfg.scheme !== "auto" && !scheme.name) throw new Error(`scheme "${cfg.scheme}" not found in Windows Terminal`);
    } catch (e) { if (cfg.scheme !== "auto") throw e; }
  }
  return { ...VESPER, ...scheme, ...cfg.palette };
}

// ---------- ANSI ----------
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)).join(";");
// 把顏色 a 往顏色 b 混合：t=1 → a，t=0 → b
const mix = (a, b, t) =>
  "#" + [1, 3, 5].map((i) => { const x = parseInt(a.slice(i, i + 2), 16), y = parseInt(b.slice(i, i + 2), 16); return Math.round(y + (x - y) * t).toString(16).padStart(2, "0"); }).join("");
const fg = (h) => `\x1b[38;2;${rgb(h)}m`, bg = (h) => `\x1b[48;2;${rgb(h)}m`;
const RESET = "\x1b[0m", BOLD = "\x1b[1m", FAINT = "\x1b[2m", NOBOLD = "\x1b[22m"; // 22 同時關掉 bold 與 faint
const width = (s) => Bun.stringWidth(s); // ANSI 不計；中文算 2 格，圖示與箭頭算 1 格（尺規實測）

// ---------- 資料 ----------
const k = (n) => (n >= 1e6 ? +(n / 1e6).toFixed(1) + "M" : n >= 1e3 ? Math.round(n / 1e3) + "k" : String(n));
// 秒數 → 2h13m / 13m / 3d4h / 45s
const dur = (s) => {
  s = Math.max(0, Math.round(s));
  const dd = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
  return dd ? `${dd}d${h}h` : h ? `${h}h${m}m` : m ? `${m}m` : `${s}s`;
};
// 截到最多 max 格，超過的以 … 結尾
const clip = (s, max) => {
  if (width(s) <= max) return s;
  let out = "", w = 0;
  for (const ch of s) { if (w + width(ch) > max - 1) break; out += ch; w += width(ch); }
  return out + "…";
};

function shortDir(dir, depth) {
  const home = os.homedir();
  const d = dir.startsWith(home) ? "~" + dir.slice(home.length) : dir;
  const parts = d.split(/[\\/]/).filter(Boolean);
  return parts.length > depth ? "…/" + parts.slice(-(depth - 1)).join("/") : parts.join("/") || d;
}

function git(cwd) {
  let out;
  try { out = execFileSync("git", ["status", "--porcelain=v2", "--branch"], { cwd, encoding: "utf8", timeout: 1500, stdio: ["ignore", "pipe", "ignore"] }); }
  catch { return null; }
  const g = { branch: "", ahead: 0, behind: 0, staged: 0, unstaged: 0, untracked: 0, conflict: 0 };
  for (const l of out.split("\n")) {
    if (l.startsWith("# branch.head ")) g.branch = l.slice(14);
    else if (l.startsWith("# branch.ab ")) [, g.ahead, g.behind] = l.match(/\+(\d+) -(\d+)/).map(Number);
    else if (l[0] === "1" || l[0] === "2") { if (l[2] !== ".") g.staged++; if (l[3] !== ".") g.unstaged++; }
    else if (l[0] === "?") g.untracked++;
    else if (l[0] === "u") g.conflict++;
  }
  return g;
}

// 未 commit 的行數變更（已暫存＋未暫存，相對於 HEAD）；不是 git 儲存庫、沒有任何 commit 或沒有變更時回傳 null
function gitLines(cwd) {
  let out;
  try { out = execFileSync("git", ["diff", "--numstat", "HEAD"], { cwd, encoding: "utf8", timeout: 1500, stdio: ["ignore", "pipe", "ignore"] }); }
  catch { return null; }
  let a = 0, r = 0;
  for (const l of out.split("\n")) {
    const m = l.match(/^(\d+)\t(\d+)\t/); // 二進位檔是 "-\t-\t"，略過
    if (m) { a += +m[1]; r += +m[2]; }
  }
  return a || r ? { a, r } : null;
}

function main() {
  const cfg = loadConfig();
  const P = loadPalette(cfg);
  const HEX = /^#[0-9a-f]{6}$/i;
  const col = (c) => { const v = P[c] ?? c; if (typeof v !== "string" || !HEX.test(v)) throw new Error(`unknown color "${c}"`); return v; };
  const ground = { mid: col(cfg.ground.mid), low: col(cfg.ground.low) };
  const ink = col(cfg.colors.ink), dim = col(cfg.colors.dim);
  const alert = (pct, base) => (pct >= cfg.thresholds.crit ? col(cfg.colors.crit) : pct >= cfg.thresholds.warn ? col(cfg.colors.warn) : base);
  const ic = (id, b) => (!cfg.icons || b.icon === false ? "" : (typeof b.icon === "string" ? b.icon : GLYPH[id]) + " ");

  const d = JSON.parse(fs.readFileSync(0, "utf8"));
  const cwd = d.workspace?.current_dir ?? d.cwd ?? process.cwd();

  // 每個區塊回傳 { text, color }（或 null＝沒資料），文字內可以夾自己的顏色碼
  const builders = {
    model: (b) => {
      const lvl = d.effort?.level;
      const effort = b.effort && lvl ? ` ${b.effortDim ? FAINT : ""}${b.effort.replace("{level}", lvl)}${b.effortDim ? NOBOLD : ""}` : "";
      const fast = d.fast_mode ? (ic("model", b) ? ` ${GLYPH.fast}` : " fast") : "";
      return { text: `${BOLD}${ic("model", b)}${d.model?.display_name ?? "?"}${NOBOLD}${effort}${fast}`, color: col(b.color) };
    },
    cwd: (b) => ({ text: `${ic("cwd", b)}${shortDir(cwd, b.depth)}`, color: col(b.color) }),
    git: (b) => {
      const g = git(cwd);
      if (!g) return null;
      const dirty = g.staged || g.unstaged || g.untracked || g.conflict;
      const bits = [
        g.conflict && `~${g.conflict}`, g.staged && `+${g.staged}`, g.unstaged && `!${g.unstaged}`, g.untracked && `?${g.untracked}`,
        g.ahead && `⇡${g.ahead}`, g.behind && `⇣${g.behind}`,
      ].filter(Boolean).join(" ");
      return { text: `${ic("git", b)}${g.branch}${bits ? " " + bits : ""}`, color: col(dirty ? b.dirtyColor : b.color) };
    },
    context: (b) => {
      const w = d.context_window;
      if (w?.used_percentage == null) return null;
      const cu = w.current_usage;
      const used = cu ? cu.input_tokens + cu.cache_creation_input_tokens + cu.cache_read_input_tokens : w.total_input_tokens;
      return { text: `${ic("context", b)}${k(used)}/${k(w.context_window_size)} ${w.used_percentage}%`, color: alert(w.used_percentage, col(b.color)) };
    },
    cache: (b) => {
      const pc = d.prompt_cache;
      if (!pc?.caching_observed) return null;
      const left = Math.max(0, Math.round((pc.expires_at - Date.now() / 1000) / 60));
      const hit = Math.round(pc.hit_ratio * 100);
      const miss = b.misses && pc.misses > 0 ? ` ${FAINT}${pc.misses} miss${NOBOLD}` : "";
      return { text: `${ic("cache", b)}${hit}%${pc.warm ? ` ${left}m` : " cold"}${miss}`, color: pc.warm ? col(b.color) : col(cfg.colors.crit) };
    },
    usage: (b) => {
      const rl = d.rate_limits;
      if (!rl?.five_hour && !rl?.seven_day) return null;
      const f = (label, r) => {
        if (!r) return null;
        const secs = r.resets_at - Date.now() / 1000;
        const reset = b.reset && secs > 0 ? ` ${FAINT}${dur(secs)}${NOBOLD}` : "";
        return `${fg(col(b.color))}${label} ${fg(alert(r.used_percentage, col(b.color)))}${Math.round(r.used_percentage)}%${reset}`;
      };
      const body = [f("5h", rl.five_hour), f("7d", rl.seven_day)].filter(Boolean).join(`${fg(dim)}${b.sep}`);
      return { text: `${ic("usage", b)}${body}`, color: col(b.color) };
    },
    cost: (b) => (d.cost?.total_cost_usd == null ? null : { text: `${ic("cost", b)}$${d.cost.total_cost_usd.toFixed(2)}`, color: col(b.color) }),
    session: (b) => (d.session_name ? { text: `${ic("session", b)}${clip(d.session_name, b.maxLen)}`, color: col(b.color) } : null),
    dirs: (b) => {
      const n = d.workspace?.added_dirs?.length ?? 0;
      return n ? { text: `${ic("dirs", b)}+${n} dir${n > 1 ? "s" : ""}`, color: col(b.color) } : null;
    },
    lines: (b) => {
      const g = gitLines(cwd);
      return g ? { text: `${ic("lines", b)}${fg(col(b.addedColor))}+${g.a} ${fg(col(b.removedColor))}-${g.r}`, color: col(b.color) } : null;
    },
    duration: (b) => (d.cost?.total_duration_ms == null ? null : { text: `${ic("duration", b)}${dur(d.cost.total_duration_ms / 1000)}`, color: col(b.color) }),
    clock: (b) => {
      const t = new Date();
      return { text: `${ic("clock", b)}${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`, color: col(b.color) };
    },
  };

  // 區塊物件 { bg, fg, tone, text, lead }；rainbow 用 bg/fg，lean／classic 用 tone。每個區塊只算一次（git 不會重複呼叫）
  const memo = {};
  const segOf = (id) => {
    if (id in memo) return memo[id];
    const b = cfg.blocks[id];
    if (!b || !builders[id]) throw new Error(`unknown block "${id}" in layout`);
    const r = b.show ? builders[id](b) : null;
    if (!r) return (memo[id] = null);
    const c = b.fade < 1 ? mix(r.color, col(P.background ? "background" : "black"), b.fade) : r.color;
    return (memo[id] = { bg: b.fill ? c : ground[b.ground], fg: b.fill ? ink : c, tone: c, text: r.text, lead: b.lead });
  };

  // lean：每塊前面可帶一個暗灰短語（on / ctx…），靠短語分隔區塊
  const leanBlock = (s) => (s.lead ? `${fg(dim)}${s.lead}${RESET} ` : "") + `${fg(s.tone)}${s.text}${RESET}`;
  const gapStr = " ".repeat(cfg.gap);

  const RENDERERS = {
    // 每塊各自底色，powerline 箭頭相接；右側用反向箭頭
    rainbow: {
      left: (ss) =>
        ss.map((s, i) => {
          const next = ss[i + 1];
          return `${bg(s.bg)}${fg(s.fg)} ${s.text} ` + (next ? `${bg(next.bg)}${fg(s.bg)}${ARROW}` : `${RESET}${fg(s.bg)}${ARROW}`);
        }).join("") + RESET,
      right: (ss) =>
        ss.map((s, i) => {
          const prev = ss[i - 1];
          return (prev ? `${bg(prev.bg)}${fg(s.bg)}` : `${RESET}${fg(s.bg)}`) + ARROW_R + `${bg(s.bg)}${fg(s.fg)} ${s.text} `;
        }).join("") + RESET,
    },
    // 無底色，只有彩色文字
    lean: {
      left: (ss) => " " + ss.map(leanBlock).join(gapStr),
      right: (ss) => ss.map(leanBlock).join(gapStr) + " ",
    },
    // 整條單一底色，區塊間用 powerline 細箭頭，兩端用實心箭頭收尾
    classic: {
      left: (ss) => `${bg(ground.mid)}` + ss.map((s) => `${s.lead ? fg(dim) + " " + s.lead : ""}${fg(s.tone)} ${s.text} `).join(`${fg(dim)}${THIN}`) + `${RESET}${fg(ground.mid)}${ARROW}${RESET}`,
      right: (ss) => `${fg(ground.mid)}${ARROW_R}${bg(ground.mid)}` + ss.map((s) => `${s.lead ? fg(dim) + " " + s.lead : ""}${fg(s.tone)} ${s.text} `).join(`${fg(dim)}${THIN_R}`) + RESET,
    },
  };

  const cols = Number(process.env.COLUMNS);
  function compose(name, line) {
    const R = RENDERERS[name];
    if (!R) throw new Error(`unknown style "${name}" (rainbow|lean|classic|all)`);
    let left = (line.left ?? []).map(segOf).filter(Boolean);
    let right = (line.right ?? []).map(segOf).filter(Boolean);
    const draw = () => [left.length ? R.left(left) : "", right.length ? R.right(right) : ""];
    if (cols) {
      // 放不下就從最後面開始丟：先右側由右往左，右側丟完再丟左側最後一個；至少留一個。左右之間至少留 1 格
      const need = () => { const [l, r] = draw(); return width(l) + (r ? width(r) + 1 : 0); };
      while (need() > cols - cfg.margin && left.length + right.length > 1) (right.length ? right : left).pop();
    }
    const [l, r] = draw();
    if (!r) return l;
    return l + (cols ? " ".repeat(Math.max(cols - cfg.margin - width(l) - width(r), 1)) : " ") + r;
  }
  const styles = cfg.style === "all" ? Object.keys(RENDERERS) : [cfg.style];
  if (!Array.isArray(cfg.layout)) throw new Error("layout must be an array of lines");
  return styles.flatMap((st) => cfg.layout.map((line) => compose(st, line))).filter((l) => l.trim()).join("\n");
}

// 設定寫錯時直接把原因顯示在 statusline 上，而不是整條變空白
try { process.stdout.write(main()); } catch (e) { process.stdout.write(`statusline: ${e.message}`); }
