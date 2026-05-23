import { createContext, useContext, useReducer, useCallback, useEffect } from 'react';
import { createElement, getElementDefinition } from '../data/elementDefinitions';
import { generateJSON, parseJSON } from '../utils/jsonGenerator';
import { loadFromMTMR as loadFromMTMRFile, saveToMTMR as saveToMTMRFile, isServerRunning } from '../utils/mtmrFileSystem';

const DEFAULT_SLOT_NAMES = ['预设 1', '预设 2', '预设 3', '预设 4'];

function createEmptySlots() {
  return DEFAULT_SLOT_NAMES.map((name, i) => ({
    id: `slot-${i}`,
    name,
    items: [],
    saved: false,
  }));
}

const initialState = {
  items: [],
  selectedItemId: null,
  slotIndex: 0,
  slots: [],
  isDirty: false,
  mtmrItems: null,
  autoLoad: JSON.parse(localStorage.getItem('mtmr-auto-load') ?? 'true'),
  settings: {
    autoSave: true,
  },
};

const ActionTypes = {
  ADD_ITEM: 'ADD_ITEM',
  REMOVE_ITEM: 'REMOVE_ITEM',
  UPDATE_ITEM: 'UPDATE_ITEM',
  REORDER_ITEMS: 'REORDER_ITEMS',
  SELECT_ITEM: 'SELECT_ITEM',
  DESELECT_ITEM: 'DESELECT_ITEM',
  LOAD_ITEMS: 'LOAD_ITEMS',
  SWITCH_SLOT: 'SWITCH_SLOT',
  SAVE_SLOT: 'SAVE_SLOT',
  RESET_SLOT: 'RESET_SLOT',
  CLEAR_SLOT: 'CLEAR_SLOT',
  RENAME_SLOT: 'RENAME_SLOT',
  LOAD_SLOTS: 'LOAD_SLOTS',
  LOAD_FROM_MTM: 'LOAD_FROM_MTM',
  MARK_CLEAN: 'MARK_CLEAN',
  TOGGLE_AUTO_LOAD: 'TOGGLE_AUTO_LOAD',
};

function appReducer(state, action) {
  switch (action.type) {
    case ActionTypes.ADD_ITEM: {
      const newItems = [...state.items, action.payload];
      return {
        ...state,
        items: newItems,
        selectedItemId: action.payload.id,
        isDirty: true,
      };
    }

    case ActionTypes.REMOVE_ITEM: {
      const newItems = state.items.filter((item) => item.id !== action.payload);
      return {
        ...state,
        items: newItems,
        selectedItemId: state.selectedItemId === action.payload ? null : state.selectedItemId,
        isDirty: true,
      };
    }

    case ActionTypes.UPDATE_ITEM: {
      const newItems = state.items.map((item) =>
        item.id === action.payload.id ? { ...item, ...action.payload.updates } : item
      );
      return {
        ...state,
        items: newItems,
        isDirty: true,
      };
    }

    case ActionTypes.REORDER_ITEMS: {
      return {
        ...state,
        items: action.payload,
        isDirty: true,
      };
    }

    case ActionTypes.SELECT_ITEM:
      return { ...state, selectedItemId: action.payload };

    case ActionTypes.DESELECT_ITEM:
      return { ...state, selectedItemId: null };

    case ActionTypes.LOAD_ITEMS:
      return {
        ...state,
        items: action.payload,
        selectedItemId: null,
        isDirty: false,
      };

    case ActionTypes.SWITCH_SLOT: {
      const newIdx = action.payload;
      const currentItems = state.items;
      const slots = state.slots.map((s, i) =>
        i === state.slotIndex ? { ...s, items: currentItems } : s
      );
      const target = slots[newIdx];
      return {
        ...state,
        slots,
        slotIndex: newIdx,
        items: target.items || [],
        selectedItemId: null,
        isDirty: !target.saved,
      };
    }

    case ActionTypes.SAVE_SLOT: {
      const slots = state.slots.map((s, i) =>
        i === state.slotIndex ? { ...s, items: state.items, saved: true } : s
      );
      localStorage.setItem('mtmr-designer-slots', JSON.stringify(slots));
      return { ...state, slots, isDirty: false };
    }

    case ActionTypes.RESET_SLOT: {
      const slots = state.slots.map((s, i) =>
        i === state.slotIndex ? { ...s, items: [], saved: false } : s
      );
      localStorage.setItem('mtmr-designer-slots', JSON.stringify(slots));
      return { ...state, slots, items: [], selectedItemId: null, isDirty: false };
    }

    case ActionTypes.CLEAR_SLOT: {
      return { ...state, items: [], selectedItemId: null, isDirty: true };
    }

    case ActionTypes.RENAME_SLOT: {
      const slots = state.slots.map((s, i) =>
        i === state.slotIndex ? { ...s, name: action.payload } : s
      );
      localStorage.setItem('mtmr-designer-slots', JSON.stringify(slots));
      return { ...state, slots };
    }

    case ActionTypes.LOAD_SLOTS:
      return { ...state, slots: action.payload };

    case ActionTypes.LOAD_FROM_MTM:
      return {
        ...state,
        items: action.payload,
        mtmrItems: JSON.parse(JSON.stringify(action.payload)),
        selectedItemId: null,
        isDirty: false,
      };

    case ActionTypes.MARK_CLEAN:
      return { ...state, isDirty: false };

    case ActionTypes.TOGGLE_AUTO_LOAD: {
      const newAutoLoad = !state.autoLoad;
      localStorage.setItem('mtmr-auto-load', JSON.stringify(newAutoLoad));
      return { ...state, autoLoad: newAutoLoad };
    }

    default:
      return state;
  }
}

