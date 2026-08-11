"use client";

export default function GlobalError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body
        style={{
          display: "flex",
          minHeight: "100vh",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: "12px",
          fontFamily: "system-ui, sans-serif",
          textAlign: "center",
          padding: "24px",
        }}
      >
        <p style={{ fontSize: "1rem", fontWeight: 600 }}>Something went wrong</p>
        <p style={{ fontSize: "0.875rem", color: "#71717a", maxWidth: "24rem" }}>
          PocketTill DataMaster hit an unexpected error. Try reloading the page.
        </p>
        <button
          onClick={reset}
          style={{
            marginTop: "4px",
            borderRadius: "6px",
            border: "1px solid #5170FF",
            color: "#5170FF",
            background: "transparent",
            padding: "6px 14px",
            fontSize: "0.875rem",
            cursor: "pointer",
          }}
        >
          Try again
        </button>
      </body>
    </html>
  );
}
