// Complete MTMR Element Definitions - Chinese v2

export const elementCategories = {
  buttons: { label: '系统按钮', description: '基本系统功能键' },
  plugins: { label: '原生插件', description: '内置功能插件' },
  media: { label: '媒体键', description: '播放控制' },
  custom: { label: '自定义', description: '脚本和静态按钮' },
  sliders: { label: '滑块', description: '交互式滑块' },
  special: { label: '特殊', description: '分组、手势等' },
  lyricsmtmr: { label: '歌词增强', description: 'LyricsMTMR 专属' },
};

export const elementTypes = {
  escape: {
    type: 'escape', category: 'buttons', label: '退出键', icon: '⎋',
    defaultTitle: 'esc', defaultProps: { width: 64, align: 'left' },
  },
  exitTouchbar: {
    type: 'exitTouchbar', category: 'buttons', label: '关闭 TouchBar', icon: '✕',
    defaultTitle: '✕', defaultProps: { align: 'left', bordered: false },
  },
  brightnessUp: {
    type: 'brightnessUp', category: 'buttons', label: '亮度+', icon: '☀',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  brightnessDown: {
    type: 'brightnessDown', category: 'buttons', label: '亮度-', icon: '☁',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  illuminationUp: {
    type: 'illuminationUp', category: 'buttons', label: '键盘灯+', icon: '◇',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  illuminationDown: {
    type: 'illuminationDown', category: 'buttons', label: '键盘灯-', icon: '◇',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  volumeUp: {
    type: 'volumeUp', category: 'buttons', label: '音量+', icon: '🔊',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  volumeDown: {
    type: 'volumeDown', category: 'buttons', label: '音量-', icon: '🔉',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  mute: {
    type: 'mute', category: 'buttons', label: '静音', icon: '🔇',
    defaultTitle: '', defaultProps: { width: 36 },
  },
  delete: {
    type: 'delete', category: 'buttons', label: '删除', icon: '⌫',
    defaultTitle: 'del', defaultProps: {},
  },
  sleep: {
    type: 'sleep', category: 'buttons', label: '睡眠', icon: '⏾',
    defaultTitle: '⏾', defaultProps: {},
  },
  displaySleep: {
    type: 'displaySleep', category: 'buttons', label: '屏幕休眠', icon: '⏾',
    defaultTitle: '⏾', defaultProps: {},
  },

  // Native Plugins
  timeButton: {
    type: 'timeButton', category: 'plugins', label: '时钟', icon: '🕐',
    defaultTitle: '', defaultProps: { formatTemplate: 'HH:mm', locale: 'zh_CN', timeZone: '' },
    properties: ['formatTemplate', 'locale', 'timeZone'],
  },
  dateButton: {
    type: 'timeButton', category: 'plugins', label: '日期', icon: '📅',
    defaultTitle: '', defaultProps: { formatTemplate: 'M月d日', locale: 'zh_CN', timeZone: '' },
    properties: ['formatTemplate', 'locale', 'timeZone'],
  },
  battery: {
    type: 'battery', category: 'plugins', label: '电池', icon: '🔋',
    defaultTitle: '', defaultProps: {},
  },
  cpu: {
    type: 'cpu', category: 'plugins', label: 'CPU', icon: '⚡',
    defaultTitle: '', defaultProps: {},
  },
  currency: {
    type: 'currency', category: 'plugins', label: '汇率', icon: '💰',
    defaultTitle: '', defaultProps: { refreshInterval: 600, from: 'BTC', to: 'USD', full: false },
    properties: ['refreshInterval', 'from', 'to', 'full'],
  },
  weather: {
    type: 'weather', category: 'plugins', label: '天气', icon: '🌤',
    defaultTitle: '', defaultProps: { refreshInterval: 600, units: 'metric', icon_type: 'text', api_key: '' },
    properties: ['refreshInterval', 'units', 'icon_type', 'api_key'],
  },
  yandexWeather: {
    type: 'yandexWeather', category: 'plugins', label: 'Yandex天气', icon: '🌡',
    defaultTitle: '', defaultProps: { refreshInterval: 600 },
    properties: ['refreshInterval'],
  },
  inputsource: {
    type: 'inputsource', category: 'plugins', label: '输入法', icon: '⌨',
    defaultTitle: '', defaultProps: {},
  },
  music: {
    type: 'music', category: 'plugins', label: '音乐', icon: '🎵',
    defaultTitle: '', defaultProps: { refreshInterval: 5, disableMarquee: false },
    properties: ['refreshInterval', 'disableMarquee'],
  },
  dock: {
    type: 'dock', category: 'plugins', label: 'Dock 栏', icon: '▣',
    defaultTitle: '', defaultProps: { width: 200, autoResize: true },
    properties: ['filter', 'autoResize'],
  },
  nightShift: {
    type: 'nightShift', category: 'plugins', label: '夜览', icon: '🌙',
    defaultTitle: '', defaultProps: { width: 38 },
  },
  dnd: {
    type: 'dnd', category: 'plugins', label: '勿扰模式', icon: '🔕',
    defaultTitle: '', defaultProps: { width: 38 },
  },
  darkMode: {
    type: 'darkMode', category: 'plugins', label: '深色模式', icon: '🌓',
    defaultTitle: '', defaultProps: {},
  },
  pomodoro: {
    type: 'pomodoro', category: 'plugins', label: '番茄钟', icon: '🍅',
    defaultTitle: '', defaultProps: { workTime: 1500, restTime: 300 },
    properties: ['workTime', 'restTime'],
  },
  network: {
    type: 'network', category: 'plugins', label: '网络', icon: '📶',
    defaultTitle: '', defaultProps: { flip: false, units: 'dynamic' },
    properties: ['flip', 'units'],
  },
  upnext: {
    type: 'upnext', category: 'plugins', label: '日历', icon: '📅',
    defaultTitle: '', defaultProps: { from: 0, to: 12, maxToShow: 3, autoResize: false },
    properties: ['from', 'to', 'maxToShow', 'autoResize'],
  },

  // Media Keys
  previous: {
    type: 'previous', category: 'media', label: '上一首', icon: '⏮',
    defaultTitle: '⏮', defaultProps: {},
  },
  play: {
    type: 'play', category: 'media', label: '播放/暂停', icon: '▶',
    defaultTitle: '▶', defaultProps: {},
  },
  next: {
    type: 'next', category: 'media', label: '下一首', icon: '⏭',
    defaultTitle: '⏭', defaultProps: {},
  },

  // Custom Elements
  staticButton: {
    type: 'staticButton', category: 'custom', label: '文字按钮', icon: 'T',
    defaultTitle: '按钮', defaultProps: { title: '按钮' },
    properties: ['title'], supportsActions: true,
  },
  appleScriptTitledButton: {
    type: 'appleScriptTitledButton', category: 'custom', label: 'AppleScript', icon: '🍎',
    defaultTitle: '脚本', defaultProps: { source: { inline: '' }, refreshInterval: 60, alternativeImages: {} },
    properties: ['source', 'refreshInterval', 'alternativeImages'], supportsActions: true,
  },
  shellScriptTitledButton: {
    type: 'shellScriptTitledButton', category: 'custom', label: 'Shell 脚本', icon: '>_',
    defaultTitle: 'Shell', defaultProps: { source: { inline: '' }, refreshInterval: 60 },
    properties: ['source', 'refreshInterval'], supportsActions: true,
  },
  memoryButton: {
    type: 'shellScriptTitledButton', category: 'custom', label: '内存', icon: '🧠',
    defaultTitle: '', defaultProps: { source: { inline: 'memory_pressure | grep "System-wide memory free percentage" | sed "s/.*: //" | sed "s/%//" | xargs -I {} bash -c \'free={} && used=$((100-free)) && echo "${used}%"\' ' }, refreshInterval: 5 },
    properties: ['source', 'refreshInterval'], supportsActions: true,
  },
  activeAppButton: {
    type: 'appleScriptTitledButton', category: 'custom', label: '当前应用', icon: '◎',
    defaultTitle: '', defaultProps: { source: { inline: 'tell application "System Events" to get name of first process whose frontmost is true' }, refreshInterval: 1 },
    properties: ['source', 'refreshInterval'], supportsActions: true,
  },

  // Sliders
  brightness: {
    type: 'brightness', category: 'sliders', label: '亮度滑块', icon: '☀',
    defaultTitle: '☀', defaultProps: {},
  },
  volume: {
    type: 'volume', category: 'sliders', label: '音量滑块', icon: '🔊',
    defaultTitle: '🔊', defaultProps: {},
  },

  // Special Elements
  group: {
    type: 'group', category: 'special', label: '分组', icon: '▤',
    defaultTitle: '分组', defaultProps: { title: '分组', items: [] },
    properties: ['title'], isContainer: true,
  },
  close: {
    type: 'close', category: 'special', label: '关闭', icon: '✕',
    defaultTitle: '✕', defaultProps: {},
  },
  swipe: {
    type: 'swipe', category: 'special', label: '滑动手势', icon: '⇌',
    defaultTitle: '滑动', defaultProps: { fingers: 2, direction: 'right', minOffset: 10, sourceApple: null, sourceBash: null },
    properties: ['fingers', 'direction', 'minOffset', 'sourceApple', 'sourceBash'],
  },

  // ── LyricsMTMR 专属 ──
  lyrics: {
    type: 'lyrics', category: 'lyricsmtmr', label: '歌词', icon: '♫',
    defaultTitle: '', defaultProps: { displayMode: 'karaoke', karaokeStyle: 'progressive', showArtwork: true, clickAction: 'original', marqueeEnabled: false },
    properties: ['displayMode', 'karaokeStyle', 'showArtwork', 'clickAction'],
  },
  lyricsArtwork: {
    type: 'lyrics', category: 'lyricsmtmr', label: '歌词+封面', icon: '🖼',
    defaultTitle: '', defaultProps: { displayMode: 'karaoke', karaokeStyle: 'progressive', showArtwork: true, clickAction: 'original' },
    properties: ['displayMode', 'karaokeStyle', 'showArtwork', 'clickAction'],
    key: 'lyricsArtwork',
  },
};

export const commonProperties = {
  width: { type: 'number', label: '宽度', description: '按钮宽度(像素)', min: 20, max: 500, default: null },
  align: { type: 'select', label: '对齐', description: '水平对齐方式',
    options: [{ value: 'left', label: '左' }, { value: 'center', label: '中' }, { value: 'right', label: '右' }], default: 'center' },
  bordered: { type: 'boolean', label: '边框', description: '显示边框', default: true },
  background: { type: 'color', label: '背景色', description: '背景颜色(十六进制)', default: null },
  title: { type: 'string', label: '标题', description: '按钮文字', default: '' },
  image: { type: 'image', label: '图片', description: '图标(base64 或路径)', default: null },
  matchAppId: { type: 'string', label: '匹配应用', description: '仅当此应用活跃时显示(正则)', default: null },
};

export const actionTriggers = [
  { value: 'singleTap', label: '单击' },
  { value: 'doubleTap', label: '双击' },
  { value: 'tripleTap', label: '三击' },
  { value: 'longTap', label: '长按' },
];

export const actionTypes = {
  hidKey: { type: 'hidKey', label: 'HID 按键', properties: ['keycode'] },
  keyPress: { type: 'keyPress', label: '按键', properties: ['keycode'] },
  appleScript: { type: 'appleScript', label: 'AppleScript', properties: ['actionAppleScript'] },
  shellScript: { type: 'shellScript', label: 'Shell 脚本', properties: ['executablePath', 'shellArguments'] },
  openUrl: { type: 'openUrl', label: '打开 URL', properties: ['url'] },
};

export const getElementsByCategory = (category) => {
  return Object.values(elementTypes).filter((el) => el.category === category);
};

export const getElementDefinition = (type) => {
  if (elementTypes[type]) return elementTypes[type];
  return Object.values(elementTypes).find((el) => el.type === type) || null;
};

export const getElementDefinitionByKey = (key) => {
  return Object.values(elementTypes).find((el) => el.key === key) || null;
};

export const createElement = (typeOrKey, overrides = {}) => {
  let definition = getElementDefinitionByKey(typeOrKey);
  if (!definition) definition = elementTypes[typeOrKey];
  if (!definition) return { id: `item-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`, type: typeOrKey, ...overrides };
  return { id: `item-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`, type: definition.type, ...definition.defaultProps, ...overrides };
};
