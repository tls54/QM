import { useEffect, useState } from "react";
import { LogOut, Package, ShoppingCart, Layers } from "lucide-react";
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
        <div className="app-brand">
          <span className="app-logo">QM</span>
          <div>
            <h1>QM Inventory</h1>
            <span className="app-subtitle">Kit &amp; bundle manager</span>
          </div>
        </div>
        <button className="logout" onClick={logout}>
          <LogOut size={14} />
          Log out
        </button>
      </header>
      <nav className="tabs">
        <button className={tab === "kits" ? "active" : ""} onClick={() => setTab("kits")}>
          <Package size={16} />
          Kits
        </button>
        <button className={tab === "bundles" ? "active" : ""} onClick={() => setTab("bundles")}>
          <Layers size={16} />
          Bundles
        </button>
        <button className={tab === "shopping" ? "active" : ""} onClick={() => setTab("shopping")}>
          <ShoppingCart size={16} />
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
