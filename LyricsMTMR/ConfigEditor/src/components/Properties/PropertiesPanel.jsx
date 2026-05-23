import { useState, useEffect } from 'react';
import { useApp } from '../../context/AppContext';
import { getElementDefinition, commonProperties, actionTypes, actionTriggers } from '../../data/elementDefinitions';
import './Properties.css';

export default function PropertiesPanel() {
  const { getSelectedItem, updateItem, removeItem } = useApp();
  const item = getSelectedItem();
  const definition = item ? getElementDefinition(item.type) : null;

  if (!item || !definition) {
    return (
      <div className="properties-panel">
        <div className="properties-empty">
          <p>选择一个元素编辑属性</p>
        </div>
      </div>
    );
  }

  return (
    <div className="properties-panel">
      <div className="properties-header">
        <div className="properties-title-group">
          <h2 className="properties-title">属性</h2>
          <span className="properties-type">{definition.label}</span>
        </div>
      </div>
      <div className="properties-content">
        <PropertySection title="通用">
          <PropertyInput
            label="宽度"
            type="number"
            value={item.width ?? ''}
            onChange={(value) => updateItem(item.id, { width: value ? Number(value) : undefined })}
            placeholder="自动"
          />
          <PropertySelect
            label="对齐"
            value={item.align || 'center'}
            options={[
              { value: 'left', label: '左对齐' },
              { value: 'center', label: '居中' },
              { value: 'right', label: '右对齐' },
            ]}
            onChange={(value) => updateItem(item.id, { align: value })}
          />
          <PropertyToggle
            label="边框"
            value={item.bordered !== false}
            onChange={(value) => updateItem(item.id, { bordered: value })}
          />
          <PropertyInput
            label="背景颜色"
            type="color"
            value={item.background || '#000000'}
            onChange={(value) => updateItem(item.id, { background: value || undefined })}
          />
          <PropertyInput
            label="匹配 App ID"
            type="text"
            value={item.matchAppId || ''}
            onChange={(value) => updateItem(item.id, { matchAppId: value || undefined })}
            placeholder="如 Safari"
          />
        </PropertySection>

        <PropertySection title="标题和图片">
          <PropertyInput
            label="标题"
            type="text"
            value={item.title || ''}
            onChange={(value) => updateItem(item.id, { title: value || undefined })}
            placeholder="按钮文本"
          />
          <PropertyImage
            value={item.image}
            onChange={(value) => updateItem(item.id, { image: value })}
          />
        </PropertySection>

        {definition.properties && definition.properties.length > 0 && (
          <PropertySection title="类型设置">
            <TypeSpecificProperties item={item} definition={definition} updateItem={updateItem} />
          </PropertySection>
        )}

        {definition.supportsActions && (
          <PropertySection title="动作">
            <ActionsEditor item={item} updateItem={updateItem} />
          </PropertySection>
        )}

        <div className="properties-actions">
          <button className="delete-button" onClick={() => removeItem(item.id)}>
            删除元素
          </button>
        </div>
      </div>
    </div>
  );
}

function PropertySection({ title, children }) {
  return (
    <div className="property-section">
      <h3 className="property-section-title">{title}</h3>
      <div className="property-section-content">{children}</div>
    </div>
  );
}

function PropertyInput({ label, type, value, onChange, placeholder }) {
  return (
    <div className="property-field">
      <label className="property-label">{label}</label>
      <input type={type} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} className="property-input" />
    </div>
  );
}

function PropertySelect({ label, value, options, onChange }) {
  return (
    <div className="property-field">
      <label className="property-label">{label}</label>
      <select value={value} onChange={(e) => onChange(e.target.value)} className="property-select">
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
    </div>
  );
}

function PropertyToggle({ label, value, onChange }) {
  return (
    <div className="property-field property-toggle">
      <label className="property-label">{label}</label>
      <button className={`toggle-button ${value ? 'active' : ''}`} onClick={() => onChange(!value)}>
        {value ? '开' : '关'}
      </button>
    </div>
  );
}

