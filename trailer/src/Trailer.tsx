import React from "react";
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  Easing,
} from "remotion";
import { Audio } from "@remotion/media";
import "./style.css";
import { loadFont } from "@remotion/fonts";
void loadFont({
  family: "Orbitron",
  url: staticFile("Orbitron-Black.ttf"),
  weight: "900",
});
void loadFont({
  family: "Orbitron",
  url: staticFile("Orbitron-Medium.ttf"),
  weight: "400",
});
void loadFont({ family: "Pixel", url: staticFile("PressStart2P-Regular.ttf") });
const gold = "#e7bd72",
  cream = "#f2ecdc",
  muted = "#aab5ab";
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const chars = [
  "rook",
  "scrapper",
  "warden",
  "flint",
  "vesper",
  "fuse",
  "moth",
  "coil",
  "suture",
  "harrow",
];
const bosses = [
  "shadow",
  "demon",
  "queen",
  "bellkeeper",
  "magistrate",
  "saint",
  "sovereign",
  "marshal",
];
const names = [
  "SHADOW",
  "DEMON",
  "SCORPION QUEEN",
  "THE BELLKEEPER",
  "CHAIN MAGISTRATE",
  "THE MIRROR SAINT",
  "KILN SOVEREIGN",
  "THE LAST MARSHAL",
];
const weapons = [
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
const file = (p: string) => staticFile(p);
function Sprite({
  kind,
  frame = 0,
  size = 350,
  style = {},
}: {
  kind: string;
  frame?: number;
  size?: number;
  style?: React.CSSProperties;
}) {
  return (
    <Img
      src={file(`${kind}/${frame}.png`)}
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
function Dust() {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: 26 }, (_, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: (i * 137.7 + f * (0.12 + (i % 3) * 0.08)) % 1920,
            top: (i * 83.1 - f * 0.14 + 1200) % 1080,
            width: i % 4 === 0 ? 4 : 2,
            height: i % 4 === 0 ? 4 : 2,
            background: i % 4 === 0 ? gold : "#d8dfcf",
            opacity: 0.12 + (i % 5) * 0.035,
          }}
        />
      ))}
    </AbsoluteFill>
  );
}
function Grain() {
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        boxShadow: "inset 0 0 240px 90px #080d0bcc",
        background:
          "repeating-linear-gradient(0deg,transparent 0px,transparent 3px,#0000000c 4px)",
      }}
    />
  );
}
function Floor({ foundry = false }: { foundry?: boolean }) {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        backgroundImage: `url(${file(foundry ? "foundry_floor.jpg" : "breach_floor.jpg")})`,
        backgroundSize: "850px",
        transform: `scale(1.12) translate(${-f * 0.05}px,${f * 0.03}px)`,
        filter: "brightness(.40) saturate(.78)",
      }}
    />
  );
}
function Label({
  children,
  style = {},
}: {
  children: React.ReactNode;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        fontFamily: "Pixel",
        fontSize: 16,
        letterSpacing: 3,
        color: gold,
        ...style,
      }}
    >
      {children}
    </div>
  );
}
function Head({
  children,
  style = {},
}: {
  children: React.ReactNode;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        fontSize: 86,
        fontWeight: 900,
        lineHeight: 1.08,
        letterSpacing: -2,
        ...style,
      }}
    >
      {children}
    </div>
  );
}
function Scene({
  children,
  length,
}: {
  children: React.ReactNode;
  length: number;
}) {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        opacity: interpolate(
          f,
          [0, 7, length - 10, length],
          [0, 1, 1, 0],
          clamp,
        ),
        overflow: "hidden",
      }}
    >
      {children}
    </AbsoluteFill>
  );
}
function Intro() {
  const f = useCurrentFrame();
  return (
    <Scene length={180}>
      <Img
        src={file("home_hideout_v2.jpg")}
        style={{
          position: "absolute",
          width: 1920,
          height: 1280,
          objectFit: "cover",
          top: -100,
          transform: `scale(${1.03 + f * 0.00045})`,
          transformOrigin: "68% 57%",
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg,#080e0be8 0%,#080e0baf 34%,transparent 72%),linear-gradient(0deg,#080d0b 0%,transparent 35%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 148,
          top: 295,
          opacity: interpolate(f, [18, 42], [0, 1], clamp),
          transform: `translateY(${interpolate(f, [18, 55], [25, 0], { ...clamp, easing: ease })}px)`,
        }}
      >
        <Label>THE WORLD FELL.</Label>
        <Head style={{ marginTop: 35, fontSize: 101 }}>
          YOU'RE
          <br />
          STILL HERE.
        </Head>
        <div
          style={{ width: 82, height: 5, background: gold, marginTop: 38 }}
        />
      </div>
      <Dust />
      <Grain />
      <Label
        style={{
          position: "absolute",
          bottom: 95,
          left: 150,
          fontSize: 12,
          color: muted,
        }}
      >
        REGUN / SURVIVAL BEGINS
      </Label>
    </Scene>
  );
}
function Survivors() {
  const f = useCurrentFrame();
  return (
    <Scene length={180}>
      <Floor />
      <div style={{ position: "absolute", top: 104, left: 140 }}>
        <Label>CHOOSE YOUR SURVIVOR</Label>
        <Head style={{ marginTop: 23 }}>TEN WAYS TO FIGHT BACK.</Head>
      </div>
      {chars.map((c, i) => {
        const arrival = interpolate(f, [8 + i * 3, 28 + i * 3], [0, 1], {
          ...clamp,
          easing: ease,
        });
        const front = i === 0;
        return (
          <div
            key={c}
            style={{
              position: "absolute",
              left: 80 + i * 174,
              top: front ? 365 : 410,
              opacity: arrival,
              transform: `translateY(${(1 - arrival) * 100}px)`,
            }}
          >
            <div
              style={{
                position: "absolute",
                left: 30,
                bottom: 45,
                width: 180,
                height: 35,
                borderRadius: "50%",
                background: "#060908aa",
                filter: "blur(9px)",
              }}
            />
            <Sprite
              kind={`characters/${c}`}
              frame={Math.floor(f / 5) % 4}
              size={front ? 330 : 285}
              style={{ filter: front ? "brightness(1.08)" : "brightness(.83)" }}
            />
            <div
              style={{
                textAlign: "center",
                fontFamily: "Pixel",
                fontSize: 13,
                color: front ? gold : muted,
                marginTop: 15,
              }}
            >
              {c.toUpperCase()}
            </div>
          </div>
        );
      })}
      <Dust />
      <Grain />
      <div
        style={{
          position: "absolute",
          left: 145,
          bottom: 90,
          fontSize: 22,
          color: muted,
          letterSpacing: 5,
        }}
      >
        PICK A FIGHTING CHANCE.
      </div>
    </Scene>
  );
}
function Arsenal() {
  const f = useCurrentFrame();
  const focus = Math.min(3, Math.floor(f / 48));
  const selected = ["arsenal", "rail_lance", "frost_shotgun", "mourning_bell"][
    focus
  ];
  const titles = ["SHOTGUN", "RAIL LANCE", "FROST SHOTGUN", "MOURNING BELL"];
  const tags = [
    "MAKE SOME ROOM.",
    "PUNCH THROUGH.",
    "STOP THEM COLD.",
    "LET IT RING.",
  ];
  return (
    <Scene length={210}>
      <Floor foundry />
      <div style={{ position: "absolute", left: 140, top: 100 }}>
        <Label>BUILD YOUR ARSENAL</Label>
        <Head style={{ marginTop: 25 }}>
          21 WEAPONS.
          <br />
          MAKE THEM COUNT.
        </Head>
      </div>
      <div
        style={{
          position: "absolute",
          left: 1000,
          top: 165,
          transform: `rotate(-9deg) translateX(${interpolate(f % 48, [0, 14], [50, 0], { ...clamp, easing: ease })}px)`,
        }}
      >
        <Sprite kind={`weapons/${selected}`} size={720} />
      </div>
      <div style={{ position: "absolute", left: 1080, top: 720 }}>
        <Label style={{ fontSize: 22 }}>{titles[focus]}</Label>
        <div
          style={{
            color: muted,
            fontSize: 20,
            letterSpacing: 4,
            marginTop: 25,
          }}
        >
          {tags[focus]}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 115,
          bottom: 160,
          width: 800,
          display: "flex",
          flexWrap: "wrap",
          gap: 0,
        }}
      >
        {weapons.map((w, i) => (
          <Sprite
            key={i}
            kind={`weapons/${w}`}
            frame={i < 4 ? i : 0}
            size={110}
            style={{
              opacity: interpolate(f, [i * 2, 20 + i * 2], [0, 0.8], clamp),
            }}
          />
        ))}
      </div>
      <Dust />
      <Grain />
    </Scene>
  );
}
function Build() {
  const f = useCurrentFrame();
  return (
    <Scene length={180}>
      <Floor />
      <div style={{ position: "absolute", left: 140, top: 110 }}>
        <Label>EVERY RUN. A NEW BUILD.</Label>
        <Head style={{ marginTop: 25 }}>
          ADAPT.
          <br />
          HIT HARDER.
        </Head>
      </div>
      <div
        style={{
          position: "absolute",
          left: 1050,
          top: 245,
          transform: `scale(${1 + f * 0.0003})`,
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 50,
            top: 370,
            width: 350,
            height: 85,
            borderRadius: "50%",
            background: "#050806aa",
          }}
        />
        <Sprite
          kind="characters/rook"
          frame={Math.floor(f / 5) % 4}
          size={480}
        />
        <Sprite
          kind="weapons/arsenal"
          size={210}
          style={{
            position: "absolute",
            left: 205,
            top: 125,
            transform: `rotate(-8deg) translateX(${f % 24 < 3 ? -8 : 0}px)`,
          }}
        />
        {[0, 1, 2, 3, 4].map((i) => (
          <Sprite
            key={i}
            kind="effects/combat_materials"
            frame={[0, 4, 8, 12, 16][i]}
            size={170}
            style={{
              position: "absolute",
              left: 210 + Math.cos(i * 1.256 + f * 0.006) * 290,
              top: 170 + Math.sin(i * 1.256 + f * 0.006) * 260,
              opacity: 0.65,
              transform: `rotate(${i * 47}deg)`,
            }}
          />
        ))}
      </div>
      <div
        style={{
          position: "absolute",
          left: 146,
          top: 570,
          borderLeft: `4px solid ${gold}`,
          paddingLeft: 35,
        }}
      >
        <div style={{ fontSize: 40, color: gold }}>41 UPGRADES</div>
        <div
          style={{
            fontSize: 24,
            letterSpacing: 3,
            color: muted,
            marginTop: 24,
          }}
        >
          FIND YOUR COMBINATION.
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 145,
          bottom: 115,
          fontFamily: "Pixel",
          fontSize: 18,
          letterSpacing: 3,
        }}
      >
        MOVE. AIM. RELOAD. SURVIVE.
      </div>
      <Dust />
      <Grain />
    </Scene>
  );
}
function Bosses() {
  const f = useCurrentFrame();
  const index = Math.min(7, Math.floor(f / 23));
  return (
    <Scene length={180}>
      <Floor foundry />
      <div style={{ position: "absolute", left: 140, top: 110 }}>
        <Label>THEY OWN THE RUINS.</Label>
        <Head style={{ marginTop: 25 }}>TAKE THEM BACK.</Head>
      </div>
      {bosses.map((b, i) => (
        <div
          key={b}
          style={{
            position: "absolute",
            left: 75 + i * 216,
            top: 365,
            opacity: interpolate(
              f,
              [i * 3, 16 + i * 3],
              [0, i === index ? 1 : 0.46],
              clamp,
            ),
            transform: `translateY(${i === index ? -16 : 0}px)`,
          }}
        >
          <Sprite
            kind={`bosses/${b}`}
            frame={Math.floor(f / 6) % 4}
            size={340}
            style={{
              filter: i === index ? "brightness(1.14)" : "brightness(.68)",
            }}
          />
        </div>
      ))}
      <div style={{ position: "absolute", bottom: 140, left: 145 }}>
        <Label style={{ fontSize: 26 }}>8 BOSSES. NO EASY WAY OUT.</Label>
        <div
          style={{
            marginTop: 26,
            fontSize: 22,
            color: muted,
            letterSpacing: 5,
          }}
        >
          {names[index]}
        </div>
      </div>
      <Dust />
      <Grain />
    </Scene>
  );
}
function End() {
  const f = useCurrentFrame();
  return (
    <Scene length={150}>
      <Floor />
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 42%,#273c3355,#080d0bef 75%)",
        }}
      />
      <Img
        src={file("rook_mark.png")}
        style={{
          position: "absolute",
          width: 270,
          height: 270,
          objectFit: "contain",
          left: 825,
          top: 105,
          opacity: interpolate(f, [5, 25], [0, 1], clamp),
          transform: `translateY(${interpolate(f, [0, 30], [20, 0], { ...clamp, easing: ease })}px)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 390,
          width: "100%",
          textAlign: "center",
          fontSize: 205,
          fontWeight: 900,
          letterSpacing: 20,
          lineHeight: 1,
          color: cream,
        }}
      >
        REGUN
      </div>
      <div
        style={{
          position: "absolute",
          top: 650,
          width: "100%",
          textAlign: "center",
        }}
      >
        <Label style={{ fontSize: 23 }}>ONE MORE ROUND.</Label>
        <div
          style={{
            marginTop: 52,
            fontSize: 20,
            letterSpacing: 7,
            color: muted,
          }}
        >
          AIM. SURVIVE. EVOLVE.
        </div>
      </div>
      <Dust />
      <Grain />
      <div
        style={{
          position: "absolute",
          bottom: 65,
          width: "100%",
          textAlign: "center",
          fontSize: 12,
          letterSpacing: 4,
          color: "#78877d",
        }}
      >
        IN-GAME ART & SOUND • CINEMATIC TEASER
      </div>
    </Scene>
  );
}
function Cue({
  at,
  src,
  volume = 0.4,
}: {
  at: number;
  src: string;
  volume?: number;
}) {
  return (
    <Sequence from={at} durationInFrames={50}>
      <Audio src={file(src)} volume={volume} />
    </Sequence>
  );
}
export function Trailer() {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{ background: "#080d0b", fontFamily: "Orbitron", color: cream }}
    >
      <Sequence durationInFrames={180}>
        <Intro />
      </Sequence>
      <Sequence from={180} durationInFrames={180}>
        <Survivors />
      </Sequence>
      <Sequence from={360} durationInFrames={210}>
        <Arsenal />
      </Sequence>
      <Sequence from={570} durationInFrames={180}>
        <Build />
      </Sequence>
      <Sequence from={750} durationInFrames={180}>
        <Bosses />
      </Sequence>
      <Sequence from={930} durationInFrames={150}>
        <End />
      </Sequence>
      <Sequence durationInFrames={186}>
        <Audio
          src={file("music_menu.wav")}
          volume={(v) =>
            interpolate(v, [0, 18, 150, 186], [0, 0.52, 0.52, 0], clamp)
          }
        />
      </Sequence>
      <Sequence from={172}>
        <Audio
          src={file("music_boss.wav")}
          loop
          volume={(v) =>
            interpolate(
              v,
              [0, 16, 735, 770, 850, 908],
              [0, 0.56, 0.56, 0.38, 0.38, 0],
              clamp,
            )
          }
        />
      </Sequence>
      <Cue at={180} src="upgrade_pulse.wav" volume={0.3} />
      <Cue at={365} src="shot_shotgun_0.wav" />
      <Cue at={411} src="shot_railLance_0.wav" volume={0.32} />
      <Cue at={570} src="upgrade_pulse.wav" volume={0.35} />
      <Cue at={752} src="blast.wav" volume={0.28} />
      <Cue at={930} src="shot_shotgun_0.wav" volume={0.45} />
      <AbsoluteFill
        style={{
          background: "#080d0b",
          opacity: interpolate(f, [0, 14, 1060, 1079], [1, 0, 0, 1], clamp),
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
}
