import React from "react";

export default function XadrezArenaPage() {
  return (
    <iframe
      title="Xadrez Arena"
      src="./index.html"
      style={{ width: "100vw", height: "100vh", border: "none", display: "block" }}
      allow="clipboard-read; clipboard-write"
    />
  );
}
