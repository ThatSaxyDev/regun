import React from "react";
import {
  AbsoluteFill,
  Img,
  Sequence,
  staticFile,
  useCurrentFrame,
  interpolate,
  Easing,
} from "remotion";
import { Audio, Video } from "@remotion/media";
import { recordings } from "./weapon-recordings";
const gold = "#e7bd72",
  cream = "#f2ecdc",
  muted = "#b2b7ac";
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const move = (f: number, start = 0, duration = 36) =>
  interpolate(f, [start, start + duration], [0, 1], { ...clamp, easing: ease });
const arsenal = [
  "arsenal",
  "arsenal",
  "arsenal",
  "arsenal",
  "burst_rifle",
  "rail_lance",
  "rivet_driver",
  "cinder_hose",
  "reaper_disc",
  "frost_shotgun",
  "prism_cutter",
  "spore_lobber",
  "scrap_mortar",
  "belt_repeater",
  "longwatch_sniper",
  "twin_verdict",
  "flak_regent",
  "anchor_engine",
  "faultline_driver",
  "cyclone_breacher",
  "mourning_bell",
];
const features = [
  {
    name: ["ARC", "CASTER"],
    atlas: "arsenal",
    frame: 3,
    index: 3,
    role: ["HEAVY BOLTS.", "TWO CHAIN JUMPS."],
    color: "#88d9df",
  },
  {
    name: ["RAIL", "LANCE"],
    atlas: "rail_lance",
    frame: 0,
    index: 5,
    role: ["CHARGE A", "PIERCING STAKE."],
    color: "#e7bd72",
  },
  {
    name: ["FROST", "SHOTGUN"],
    atlas: "frost_shotgun",
    frame: 0,
    index: 9,
    role: ["THREE ICE PELLETS.", "FREEZE ENEMIES."],
    color: "#b4d8ef",
  },
  {
    name: ["RIVET", "DRIVER"],
    atlas: "rivet_driver",
    frame: 0,
    index: 6,
    role: ["PLANT CHARGES.", "RELOAD TO BLAST."],
    color: "#edb591",
  },
];
const introFrames = 180,
  ctaFrames = 420;
export const spotlightDuration =
  introFrames + recordings.reduce((s, r) => s + r.frames, 0) + ctaFrames;