function PropertyImage({ value, onChange }) {
  const [mode, setMode] = useState('none');

  useEffect(() => {
    if (!value) setMode('none');
    else if (value.base64) setMode('base64');
    else if (value.filePath) setMode('filePath');
  }, [value]);

  const handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64 = reader.result.split(',')[1];
        onChange({ base64 });
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className="property-field">
      <label className="property-label">图片</label>
      <div className="image-inputs">
        <select value={mode} onChange={(e) => { setMode(e.target.value); if (e.target.value === 'none') onChange(null); }} className="property-select">
          <option value="none">无</option>
          <option value="base64">上传图片</option>
          <option value="filePath">文件路径</option>
        </select>
        {mode === 'base64' && (
          <div className="image-upload">
            <input type="file" accept="image/*" onChange={handleFileChange} className="property-file-input" />
            {value?.base64 && <img src={`data:image/png;base64,${value.base64}`} alt="预览" className="image-preview" />}
          </div>
        )}
        {mode === 'filePath' && (
          <input type="text" value={value?.filePath || ''} onChange={(e) => onChange({ filePath: e.target.value })} placeholder="~/path/to/image.png" className="property-input" />
        )}
      </div>
    </div>
  );
}

function TypeSpecificProperties({ item, definition, updateItem }) {
  const type = item.type;

  switch (type) {
    case 'timeButton':
      return (
        <>
          <PropertyInput label="格式模板" type="text" value={item.formatTemplate || ''} onChange={(value) => updateItem(item.id, { formatTemplate: value })} placeholder="HH:mm" />
          <PropertyInput label="区域" type="text" value={item.locale || ''} onChange={(value) => updateItem(item.id, { locale: value })} placeholder="en_US" />
          <PropertyInput label="时区" type="text" value={item.timeZone || ''} onChange={(value) => updateItem(item.id, { timeZone: value })} placeholder="UTC" />
        </>
      );

    case 'currency':
      return (
        <>
          <PropertyInput label="刷新间隔(秒)" type="number" value={item.refreshInterval ?? ''} onChange={(value) => updateItem(item.id, { refreshInterval: value ? Number(value) : undefined })} />
          <PropertyInput label="源货币" type="text" value={item.from || ''} onChange={(value) => updateItem(item.id, { from: value })} placeholder="BTC" />
          <PropertyInput label="目标货币" type="text" value={item.to || ''} onChange={(value) => updateItem(item.id, { to: value })} placeholder="USD" />
          <PropertyToggle label="完整格式" value={item.full || false} onChange={(value) => updateItem(item.id, { full: value })} />
        </>
      );

    case 'weather':
      return (
        <>
          <PropertyInput label="刷新间隔(秒)" type="number" value={item.refreshInterval ?? ''} onChange={(value) => updateItem(item.id, { refreshInterval: value ? Number(value) : undefined })} />
          <PropertySelect label="单位" value={item.units || 'imperial'} options={[{ value: 'imperial', label: '华氏 (°F)' }, { value: 'metric', label: '摄氏 (°C)' }]} onChange={(value) => updateItem(item.id, { units: value })} />
          <PropertySelect label="图标类型" value={item.icon_type || 'text'} options={[{ value: 'text', label: '文字' }, { value: 'images', label: '图片' }]} onChange={(value) => updateItem(item.id, { icon_type: value })} />
          <PropertyInput label="API 密钥" type="text" value={item.api_key || ''} onChange={(value) => updateItem(item.id, { api_key: value })} placeholder="OpenWeather API key" />
        </>
      );

    case 'yandexWeather':
    case 'music':
      return (
        <>
          <PropertyInput label="刷新间隔(秒)" type="number" value={item.refreshInterval ?? ''} onChange={(value) => updateItem(item.id, { refreshInterval: value ? Number(value) : undefined })} />
          {type === 'music' && <PropertyToggle label="禁止滚动" value={item.disableMarquee || false} onChange={(value) => updateItem(item.id, { disableMarquee: value })} />}
        </>
      );

    case 'dock':
      return (
        <>
          <PropertyInput label="过滤(正则)" type="text" value={item.filter || ''} onChange={(value) => updateItem(item.id, { filter: value })} placeholder="(^Xcode$)|(Safari)" />
          <PropertyToggle label="自动调整大小" value={item.autoResize || false} onChange={(value) => updateItem(item.id, { autoResize: value })} />
        </>
      );

    case 'pomodoro':
      return (
        <>
          <PropertyInput label="工作时间(秒)" type="number" value={item.workTime ?? ''} onChange={(value) => updateItem(item.id, { workTime: value ? Number(value) : undefined })} />
          <PropertyInput label="休息时间(秒)" type="number" value={item.restTime ?? ''} onChange={(value) => updateItem(item.id, { restTime: value ? Number(value) : undefined })} />
        </>
      );

    case 'network':
      return (
        <>
          <PropertyToggle label="翻转" value={item.flip || false} onChange={(value) => updateItem(item.id, { flip: value })} />
          <PropertySelect label="单位" value={item.units || 'dynamic'} options={[{ value: 'dynamic', label: '动态' }, { value: 'B/s', label: 'B/s' }, { value: 'KB/s', label: 'KB/s' }, { value: 'MB/s', label: 'MB/s' }, { value: 'GB/s', label: 'GB/s' }]} onChange={(value) => updateItem(item.id, { units: value })} />
        </>
      );

    case 'upnext':
      return (
        <>
          <PropertyInput label="起始(小时)" type="number" value={item.from ?? ''} onChange={(value) => updateItem(item.id, { from: value ? Number(value) : 0 })} />
          <PropertyInput label="截止(小时)" type="number" value={item.to ?? ''} onChange={(value) => updateItem(item.id, { to: value ? Number(value) : 12 })} />
          <PropertyInput label="最多显示" type="number" value={item.maxToShow ?? ''} onChange={(value) => updateItem(item.id, { maxToShow: value ? Number(value) : 3 })} />
          <PropertyToggle label="自动调整大小" value={item.autoResize || false} onChange={(value) => updateItem(item.id, { autoResize: value })} />
        </>
      );

    case 'staticButton':
      return <PropertyInput label="标题" type="text" value={item.title || ''} onChange={(value) => updateItem(item.id, { title: value })} placeholder="按钮文本" />;

    case 'appleScriptTitledButton':
    case 'shellScriptTitledButton':
      return (
        <>
          <SourceEditor label="源" value={item.source} onChange={(value) => updateItem(item.id, { source: value })} />
          <PropertyInput label="刷新间隔(秒)" type="number" value={item.refreshInterval ?? ''} onChange={(value) => updateItem(item.id, { refreshInterval: value ? Number(value) : undefined })} />
          {type === 'appleScriptTitledButton' && <AlternativeImagesEditor value={item.alternativeImages || {}} onChange={(value) => updateItem(item.id, { alternativeImages: value })} />}
        </>
      );

    case 'swipe':
      return (
        <>
          <PropertySelect label="手指数" value={item.fingers || 2} options={[{ value: 2, label: '2 指' }, { value: 3, label: '3 指' }, { value: 4, label: '4 指' }]} onChange={(value) => updateItem(item.id, { fingers: Number(value) })} />
          <PropertySelect label="方向" value={item.direction || 'right'} options={[{ value: 'left', label: '左滑' }, { value: 'right', label: '右滑' }]} onChange={(value) => updateItem(item.id, { direction: value })} />
          <PropertyInput label="最小偏移" type="number" value={item.minOffset ?? ''} onChange={(value) => updateItem(item.id, { minOffset: value ? Number(value) : undefined })} />
          <SourceEditor label="AppleScript" value={item.sourceApple} onChange={(value) => updateItem(item.id, { sourceApple: value })} />
          <SourceEditor label="Shell Script" value={item.sourceBash} onChange={(value) => updateItem(item.id, { sourceBash: value })} />
        </>
      );

    case 'group':
      return <PropertyInput label="标题" type="text" value={item.title || ''} onChange={(value) => updateItem(item.id, { title: value })} placeholder="组名" />;

    default:
      return <p className="no-properties">无额外属性</p>;
  }
}

