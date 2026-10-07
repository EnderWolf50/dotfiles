// p10k 風格 statusline（rainbow / lean / classic）。所有選項見 config.json（缺的欄位用下面的 DEFAULTS）。
// preset 管版面，theme 管顏色，兩者各選各的。theme＝內建 p10k 或 config.json 的 themes 裡的名稱（chezmoi 寫入 vesper）。
// bun statusline.js --print-config [preset]  印出某個 preset 合併後的完整設定
// 每次刷新都整支重跑；要跑 git 的區塊（git、lines）照各自的 ttl 快取，見下方「快取」
const fs = require("fs"), path = require("path"), os = require("os");

const DEFAULTS = {
  preset: "vesper", // vesper | lean | rainbow | classic，見下方 PRESETS；config.json 的欄位再疊在 preset 上
  style: "lean", // rainbow | lean | classic
  icons: true, // false＝全部拿掉 Nerd Font 圖示
  theme: "p10k", // 色票名稱：p10k（內建）或 themes 裡的名稱；缺的色名用 p10k 補
  themes: {}, // 額外的色票，例如 { "vesper": { "brightGreen": "#99FFE4", ... } }
  margin: 4, // 右側保留的格數（尺規實測：COLUMNS-4 剛好貼邊）
  gap: 1, // lean：區塊之間的空格數
  thresholds: { warn: 60, crit: 85 }, // context／用量百分比的警示門檻
  colors: { warn: "brightYellow", crit: "brightRed", dim: "brightBlack", ink: "black" },
  ground: { mid: "#2A2A2A", low: "#1E1E1E" }, // rainbow／classic 資訊區塊的底色
  // 版面：每個物件是一行；left 靠左、right 靠右，區塊照陣列順序排，同一個區塊可以放在任何一行任何位置
  // 窄視窗放不下時，從每一行最後面開始丟（先右側由右往左，再左側由右往左，至少留一個），所以不重要的放後面
  // 區塊：model cwd git context cache usage cost dirs lines duration clock；沒有資料的區塊會自動略過
  layout: [
    // 單行：左＝位置（cwd、額外目錄）與程式碼狀態（git、行數）；右＝模型與額度、花費與快取、時間
    { left: ["cwd", "dirs", "git", "lines"], right: ["model", "context", "cache", "usage", "cost", "clock"] },
  ],
  blocks: {
    // show 顯示；icon true/false/自訂字元；lead 區塊前的短語（只有 lean 用）
    // color 色票名稱或 #rrggbb；fill rainbow 是否用 color 當底色；ground 資訊底色 mid/low
    // effort：顯示格式（{level} 會換成 high 等；空字串＝不顯示，例如 "({level})"），用淡色顯示
    model: { show: true, icon: true, lead: "", color: "brightGreen", fill: true, ground: "mid", effort: "{level}" },
    cwd: { show: true, icon: false, lead: "", color: "blue", fill: true, ground: "mid", depth: 3 },
    // ttl：快取秒數（0＝每次重跑 git）。過期時先顯示舊值、背景更新；對話有新訊息時一律重跑
    git: { show: true, icon: false, lead: "", color: "green", dirtyColor: "brightYellow", fill: true, ground: "mid", ttl: 3 },
    context: { show: true, icon: true, lead: "", color: "purple", fill: false, ground: "mid" },
    cache: { show: true, icon: true, lead: "", color: "brightBlue", fill: false, ground: "low" }, // 有 miss 時多顯示次數（淡色）
    usage: { show: true, icon: true, lead: "", color: "green", fill: false, ground: "mid", sep: " · " }, // 附距離重置的剩餘時間（淡色）
    cost: { show: true, icon: true, lead: "", color: "yellow", fill: false, ground: "low" },
    dirs: { show: true, icon: false, lead: "", color: "brightBlack", fill: false, ground: "low" }, // /add-dir 加入的目錄數
    lines: { show: true, icon: false, lead: "·", color: "green", addedColor: "green", removedColor: "red", fill: false, ground: "mid", ttl: 10 }, // git 未 commit 的行數變更（git diff --numstat HEAD：已暫存＋未暫存）；不在儲存庫或沒有變更時不顯示
    duration: { show: true, icon: true, lead: "", color: "white", fill: false, ground: "low" }, // 本 session 時長
    clock: { show: true, icon: true, lead: "", color: "white", fill: false, ground: "mid" }, // 現在時間 HH:MM
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
const GLYPH = { dirs: "", lines: "", duration: "", clock: "", model: "", cwd: "", git: "", context: "", cache: "", usage: "", cost: "", fast: "" };
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
  const p = path.join(__dirname, "config.json");
  return withPreset(fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8").replace(/^﻿/, "")) : {});
}

if (process.argv[2] === "--print-config") {
  console.log(JSON.stringify(withPreset({ preset: process.argv[3] }), null, 2));
  process.exit(0);
}

// ---------- 色票 ----------
// p10k lean 各區段的預設 256 色（括號內是色號與 p10k 用在哪）
const P10K = {
  black: "#000000", brightWhite: "#E4E4E4", // 0、254
  blue: "#0087AF", // 31 dir
  green: "#5FD700", brightGreen: "#5FAF00", // 76 vcs clean、70 status ok
  brightYellow: "#D7AF00", // 178 vcs modified
  brightBlue: "#00AFFF", // 39 vcs untracked、dir anchor
  white: "#5F8787", // 66 time
  yellow: "#87875F", // 101 command_execution_time
  brightBlack: "#6C6C6C", // 242 分隔線、連接詞
  red: "#D70000", brightRed: "#FF0000", // 160 status error、196 prompt error
  purple: "#D7AF87", brightPurple: "#8787AF", // 180 context、103 dir shortened
};

// ---------- ANSI ----------
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)).join(";");
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

