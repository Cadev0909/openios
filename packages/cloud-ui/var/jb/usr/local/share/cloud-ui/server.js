#!/usr/bin/env node
/**
 * cloud-ui server — lightweight LLM chat UI
 * Runs on http://127.0.0.1:3000
 * Proxies to local llama-server (port 8080) or cloud APIs
 */

const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");
const url = require("url");

const PORT = 3000;
const SHARE_DIR = "/var/jb/usr/local/share/cloud-ui";

// ── Config (stored in /var/jb/var/cloud-ui-config.json) ─────────────────────
const CONFIG_PATH = "/var/jb/var/cloud-ui-config.json";
let config = {
  defaultBackend: "local", // "local" | "openai" | "anthropic" | "gemini"
  openaiKey: "",
  anthropicKey: "",
  geminiKey: "",
  localUrl: "http://127.0.0.1:8080",
};
if (fs.existsSync(CONFIG_PATH)) {
  try {
    config = { ...config, ...JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8")) };
  } catch (_) {}
}

// ── HTML UI ──────────────────────────────────────────────────────────────────
const HTML = `<!DOCTYPE html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>iOS LLM Chat</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,sans-serif;background:#0d0d0d;color:#e8e8e8;height:100dvh;display:flex;flex-direction:column}
  #header{padding:12px 16px;background:#1a1a1a;border-bottom:1px solid #333;display:flex;align-items:center;gap:10px}
  #header h1{font-size:16px;flex:1}
  select,input,button{background:#2a2a2a;color:#e8e8e8;border:1px solid #444;border-radius:8px;padding:6px 10px;font-size:14px}
  #messages{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px}
  .msg{max-width:85%;padding:10px 14px;border-radius:14px;line-height:1.5;white-space:pre-wrap}
  .user{background:#1a4a8a;align-self:flex-end}
  .assistant{background:#1a1a1a;border:1px solid #333;align-self:flex-start}
  .system{background:#2a1a00;border:1px solid #553300;align-self:center;font-size:12px;color:#aaa;max-width:95%}
  #input-row{padding:12px;display:flex;gap:8px;background:#1a1a1a;border-top:1px solid #333}
  #prompt{flex:1;resize:none;height:44px;max-height:120px;font-size:15px}
  #send{padding:10px 18px;background:#1a4a8a;border:none;border-radius:8px;cursor:pointer;font-weight:600}
  #send:disabled{opacity:.4}
  #settings{display:none;position:fixed;inset:0;background:#000a;z-index:10;align-items:center;justify-content:center}
  #settings.open{display:flex}
  #settings-box{background:#1a1a1a;border:1px solid #333;border-radius:16px;padding:20px;width:min(400px,95vw);display:flex;flex-direction:column;gap:12px}
  label{font-size:13px;color:#aaa}
  input[type=text],input[type=password]{width:100%}
</style>
<div id="header">
  <h1>iOS LLM Chat</h1>
  <select id="backend">
    <option value="local">Local (llama.cpp)</option>
    <option value="openai">OpenAI</option>
    <option value="anthropic">Anthropic Claude</option>
    <option value="gemini">Google Gemini</option>
  </select>
  <button onclick="document.getElementById('settings').classList.add('open')">&#9881;</button>
</div>
<div id="messages">
  <div class="msg system">Select a backend above, then start chatting. Local backend requires llama-server running on port 8080.</div>
</div>
<div id="input-row">
  <textarea id="prompt" placeholder="Message..."></textarea>
  <button id="send" onclick="sendMessage()">Send</button>
</div>
<div id="settings">
  <div id="settings-box">
    <b>Settings</b>
    <label>OpenAI API Key<input type="password" id="cfg-openai" placeholder="sk-..."></label>
    <label>Anthropic API Key<input type="password" id="cfg-anthropic" placeholder="sk-ant-..."></label>
    <label>Gemini API Key<input type="password" id="cfg-gemini" placeholder="AIza..."></label>
    <label>Local llama-server URL<input type="text" id="cfg-local" value="http://127.0.0.1:8080"></label>
    <button onclick="saveSettings()">Save</button>
    <button onclick="document.getElementById('settings').classList.remove('open')">Cancel</button>
  </div>
</div>
<script>
let history = [];
const msgs = document.getElementById('messages');
const prompt = document.getElementById('prompt');
const send = document.getElementById('send');
const backend = document.getElementById('backend');

prompt.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
});

function addMsg(role, text) {
  const d = document.createElement('div');
  d.className = 'msg ' + role;
  d.textContent = text;
  msgs.appendChild(d);
  msgs.scrollTop = msgs.scrollHeight;
  return d;
}

async function sendMessage() {
  const text = prompt.value.trim();
  if (!text) return;
  prompt.value = '';
  send.disabled = true;
  addMsg('user', text);
  history.push({ role: 'user', content: text });
  const bubble = addMsg('assistant', '...');
  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ backend: backend.value, messages: history })
    });
    const data = await res.json();
    const reply = data.content || data.error || 'No response';
    bubble.textContent = reply;
    history.push({ role: 'assistant', content: reply });
  } catch(e) {
    bubble.textContent = 'Error: ' + e.message;
  }
  send.disabled = false;
  prompt.focus();
}

function saveSettings() {
  fetch('/api/config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      openaiKey: document.getElementById('cfg-openai').value,
      anthropicKey: document.getElementById('cfg-anthropic').value,
      geminiKey: document.getElementById('cfg-gemini').value,
      localUrl: document.getElementById('cfg-local').value,
    })
  }).then(() => document.getElementById('settings').classList.remove('open'));
}
</script>`;

// ── HTTP helpers ─────────────────────────────────────────────────────────────
function httpsPost(hostname, path, headers, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      { hostname, path, method: "POST", headers: { ...headers, "Content-Length": Buffer.byteLength(data) } },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          try { resolve(JSON.parse(raw)); } catch { resolve({ error: raw }); }
        });
      }
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
}