function SourceEditor({ label, value, onChange }) {
  const [mode, setMode] = useState(value?.inline ? 'inline' : value?.filePath ? 'filePath' : 'inline');

  return (
    <div className="property-field source-editor">
      <label className="property-label">{label}</label>
      <select value={mode} onChange={(e) => { setMode(e.target.value); onChange({ [e.target.value]: '' }); }} className="property-select">
        <option value="inline">内联</option>
        <option value="filePath">文件路径</option>
        <option value="base64">Base64</option>
      </select>
      <textarea value={value?.[mode] || ''} onChange={(e) => onChange({ [mode]: e.target.value })} placeholder={mode === 'inline' ? '输入脚本...' : mode === 'filePath' ? '~/path/to/script' : 'Base64...'} className="property-textarea" rows={4} />
    </div>
  );
}

function AlternativeImagesEditor({ value, onChange }) {
  const [newKey, setNewKey] = useState('');

  const addImage = () => {
    if (newKey) { onChange({ ...value, [newKey]: { base64: '' } }); setNewKey(''); }
  };

  const removeImage = (key) => {
    const newValue = { ...value };
    delete newValue[key];
    onChange(newValue);
  };

  return (
    <div className="property-field alternative-images">
      <label className="property-label">替代图片</label>
      <div className="alt-images-list">
        {Object.entries(value).map(([key, img]) => (
          <div key={key} className="alt-image-item">
            <span className="alt-image-key">{key}</span>
            <button className="remove-alt-image" onClick={() => removeImage(key)}>×</button>
          </div>
        ))}
      </div>
      <div className="add-alt-image">
        <input type="text" value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="图片标签" className="property-input" />
        <button onClick={addImage} className="add-button">添加</button>
      </div>
    </div>
  );
}