function shortDir(dir, depth) {
  const home = os.homedir();
  const d = dir.startsWith(home) ? "~" + dir.slice(home.length) : dir;
  const parts = d.split(/[\\/]/).filter(Boolean);
  return parts.length > depth ? "…/" + parts.slice(-(depth - 1)).join("/") : parts.join("/") || d;
}

// 跑 git，失敗（不是儲存庫、逾時、cwd 不存在）回傳 null
// --no-optional-locks：status / diff 不寫 index.lock。逾時只殺得到 Windows 的 git 外層程式，
// 留下的 git.exe 會一直佔著鎖，讓同一個 repo 的 commit、pull 失敗
function runGit(cwd, args) {
  try {
    const r = Bun.spawnSync(["git", "--no-optional-locks", ...args], { cwd, stdin: "ignore", stderr: "ignore", timeout: 1500, windowsHide: true });
    return r.success ? r.stdout.toString() : null;
  } catch { return null; }
}

function git(cwd) {
  const out = runGit(cwd, ["status", "--porcelain=v2", "--branch"]);
  if (out == null) return null;
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
  const out = runGit(cwd, ["diff", "--numstat", "HEAD"]);
  if (out == null) return null;
  let a = 0, r = 0;
  for (const l of out.split("\n")) {
    const m = l.match(/^(\d+)\t(\d+)\t/); // 二進位檔是 "-\t-\t"，略過
    if (m) { a += +m[1]; r += +m[2]; }
  }
  return a || r ? { a, r } : null;
}

// ---------- 快取 ----------
// 每個 (session, 區塊, cwd) 一個檔：{ t 算出的時間, epoch, v 結果, pending 背景更新開始的時間 }
// - ttl 內：直接用 v
// - 過期：先回傳舊的 v，另開背景 process（--refresh）重算寫回，下次刷新就是新的；statusline 不用等 git
// - epoch 變了（對話有新訊息，例如剛跑完 git commit）：同步重算，不顯示舊值
const FETCH = { git, lines: gitLines };
const CACHE_DIR = path.join(os.tmpdir(), "claude-statusline");
const PENDING_MS = 5000; // 背景更新超過這麼久沒寫回，就當它死了，再開一個
const readCache = (f) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return null; } };
function writeCache(f, e) {
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    const tmp = `${f}.${process.pid}`;
    fs.writeFileSync(tmp, JSON.stringify(e));
    fs.renameSync(tmp, f); // 整檔替換，讀的一方不會讀到寫一半的內容
  } catch {}
}

