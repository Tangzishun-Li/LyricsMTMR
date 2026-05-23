import { useState, useMemo, useRef, useCallback } from 'react';
import { useDraggable } from '@dnd-kit/core';
import { useApp } from '../../context/AppContext';
import { elementCategories, getElementsByCategory } from '../../data/elementDefinitions';
import './Palette.css';

export default function Palette() {
  const { addItem, selectItem } = useApp();
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedCategories, setExpandedCategories] = useState(
    Object.keys(elementCategories).reduce((acc, key) => {
      acc[key] = true;
      return acc;
    }, {})
  );
  const clickTimer = useRef(null);

  const toggleCategory = (category) => {
    setExpandedCategories((prev) => ({
      ...prev,
      [category]: !prev[category],
    }));
  };

  const handleItemDoubleClick = useCallback((elementKey) => {
    const newItem = addItem(elementKey);
    if (newItem) {
      selectItem(newItem.id);
    }
  }, [addItem, selectItem]);

  const filteredCategories = useMemo(() => {
    if (!searchQuery.trim()) {
      return Object.entries(elementCategories).map(([categoryKey, category]) => ({
        categoryKey,
        category,
        elements: getElementsByCategory(categoryKey),
      }));
    }
    const query = searchQuery.toLowerCase().trim();
    return Object.entries(elementCategories)
      .map(([categoryKey, category]) => {
        const allElements = getElementsByCategory(categoryKey);
        const filteredElements = allElements.filter(
          (el) =>
            el.label.toLowerCase().includes(query) ||
            el.type.toLowerCase().includes(query) ||
            (el.key && el.key.toLowerCase().includes(query))
        );
        return { categoryKey, category, elements: filteredElements };
      })
      .filter((cat) => cat.elements.length > 0);
  }, [searchQuery]);

  const isSearching = searchQuery.trim().length > 0;

  return (
    <div className="palette">
      <div className="palette-header">
        <div className="palette-search">
          <input
            type="text"
            className="palette-search-input"
            placeholder="搜索元素..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          {searchQuery && (
            <button
              type="button"
              className="palette-search-clear"
              onClick={() => setSearchQuery('')}
            >
              ✕
            </button>
          )}
        </div>
      </div>
      <div className="palette-content">
        {filteredCategories.map(({ categoryKey, category, elements }) => (
          <PaletteCategory
            key={categoryKey}
            categoryKey={categoryKey}
            category={category}
            elements={elements}
            isExpanded={isSearching ? true : expandedCategories[categoryKey]}
            onToggle={() => toggleCategory(categoryKey)}
            onItemDoubleClick={handleItemDoubleClick}
          />
        ))}
        {filteredCategories.length === 0 && (
          <div className="palette-no-results">
            未找到 "{searchQuery}"
          </div>
        )}
      </div>
    </div>
  );
}

function PaletteCategory({ categoryKey, category, elements, isExpanded, onToggle, onItemDoubleClick }) {
  return (
    <div className={`palette-category ${isExpanded ? 'expanded' : ''}`}>
      <button className="palette-category-header" onClick={onToggle}>
        <span className="category-icon">{isExpanded ? '▾' : '▸'}</span>
        <span className="category-label">{category.label}</span>
        <span className="category-count">{elements.length}</span>
      </button>
      {isExpanded && (
        <div className="palette-items">
          {elements.map((element) => {
            const elementKey = element.key || element.type;
            return (
              <PaletteItem
                key={elementKey}
                element={element}
                onDoubleClick={() => onItemDoubleClick(elementKey)}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

function PaletteItem({ element, onDoubleClick }) {
  const elementKey = element.key || element.type;
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: `palette-${elementKey}`,
    data: {
      type: 'palette-item',
      elementType: element.type,
      elementKey: elementKey,
      defaultProps: element.defaultProps,
    },
  });

  return (
    <div
      ref={setNodeRef}
      className={`palette-item ${isDragging ? 'dragging' : ''}`}
      onDoubleClick={onDoubleClick}
      {...attributes}
      {...listeners}
    >
      <span className="palette-item-icon">{element.icon}</span>
      <span className="palette-item-label">{element.label}</span>
    </div>
  );
}