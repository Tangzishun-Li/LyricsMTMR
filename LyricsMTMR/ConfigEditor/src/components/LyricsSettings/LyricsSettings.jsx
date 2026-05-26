import { useState, useEffect } from 'react';
import './LyricsSettings.css';

const FONTS = ['System', 'Helvetica', 'Arial', 'Times New Roman', 'Courier New', 'Georgia', 'Verdana', 'Trebuchet MS', 'Impact', 'Comic Sans MS'];

export default function LyricsSettings({ onClose }) {
  const [tab, setTab] = useState('general');
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState(null);

  useEffect(() => {
    fetch('/api/lyricsmtmr/settings')
      .then(r => r.json())
      .then(r => { if (r.success) setSettings(r.data); })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      const r = await fetch('/api/lyricsmtmr/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings })
      });
      const result = await r.json();
      setToast(result.success ? '✅ 已保存' : '❌ 保存失败');
    } catch { setToast('❌ 保存失败'); }
    setSaving(false);
    setTimeout(() => setToast(null), 2000);
  };

  const set = (key, value) => setSettings(prev => ({ ...prev, [key]: value }));

  if (loading) {
    return (
      <div className="ls-overlay" onClick={onClose}>
        <div className="ls-modal" onClick={e => e.stopPropagation()}>
          <div className="ls-loading">加载中...</div>
        </div>
      </div>
    );
  }

  if (!settings) {
    return (
      <div className="ls-overlay" onClick={onClose}>
        <div className="ls-modal" onClick={e => e.stopPropagation()}>
          <div className="ls-loading">无法加载设置</div>
        </div>
      </div>
    );
  }

  return (
    <div className="ls-overlay" onClick={onClose}>
      <div className="ls-modal" onClick={e => e.stopPropagation()}>
        <div className="ls-header">
          <h2>LyricsMTMR 设置</h2>
          <button className="ls-close" onClick={onClose}>✕</button>
        </div>

        <div className="ls-tabs">
          {['general', 'lyrics', 'filters', 'blacklist'].map(t => (
            <button key={t} className={`ls-tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>
              {{general:'通用', lyrics:'歌词', filters:'拦截规则', blacklist:'黑名单'}[t]}
            </button>
          ))}
        </div>

        <div className="ls-body">
          {tab === 'general' && <GeneralTab s={settings} set={set} />}
          {tab === 'lyrics' && <LyricsTab s={settings} set={set} />}
          {tab === 'filters' && <FiltersTab s={settings} set={set} />}
          {tab === 'blacklist' && <BlacklistTab s={settings} set={set} />}
        </div>

        <div className="ls-footer">
          <button className="ls-btn ls-btn-secondary" onClick={onClose}>关闭</button>
          <button className="ls-btn ls-btn-primary" onClick={save} disabled={saving}>
            {saving ? '保存中...' : '保存设置'}
          </button>
        </div>

        {toast && <div className="ls-toast">{toast}</div>}
      </div>
    </div>
  );
}

function Toggle({ label, value, onChange }) {
  return (
    <label className="ls-row">
      <span>{label}</span>
      <input type="checkbox" checked={!!value} onChange={e => onChange(e.target.checked)} />
    </label>
  );
}

function Select({ label, value, options, onChange }) {
  return (
    <label className="ls-row">
      <span>{label}</span>
      <select value={value} onChange={e => onChange(e.target.value)} className="ls-select">
        {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </label>
  );
}

function SliderField({ label, value, min, max, onChange }) {
  return (
    <label className="ls-row">
      <span>{label}</span>
      <div className="ls-slider-group">
        <input type="range" min={min} max={max} value={value} onChange={e => onChange(Number(e.target.value))} />
        <span className="ls-slider-val">{value}</span>
      </div>
    </label>
  );
}

function ColorField({ label, value, onChange }) {
  return (
    <label className="ls-row">
      <span>{label}</span>
      <input type="color" value={value || '#ffffff'} onChange={e => onChange(e.target.value)} className="ls-color" />
    </label>
  );
}

// ── General Tab ────────────────────────────────────
function GeneralTab({ s, set }) {
  return (
    <div className="ls-panel">
      <h3>启动</h3>
      <Toggle label="开机自启" value={s.startAtLogin} onChange={v => set('startAtLogin', v)} />

      <h3>交互</h3>
      <Toggle label="触觉反馈" value={s.hapticFeedback} onChange={v => set('hapticFeedback', v)} />
      <Toggle label="隐藏 Control Strip" value={!s.showControlStrip} onChange={v => set('showControlStrip', !v)} />
      <Toggle label="音量/亮度滑动手势" value={s.multitouchGestures} onChange={v => set('multitouchGestures', v)} />

      <h3>语言</h3>
      <div className="ls-radio-group">
        {[{v:'system',l:'系统默认'},{v:'en',l:'English'},{v:'zh-Hans',l:'中文'}].map(o => (
          <label key={o.v} className="ls-radio">
            <input type="radio" name="lang" checked={s.appLanguage === o.v} onChange={() => set('appLanguage', o.v)} />
            {o.l}
          </label>
        ))}
      </div>

      <h3>音乐源</h3>
      {['spotify','itunes','vox','audirvana','swinsian'].map(p => (
        <Toggle key={p} label={p} value={s.selectedPlayerIds?.includes(p)} onChange={v => {
          const arr = s.selectedPlayerIds || [];
          set('selectedPlayerIds', v ? [...arr, p] : arr.filter(id => id !== p));
        }} />
      ))}
    </div>
  );
}

// ── Lyrics Tab ────────────────────────────────────
function LyricsTab({ s, set }) {
  const [preview, setPreview] = useState('当世界终止时 君と僕の歌よ');
  const progressColor = s.lyricsProgressColor || '#ff9500';
  const textColor = s.lyricsTextColor || '#ffffff';

  return (
    <div className="ls-panel">
      <h3>预览</h3>
      <div className="ls-preview" style={{ background: '#333' }}>
        <span style={{ color: progressColor }}>{preview.slice(0, Math.min(preview.length, 12))}</span>
        <span style={{ color: textColor }}>{preview.slice(Math.min(preview.length, 12))}</span>
      </div>

      <h3>显示</h3>
      <Select label="显示模式" value={s.lyricsDisplayMode || 'karaoke'} onChange={v => set('lyricsDisplayMode', v)}
        options={[{v:'karaoke',l:'卡拉OK'},{v:'static',l:'静态文字'},{v:'artwork',l:'仅封面'}]} />
      <Select label="卡拉OK风格" value={s.lyricsKaraokeStyle || 'progressive'} onChange={v => set('lyricsKaraokeStyle', v)}
        options={[{v:'progressive',l:'平滑渐进'},{v:'jump',l:'逐词跳跃'}]} />

      <h3>颜色</h3>
      <ColorField label="进度颜色" value={progressColor} onChange={v => set('lyricsProgressColor', v)} />
      <ColorField label="文字颜色" value={textColor} onChange={v => set('lyricsTextColor', v)} />

      <h3>字体</h3>
      <Select label="字体" value={s.lyricsFontName || 'System'} onChange={v => set('lyricsFontName', v)}
        options={FONTS.map(f => ({v:f, l:f}))} />
      <SliderField label="字号" value={s.lyricsFontSize || 16} min={10} max={36} onChange={v => set('lyricsFontSize', v)} />

      <h3>封面</h3>
      <Toggle label="显示专辑封面" value={s.lyricsShowArtwork} onChange={v => set('lyricsShowArtwork', v)} />
      <SliderField label="封面尺寸" value={s.lyricsArtworkSize || 24} min={16} max={48} onChange={v => set('lyricsArtworkSize', v)} />

      <h3>交互</h3>
      <Select label="单击操作" value={s.lyricsClickAction || 'original'} onChange={v => set('lyricsClickAction', v)}
        options={[{v:'original',l:'原始歌词'},{v:'translation',l:'翻译'},{v:'romaji',l:'罗马音'}]} />
    </div>
  );
}

// ── Filters Tab ────────────────────────────────────
function FiltersTab({ s, set }) {
  const [newRule, setNewRule] = useState('');
  const keys = s.lyricsFilterKeys || [];

  const addRule = () => {
    if (!newRule.trim()) return;
    set('lyricsFilterKeys', [...keys, newRule.trim()]);
    setNewRule('');
  };

  const removeRule = (idx) => {
    set('lyricsFilterKeys', keys.filter((_, i) => i !== idx));
  };

  const resetRules = () => {
    set('lyricsFilterKeys', ['作詞', '作曲', '編曲', '歌詞', '訳詞', '作词', '作曲', '编曲', '歌词', '翻译', '/^\\s*$/']);
  };

  return (
    <div className="ls-panel">
      <Toggle label="启用歌词过滤" value={s.lyricsFilterEnabled} onChange={v => set('lyricsFilterEnabled', v)} />
      <p className="ls-hint">以 / 开头的为正则表达式，否则为普通文本匹配</p>

      <div className="ls-filter-list">
        {keys.length === 0 && <p className="ls-empty">暂无规则</p>}
        {keys.map((key, i) => (
          <div key={i} className="ls-filter-row">
            <span className={`ls-badge ${key.startsWith('/') ? 'regex' : 'text'}`}>
              {key.startsWith('/') ? 'R' : 'T'}
            </span>
            <code className="ls-filter-text">{key}</code>
            <button className="ls-btn-sm" onClick={() => removeRule(i)}>✕</button>
          </div>
        ))}
      </div>

      <div className="ls-filter-add">
        <input type="text" value={newRule} onChange={e => setNewRule(e.target.value)}
          placeholder="输入规则，以 / 开头为正则" onKeyDown={e => e.key === 'Enter' && addRule()} />
        <button className="ls-btn ls-btn-primary" onClick={addRule}>添加</button>
      </div>

      <button className="ls-btn" onClick={resetRules} style={{ marginTop: 8 }}>恢复默认</button>
    </div>
  );
}

// ── Blacklist Tab ─────────────────────────────────
function BlacklistTab({ s, set }) {
  const ids = s.blacklistedAppIds || [];

  const remove = (id) => {
    set('blacklistedAppIds', ids.filter(i => i !== id));
  };

  return (
    <div className="ls-panel">
      <p className="ls-hint">黑名单中的应用将不会显示自定义 Touch Bar</p>

      <div className="ls-filter-list">
        {ids.length === 0 && <p className="ls-empty">暂无黑名单应用</p>}
        {ids.map(id => (
          <div key={id} className="ls-filter-row">
            <span className="ls-app-name">{id}</span>
            <button className="ls-btn-sm ls-btn-danger" onClick={() => remove(id)}>✕</button>
          </div>
        ))}
      </div>
    </div>
  );
}
