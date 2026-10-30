import { useState } from "react";
import { useAppStore } from "./store";
import { Button } from "./components/ui";
import { Icon } from "./components/icons";
import type { AppLanguage } from "./types";
import RandomArtistLab from "./RandomArtistLab";
import DetectiveArtistLab from "./DetectiveArtistLab";

const HOME = {
  "zh-CN": { title: "画风实验室", subtitle: "目标图自动迭代与随机画师串抽卡是两条独立流程。", back: "返回工具", target: "目标图自动迭代", targetDesc: "本机模型筛选和评分，自动扩展相似画师并迭代到目标。", random: "随机画师串抽卡", randomDesc: "每批重新随机画师与权重，由你选择喜欢的组合。", enter: "进入" },
} satisfies Record<AppLanguage, Record<string, string>>;

type ArtistLabScreen = "home" | "target" | "random";
export default function ArtistLab({ onBack }: { onBack: () => void }) {
  const language = useAppStore((state) => state.settings?.language ?? "zh-CN");
  const [screen, setScreen] = useState<ArtistLabScreen>("home");
  // ToolsHub stays mounted across top-level tabs. Keep this subpage and its
  // in-memory draft alive; only an explicit Back action returns to the index.
  // A fresh application session still starts on the lightweight home screen.
  const open = setScreen;
  if (screen === "target") return <DetectiveArtistLab onBack={() => open("home")} />;
  if (screen === "random") return <RandomArtistLab onBack={() => open("home")} />;
  const text = HOME[language];
  return <main className="artist-lab artist-lab-home"><header className="artist-lab-hero"><div><h2>{text.title}</h2><p>{text.subtitle}</p></div><Button onClick={onBack}>{text.back}</Button></header><section className="artist-lab-mode-grid"><button type="button" className="artist-lab-mode-card reverse" onClick={() => open("target")}><span className="artist-mode-icon"><Icon name="scan" /></span><div><h3>{text.target}</h3><p>{text.targetDesc}</p><b>{text.enter} →</b></div></button><button type="button" className="artist-lab-mode-card random" onClick={() => open("random")}><span className="artist-mode-icon"><Icon name="dice" /></span><div><h3>{text.random}</h3><p>{text.randomDesc}</p><b>{text.enter} →</b></div></button></section></main>;
}
