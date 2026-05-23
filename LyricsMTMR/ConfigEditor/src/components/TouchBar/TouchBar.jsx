import { useState, useEffect, useRef } from 'react';
import {
  SortableContext,
  horizontalListSortingStrategy,
} from '@dnd-kit/sortable';
import { useDroppable } from '@dnd-kit/core';
import { useApp } from '../../context/AppContext';
import TouchBarItem from './TouchBarItem';
import './TouchBar.css';

const DOCK_SUB_APPS = [
  { icon: '🔍', name: 'Finder', active: true },
  { icon: '📧', name: 'Mail', active: false },
  { icon: '🌐', name: 'Safari', active: true },
  { icon: '💬', name: 'Messages', active: false },
  { icon: '📝', name: 'Notes', active: true },
  { icon: '📅', name: 'Calendar', active: false },
  { icon: '🎵', name: 'Music', active: false },
  { icon: '📁', name: 'Downloads', active: false },
  null,
  { icon: '🗑', name: 'Trash', active: false },
];

export default function TouchBar() {
  const { items, selectItem, selectedItemId, removeItem, addItem } = useApp();
  const [contextMenu, setContextMenu] = useState(null);
  const [expandedDockId, setExpandedDockId] = useState(null);
  const containerRef = useRef(null);

  const { setNodeRef, isOver } = useDroppable({
    id: 'touchbar-drop-zone',
  });

  const handleContextMenu = (e, itemId) => {
    e.preventDefault();
    e.stopPropagation();

    setContextMenu({
      x: e.clientX,
      y: e.clientY,
      itemId,
    });
  };

  const handleItemSelect = (itemId) => {
    const item = items.find((i) => i.id === itemId);
    if (item && item.type === 'dock') {
      if (expandedDockId === itemId) {
        setExpandedDockId(null);
      } else {
        setExpandedDockId(itemId);
      }
    } else {
      setExpandedDockId(null);
    }
    selectItem(itemId);
  };

  useEffect(() => {
    const handleClickOutside = () => {
      setContextMenu(null);
    };
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (selectedItemId && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') {
          removeItem(selectedItemId);
          if (expandedDockId === selectedItemId) {
            setExpandedDockId(null);
          }
        }
      }
      if (e.key === 'Escape') {
        selectItem(null);
        setContextMenu(null);
        setExpandedDockId(null);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [selectedItemId, removeItem, selectItem, expandedDockId]);

  const leftItems = items.filter(item => item.align === 'left');
  const centerItems = items.filter(item => !item.align || item.align === 'center');
  const rightItems = items.filter(item => item.align === 'right');

  const expandedDockItem = expandedDockId ? items.find((i) => i.id === expandedDockId) : null;

  return (
    <div className="touchbar-container" ref={containerRef}>
      <div className={`touchbar-frame ${isOver ? 'drag-over' : ''}`}>
        <div className="touchbar-screen" ref={setNodeRef}>
          <SortableContext items={items.map((i) => i.id)} strategy={horizontalListSortingStrategy}>
            <div className="touchbar-items">
              {items.length === 0 ? (
                <div className="touchbar-empty">
                  <span>从备选栏拖拽元素过来</span>
                </div>
              ) : (
                <>
                  <div className="touchbar-section touchbar-section-left">
                    {leftItems.map((item) => (
                      <TouchBarItem
                        key={item.id}
                        item={item}
                        isSelected={selectedItemId === item.id}
                        onSelect={() => handleItemSelect(item.id)}
                        onContextMenu={(e) => handleContextMenu(e, item.id)}
                      />
                    ))}
                  </div>

                  <div className="touchbar-section touchbar-section-center">
                    {centerItems.map((item) => (
                      <TouchBarItem
                        key={item.id}
                        item={item}
                        isSelected={selectedItemId === item.id}
                        onSelect={() => handleItemSelect(item.id)}
                        onContextMenu={(e) => handleContextMenu(e, item.id)}
                      />
                    ))}
                  </div>

                  <div className="touchbar-section touchbar-section-right">
                    {rightItems.map((item) => (
                      <TouchBarItem
                        key={item.id}
                        item={item}
                        isSelected={selectedItemId === item.id}
                        onSelect={() => handleItemSelect(item.id)}
                        onContextMenu={(e) => handleContextMenu(e, item.id)}
                      />
                    ))}
                  </div>
                </>
              )}
            </div>
          </SortableContext>
        </div>
      </div>

      {expandedDockItem && (
        <div className="touchbar-sub-bar">
          <div className="touchbar-sub-bar-screen">
            {DOCK_SUB_APPS.map((app, i) =>
              app === null ? (
                <div key={`sep-${i}`} className="touchbar-sub-sep" />
              ) : (
                <div
                  key={app.name}
                  className={`touchbar-sub-item ${app.active ? 'active' : ''}`}
                  title={app.name}
                >
                  <span style={{ position: 'relative' }}>
                    {app.icon}
                    {app.active && <span className="touchbar-sub-item-dot" />}
                  </span>
                </div>
              )
            )}
          </div>
        </div>
      )}

      {contextMenu && (
        <div
          className="context-menu"
          style={{
            position: 'fixed',
            left: contextMenu.x,
            top: contextMenu.y,
            zIndex: 1000,
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            className="context-menu-item"
            onClick={() => {
              selectItem(contextMenu.itemId);
              setContextMenu(null);
            }}
          >
            编辑
          </button>
          <button
            className="context-menu-item"
            onClick={() => {
              duplicateItem(contextMenu.itemId);
              setContextMenu(null);
            }}
          >
            复制
          </button>
          <div className="context-menu-divider" />
          <button
            className="context-menu-item danger"
            onClick={() => {
              removeItem(contextMenu.itemId);
              setContextMenu(null);
            }}
          >
            删除
          </button>
        </div>
      )}
    </div>
  );

  function duplicateItem(itemId) {
    const item = items.find((i) => i.id === itemId);
    if (item) {
      const { id, ...itemWithoutId } = item;
      addItem(item.type, itemWithoutId);
    }
  }
}