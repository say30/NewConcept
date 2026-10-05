// Dev tool: draws Instance trees exported by export.luau in a browser and saves a PNG.
// It reproduces how Roblox lays out GUI objects (UDim2 sizes, anchors, UIListLayout,
// UIGridLayout, UIPadding, UICorner, UIStroke, UIGradient, CanvasGroup) closely enough to
// judge a design without Studio.
//
//   node tools/preview/render.js scenes.json out.png
//
// scenes.json: { columns?, background?, scenes: [{ title?, width, height, background?, root }] }

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const FONTS = {
	FredokaOne: ["'Fredoka'", 600],
	LuckiestGuy: ["'Luckiest Guy'", 400],
	Bangers: ["'Bangers'", 400],
	GothamBlack: ["'Montserrat'", 900],
	GothamBold: ["'Montserrat'", 700],
	GothamMedium: ["'Montserrat'", 500],
	Gotham: ["'Montserrat'", 400],
	BuilderSans: ["'Nunito Sans'", 400],
	BuilderSansBold: ["'Nunito Sans'", 700],
	BuilderSansExtraBold: ["'Nunito Sans'", 800],
	SourceSans: ["'Source Sans 3'", 400],
	SourceSansBold: ["'Source Sans 3'", 700],
	SourceSansSemibold: ["'Source Sans 3'", 600],
	Cartoon: ["'Comic Neue'", 700],
	Arcade: ["'Press Start 2P'", 400],
	Highway: ["'Oswald'", 500],
	Oswald: ["'Oswald'", 500],
	Michroma: ["'Michroma'", 400],
	Ubuntu: ["'Ubuntu'", 500],
	Nunito: ["'Nunito'", 800],
};
const FONT_CSS = "file://" + path.join(__dirname, "fonts", "local.css");

const GUI = new Set([
	"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame",
	"CanvasGroup", "ViewportFrame",
]);
const TEXT = new Set(["TextLabel", "TextButton", "TextBox"]);