const AppContext = createContext(null);

export function AppProvider({ children }) {
  const [state, dispatch] = useReducer(appReducer, initialState);

  useEffect(() => {
    const saved = localStorage.getItem('mtmr-designer-slots');
    let slots;
    if (saved) {
      try {
        slots = JSON.parse(saved);
        if (!Array.isArray(slots) || slots.length !== 4) throw new Error('invalid');
      } catch {
        slots = createEmptySlots();
      }
    } else {
      slots = createEmptySlots();
    }
    dispatch({ type: ActionTypes.LOAD_SLOTS, payload: slots });

    const lastSlot = parseInt(localStorage.getItem('mtmr-designer-active-slot') || '0', 10);
    const validIdx = Math.min(Math.max(lastSlot, 0), 3);
    const currentItems = slots[validIdx]?.items || [];
    dispatch({ type: ActionTypes.LOAD_ITEMS, payload: currentItems });
    // We need a way to set slotIndex too - let's use a combined initial load
    dispatch({ type: ActionTypes.SWITCH_SLOT, payload: validIdx });
  }, []);

  useEffect(() => {
    if (state.settings.autoSave && state.items.length > 0) {
      const json = generateJSON(state.items);
      localStorage.setItem('mtmr-designer-items', json);
    }
  }, [state.items, state.settings.autoSave]);

  const addItem = useCallback((type, overrides = {}) => {
    const item = createElement(type, overrides);
    if (item) {
      dispatch({ type: ActionTypes.ADD_ITEM, payload: item });
    }
    return item;
  }, []);

  const removeItem = useCallback((id) => {
    dispatch({ type: ActionTypes.REMOVE_ITEM, payload: id });
  }, []);

  const updateItem = useCallback((id, updates) => {
    dispatch({ type: ActionTypes.UPDATE_ITEM, payload: { id, updates } });
  }, []);

  const reorderItems = useCallback((items) => {
    dispatch({ type: ActionTypes.REORDER_ITEMS, payload: items });
  }, []);

  const selectItem = useCallback((id) => {
    dispatch({ type: ActionTypes.SELECT_ITEM, payload: id });
  }, []);

  const deselectItem = useCallback(() => {
    dispatch({ type: ActionTypes.DESELECT_ITEM });
  }, []);

  const loadItems = useCallback((items) => {
    dispatch({ type: ActionTypes.LOAD_ITEMS, payload: items });
  }, []);

  const getSelectedItem = useCallback(() => {
    if (!state.selectedItemId) return null;
    let item = state.items.find((i) => i.id === state.selectedItemId);
    if (item) return item;
    for (const groupItem of state.items) {
      if (groupItem.type === 'group' && groupItem.items) {
        item = groupItem.items.find((i) => i.id === state.selectedItemId);
        if (item) return item;
      }
    }
    return null;
  }, [state.items, state.selectedItemId]);

  const importJSON = useCallback((jsonString) => {
    const { items, error } = parseJSON(jsonString);
    if (error) return { success: false, error };
    dispatch({ type: ActionTypes.LOAD_ITEMS, payload: items });
    return { success: true };
  }, []);

  const exportJSON = useCallback(() => {
    return generateJSON(state.items);
  }, [state.items]);

  const clearAll = useCallback(() => {
    dispatch({ type: ActionTypes.CLEAR_SLOT });
  }, []);

  const switchSlot = useCallback((idx) => {
    localStorage.setItem('mtmr-designer-active-slot', String(idx));
    dispatch({ type: ActionTypes.SWITCH_SLOT, payload: idx });
  }, []);

  const saveSlot = useCallback(() => {
    dispatch({ type: ActionTypes.SAVE_SLOT });
  }, []);

  const resetSlot = useCallback(() => {
    dispatch({ type: ActionTypes.RESET_SLOT });
  }, []);

  const renameSlot = useCallback((name) => {
    dispatch({ type: ActionTypes.RENAME_SLOT, payload: name });
  }, []);

  const loadFromMTMR = useCallback(async () => {
    try {
      const serverRunning = await isServerRunning();
      if (!serverRunning) {
        return { success: false, error: 'MTMR Designer Server is not running.' };
      }
      const result = await loadFromMTMRFile();
      if (result.success) {
        const items = processMTMRItems(result.data);
        dispatch({ type: ActionTypes.LOAD_FROM_MTM, payload: items });
        return { success: true };
      } else {
        return { success: false, error: result.error };
      }
    } catch (error) {
      return { success: false, error: error.message };
    }
  }, []);

  const processMTMRItems = useCallback((items) => {
    return items.map((item) => {
      const id = `item-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      const definition = getElementDefinition(item.type);
      if (!definition) {
        return { id, type: item.type, ...item };
      }
      const element = { id, type: item.type, ...definition.defaultProps, ...item };
      if (item.items && Array.isArray(item.items)) {
        element.items = processMTMRItems(item.items);
      }
      return element;
    }).filter(Boolean);
  }, []);

  const saveToMTMR = useCallback(async () => {
    try {
      const jsonContent = generateJSON(state.items);
      const result = await saveToMTMRFile(jsonContent);
      if (result.success) {
        dispatch({ type: ActionTypes.MARK_CLEAN });
        dispatch({ type: ActionTypes.LOAD_FROM_MTM, payload: JSON.parse(JSON.stringify(state.items)) });
      }
      return result;
    } catch (error) {
      return { success: false, error: error.message };
    }
  }, [state.items]);

  const shouldEnableSave = state.isDirty;

  const value = {
    items: state.items,
    selectedItemId: state.selectedItemId,
    slotIndex: state.slotIndex,
    slots: state.slots,
    isDirty: state.isDirty,
    shouldEnableSave,
    autoLoad: state.autoLoad,

    addItem,
    removeItem,
    updateItem,
    reorderItems,
    selectItem,
    deselectItem,
    loadItems,
    getSelectedItem,
    importJSON,
    exportJSON,
    clearAll,

    switchSlot,
    saveSlot,
    resetSlot,
    renameSlot,

    loadFromMTMR,
    saveToMTMR,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}

export { ActionTypes };