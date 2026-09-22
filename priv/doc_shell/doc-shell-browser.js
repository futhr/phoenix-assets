var M = /[\u0000-\u0020\u007f-\u009f]/g, R = /^([a-z][a-z\d+.-]*):/i, O = /&#(?:x([\da-f]+)|(\d+));?/gi;
function _() {
  return typeof window > "u" ? "http://localhost/" : window.location.href;
}
function N(e) {
  let r = e;
  for (let o = 0; o < 2; o += 1) try {
    const a = decodeURIComponent(r);
    if (a === r) break;
    r = a;
  } catch {
    break;
  }
  return r.replace(O, (o, a, n) => {
    const t = Number.parseInt(a ?? n ?? "0", a ? 16 : 10);
    return t <= 1114111 ? String.fromCodePoint(t) : "";
  }).replace(/&colon;/gi, ":").replace(M, "");
}
function P(e) {
  return e.startsWith("//") || e.startsWith("\\\\");
}
function D(e, r = _()) {
  const o = e?.trim();
  if (!o || o.includes("\\")) return;
  const a = N(o);
  if (P(a)) return;
  const n = a.match(R);
  if (!n) return {
    href: o,
    external: !1,
    navigable: !0
  };
  const t = n[1]?.toLowerCase();
  if (t === "mailto") return {
    href: o,
    external: !1,
    navigable: !1
  };
  if (!(t !== "http" && t !== "https"))
    try {
      const i = new URL(o), s = i.origin !== new URL(r).origin;
      return {
        href: i.href,
        external: s,
        navigable: !s
      };
    } catch {
      return;
    }
}
var L = (e) => e.normalize("NFC").toLocaleLowerCase("und"), U = (e, r) => {
  const o = Array.isArray(e.audience) ? e.audience : [e.audience];
  return (Array.isArray(r) ? r : [r]).every((a) => o.includes(a));
}, I = (e, r) => Object.entries(r).every(([o, a]) => a === void 0 ? !0 : o === "tag" ? e.tags.includes(String(a)) : o === "audience" ? U(e, a) : e[o] === a), b = (e, r, o) => e && L(e).includes(r) ? o : 0, j = (e, r, o = {}, a = 20) => {
  const n = L(r);
  return e.filter((t) => I(t, o)).map((t) => ({
    record: t,
    score: n === "" ? 1 : b(t.title, n, 4) + b(t.section, n, 2) + b(t.text, n, 1)
  })).filter(({ score: t }) => t > 0).sort((t, i) => i.score - t.score || t.record.route.localeCompare(i.record.route) || t.record.id.localeCompare(i.record.id)).slice(0, a).map(({ record: t }) => t);
}, $ = (e) => typeof e == "object" && e !== null && typeof e.search == "function", B = (e, r = window.location.origin) => {
  if (typeof e != "object" || e === null || e.schema_version !== "doc-shell-search-query/v1" || e.algorithm !== "pagefind/v1") return;
  const o = e.path;
  if (!(typeof o != "string" || !o.startsWith("/") || o.startsWith("//"))) {
    try {
      const a = new URL(o, r);
      if (a.origin !== r || a.pathname !== o || a.search !== "" || a.hash !== "" || o.split("/").some((n) => n === "." || n === "..")) return;
    } catch {
      return;
    }
    return e;
  }
}, z = async (e) => import(
  /* @vite-ignore */
  e
), H = (e, r = z, o = window.location.origin) => {
  const a = B(e, o);
  if (a)
    return W(async () => {
      const n = await r(a.path);
      if (!$(n)) throw new Error("Invalid Pagefind browser module");
      return n;
    });
}, W = (e) => {
  let r;
  return async (o, a = {}) => {
    r ??= e();
    const n = await (await r).search(o, { filters: Object.fromEntries(Object.entries(a).filter((t) => t[1] !== void 0)) });
    return (await Promise.all(n.results.map((t) => t.data()))).map((t) => ({
      ...t,
      id: t.id ?? t.meta.record_id,
      url: t.meta.route ?? t.url
    }));
  };
}, v = (e, r) => [...e.querySelectorAll(r)], F = (e) => {
  const r = new AbortController(), o = () => v(e, "[data-doc-nav-toggle]").forEach((a) => {
    const n = a.getAttribute("aria-controls"), t = n ? e.querySelector(`#${CSS.escape(n)}`) : null;
    t && !t.dataset.docNavState && (t.dataset.docNavState = "closed");
  });
  return e.addEventListener("click", (a) => {
    const n = a.target.closest("[data-doc-nav-toggle]");
    if (!n) return;
    const t = n.getAttribute("aria-controls"), i = t ? e.querySelector(`#${CSS.escape(t)}`) : void 0;
    if (!i) return;
    const s = n.getAttribute("aria-expanded") !== "true";
    n.setAttribute("aria-expanded", String(s)), i.dataset.docNavState = s ? "open" : "closed";
  }, { signal: r.signal }), o(), {
    refresh: o,
    destroy: () => r.abort()
  };
}, K = (e) => {
  const r = e.dataset.docSearchRecords;
  if (!r) return [];
  try {
    const o = Uint8Array.from(atob(r.replace(/-/g, "+").replace(/_/g, "/")), (n) => n.charCodeAt(0)), a = JSON.parse(new TextDecoder().decode(o));
    return Array.isArray(a) ? a : [];
  } catch {
    return [];
  }
}, J = (e) => {
  const r = e.dataset.docSearchContract;
  if (r)
    try {
      const o = Uint8Array.from(atob(r.replace(/-/g, "+").replace(/_/g, "/")), (a) => a.charCodeAt(0));
      return JSON.parse(new TextDecoder().decode(o));
    } catch {
      return;
    }
}, V = (e) => {
  const r = e.id ?? e.meta.record_id ?? e.url;
  return {
    id: r,
    page_id: e.meta.page_id ?? r,
    route: e.url,
    title: e.meta.title ?? e.meta.record_id ?? e.url,
    section: e.meta.section,
    text: e.excerpt,
    locale: e.meta.locale ?? "",
    audience: e.meta.audience,
    kind: e.meta.kind ?? "",
    collection: e.meta.collection ?? "",
    version: e.meta.version ?? "",
    tags: [],
    status: e.meta.status
  };
}, Y = (e, r) => {
  const o = new AbortController();
  let a, n = 0, t = [], i = 0;
  const s = e.querySelector("[data-doc-search-dialog]"), d = s?.querySelector("[data-doc-search-input]"), l = s?.querySelector("[data-doc-search-results]"), T = s ? K(s) : [], S = s ? H(J(s), r) : void 0, w = () => Object.fromEntries(v(s ?? e, "[data-doc-search-filter]").map((c) => [c.dataset.docSearchFilter, c.value]).filter((c) => !!(c[0] && c[1]))), g = () => {
    !d || !l || (n = Math.min(n, Math.max(0, t.length - 1)), l.replaceChildren(...t.map((c, u) => {
      const f = document.createElement("li");
      f.id = `doc-search-result-${u}`, f.setAttribute("role", "option"), f.setAttribute("aria-selected", String(u === n));
      const m = D(c.route), h = document.createElement(m ? "a" : "span");
      m && h instanceof HTMLAnchorElement && (h.href = m.href, m.external && (h.target = "_blank", h.rel = "noopener noreferrer"));
      const C = [
        c.section,
        c.collection,
        c.version
      ].filter(Boolean).join(" · ");
      if (h.append(document.createTextNode(c.title)), C) {
        const E = document.createElement("small");
        E.textContent = C, h.append(E);
      }
      return f.append(h), f;
    })), d.setAttribute("aria-activedescendant", t[n] ? `doc-search-result-${n}` : ""));
  }, p = () => {
    if (!d || !l) return;
    const c = d.value.trim(), u = ++i;
    if (c.length < 2) {
      t = [], l.dataset.docSearchState = "idle", l.removeAttribute("aria-busy"), g();
      return;
    }
    if (!S) {
      t = j(T, c, w(), 20), l.dataset.docSearchState = "ready", l.removeAttribute("aria-busy"), g();
      return;
    }
    l.dataset.docSearchState = "loading", l.setAttribute("aria-busy", "true"), S(c, w()).then((f) => {
      i !== u || o.signal.aborted || (t = f.slice(0, 20).map(V), l.dataset.docSearchState = "ready", l.removeAttribute("aria-busy"), g());
    }).catch(() => {
      i !== u || o.signal.aborted || (t = [], l.dataset.docSearchState = "error", l.removeAttribute("aria-busy"), g());
    });
  }, A = (c) => {
    !s || !d || (a = c ?? a, typeof s.showModal == "function" ? s.showModal() : s.setAttribute("open", ""), d.focus());
  }, y = () => {
    s && (typeof s.close == "function" ? s.close() : s.removeAttribute("open"), a?.focus());
  };
  return e.addEventListener("click", (c) => {
    const u = c.target, f = u.closest("[data-doc-search-open]");
    f && A(f), u.closest("[data-doc-search-close]") && y(), u.closest("[data-doc-search-results] a") && y();
  }, { signal: o.signal }), e.addEventListener("input", (c) => {
    c.target.matches("[data-doc-search-input], [data-doc-search-filter]") && p();
  }, { signal: o.signal }), e.addEventListener("change", (c) => {
    c.target.matches("[data-doc-search-filter]") && p();
  }, { signal: o.signal }), e.addEventListener("keydown", (c) => {
    if ((c.metaKey || c.ctrlKey) && c.key.toLowerCase() === "k") {
      c.preventDefault(), A(e.querySelector("[data-doc-search-open]") ?? void 0);
      return;
    }
    if (s?.hasAttribute("open"))
      if (c.key === "Escape")
        c.preventDefault(), y();
      else if (c.key === "ArrowDown" || c.key === "ArrowUp") {
        c.preventDefault();
        const u = c.key === "ArrowDown" ? 1 : -1;
        n = Math.max(0, Math.min(t.length - 1, n + u)), g();
      } else c.key === "Enter" && t[n] && l?.children[n]?.querySelector("a")?.click();
  }, { signal: o.signal }), {
    refresh: p,
    destroy: () => o.abort()
  };
}, G = (e) => {
  const r = new AbortController();
  return e.addEventListener("click", async (o) => {
    const a = o.target.closest("[data-doc-copy]");
    if (!a) return;
    const n = a.dataset.docCopy, t = n ? e.querySelector(`#${CSS.escape(n)}`) : a.closest("[data-doc-code]")?.querySelector("code");
    t && (await navigator.clipboard?.writeText(t.textContent ?? ""), a.dataset.docCopyState = "copied", a.setAttribute("aria-label", "Copied"));
  }, { signal: r.signal }), {
    refresh: () => {
    },
    destroy: () => r.abort()
  };
}, Q = (e) => {
  const r = new AbortController(), o = (a) => {
    const n = a.closest('[role="tablist"]');
    if (n)
      for (const t of n.querySelectorAll('[role="tab"]')) {
        const i = t === a;
        t.setAttribute("aria-selected", String(i)), t.tabIndex = i ? 0 : -1;
        const s = t.getAttribute("aria-controls");
        if (s) {
          const d = e.querySelector(`#${CSS.escape(s)}`);
          d && (d.hidden = !i);
        }
      }
  };
  return e.addEventListener("click", (a) => {
    const n = a.target.closest('[role="tab"]');
    n && o(n);
  }, { signal: r.signal }), e.addEventListener("keydown", (a) => {
    const n = a.target.closest('[role="tab"]');
    if (!n) return;
    const t = [...n.closest('[role="tablist"]')?.querySelectorAll('[role="tab"]:not([disabled])') ?? []], i = t.indexOf(n);
    let s = i;
    if (a.key === "ArrowRight" || a.key === "ArrowDown") s = (i + 1) % t.length;
    else if (a.key === "ArrowLeft" || a.key === "ArrowUp") s = (i - 1 + t.length) % t.length;
    else if (a.key === "Home") s = 0;
    else if (a.key === "End") s = t.length - 1;
    else return;
    a.preventDefault();
    const d = t[s];
    d && (o(d), d.focus());
  }, { signal: r.signal }), {
    refresh: () => v(e, '[role="tablist"]').forEach((a) => {
      const n = a.querySelector('[role="tab"][aria-selected="true"]') ?? a.querySelector('[role="tab"]');
      n && o(n);
    }),
    destroy: () => r.abort()
  };
}, x = "phoenix-assets:doc-shell:theme", q = /* @__PURE__ */ new Set([
  "system",
  "light",
  "dark",
  "contrast"
]), X = (e = localStorage) => {
  const r = e.getItem(x);
  return r && q.has(r) ? r : "system";
}, k = (e, r) => {
  e.dataset.paTheme = r === "system" ? "" : r, e.dataset.docTheme = r;
}, Z = (e, r = localStorage) => {
  const o = new AbortController(), a = () => k(e, X(r));
  return e.addEventListener("click", (n) => {
    const t = n.target.closest("[data-doc-theme-value]")?.dataset.docThemeValue;
    !t || !q.has(t) || (r.setItem(x, t), k(e, t));
  }, { signal: o.signal }), a(), {
    refresh: a,
    destroy: () => o.abort()
  };
}, ee = (e) => {
  const r = [
    Z(e),
    F(e),
    Y(e),
    G(e),
    Q(e)
  ];
  return {
    refresh: () => r.forEach((o) => o.refresh()),
    destroy: () => r.splice(0).forEach((o) => o.destroy())
  };
}, te = (e = document.documentElement) => {
  let r;
  const o = () => {
    r ??= ee(e);
  };
  return document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", o, { once: !0 }) : o(), {
    refresh: () => r?.refresh(),
    destroy: () => {
      document.removeEventListener("DOMContentLoaded", o), r?.destroy(), r = void 0;
    }
  };
};
te();
