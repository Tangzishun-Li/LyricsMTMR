import { useState, useEffect, useRef } from 'react';
import {
  DndContext,
  DragOverlay,
  pointerWithin,
  useSensor,
  useSensors,
  PointerSensor,
  KeyboardSensor,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
} from '@dnd-kit/sortable';
import { AppProvider, useApp } from './context/AppContext';
import TouchBar from './components/TouchBar/TouchBar';
import TouchBarItem from './components/TouchBar/TouchBarItem';
import Palette from './components/Palette/Palette';
import PropertiesPanel from './components/Properties/PropertiesPanel';
import JsonOutput from './components/JsonOutput/JsonOutput';
import { getElementDefinition, createElement } from './data/elementDefinitions';
import './App.css';
import './components/LyricsSettings/LyricsSettings.css';

function EditorView() {
  const {
    addItem, selectItem, items, reorderItems, selectedItemId, removeItem, loadItems, clearAll,
    slotIndex, slots, isDirty, shouldEnableSave, switchSlot, saveSlot, resetSlot, renameSlot,
    loadFromMTMR, saveToMTMR,
  } = useApp();
  const [activeId, setActiveId] = useState(null);
  const [activeType, setActiveType] = useState(null);
  const [showProperties, setShowProperties] = useState(true);
  const [showJsonSection, setShowJsonSection] = useState(true);
  const [errorToast, setErrorToast] = useState(null);
  const [editingSlotName, setEditingSlotName] = useState(false);
  const [slotNameValue, setSlotNameValue] = useState('');
  const slotNameInputRef = useRef(null);

  const activeSlot = slots[slotIndex] || { name: '', saved: false, items: [] };

  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        if (shouldEnableSave) handleUpdateMTMR();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [shouldEnableSave]);

  useEffect(() => { if (selectedItemId) setShowProperties(true); }, [selectedItemId]);

  const startRenameSlot = () => {
    setSlotNameValue(activeSlot.name);
    setEditingSlotName(true);
    setTimeout(() => slotNameInputRef.current?.focus(), 50);
  };
  const commitRenameSlot = () => {
    const trimmed = slotNameValue.trim();
    if (trimmed) renameSlot(trimmed);
    setEditingSlotName(false);
  };

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  const handleDragStart = (event) => {
    const { active } = event;
    setActiveId(active.id);
    setActiveType(active.data.current?.type === 'palette-item' ? 'palette' : 'touchbar');
  };

  const handleDragEnd = (event) => {
    const { active, over } = event;
    if (active.data.current?.type === 'palette-item') {
      if (over) {
        const elementType = active.data.current.elementType;
        const newItem = addItem(elementType);
        if (newItem) selectItem(newItem.id);
      }
    } else if (over && active.id !== over.id) {
      const oldIndex = items.findIndex((item) => item.id === active.id);
      const newIndex = items.findIndex((item) => item.id === over.id);
      if (oldIndex !== -1 && newIndex !== -1) reorderItems(arrayMove(items, oldIndex, newIndex));
    }
    setActiveId(null);
    setActiveType(null);
  };

  const handleLoadFromMTMR = async () => {
    try {
      const result = await loadFromMTMR();
      setErrorToast(result.success ? '✅ 成功从 MTMR 加载配置' : `❌ 加载失败: ${result.error}`);
    } catch (error) { setErrorToast(`❌ 错误: ${error.message}`); }
    setTimeout(() => setErrorToast(null), 3000);
  };

  const handleUpdateMTMR = async () => {
    try {
      const result = await saveToMTMR();
      setErrorToast(result.success ? '✅ 成功更新 MTMR 配置' : `❌ 保存失败: ${result.error}`);
    } catch (error) { setErrorToast(`❌ 错误: ${error.message}`); }
    setTimeout(() => setErrorToast(null), 3000);
  };

  const activeItem = activeType === 'touchbar' ? items.find((item) => item.id === activeId) : null;
  const activeItemDef = activeItem ? getElementDefinition(activeItem.type) : null;
  const paletteItemDef = activeType === 'palette' && activeId
    ? getElementDefinition(activeId.replace('palette-', ''))
    : null;

  return (
    <DndContext sensors={sensors} collisionDetection={pointerWithin} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div className="editor-layout">
        <div className="editor-topbar">
          <div className="topbar-left">
            <div className="preset-tabs">
              {slots.map((slot, i) => (
                <div key={slot.id} className={`preset-tab ${i === slotIndex ? 'active' : ''}`} onClick={() => switchSlot(i)}>
                  <span className="preset-tab-label">{slot.name}</span>
                  {slot.saved && i === slotIndex && <span className="preset-tab-saved">●</span>}
                </div>
              ))}
            </div>
          </div>
          <div className="topbar-center">
            <div className="topbar-actions">
              <button className="tb-btn tb-btn-primary" onClick={saveSlot}>💾 存档</button>
              <button className="tb-btn" onClick={() => { clearAll(); }}>🗑 清空</button>
              <button className="tb-btn" onClick={startRenameSlot}>✏️ 重命名</button>
              <span className="topbar-sep" />
              <button className="tb-btn" onClick={handleLoadFromMTMR}>📥 加载</button>
              <button className="tb-btn" onClick={handleUpdateMTMR} disabled={!shouldEnableSave}>📤 保存</button>
              <span className="topbar-sep" />
              <button className={`tb-btn ${showJsonSection ? 'tb-btn-active' : ''}`} onClick={() => setShowJsonSection(!showJsonSection)}>
                {showJsonSection ? '隐藏' : '显示'} JSON
              </button>
            </div>
          </div>
          <div className="topbar-right">{isDirty && <span className="dirty-indicator">未保存</span>}</div>
        </div>

        {editingSlotName && (
          <div className="rename-overlay" onClick={() => setEditingSlotName(false)}>
            <div className="rename-dialog" onClick={(e) => e.stopPropagation()}>
              <h3>重命名预设</h3>
              <input ref={slotNameInputRef} type="text" value={slotNameValue}
                onChange={(e) => setSlotNameValue(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') commitRenameSlot(); if (e.key === 'Escape') setEditingSlotName(false); }}
                className="rename-input" />
              <div className="rename-actions">
                <button className="tb-btn" onClick={() => setEditingSlotName(false)}>取消</button>
                <button className="tb-btn tb-btn-primary" onClick={commitRenameSlot}>确定</button>
              </div>
            </div>
          </div>
        )}

        <main className="editor-main">
          <aside className="sidebar-left"><Palette /></aside>
          <section className="content-center">
            <div className={`touchbar-wrapper ${!showJsonSection ? 'fullscreen' : ''}`}><TouchBar /></div>
            {showJsonSection && <JsonOutput />}
          </section>
          {showProperties && selectedItemId && (
            <aside className="sidebar-right">
              <button className="sidebar-close" onClick={() => { selectItem(null); setShowProperties(false); }}>✕</button>
              <PropertiesPanel />
            </aside>
          )}
        </main>

        <footer className="app-footer">
          <span className="app-footer-hint">双击备选栏添加 • 拖拽排序 • 点击选中编辑 • 右键更多选项</span>
          <span className="app-footer-credits">LyricsMTMR Config Editor</span>
        </footer>
      </div>

      <DragOverlay>
        {activeType === 'touchbar' && activeItem && activeItemDef && (
          <div className="touchbar-item-overlay"><span className="touchbar-item-title">{activeItem.title || activeItemDef.defaultTitle}</span></div>
        )}
        {activeType === 'palette' && paletteItemDef && (
          <div className="touchbar-item-overlay"><span className="touchbar-item-title">{paletteItemDef.icon} {paletteItemDef.label}</span></div>
        )}
      </DragOverlay>

      {errorToast && <div className="error-toast"><span>{errorToast}</span></div>}
    </DndContext>
  );
}

function SettingsView() {
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
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings })
      });
      const result = await r.json();
      setToast(result.success ? '✅ 已保存' : '❌ 保存失败');
    } catch { setToast('❌ 保存失败'); }
    setSaving(false);
    setTimeout(() => setToast(null), 2000);
  };

  const set = (key, value) => setSettings(prev => ({ ...prev, [key]: value }));

  if (loading) return <div className="settings-loading">加载中...</div>;

  return (
    <div className="settings-page">
      <div className="settings-body">
        <div className="settings-tabs">
          {['general', 'lyrics', 'filters', 'blacklist'].map(t => (
            <button key={t} className={`settings-tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>
              {{general:'通用', lyrics:'歌词', filters:'拦截规则', blacklist:'黑名单'}[t]}
            </button>
          ))}
        </div>
        <div className="settings-content">
          {tab === 'general' && <GeneralTab s={settings} set={set} />}
          {tab === 'lyrics' && <LyricsTab s={settings} set={set} />}
          {tab === 'filters' && <FiltersTab s={settings} set={set} />}
          {tab === 'blacklist' && <BlacklistTab s={settings} set={set} />}
        </div>
      </div>
      <div className="settings-footer">
        <button className="tb-btn tb-btn-primary" onClick={save} disabled={saving}>
          {saving ? '保存中...' : '保存设置'}
        </button>
      </div>
      {toast && <div className="error-toast"><span>{toast}</span></div>}
    </div>
  );
}

const MUSIC_PLAYERS = [
  { id: 'com.apple.Music', name: 'Apple Music' },
  { id: 'com.spotify.client', name: 'Spotify' },
  { id: 'com.coppertino.Vox', name: 'Vox' },
  { id: 'com.audirvana.Audirvana-Origin', name: 'Audirvana' },
  { id: 'com.swinsian.Swinsian', name: 'Swinsian' },
  { id: 'com.netease.163music', name: '网易云音乐' },
  { id: 'com.netease.163music.new', name: '网易云音乐(新)' },
  { id: 'com.tencent.QQMusicMac', name: 'QQ音乐' },
];

function Toggle({ label, value, onChange }) {
  return (
    <label className="ls-row"><span>{label}</span>
      <label className="switch">
        <input type="checkbox" checked={!!value} onChange={e => onChange(e.target.checked)} />
        <span className="slider round"></span>
      </label>
    </label>
  );
}

function Select({ label, value, options, onChange }) {
  return (
    <label className="ls-row" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', fontSize: '13px', color: '#1d1d1f', cursor: 'pointer' }}>
      <span>{label}</span>
      <select value={value} onChange={e => onChange(e.target.value)}
        style={{
          padding: '6px 10px', border: '1px solid #d2d2d7', borderRadius: '6px',
          background: '#ffffff', fontSize: '12px', color: '#1d1d1f', minWidth: '140px',
          WebkitAppearance: 'menulist', appearance: 'auto'
        }}>
        {options.map(o => (
          <option key={o.value} value={o.value} style={{ color: '#1d1d1f', background: '#ffffff' }}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function SliderField({ label, value, min, max, step, onChange }) {
  return (
    <label className="ls-row"><span>{label}</span>
      <div className="ls-slider-group">
        <input type="range" min={min} max={max} step={step || 1} value={value} onChange={e => onChange(Number(e.target.value))} />
        <span className="ls-slider-val">{value}</span>
      </div>
    </label>
  );
}

function ColorField({ label, value, onChange }) {
  return (
    <label className="ls-row"><span>{label}</span>
      <input type="color" value={value || '#ffffff'} onChange={e => onChange(e.target.value)} className="ls-color" />
    </label>
  );
}

function GeneralTab({ s, set }) {
  const sel = s.selectedPlayerIds || [];
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
        {[{v:'System',l:'系统默认'},{v:'en',l:'English'},{v:'zh-Hans',l:'中文'}].map(o => (
          <label key={o.v} className="ls-radio">
            <input type="radio" name="lang" checked={s.appLanguage === o.v} onChange={() => set('appLanguage', o.v)} />
            {o.l}
          </label>
        ))}
      </div>
      <h3>音乐源（至少选一个）</h3>
      {MUSIC_PLAYERS.map(p => (
        <Toggle key={p.id} label={p.name} value={sel.includes(p.id)} onChange={v => {
          set('selectedPlayerIds', v ? [...sel, p.id] : sel.filter(id => id !== p.id));
        }} />
      ))}
    </div>
  );
}

function LyricsTab({ s, set }) {
  const pc = s.lyricsProgressColor || '#ff9500';
  const tc = s.lyricsTextColor || '#ffffff';
  const previewText = '当世界终止时 君と僕の歌よ';
  const splitAt = Math.min(previewText.length, 12);
  return (
    <div className="ls-panel">
      <h3>预览</h3>
      <div className="ls-preview" style={{ background: '#333' }}>
        <span style={{ color: pc }}>{previewText.slice(0, splitAt)}</span>
        <span style={{ color: tc }}>{previewText.slice(splitAt)}</span>
      </div>
      <h3>显示</h3>
      <Select label="显示模式" value={s.lyricsDisplayMode || 'karaoke'} onChange={v => set('lyricsDisplayMode', v)}
        options={[{v:'karaoke',l:'卡拉OK'},{v:'static',l:'静态文字'},{v:'artwork',l:'仅封面'}]} />
      <Select label="卡拉OK风格" value={s.lyricsKaraokeStyle || 'progressive'} onChange={v => set('lyricsKaraokeStyle', v)}
        options={[{v:'progressive',l:'平滑渐进'},{v:'jump',l:'逐词跳跃'}]} />
      <h3>颜色</h3>
      <ColorField label="进度颜色" value={pc} onChange={v => set('lyricsProgressColor', v)} />
      <ColorField label="文字颜色" value={tc} onChange={v => set('lyricsTextColor', v)} />
      <h3>字体</h3>
      <Select label="字体" value={s.lyricsFontName || 'System'} onChange={v => set('lyricsFontName', v)}
        options={['System','Helvetica','Arial','PingFang SC','STHeiti','STSong','Times New Roman','Courier New','Georgia','Verdana'].map(f => ({v:f, l:f}))} />
      <SliderField label="字号" value={s.lyricsFontSize || 16} min={10} max={36} onChange={v => set('lyricsFontSize', v)} />
      <h3>封面</h3>
      <Toggle label="显示专辑封面" value={s.lyricsShowArtwork} onChange={v => set('lyricsShowArtwork', v)} />
      <SliderField label="封面尺寸" value={s.lyricsArtworkSize || 24} min={16} max={48} onChange={v => set('lyricsArtworkSize', v)} />
      <h3>延迟</h3>
      <SliderField label="歌词延迟(秒)" value={s.lyricsDelay || 0} min={-5} max={5} step={0.1} onChange={v => set('lyricsDelay', v)} />
      <h3>交互</h3>
      <Select label="单击操作" value={s.lyricsClickAction || 'original'} onChange={v => set('lyricsClickAction', v)}
        options={[{v:'original',l:'原始歌词'},{v:'translation',l:'翻译'},{v:'romaji',l:'罗马音'}]} />
    </div>
  );
}

function FiltersTab({ s, set }) {
  const [newRule, setNewRule] = useState('');
  const keys = s.lyricsFilterKeys || [];
  const addRule = () => {
    if (!newRule.trim()) return;
    set('lyricsFilterKeys', [...keys, newRule.trim()]);
    setNewRule('');
  };
  const removeRule = (i) => { set('lyricsFilterKeys', keys.filter((_, j) => j !== i)); };
  const resetRules = () => {
    set('lyricsFilterKeys', ['作詞', '作曲', '編曲', '歌詞', '訳詞', '作词', '作曲', '编曲', '歌词', '翻译', '/^\\\\s*$/']);
  };
  return (
    <div className="ls-panel">
      <Toggle label="启用歌词过滤" value={s.lyricsFilterEnabled} onChange={v => set('lyricsFilterEnabled', v)} />
      <Select label="过滤模式" value={String(s.lyricsFilterMode ?? 0)} onChange={v => set('lyricsFilterMode', parseInt(v))}
        options={[{v:'0',l:'排除匹配行'},{v:'1',l:'仅保留匹配行'}]} />
      <p className="ls-hint">以 / 开头的为正则表达式</p>
      <div className="ls-filter-list">
        {keys.length === 0 && <p className="ls-empty">暂无规则</p>}
        {keys.map((key, i) => (
          <div key={i} className="ls-filter-row">
            <span className={`ls-badge ${key.startsWith('/') ? 'regex' : 'text'}`}>{key.startsWith('/') ? 'R' : 'T'}</span>
            <code className="ls-filter-text">{key}</code>
            <button className="ls-btn-sm" onClick={() => removeRule(i)}>✕</button>
          </div>
        ))}
      </div>
      <div className="ls-filter-add">
        <input type="text" value={newRule} onChange={e => setNewRule(e.target.value)}
          placeholder="输入过滤关键词或 /正则/" onKeyDown={e => e.key === 'Enter' && addRule()} />
        <button className="tb-btn tb-btn-primary" onClick={addRule}>添加</button>
      </div>
      <button className="tb-btn" onClick={resetRules} style={{ marginTop: 8 }}>恢复默认</button>
    </div>
  );
}

function BlacklistTab({ s, set }) {
  const ids = s.blacklistedAppIds || [];
  return (
    <div className="ls-panel">
      <p className="ls-hint">黑名单中的应用不会显示自定义 Touch Bar</p>
      <div className="ls-filter-list">
        {ids.length === 0 && <p className="ls-empty">暂无黑名单应用</p>}
        {ids.map(id => (
          <div key={id} className="ls-filter-row">
            <span className="ls-app-name">{id}</span>
            <button className="ls-btn-sm ls-btn-danger" onClick={() => set('blacklistedAppIds', ids.filter(i => i !== id))}>✕</button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function App() {
  const [view, setView] = useState('settings');

  return (
    <AppProvider>
      <div className="app">
        <header className="app-topbar">
          <div className="topbar-left">
            <div className="nav-tabs">
              <button className={`nav-tab ${view === 'settings' ? 'active' : ''}`} onClick={() => setView('settings')}>
                ⚙️ 设置
              </button>
              <button className={`nav-tab ${view === 'editor' ? 'active' : ''}`} onClick={() => setView('editor')}>
                ⌨️ 编辑器
              </button>
            </div>
          </div>
          <div className="topbar-center" />
          <div className="topbar-right" />
        </header>
        <main className="app-main">
          {view === 'settings' ? <SettingsView /> : <EditorView />}
        </main>
      </div>
    </AppProvider>
  );
}
