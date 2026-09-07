// Plan remaining — how much of each AI plan is left.
//
// Renders whatever providers report, so adding a new API means dropping a
// script into ~/.config/dev-hud/providers/ — nothing here needs changing.
//
// Fed by ~/.ai-usage.sh. Debug with:  bash ~/.ai-usage.sh --debug

import { css, run } from "uebersicht";

/* ─── config ─────────────────────────────────────────────── */

const POSITION = "top: 48px; right: 36px;";
const WIDTH = 380;
const HEIGHT = 250;   // fixed so the column spaces evenly

export const refreshFrequency = 300000; // 5 minutes

export const command = "bash $HOME/.ai-usage.sh";

/* ─── thresholds ─────────────────────────────────────────── */

const CALM = "#4E9E7C";
const WARM = "#E0A23C";
const HOT = "#F0563E";

function pressure(used) {
  if (used >= 80) return HOT;
  if (used >= 50) return WARM;
  return CALM;
}

/* ─── styles ─────────────────────────────────────────────── */

export const className = `
  ${POSITION}
  width: ${WIDTH}px;
  height: ${HEIGHT}px;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  color: #E9EDF5;
  background: rgba(20, 25, 36, 0.82);
  -webkit-backdrop-filter: blur(24px) saturate(140%);
  border: 1px solid rgba(255, 255, 255, 0.10);
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 18px 50px rgba(0, 0, 0, 0.45);
  -webkit-font-smoothing: antialiased;
`;

const head = css`
  padding: 14px 16px 4px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: -0.1px;
  cursor: pointer;
  &:hover .refreshhint { opacity: 1; }
`;

const refreshHint = css`
  opacity: 0;
  margin-left: 7px;
  font-size: 9.5px;
  font-weight: 400;
  color: #5A6478;
`;

const scroll = css`
  overflow-y: auto;
  max-height: ${HEIGHT - 34}px;
  &::-webkit-scrollbar { width: 6px; }
  &::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.12);
    border-radius: 3px;
  }
`;

const block = css`
  padding: 10px 16px 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
`;

const blockHead = css`
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 9px;
`;

const provider = css`
  font-size: 12.5px;
  color: #E9EDF5;
`;

const tier = css`
  font-size: 10px;
  letter-spacing: 0.2px;
  color: #8B95AB;
  background: rgba(255, 255, 255, 0.07);
  padding: 2px 6px;
  border-radius: 4px;
`;

const rowGrid = css`
  display: grid;
  grid-template-columns: 52px 1fr 34px 52px;
  align-items: center;
  gap: 8px;
  margin-bottom: 7px;
  &:last-child { margin-bottom: 0; }
`;

const winLabel = css`
  font-size: 10.5px;
  color: #8B95AB;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
`;

const track = css`
  height: 6px;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.09);
  overflow: hidden;
`;

const fill = css`
  height: 100%;
  border-radius: 3px;
`;

const pctText = css`
  font-size: 11.5px;
  font-variant-numeric: tabular-nums;
  text-align: right;
  color: #E9EDF5;
`;

const resetText = css`
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  text-align: right;
  color: #5A6478;
`;

const msg = css`
  font-size: 10.5px;
  line-height: 1.5;
  color: #8B95AB;
`;

const lidRow = css`
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 9px 16px 11px;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
  font-size: 10.5px;
  color: #8B95AB;
  cursor: pointer;
  &:hover { background: rgba(255, 255, 255, 0.05); }
  &:hover .lidhint { opacity: 1; }
`;

const lidHint = css`
  opacity: 0;
  font-size: 9.5px;
  color: #5A6478;
`;

const lidDot = css`
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex: none;
`;

const lidNote = css`
  margin-left: auto;
  font-size: 9.5px;
  font-variant-numeric: tabular-nums;
`;

const panel = css`
  padding: 16px;
  font-size: 12px;
  line-height: 1.5;
  color: #8B95AB;
`;

const code = css`
  display: block;
  margin-top: 6px;
  padding: 7px 9px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 9.5px;
  color: #C9D2E3;
  background: rgba(0, 0, 0, 0.32);
  border-radius: 6px;
`;

/* ─── helpers ────────────────────────────────────────────── */

