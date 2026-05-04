import React from "react";

export default function App() {
  const gameUrl = `${import.meta.env.BASE_URL}xadrez-arena.html`;

  return (
    <iframe
      title="Xadrez Arena"
      src={gameUrl}
      style={{ width: "100vw", height: "100vh", border: "none", display: "block" }}
      allow="clipboard-read; clipboard-write"
    />
  );
}
