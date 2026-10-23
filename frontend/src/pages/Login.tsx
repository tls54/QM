import { useState } from "react";
import { ApiError, login, setToken } from "../api";

export default function Login({ onLogin }: { onLogin: () => void }) {
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const token = await login(password);
      setToken(token);
      onLogin();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setError("Incorrect password");
      } else {
        setError("Unable to reach the server. Please try again.");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-screen">
      <form onSubmit={handleSubmit} className="login-form">
        <div className="login-badge">QM</div>
        <h1>QM Inventory</h1>
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoFocus
        />
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={loading || !password}>
          {loading ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
