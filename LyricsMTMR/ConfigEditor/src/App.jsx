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

function AppContent() {
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

  // Keyboard shortcut for Save to MTMR (Cmd+S / Ctrl+S)
  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        if (shouldEnableSave) {
          handleUpdateMTMR();
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [shouldEnableSave]);

  // Auto-show properties when an item is selected, auto-hide on deselect
  useEffect(() => {
    if (selectedItemId) {
      setShowProperties(true);
    }
  }, [selectedItemId]);

  const startRenameSlot = () => {
    setSlotNameValue(activeSlot.name);
    setEditingSlotName(true);
    setTimeout(() => slotNameInputRef.current?.focus(), 50);
  };

  const commitRenameSlot = () => {
    const trimmed = slotNameValue.trim();
    if (trimmed) {
      renameSlot(trimmed);
    }
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
      if (oldIndex !== -1 && newIndex !== -1) {
        reorderItems(arrayMove(items, oldIndex, newIndex));
      }
    }
    setActiveId(null);
    setActiveType(null);
  };

  const handleLoadFromMTMR = async () => {
    try {
      const result = await loadFromMTMR();
      if (result.success) {
        setErrorToast('✅ 成功从 MTMR 加载配置');
      } else {
        setErrorToast(`❌ 加载失败: ${result.error}`);
      }
    } catch (error) {
      setErrorToast(`❌ 错误: ${error.message}`);
    }
    setTimeout(() => setErrorToast(null), 3000);
  };

  const handleUpdateMTMR = async () => {
    try {
      const result = await saveToMTMR();
      if (result.success) {
        setErrorToast('✅ 成功更新 MTMR 配置');
      } else {
        setErrorToast(`❌ 保存失败: ${result.error}`);
      }
    } catch (error) {
      setErrorToast(`❌ 错误: ${error.message}`);
    }
    setTimeout(() => setErrorToast(null), 3000);
  };

  const activeItem = activeType === 'touchbar' ? items.find((item) => item.id === activeId) : null;
  const activeItemDef = activeItem ? getElementDefinition(activeItem.type) : null;
  const paletteItemDef = activeType === 'palette' && activeId
    ? getElementDefinition(activeId.replace('palette-', ''))
    : null;

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={pointerWithin}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="app">
        <header className="app-topbar">
          <div className="topbar-left">
            <div className="preset-tabs">
              {slots.map((slot, i) => (
                <div
                  key={slot.id}
                  className={`preset-tab ${i === slotIndex ? 'active' : ''}`}
                  onClick={() => switchSlot(i)}
                >
                  <span className="preset-tab-label">{slot.name}</span>
                  {slot.saved && i === slotIndex && <span className="preset-tab-saved" title="已存档">●</span>}
                </div>
              ))}
            </div>
          </div>
          <div className="topbar-center">
            <div className="topbar-actions">
              <button className="tb-btn tb-btn-primary" onClick={saveSlot} title="存档当前预设">
                💾 存档
              </button>
              <button className="tb-btn" onClick={() => { clearAll(); }} title="清空当前栏">
                🗑 清空
              </button>
              <button className="tb-btn" onClick={startRenameSlot} title="重命名预设">
                ✏️ 重命名
              </button>
              <span className="topbar-sep" />
              <button className="tb-btn" onClick={handleLoadFromMTMR} title="从 MTMR 加载">
                📥 加载
              </button>
              <button className="tb-btn" onClick={handleUpdateMTMR} disabled={!shouldEnableSave} title="保存到 MTMR">
                📤 保存
              </button>
              <span className="topbar-sep" />
              <button
                className={`tb-btn ${showJsonSection ? 'tb-btn-active' : ''}`}
                onClick={() => setShowJsonSection(!showJsonSection)}
              >
                {showJsonSection ? '隐藏' : '显示'} JSON
              </button>
            </div>
          </div>
          <div className="topbar-right">
            {isDirty && <span className="dirty-indicator">未保存</span>}
          </div>
        </header>

        {editingSlotName && (
          <div className="rename-overlay" onClick={() => setEditingSlotName(false)}>
            <div className="rename-dialog" onClick={(e) => e.stopPropagation()}>
              <h3>重命名预设</h3>
              <input
                ref={slotNameInputRef}
                type="text"
                value={slotNameValue}
                onChange={(e) => setSlotNameValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') commitRenameSlot();
                  if (e.key === 'Escape') setEditingSlotName(false);
                }}
                className="rename-input"
              />
              <div className="rename-actions">
                <button className="tb-btn" onClick={() => setEditingSlotName(false)}>取消</button>
                <button className="tb-btn tb-btn-primary" onClick={commitRenameSlot}>确定</button>
              </div>
            </div>
          </div>
        )}

        <main className="app-main">
          <aside className="sidebar-left">
            <Palette />
          </aside>

          <section className="content-center">
            <div className={`touchbar-wrapper ${!showJsonSection ? 'fullscreen' : ''}`}>
              <TouchBar />
            </div>
            {showJsonSection && <JsonOutput />}
          </section>

          {showProperties && selectedItemId && (
            <aside className="sidebar-right">
              <button
                className="sidebar-close"
                onClick={() => { selectItem(null); setShowProperties(false); }}
                title="关闭属性面板"
              >
                ✕
              </button>
              <PropertiesPanel />
            </aside>
          )}
        </main>

        <footer className="app-footer">
          <span className="app-footer-hint">双击备选栏添加 • 拖拽排序 • 点击选中编辑 • 右键更多选项</span>
          <span className="app-footer-credits">
            LyricsMTMR Config Editor
          </span>
        </footer>
      </div>

      <DragOverlay>
        {activeType === 'touchbar' && activeItem && activeItemDef && (
          <div className="touchbar-item-overlay">
            <span className="touchbar-item-title">
              {activeItem.title || activeItemDef.defaultTitle}
            </span>
          </div>
        )}
        {activeType === 'palette' && paletteItemDef && (
          <div className="touchbar-item-overlay">
            <span className="touchbar-item-title">
              {paletteItemDef.icon} {paletteItemDef.label}
            </span>
          </div>
        )}
      </DragOverlay>

      {errorToast && (
        <div className="error-toast">
          <span>{errorToast}</span>
        </div>
      )}
    </DndContext>
  );
}

export default function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}