const child = (n, cls) => n.children.find((c) => c.class === cls);
const udim2 = (v, def) => v || def || [0, 0, 0, 0];
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function hexToRgb(h) {
	const n = parseInt(h.slice(1), 16);
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function rgba(hex, transparency = 0) {
	const [r, g, b] = hexToRgb(hex || "#000000");
	return `rgba(${r},${g},${b},${+(1 - transparency).toFixed(3)})`;
}
function multiply(a, b) {
	const x = hexToRgb(a), y = hexToRgb(b);
	return "#" + x.map((v, i) => Math.round((v * y[i]) / 255).toString(16).padStart(2, "0")).join("");
}
function sample(seq, t) {
	if (!seq || !seq.length) return null;
	for (let i = 0; i < seq.length - 1; i++) {
		const [t0, v0] = seq[i], [t1, v1] = seq[i + 1];
		if (t >= t0 && t <= t1) {
			const k = t1 === t0 ? 0 : (t - t0) / (t1 - t0);
			if (typeof v0 === "number") return v0 + (v1 - v0) * k;
			const a = hexToRgb(v0), b = hexToRgb(v1);
			return "#" + a.map((v, j) => Math.round(v + (b[j] - v) * k).toString(16).padStart(2, "0")).join("");
		}
	}
	return seq[seq.length - 1][1];
}

// CSS background for a GuiObject: its colour, multiplied by a UIGradient if any.
function background(n, extraTransparency = 0) {
	const p = n.props;
	const bt = p.BackgroundTransparency ?? 1;
	if (bt >= 1 && n.class !== "ImageLabel") return null;
	const base = p.BackgroundColor3 || "#FFFFFF";
	const g = child(n, "UIGradient");
	if (g && g.props.Enabled !== false) {
		const stops = new Set([0, 1]);
		(g.props.Color || []).forEach(([t]) => stops.add(t));
		(g.props.Transparency || []).forEach(([t]) => stops.add(t));
		const parts = [...stops].sort((a, b) => a - b).map((t) => {
			const c = multiply(base, sample(g.props.Color, t) || "#FFFFFF");
			const tr = 1 - (1 - bt) * (1 - (sample(g.props.Transparency, t) ?? 0)) * (1 - extraTransparency);
			return `${rgba(c, tr)} ${(t * 100).toFixed(2)}%`;
		});
		const angle = (g.props.Rotation || 0) + 90;
		if (g.props.Type === "Radial") return `radial-gradient(circle, ${parts.join(",")})`;
		return `linear-gradient(${angle}deg, ${parts.join(",")})`;
	}
	if (bt >= 1) return null;
	return rgba(base, 1 - (1 - bt) * (1 - extraTransparency));
}

function measureSize(n, parentW, parentH) {
	const s = udim2(n.props.Size);
	let w = s[0] * parentW + s[1];
	let h = s[2] * parentH + s[3];
	const a = child(n, "UIAspectRatioConstraint");
	if (a) {
		const r = a.props.AspectRatio || 1;
		if (a.props.AspectType === "ScaleWithParentSize") {
			if (a.props.DominantAxis === "Height") w = h * r;
			else h = w / r;
		} else if (w / h > r) w = h * r;
		else h = w / r;
	}
	const auto = n.props.AutomaticSize;
	if (auto === "Y" || auto === "XY") h = Math.max(h, autoHeight(n, w));
	return [Math.max(0, w), Math.max(0, h)];
}

// Height a container grows to with AutomaticSize Y: the bottom of its laid-out children.
function autoHeight(n, w) {
	const [pt, pr, pb, pl] = padding(n, w, 0);
	const rects = layoutChildren(n, w - pl - pr, 0);
	let bottom = 0;
	for (const r of rects.values()) bottom = Math.max(bottom, r.y + r.h);
	return bottom + pt + pb;
}

function padding(n, w, h) {
	const p = child(n, "UIPadding");
	if (!p) return [0, 0, 0, 0];
	const u = (v) => (v ? v[0] : 0);
	const o = (v) => (v ? v[1] : 0);
	return [
		u(p.props.PaddingTop) * h + o(p.props.PaddingTop),
		u(p.props.PaddingRight) * w + o(p.props.PaddingRight),
		u(p.props.PaddingBottom) * h + o(p.props.PaddingBottom),
		u(p.props.PaddingLeft) * w + o(p.props.PaddingLeft),
	];
}

// Returns {x, y, w, h} for every visible GUI child of `n`, inside a content box of cw x ch.
function layoutChildren(n, cw, ch) {
	const kids = n.children.filter((c) => GUI.has(c.class) && c.props.Visible !== false);
	const list = child(n, "UIListLayout");
	const grid = child(n, "UIGridLayout");
	const rects = new Map();
	if (!list && !grid) {
		for (const c of kids) {
			const [w, h] = measureSize(c, cw, ch);
			const pos = udim2(c.props.Position);
			const an = c.props.AnchorPoint || [0, 0];
			rects.set(c, { x: pos[0] * cw + pos[1] - an[0] * w, y: pos[2] * ch + pos[3] - an[1] * h, w, h });
		}
		return rects;
	}
	const sorted = [...kids].sort((a, b) => (a.props.LayoutOrder || 0) - (b.props.LayoutOrder || 0));
	if (list) {
		const lp = list.props;
		const horizontal = lp.FillDirection === "Horizontal";
		const pad = lp.Padding ? lp.Padding[0] * (horizontal ? cw : ch) + lp.Padding[1] : 0;
		const sizes = sorted.map((c) => measureSize(c, cw, ch));
		const total = sizes.reduce((s, [w, h]) => s + (horizontal ? w : h), 0) + pad * Math.max(0, sorted.length - 1);
		const main = horizontal ? cw : ch;
		const alignMain = horizontal ? lp.HorizontalAlignment : lp.VerticalAlignment;
		let cursor = alignMain === "Center" ? (main - total) / 2 : alignMain === "Right" || alignMain === "Bottom" ? main - total : 0;
		const alignCross = horizontal ? lp.VerticalAlignment : lp.HorizontalAlignment;
		sorted.forEach((c, i) => {
			const [w, h] = sizes[i];
			const cross = horizontal ? ch - h : cw - w;
			const off = alignCross === "Center" ? cross / 2 : alignCross === "Right" || alignCross === "Bottom" ? cross : 0;
			rects.set(c, horizontal ? { x: cursor, y: off, w, h } : { x: off, y: cursor, w, h });
			cursor += (horizontal ? w : h) + pad;
		});
		return rects;
	}
	const gp = grid.props;
	const cs = udim2(gp.CellSize, [0, 100, 0, 100]);
	const cp = udim2(gp.CellPadding, [0, 5, 0, 5]);
	const w = cs[0] * cw + cs[1], h = cs[2] * ch + cs[3];
	const px = cp[0] * cw + cp[1], py = cp[2] * ch + cp[3];
	const perRow = Math.max(1, Math.floor((cw + px) / (w + px)));
	const rowW = Math.min(perRow, sorted.length) * (w + px) - px;
	const rows = Math.ceil(sorted.length / perRow);
	const totalH = rows * (h + py) - py;
	const x0 = gp.HorizontalAlignment === "Center" ? (cw - rowW) / 2 : gp.HorizontalAlignment === "Right" ? cw - rowW : 0;
	const y0 = gp.VerticalAlignment === "Center" ? (ch - totalH) / 2 : gp.VerticalAlignment === "Bottom" ? ch - totalH : 0;
	sorted.forEach((c, i) => {
		rects.set(c, { x: x0 + (i % perRow) * (w + px), y: y0 + Math.floor(i / perRow) * (h + py), w, h });
	});
	return rects;
}

function cornerRadius(n, w, h) {
	const c = child(n, "UICorner");
	if (!c) return 0;
	const r = c.props.CornerRadius || [0, 8];
	return Math.min(r[0] * Math.min(w, h) + r[1], Math.min(w, h) / 2);
}

function textCss(n, w, h) {
	const p = n.props;
	const [family, weight] = FONTS[p.Font] || ["'Source Sans 3'", 700];
	const xa = { Left: "flex-start", Center: "center", Right: "flex-end" }[p.TextXAlignment || "Center"];
	const ya = { Top: "flex-start", Center: "center", Bottom: "flex-end" }[p.TextYAlignment || "Center"];
	let css = `display:flex;align-items:${ya};justify-content:${xa};text-align:${(p.TextXAlignment || "Center").toLowerCase()};`;
	css += `font-family:${family};font-weight:${weight};line-height:1;color:${rgba(p.TextColor3, p.TextTransparency || 0)};`;
	css += p.TextWrapped ? "white-space:normal;overflow-wrap:break-word;" : "white-space:pre;";
	let shadow = [];
	const s = n.children.find((c) => c.class === "UIStroke" && c.props.ApplyStrokeMode !== "Border" && c.props.Enabled !== false);
	if (s) {
		const t = s.props.Thickness || 1;
		css += `-webkit-text-stroke:${t * 2}px ${rgba(s.props.Color, s.props.Transparency || 0)};paint-order:stroke fill;`;
	} else if ((p.TextStrokeTransparency ?? 1) < 1) {
		const c = rgba(p.TextStrokeColor3, p.TextStrokeTransparency);
		shadow = [`1px 1px 0 ${c}`, `-1px -1px 0 ${c}`, `1px -1px 0 ${c}`, `-1px 1px 0 ${c}`];
	}
	if (shadow.length) css += `text-shadow:${shadow.join(",")};`;
	const g = child(n, "UIGradient");
	let inner = "";
	if (g && g.props.Enabled !== false && g.props.Color) {
		const stops = g.props.Color.map(([t, c]) => `${multiply(p.TextColor3 || "#FFFFFF", c)} ${t * 100}%`).join(",");
		inner = `background:linear-gradient(${(g.props.Rotation || 0) + 90}deg,${stops});-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;`;
	}
	return { css, inner, size: p.TextSize || 14, scaled: !!p.TextScaled };
}

let uid = 0;
function renderNode(n, rect, z) {
	const p = n.props;
	const { x, y, w, h } = rect;
	const radius = cornerRadius(n, w, h);
	let css = `position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;z-index:${z};`;
	const uiScale = child(n, "UIScale");
	const transforms = [];
	if (p.Rotation) transforms.push(`rotate(${p.Rotation}deg)`);
	if (uiScale && uiScale.props.Scale !== undefined && uiScale.props.Scale !== 1) {
		transforms.push(`scale(${uiScale.props.Scale})`);
		const an = p.AnchorPoint || [0, 0];
		css += `transform-origin:${an[0] * 100}% ${an[1] * 100}%;`;
	}
	if (transforms.length) css += `transform:${transforms.join(" ")};`;
	if (radius) css += `border-radius:${radius}px;`;
	const groupT = n.class === "CanvasGroup" ? p.GroupTransparency || 0 : 0;
	if (groupT) css += `opacity:${1 - groupT};`;
	const bg = background(n);
	if (bg) css += `background:${bg};`;
	if (n.class === "ImageLabel" && p.Image) {
		css += `background-image:repeating-linear-gradient(45deg,rgba(255,255,255,.25) 0 6px,rgba(0,0,0,.08) 6px 12px);`;
	}
	const shadows = [];
	for (const s of n.children) {
		if (s.class !== "UIStroke" || s.props.Enabled === false) continue;
		if (TEXT.has(n.class) && s.props.ApplyStrokeMode !== "Border") continue;
		const t = s.props.Thickness || 1;
		const col = rgba(s.props.Color, s.props.Transparency || 0);
		const pos = s.props.BorderStrokePosition || "Outer";
		if (pos === "Inner") shadows.push(`inset 0 0 0 ${t}px ${col}`);
		else if (pos === "Center") shadows.push(`0 0 0 ${t / 2}px ${col}`, `inset 0 0 0 ${t / 2}px ${col}`);
		else shadows.push(`0 0 0 ${t}px ${col}`);
	}
	if (shadows.length) css += `box-shadow:${shadows.join(",")};`;
	if (p.ClipsDescendants || n.class === "CanvasGroup" || n.class === "ScrollingFrame") css += "overflow:hidden;";
	if (n.class === "CanvasGroup" && radius) css += `clip-path:inset(0 round ${radius}px);`;

	const [pt, pr, pb, pl] = padding(n, w, h);
	const cw = w - pl - pr, ch = h - pt - pb;
	let html = `<div data-name="${esc(n.name)}" style="${css}">`;
	if (n.class === "TextBox" && !p.Text && p.PlaceholderText) {
		p.Text = p.PlaceholderText;
		p.TextColor3 = p.PlaceholderColor3 || "#888888";
	}
	if (TEXT.has(n.class) && p.Text) {
		const t = textCss(n, cw, ch);
		const fs = t.scaled ? Math.max(8, Math.min(100, ch)) : t.size;
		html += `<div class="txt${t.scaled ? " fit" : ""}" style="position:absolute;left:${pl}px;top:${pt}px;width:${cw}px;height:${ch}px;${t.css}font-size:${fs}px;"><span style="${t.inner}">${esc(p.Text)}</span></div>`;
	}
	const rects = layoutChildren(n, cw, ch);
	const kids = [...rects.keys()];
	// Sibling ZIndex behaviour: higher ZIndex on top, then later siblings on top.
	kids.forEach((c, i) => {
		const r = rects.get(c);
		html += renderNode(c, { x: r.x + pl, y: r.y + pt, w: r.w, h: r.h }, (c.props.ZIndex ?? 1) * 1000 + i);
	});
	html += "</div>";
	return html;
}

function renderScene(scene) {
	const root = scene.root;
	const w = scene.width, h = scene.height;
	let inner = "";
	const kids = GUI.has(root.class) ? [root] : root.children.filter((c) => GUI.has(c.class) && c.props.Visible !== false);
	const rects = GUI.has(root.class) ? new Map([[root, { x: 0, y: 0, w, h }]]) : layoutChildren(root, w, h);
	if (GUI.has(root.class) && !scene.fillRoot) rects.set(root, (() => {
		const [sw, sh] = measureSize(root, w, h);
		const pos = udim2(root.props.Position);
		const an = root.props.AnchorPoint || [0, 0];
		return { x: pos[0] * w + pos[1] - an[0] * sw, y: pos[2] * h + pos[3] - an[1] * sh, w: sw, h: sh };
	})());
	kids.forEach((c, i) => {
		if (rects.has(c)) inner += renderNode(c, rects.get(c), (c.props.ZIndex ?? 1) * 1000 + i);
	});
	const bg = scene.background || "#7EC8F0";
	return `<figure><div class="stage" style="width:${w}px;height:${h}px;background:${bg}">${inner}</div>${scene.title ? `<figcaption>${esc(scene.title)}</figcaption>` : ""}</figure>`;
}

async function main() {
	const [input, output, only] = process.argv.slice(2);
	const data = JSON.parse(fs.readFileSync(input, "utf8"));
	// Optional third argument: render only the scene at that index.
	if (only !== undefined) data.scenes = [data.scenes[Number(only)]];
	// Lua encodes empty tables as objects.
	const fix = (n) => {
		n.children = Array.isArray(n.children) ? n.children : [];
		if (Array.isArray(n.props)) n.props = {};
		n.children.forEach(fix);
	};
	data.scenes.forEach((s) => fix(s.root));
	const columns = data.columns || 1;
	const html = `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="${FONT_CSS}">
<style>body{margin:0;padding:16px;background:${data.background || "#1d1f24"};font-family:'Nunito Sans',sans-serif}
.grid{display:grid;grid-template-columns:repeat(${columns},max-content);gap:16px}
figure{margin:0}figcaption{color:#cfd3da;font-size:13px;margin-top:4px}
.stage{position:relative;overflow:hidden}</style></head>
<body><div class="grid">${data.scenes.map(renderScene).join("")}</div>
<script>
document.fonts.ready.then(()=>{
  for (const el of document.querySelectorAll('.txt.fit')) {
    let s = parseFloat(el.style.fontSize);
    const span = el.firstChild;
    while (s > 6 && (span.offsetWidth > el.clientWidth || span.offsetHeight > el.clientHeight)) { s -= 1; el.style.fontSize = s + 'px'; }
  }
  document.body.dataset.ready = '1';
});
</script></body></html>`;
	const htmlPath = path.resolve(output.replace(/\.png$/, ".html"));
	fs.writeFileSync(htmlPath, html);
	const browser = await chromium.launch();
	const widest = Math.max(...data.scenes.map((s) => s.width));
	const page = await browser.newPage({
		deviceScaleFactor: data.scale || 1,
		viewport: { width: columns * (widest + 16) + 40, height: 800 },
	});
	await page.goto("file://" + htmlPath);
	await page.waitForFunction(() => document.body.dataset.ready === "1", null, { timeout: 15000 });
	await page.locator(".grid").screenshot({ path: output });
	await browser.close();
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