function countdown(resetMs, nowMs) {
  if (!resetMs) return "";
  var d = resetMs - nowMs;
  if (d <= 0) return "due";
  var m = Math.floor(d / 60000);
  var h = Math.floor(m / 60);
  var days = Math.floor(h / 24);
  if (days >= 1) return days + "d " + (h % 24) + "h";
  if (h >= 1) return h + "h " + (m % 60) + "m";
  return m + "m";
}

// Bars and numbers show what's LEFT, so each drains toward empty as it's spent.
// Colour keys off consumption, so it warms as the window runs out.
function Window(props) {
  var w = props.win;
  var used = typeof w.pct === "number" ? w.pct : null;
  if (used === null) {
    return (
      <div className={rowGrid}>
        <span className={winLabel}>{w.label}</span>
        <span className={track} />
        <span className={pctText}>—</span>
        <span className={resetText} />
      </div>
    );
  }
  var left = Math.max(0, Math.min(100, 100 - used));
  return (
    <div className={rowGrid}>
      <span className={winLabel}>{w.label}</span>
      <span className={track}>
        <span
          className={fill}
          style={{ width: left + "%", background: pressure(used), display: "block" }}
        />
      </span>
      <span className={pctText}>{left}%</span>
      <span className={resetText}>{countdown(w.resets, props.now)}</span>
    </div>
  );
}

function Provider(props) {
  var p = props.data;
  return (
    <div className={block}>
      <div className={blockHead}>
        <span className={provider}>{p.name}</span>
        {p.tier ? <span className={tier}>{p.tier}</span> : null}
      </div>
      {p.ok
        ? p.windows.map(function (w, i) {
            return <Window key={i} win={w} now={props.now} />;
          })
        : <div className={msg}>{p.err}</div>}
    </div>
  );
}

// Whether a long run survives you shutting the lid. Quota and sleep answer the
// same question — can this finish? — so they belong together.
function Lid(props) {
  var l = props.lid;
  if (!l) return null;
  var colour = l.on ? (l.risk ? WARM : CALM) : "#5A6478";
  var label = l.on ? "Lid closed: keeps running" : "Lid closed: sleeps";
  var note = "";
  if (l.on && typeof l.mins === "number") {
    note = l.mins >= 60
      ? "on " + Math.floor(l.mins / 60) + "h " + (l.mins % 60) + "m"
      : "on " + l.mins + "m";
  }
  if (l.risk) note = "on battery " + l.batt + "%";
  return (
    <div
      className={lidRow}
      onClick={function () {
        run("bash $HOME/.lid-awake-toggle.sh");
      }}
    >
      <span className={lidDot} style={{ background: colour }} />
      <span>{label}</span>
      <span className={"lidhint " + lidHint}>
        {l.on ? "click to stop" : "click to keep awake"}
      </span>
      <span className={lidNote} style={{ color: l.risk ? WARM : "#5A6478" }}>
        {note}
      </span>
    </div>
  );
}

/* ─── render ─────────────────────────────────────────────── */

export const render = function (props) {
  if (props.error) {
    return <div className={panel}>Collector failed: {String(props.error)}</div>;
  }
  if (!props.output) {
    return <div className={panel}>Reading plan usage…</div>;
  }

  var d;
  try {
    d = JSON.parse(props.output);
  } catch (e) {
    return <div className={panel}>The collector returned something unreadable.</div>;
  }

  var now = d.now || Date.now();
  var providers = d.providers || [];

  return (
    <div>
      <div
        className={head}
        onClick={function () {
          run('touch "$HOME/Library/Application Support/Übersicht/widgets/usage.jsx"');
        }}
      >
        Plan remaining
        <span className={"refreshhint " + refreshHint}>click to refresh</span>
      </div>

      {providers.length === 0 ? (
        <div className={panel}>
          No providers set up yet. Add one:
          <code className={code}>~/.config/dev-hud/providers/</code>
        </div>
      ) : (
        <div className={scroll}>
          {providers.map(function (p, i) {
            return <Provider key={i} data={p} now={now} />;
          })}
        </div>
      )}

      <Lid lid={d.lid} />
    </div>
  );
};