function cached(id, ttl, cwd, ctx) {
  if (!ttl) return FETCH[id](cwd);
  const f = path.join(CACHE_DIR, Bun.hash([ctx.session, id, cwd].join("\0")).toString(36) + ".json");
  const e = readCache(f), now = Date.now();
  if (e && e.epoch === ctx.epoch) {
    if (now - e.t < ttl * 1000) return e.v;
    if (!(now - (e.pending ?? 0) < PENDING_MS)) {
      writeCache(f, { ...e, pending: now });
      try {
        Bun.spawn([process.execPath, __filename, "--refresh", f, id, cwd, ctx.epoch], { stdio: ["ignore", "ignore", "ignore"], detached: true, windowsHide: true }).unref();
      } catch {}
    }
    return e.v;
  }
  const v = FETCH[id](cwd);
  writeCache(f, { t: now, epoch: ctx.epoch, v });
  return v;
}

// 背景更新：bun statusline.js --refresh <快取檔> <區塊> <cwd> <epoch>
if (process.argv[2] === "--refresh") {
  const [f, id, cwd, epoch] = process.argv.slice(3);
  const v = FETCH[id](cwd);
  // 這段時間內前景已經因新訊息同步重算過（epoch 不同），就不要拿舊 epoch 的結果蓋掉
  if (readCache(f)?.epoch === epoch) writeCache(f, { t: Date.now(), epoch, v });
  // 順便清掉一天沒動過的快取（結束的 session）
  try {
    for (const n of fs.readdirSync(CACHE_DIR)) {
      const p = path.join(CACHE_DIR, n);
      if (Date.now() - fs.statSync(p).mtimeMs > 86400e3) fs.unlinkSync(p);
    }
  } catch {}
  process.exit(0);
}