function ActionsEditor({ item, updateItem }) {
  const actions = item.actions || [];

  const addAction = () => {
    const newAction = { id: `action-${Date.now()}`, trigger: 'singleTap', action: 'hidKey', keycode: 0 };
    updateItem(item.id, { actions: [...actions, newAction] });
  };

  const updateAction = (actionId, updates) => {
    updateItem(item.id, { actions: actions.map((a) => (a.id === actionId ? { ...a, ...updates } : a)) });
  };

  const removeAction = (actionId) => {
    updateItem(item.id, { actions: actions.filter((a) => a.id !== actionId) });
  };

  return (
    <div className="actions-editor">
      {actions.map((action) => (
        <ActionItem key={action.id} action={action} onUpdate={(updates) => updateAction(action.id, updates)} onRemove={() => removeAction(action.id)} />
      ))}
      <button onClick={addAction} className="add-action-button">+ 添加动作</button>
    </div>
  );
}

function ActionItem({ action, onUpdate, onRemove }) {
  return (
    <div className="action-item">
      <div className="action-header">
        <select value={action.trigger} onChange={(e) => onUpdate({ trigger: e.target.value })} className="property-select small">
          {actionTriggers.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
        </select>
        <select value={action.action} onChange={(e) => onUpdate({ action: e.target.value })} className="property-select small">
          {Object.values(actionTypes).map((t) => <option key={t.type} value={t.type}>{t.label}</option>)}
        </select>
        <button onClick={onRemove} className="remove-action-button">×</button>
      </div>
      <div className="action-params">
        {action.action === 'hidKey' && <PropertyInput label="键码" type="number" value={action.keycode || 0} onChange={(value) => onUpdate({ keycode: Number(value) })} />}
        {action.action === 'keyPress' && <PropertyInput label="键码" type="number" value={action.keycode || 0} onChange={(value) => onUpdate({ keycode: Number(value) })} />}
        {action.action === 'appleScript' && <SourceEditor label="脚本" value={action.actionAppleScript} onChange={(value) => onUpdate({ actionAppleScript: value })} />}
        {action.action === 'shellScript' && (
          <>
            <PropertyInput label="可执行路径" type="text" value={action.executablePath || ''} onChange={(value) => onUpdate({ executablePath: value })} />
            <PropertyInput label="参数" type="text" value={action.shellArguments?.join(' ') || ''} onChange={(value) => onUpdate({ shellArguments: value ? value.split(' ') : undefined })} />
          </>
        )}
        {action.action === 'openUrl' && <PropertyInput label="URL" type="text" value={action.url || ''} onChange={(value) => onUpdate({ url: value })} />}
      </div>
    </div>
  );
}