const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json({ limit: '10mb' }));

// ── Config Paths ──────────────────────────────────────
const getItemsPath = () => {
  return path.join(os.homedir(), 'Library', 'Application Support', 'LyricsMTMR', 'items.json');
};

const getPreferencesPath = () => {
  return path.join(os.homedir(), 'Library', 'Preferences', 'com.toxblh.mtmr.plist');
};

// ── Static Files (built dist) ─────────────────────────
const distPath = path.join(__dirname, '..', 'dist');
app.use(express.static(distPath));

// ── Helper: read plist-like file ──────────────────────
async function readPrefs() {
  // UserDefaults on macOS stores as binary plist
  // We use a simple JSON file alongside for compatibility
  const prefsPath = path.join(os.homedir(), 'Library', 'Application Support', 'LyricsMTMR', 'settings.json');
  try {
    await fs.access(prefsPath);
    const content = await fs.readFile(prefsPath, 'utf8');
    return JSON.parse(content);
  } catch {
    return {};
  }
}

async function writePrefs(data) {
  const dir = path.join(os.homedir(), 'Library', 'Application Support', 'LyricsMTMR');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'settings.json'), JSON.stringify(data, null, 2), 'utf8');
}

// Read the actual macOS preferences using shell defaults command
async function readUserDefaults() {
  const bundleId = 'com.toxblh.mtmr';
  const { execSync } = require('child_process');
  const result = {};
  const keys = [
    'hapticFeedback', 'showControlStrip', 'multitouchGestures',
    'appLanguage', 'selectedPlayerIds', 'blacklistedAppIds',
    'lyricsFilterEnabled', 'lyricsFilterKeys', 'lyricsDisplayMode',
    'lyricsKaraokeStyle', 'lyricsProgressColor', 'lyricsTextColor',
    'lyricsFontName', 'lyricsFontSize', 'lyricsShowArtwork',
    'lyricsArtworkSize', 'lyricsClickAction'
  ];
  for (const key of keys) {
    try {
      const out = execSync(
        `defaults read ${bundleId} ${key} 2>/dev/null || echo "__NULL__"`,
        { encoding: 'utf8', timeout: 2000 }
      ).trim();
      if (out !== '__NULL__' && out !== '') {
        // Try to parse as JSON (for arrays, dicts, numbers, booleans)
        try { result[key] = JSON.parse(out); }
        catch { result[key] = out; }
      }
    } catch { /* key not found */ }
  }
  return result;
}

async function writeUserDefaults(key, value) {
  const bundleId = 'com.toxblh.mtmr';
  const { execSync } = require('child_process');
  let valStr;
  if (typeof value === 'boolean') {
    valStr = value ? 'YES' : 'NO';
    execSync(`defaults write ${bundleId} ${key} -bool ${valStr}`, { timeout: 2000 });
  } else if (typeof value === 'number') {
    execSync(`defaults write ${bundleId} ${key} -float ${value}`, { timeout: 2000 });
  } else if (Array.isArray(value)) {
    const arrStr = value.map(v => `"${v}"`).join(' ');
    execSync(`defaults write ${bundleId} ${key} -array ${arrStr}`, { timeout: 2000 });
  } else {
    execSync(`defaults write ${bundleId} ${key} -string "${value}"`, { timeout: 2000 });
  }
}

async function writeAllUserDefaults(settings) {
  for (const [key, value] of Object.entries(settings)) {
    await writeUserDefaults(key, value);
  }
}

// ── Items API ─────────────────────────────────────────
app.get('/api/load-mtmr', async (req, res) => {
  try {
    const itemsPath = getItemsPath();
    try { await fs.access(itemsPath); } catch { return res.json({ success: true, data: [] }); }
    const content = await fs.readFile(itemsPath, 'utf8');
    const data = JSON.parse(content);
    res.json({ success: true, data });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

app.post('/api/save-mtmr', async (req, res) => {
  try {
    const { data } = req.body;
    if (!Array.isArray(data)) return res.status(400).json({ success: false, error: 'Expected array' });
    const itemsPath = getItemsPath();
    await fs.mkdir(path.dirname(itemsPath), { recursive: true });
    await fs.writeFile(itemsPath, JSON.stringify(data, null, 2), 'utf8');
    res.json({ success: true });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

app.get('/api/config-path', (req, res) => {
  res.json({ success: true, path: getItemsPath() });
});

// ── LyricsMTMR Settings API ───────────────────────────
// GET all settings
app.get('/api/lyricsmtmr/settings', async (req, res) => {
  try {
    const defaults = await readUserDefaults();
    const prefs = await readPrefs();
    res.json({ success: true, data: { ...defaults, ...prefs } });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// POST save settings
app.post('/api/lyricsmtmr/settings', async (req, res) => {
  try {
    const { settings } = req.body;
    if (!settings || typeof settings !== 'object') {
      return res.status(400).json({ success: false, error: 'Expected settings object' });
    }
    await writeAllUserDefaults(settings);
    await writePrefs(settings);
    res.json({ success: true, message: 'Settings saved' });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// ── Health ────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'LyricsMTMR Designer running' });
});

// ── SPA Fallback ──────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(distPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`LyricsMTMR Designer running on http://localhost:${PORT}`);
  console.log(`Config path: ${getItemsPath()}`);
});
