import { useEffect, useState } from "react";
import { clearToken, getToken } from "./api";
import Login from "./pages/Login";
import Kits from "./pages/Kits";
import Bundles from "./pages/Bundles";
import Shopping from "./pages/Shopping";
import "./App.css";

type Tab = "kits" | "bundles" | "shopping";

export default function App() {
  const [authed, setAuthed] = useState(() => !!getToken());
  const [tab, setTab] = useState<Tab>("kits");

  useEffect(() => {
    function onUnauthorized() {
      setAuthed(false);
    }
    window.addEventListener("qm-unauthorized", onUnauthorized);
    return () => window.removeEventListener("qm-unauthorized", onUnauthorized);
  }, []);

  if (!authed) {
    return <Login onLogin={() => setAuthed(true)} />;
  }

  function logout() {
    clearToken();
    setAuthed(false);
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>QM Inventory</h1>
        <button className="logout" onClick={logout}>
          Log out
        </button>
      </header>
      <nav className="tabs">
        <button className={tab === "kits" ? "active" : ""} onClick={() => setTab("kits")}>
          Kits
        </button>
        <button className={tab === "bundles" ? "active" : ""} onClick={() => setTab("bundles")}>
          Bundles
        </button>
        <button className={tab === "shopping" ? "active" : ""} onClick={() => setTab("shopping")}>
          Shopping
        </button>
      </nav>
      <main>
        {tab === "kits" && <Kits />}
        {tab === "bundles" && <Bundles />}
        {tab === "shopping" && <Shopping />}
      </main>
    </div>
  );
}