const ctaStart = spotlightDuration - ctaFrames;
function Art({
  atlas,
  frame = 0,
  size = 500,
  style = {},
}: {
  atlas: string;
  frame?: number;
  size?: number;
  style?: React.CSSProperties;
}) {
  return (
    <Img
      src={staticFile(`weapons/${atlas}/${frame}.png`)}
      style={{
        width: size,
        height: size,
        objectFit: "contain",
        imageRendering: "pixelated",
        ...style,
      }}
    />
  );
}
function Back() {
  return (
    <>
      <AbsoluteFill style={{ background: "#161b18" }} />
      <Img
        src={staticFile("foundry_floor.jpg")}
        style={{
          position: "absolute",
          right: -160,
          top: -370,
          width: 1500,
          height: 1500,
          opacity: 0.12,
        }}
      />
      <AbsoluteFill
        style={{
          background: "linear-gradient(90deg,#161b18 18%,transparent 100%)",
        }}
      />
    </>
  );
}
function Header() {
  return (
    <div
      style={{
        position: "absolute",
        left: 100,
        right: 100,
        top: 54,
        display: "flex",
        justifyContent: "space-between",
        fontFamily: "Pixel",
        fontSize: 16,
        color: gold,
      }}
    >
      <span>REGUN / WEAPON SPOTLIGHT</span>
      <span>▪ BETA</span>
    </div>
  );
}
function Words({
  lines,
  size = 73,
  delay = 0,
  firstVisible = false,
  color = cream,
}: {
  lines: string[];
  size?: number;
  delay?: number;
  firstVisible?: boolean;
  color?: string;
}) {
  const f = useCurrentFrame();
  return (
    <div style={{ fontSize: size, fontWeight: 900, lineHeight: 1.16, color }}>
      {lines.map((line, i) => {
        const p = firstVisible ? 1 : move(f, delay + i * 9, 38);
        return (
          <div key={line} style={{ overflow: "hidden", paddingBottom: 7 }}>
            <div style={{ transform: `translateY(${(1 - p) * 115}%)` }}>
              {line}
            </div>
          </div>
        );
      })}
    </div>
  );
}
function Grid({
  selected = -1,
  previous = -1,
}: {
  selected?: number;
  previous?: number;
}) {
  const f = useCurrentFrame();
  const p = move(f, 0, 42);
  const width = 1720,
    step = width / 21;
  const pos = previous < 0 ? selected : previous + (selected - previous) * p;
  return (
    <div
      style={{
        position: "absolute",
        left: 100,
        bottom: 50,
        width,
        height: 74,
        display: "flex",
        justifyContent: "space-between",
      }}
    >
      {arsenal.map((a, i) => (
        <div
          key={i}
          style={{
            width: 74,
            height: 74,
            opacity: selected < 0 || i === selected ? 1 : 0.4,
            transform: `translateY(${i === selected ? -6 * p : 0}px)`,
          }}
        >
          <Art atlas={a} frame={i < 4 ? i : 0} size={74} />
        </div>
      ))}
      {selected >= 0 && (
        <div
          style={{
            position: "absolute",
            left: pos * step,
            top: -6 * p,
            width: 74,
            height: 74,
            border: `2px solid ${gold}`,
            background: "#e7bd7210",
          }}
        />
      )}
    </div>
  );
}
function Intro() {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Back />
      <Header />
      <div style={{ position: "absolute", left: 100, top: 235 }}>
        <div style={{ fontFamily: "Pixel", fontSize: 19, color: gold }}>
          21 WEAPONS TO DISCOVER
        </div>
        <div style={{ marginTop: 30 }}>
          <Words lines={["MEET YOUR", "NEXT WEAPON."]} size={96} firstVisible />
        </div>
        <div
          style={{
            position: "relative",
            marginTop: 30,
            fontSize: 28,
            color: muted,
            overflow: "hidden",
          }}
        >
          <div style={{ transform: `translateY(${(1 - move(f, 10)) * 110}%)` }}>
            Four weapons. See them in action.
          </div>
        </div>
        <div
          style={{
            width: interpolate(f, [0, 150], [80, 620], clamp),
            height: 5,
            background: gold,
            marginTop: 36,
          }}
        />
      </div>
      {features.slice(0, 3).map((w, i) => (
        <Art
          key={w.index}
          atlas={w.atlas}
          frame={w.frame}
          size={460}
          style={{
            position: "absolute",
            left: 1190,
            top: 100 + i * 195,
            transform: `rotate(-10deg) translateX(${(1 - move(f, i * 12)) * 25}px)`,
          }}
        />
      ))}
      <Grid />
    </AbsoluteFill>
  );
}
function Feature({ index }: { index: number }) {
  const f = useCurrentFrame();
  const w = features[index],
    r = recordings[index];
  const p = move(f, 0, 44);
  return (
    <AbsoluteFill>
      <Back />
      <Header />
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 160,
          color: w.color,
          fontFamily: "Pixel",
          fontSize: 17,
        }}
      >
        0{index + 1} / 04
      </div>
      <div style={{ position: "absolute", left: 100, top: 220, width: 540 }}>
        <Words lines={w.name} size={index === 2 ? 64 : 79} />
      </div>
      <div style={{ position: "absolute", left: 100, top: 472, width: 510 }}>
        <Words lines={w.role} size={25} delay={30} color={w.color} />
        <div
          style={{
            width: 160 * move(f, 48, 48),
            height: 4,
            background: w.color,
            marginTop: 22,
          }}
        />
      </div>
      <Art
        atlas={w.atlas}
        frame={w.frame}
        size={450}
        style={{
          position: "absolute",
          left: 78,
          top: 580,
          transform: `rotate(${(1 - p) * -8}deg) translateX(${(1 - p) * -60}px)`,
        }}
      />
      <div style={{ position: "absolute", left: 660, top: 200, width: 1160 }}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            color: muted,
            fontFamily: "Pixel",
            fontSize: 12,
            marginBottom: 17,
          }}
        >
          <span>ACTUAL GAMEPLAY</span>
          <span>BUILD IN PROGRESS</span>
        </div>
        <div
          style={{
            position: "relative",
            padding: 7,
            border: "1px solid #625a44",
            background: "#1e241e",
            boxShadow: "12px 12px 0 #101510",
          }}
        >
          <Video
            src={staticFile(r.file)}
            volume={0.16}
            objectFit="contain"
            style={{ width: "100%", aspectRatio: "1920/888", display: "block" }}
          />
          <div
            style={{
              position: "absolute",
              left: -1,
              top: -2,
              width: 42,
              height: 4,
              background: w.color,
            }}
          />
          <div
            style={{
              position: "absolute",
              right: -1,
              bottom: -2,
              width: 42,
              height: 4,
              background: w.color,
            }}
          />
        </div>
        <div style={{ height: 4, background: "#353c32", marginTop: 20 }}>
          <div
            style={{
              height: 4,
              width: `${(100 * f) / r.frames}%`,
              background: w.color,
            }}
          />
        </div>
        <div
          style={{
            marginTop: 26,
            display: "flex",
            justifyContent: "space-between",
            color: muted,
            fontSize: 17,
          }}
        >
          <span>Real run. Upgraded loadout.</span>
          <span>
            {(Math.min(f, r.frames) / 60).toFixed(1)}s /{" "}
            {r.source_duration.toFixed(1)}s
          </span>
        </div>
      </div>
      <Grid
        selected={w.index}
        previous={index > 0 ? features[index - 1].index : w.index}
      />
    </AbsoluteFill>
  );
}
function Invite() {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Back />
      <Header />
      <div style={{ position: "absolute", left: 100, top: 200 }}>
        <Words lines={["THAT'S FOUR."]} size={84} />
        <Words
          lines={["DISCOVER THE REST."]}
          size={76}
          color={gold}
          delay={10}
        />
        <div
          style={{
            position: "relative",
            fontSize: 28,
            marginTop: 35,
            transform: `translateY(${(1 - move(f, 32)) * 25}px)`,
            opacity: move(f, 32),
          }}
        >
          Join the beta. Play to unlock more weapons.
        </div>
        <div style={{ display: "flex", gap: 20, marginTop: 38 }}>
          {["iOS · TestFlight", "Android · App Tester"].map((s, i) => (
            <div
              key={s}
              style={{
                padding: "22px 25px",
                fontSize: 23,
                border: `2px solid ${gold}`,
                color: i === 0 ? "#161b18" : cream,
                background: i === 0 ? gold : "transparent",
                transform: `translateY(${(1 - move(f, 46 + i * 10)) * 45}px)`,
                opacity: move(f, 46 + i * 10),
              }}
            >
              {s}
            </div>
          ))}
        </div>
        <div
          style={{
            fontSize: 39,
            color: gold,
            marginTop: 40,
            opacity: move(f, 65),
          }}
        >
          regun.kiishi.space
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          right: 130,
          top: 285,
          textAlign: "center",
          opacity: move(f, 22),
        }}
      >
        <Img
          src={staticFile("beta-qr.png")}
          style={{ width: 340, height: 340, imageRendering: "pixelated" }}
        />
        <div
          style={{
            fontFamily: "Pixel",
            fontSize: 14,
            color: gold,
            marginTop: 25,
          }}
        >
          SCAN TO JOIN
        </div>
      </div>
      <Grid />
    </AbsoluteFill>
  );
}
export function WeaponSpotlight() {
  let start = introFrames;
  return (
    <AbsoluteFill
      style={{ fontFamily: "Orbitron", color: cream, background: "#161b18" }}
    >
      <Sequence durationInFrames={introFrames}>
        <Intro />
      </Sequence>
      {recordings.map((r, i) => {
        const at = start;
        start += r.frames;
        return (
          <Sequence key={r.key} from={at} durationInFrames={r.frames}>
            <Feature index={i} />
          </Sequence>
        );
      })}
      <Sequence from={ctaStart} durationInFrames={ctaFrames}>
        <Invite />
      </Sequence>
      <Audio
        src={staticFile("space_synth_score.wav")}
        volume={(f) =>
          interpolate(
            f,
            [0, 24, spotlightDuration - 180, spotlightDuration - 1],
            [0, 0.63, 0.63, 0],
            clamp,
          )
        }
      />
    </AbsoluteFill>
  );
}