function main() {
  const cfg = loadConfig();
  const themes = { p10k: P10K, ...cfg.themes };
  if (!themes[cfg.theme]) throw new Error(`unknown theme "${cfg.theme}" (${Object.keys(themes).join("|")})`);
  const P = { ...P10K, ...themes[cfg.theme] };
  const HEX = /^#[0-9a-f]{6}$/i;
  const col = (c) => { const v = P[c] ?? c; if (typeof v !== "string" || !HEX.test(v)) throw new Error(`unknown color "${c}"`); return v; };
  const ground = { mid: col(cfg.ground.mid), low: col(cfg.ground.low) };
  const ink = col(cfg.colors.ink), dim = col(cfg.colors.dim);
  const alert = (pct, base) => (pct >= cfg.thresholds.crit ? col(cfg.colors.crit) : pct >= cfg.thresholds.warn ? col(cfg.colors.warn) : base);
  const ic = (id, b) => (!cfg.icons || b.icon === false ? "" : (typeof b.icon === "string" ? b.icon : GLYPH[id]) + " ");

  const d = JSON.parse(fs.readFileSync(0, "utf8"));
  const cwd = d.workspace?.current_dir ?? d.cwd ?? process.cwd();
  // epoch：對話有新訊息就會變（transcript 被寫入、API 時間累加），拿來讓 git 快取失效
  let mtime = 0;
  try { if (d.transcript_path) mtime = fs.statSync(d.transcript_path).mtimeMs; } catch {}
  const ctx = { session: d.session_id ?? "", epoch: `${d.cost?.total_api_duration_ms ?? ""}|${mtime}` };

  // 每個區塊回傳 { text, color }（或 null＝沒資料），文字內可以夾自己的顏色碼
  const builders = {
    model: (b) => {
      const lvl = d.effort?.level;
      const effort = b.effort && lvl ? ` ${FAINT}${b.effort.replace("{level}", lvl)}${NOBOLD}` : "";
      const fast = d.fast_mode ? (ic("model", b) ? ` ${GLYPH.fast}` : " fast") : "";
      return { text: `${BOLD}${ic("model", b)}${d.model?.display_name ?? "?"}${NOBOLD}${effort}${fast}`, color: col(b.color) };
    },
    cwd: (b) => ({ text: `${ic("cwd", b)}${shortDir(cwd, b.depth)}`, color: col(b.color) }),
    git: (b) => {
      const g = cached("git", b.ttl, cwd, ctx);
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
      const miss = pc.misses > 0 ? ` ${FAINT}${pc.misses} miss${NOBOLD}` : "";
      return { text: `${ic("cache", b)}${hit}%${pc.warm ? ` ${left}m` : " cold"}${miss}`, color: pc.warm ? col(b.color) : col(cfg.colors.crit) };
    },
    usage: (b) => {
      const rl = d.rate_limits;
      if (!rl?.five_hour && !rl?.seven_day) return null;
      const f = (label, r) => {
        if (!r) return null;
        const secs = r.resets_at - Date.now() / 1000;
        const reset = secs > 0 ? ` ${FAINT}${dur(secs)}${NOBOLD}` : "";
        return `${fg(col(b.color))}${label} ${fg(alert(r.used_percentage, col(b.color)))}${Math.round(r.used_percentage)}%${reset}`;
      };
      const body = [f("5h", rl.five_hour), f("7d", rl.seven_day)].filter(Boolean).join(`${fg(dim)}${b.sep}`);
      return { text: `${ic("usage", b)}${body}`, color: col(b.color) };
    },
    cost: (b) => (d.cost?.total_cost_usd == null ? null : { text: `${ic("cost", b)}$${d.cost.total_cost_usd.toFixed(2)}`, color: col(b.color) }),
    dirs: (b) => {
      const n = d.workspace?.added_dirs?.length ?? 0;
      return n ? { text: `${ic("dirs", b)}+${n} dir${n > 1 ? "s" : ""}`, color: col(b.color) } : null;
    },
    lines: (b) => {
      const g = cached("lines", b.ttl, cwd, ctx);
      return g ? { text: `${ic("lines", b)}${fg(col(b.addedColor))}+${g.a} ${fg(col(b.removedColor))}-${g.r}`, color: col(b.color) } : null;
    },
    duration: (b) => (d.cost?.total_duration_ms == null ? null : { text: `${ic("duration", b)}${dur(d.cost.total_duration_ms / 1000)}`, color: col(b.color) }),
    clock: (b) => ({ text: `${ic("clock", b)}${new Date().toTimeString().slice(0, 5)}`, color: col(b.color) }),
  };

  // 區塊物件 { bg, fg, tone, text, lead }；rainbow 用 bg/fg，lean／classic 用 tone
  const segOf = (id) => {
    const b = cfg.blocks[id];
    if (!b || !builders[id]) throw new Error(`unknown block "${id}" in layout`);
    const r = b.show ? builders[id](b) : null;
    if (!r) return null;
    const c = r.color;
    return { bg: b.fill ? c : ground[b.ground], fg: b.fill ? ink : c, tone: c, text: r.text, lead: b.lead };
  };

  // lean：每塊前面可帶一個暗灰短語（on / ctx…），靠短語分隔區塊
  const leanBlock = (s) => (s.lead ? `${fg(dim)}${s.lead}${RESET} ` : "") + `${fg(s.tone)}${s.text}${RESET}`;
  const gapStr = " ".repeat(cfg.gap);
  // classic：區塊之間的內容（底色由外層給）
  const classicBlock = (s) => `${s.lead ? fg(dim) + " " + s.lead : ""}${fg(s.tone)} ${s.text} `;

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
      left: (ss) => `${bg(ground.mid)}` + ss.map(classicBlock).join(`${fg(dim)}${THIN}`) + `${RESET}${fg(ground.mid)}${ARROW}${RESET}`,
      right: (ss) => `${fg(ground.mid)}${ARROW_R}${bg(ground.mid)}` + ss.map(classicBlock).join(`${fg(dim)}${THIN_R}`) + RESET,
    },
  };

  const cols = Number(process.env.COLUMNS);
  function compose(name, line) {
    const R = RENDERERS[name];
    if (!R) throw new Error(`unknown style "${name}" (rainbow|lean|classic)`);
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
  if (!Array.isArray(cfg.layout)) throw new Error("layout must be an array of lines");
  return cfg.layout.map((line) => compose(cfg.style, line)).filter((l) => l.trim()).join("\n");
}

// 設定寫錯時直接把原因顯示在 statusline 上，而不是整條變空白
// 用 fs.writeSync 而不是 process.stdout：bun 初始化 process.stdout 要十幾 ms
let out;
try { out = main(); } catch (e) { out = `statusline: ${e.message}`; }
fs.writeSync(1, out);