async function callLocal(messages) {
  return new Promise((resolve) => {
    const body = JSON.stringify({ messages, stream: false });
    const reqUrl = new URL(config.localUrl + "/v1/chat/completions");
    const mod = reqUrl.protocol === "https:" ? https : http;
    const req = mod.request(
      { hostname: reqUrl.hostname, port: reqUrl.port || (reqUrl.protocol === "https:" ? 443 : 80), path: reqUrl.pathname, method: "POST",
        headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) } },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          try {
            const j = JSON.parse(raw);
            resolve({ content: j.choices?.[0]?.message?.content || raw });
          } catch { resolve({ content: raw }); }
        });
      }
    );
    req.on("error", (e) => resolve({ error: e.message }));
    req.write(body);
    req.end();
  });
}

async function callOpenAI(messages) {
  if (!config.openaiKey) return { error: "OpenAI API key not set. Open settings." };
  const j = await httpsPost("api.openai.com", "/v1/chat/completions",
    { "Content-Type": "application/json", "Authorization": `Bearer ${config.openaiKey}` },
    { model: "gpt-4o-mini", messages });
  return { content: j.choices?.[0]?.message?.content || j.error?.message || JSON.stringify(j) };
}

async function callAnthropic(messages) {
  if (!config.anthropicKey) return { error: "Anthropic API key not set. Open settings." };
  const j = await httpsPost("api.anthropic.com", "/v1/messages",
    { "Content-Type": "application/json", "x-api-key": config.anthropicKey, "anthropic-version": "2023-06-01" },
    { model: "claude-3-haiku-20240307", max_tokens: 1024, messages });
  return { content: j.content?.[0]?.text || j.error?.message || JSON.stringify(j) };
}

async function callGemini(messages) {
  if (!config.geminiKey) return { error: "Gemini API key not set. Open settings." };
  const contents = messages.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));
  const j = await httpsPost("generativelanguage.googleapis.com",
    `/v1beta/models/gemini-1.5-flash:generateContent?key=${config.geminiKey}`,
    { "Content-Type": "application/json" }, { contents });
  return { content: j.candidates?.[0]?.content?.parts?.[0]?.text || j.error?.message || JSON.stringify(j) };
}

// ── Server ───────────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const parsed = url.parse(req.url, true);

  if (req.method === "GET" && parsed.pathname === "/") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    return res.end(HTML);
  }

  if (req.method === "POST" && parsed.pathname === "/api/chat") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", async () => {
      try {
        const { backend: be, messages } = JSON.parse(body);
        let result;
        if (be === "openai") result = await callOpenAI(messages);
        else if (be === "anthropic") result = await callAnthropic(messages);
        else if (be === "gemini") result = await callGemini(messages);
        else result = await callLocal(messages);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(result));
      } catch (e) {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  if (req.method === "POST" && parsed.pathname === "/api/config") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const updates = JSON.parse(body);
        // Only accept known keys to avoid injection
        const allowed = ["openaiKey", "anthropicKey", "geminiKey", "localUrl"];
        allowed.forEach((k) => { if (updates[k] !== undefined) config[k] = String(updates[k]); });
        fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf8");
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Cloud UI running at http://127.0.0.1:${PORT}`);
});
