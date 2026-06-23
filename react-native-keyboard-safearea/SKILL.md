---
name: react-native-keyboard-safearea
description: React Native keyboard avoidance + SafeArea patterns — SafeAreaView, useSafeAreaInsets, KeyboardAvoidingView, KeyboardAwareScrollView, platform differences
---

# React Native — Keyboard & SafeArea

## SafeArea — `react-native-safe-area-context`

Always use `react-native-safe-area-context` (not the deprecated `SafeAreaView` from RN core).

### Setup

```tsx
// App.tsx — wrap root
import { SafeAreaProvider } from 'react-native-safe-area-context';

export default function App() {
  return (
    <SafeAreaProvider>
      <NavigationContainer>
        <RootNavigator />
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
```

### SafeAreaView — Full Screen Safe Zone

```tsx
import SafeAreaView from 'react-native-safe-area-context';

// ❌ RN core SafeAreaView — deprecated, no edge control
import { SafeAreaView } from 'react-native';

// ✅ SafeAreaView from safe-area-context — edges prop
<SafeAreaView edges={['top', 'bottom']} style={{ flex: 1 }}>
  <YourContent />
</SafeAreaView>
```

| `edges` | Effect |
|---------|--------|
| `['top']` | Pads below status bar / notch / Dynamic Island |
| `['bottom']` | Pads above home indicator |
| `['top', 'bottom']` | Most common — both ends |
| `['left', 'right']` | Rare (iPad landscape split view) |
| `[]` | No padding (op-out specific edge) |

### useSafeAreaInsets Hook — Manual Control

Use when you need custom layout around SafeArea (e.g. a custom header).

```tsx
import { useSafeAreaInsets } from 'react-native-safe-area-context';

function CustomHeader() {
  const insets = useSafeAreaInsets();
  // insets = { top: 47, bottom: 34, left: 0, right: 0 }

  return (
    <View style={{ paddingTop: insets.top, height: 44 + insets.top }}>
      <Text>Header</Text>
    </View>
  );
}
```

```tsx
// ✅ Full-screen immersive layout — content under notch, no clipped zones
function FullScreenPage() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, paddingBottom: insets.bottom }}>
      <View style={{ paddingTop: insets.top }}>
        <Text>Safe title</Text>
      </View>

      <ScrollView style={{ flex: 1 }}>
        <Content />
      </ScrollView>
    </View>
  );
}
```

### Platform Differences

| Device | `insets.top` | `insets.bottom` |
|--------|-------------|-----------------|
| iPhone 14 Pro Max | 59 | 34 |
| iPhone SE (no notch) | 20 (status bar) | 0 |
| Android (status bar) | 24–48 | 0 |
| Android (gesture nav) | 24–48 | 24–48 |
| Android (3-button nav) | 24–48 | 0 |

---

## Keyboard — Avoidance Strategies

### 1. KeyboardAvoidingView (Built-in)

Simple forms where content sits above the input.

```tsx
import { KeyboardAvoidingView, Platform } from 'react-native';

function LoginForm() {
  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      keyboardVerticalOffset={Platform.select({ ios: 88, android: 0 })}
    >
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'center' }}
        keyboardShouldPersistTaps="handled"
      >
        <TextInput placeholder="Email" />
        <TextInput placeholder="Password" />
        <Button title="Login" />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
```

| Prop | iOS | Android |
|------|-----|---------|
| `behavior` | `'padding'` (resize view) | `'height'` (resize view) |
| `keyboardVerticalOffset` | Header/NavBar height | 0 |

`keyboardVerticalOffset` is critical on iOS — it's the height of your navigation bar / header above the form, otherwise the keyboard pushes content too high.

### 2. KeyboardAwareScrollView (react-native-keyboard-aware-scroll-view)

Better for complex forms with multiple inputs — auto-scrolls to focused input.

```tsx
import { KeyboardAwareScrollView } from 'react-native-keyboard-aware-scroll-view';

function LongForm() {
  return (
    <KeyboardAwareScrollView
      extraScrollHeight={20}
      enableOnAndroid
      keyboardShouldPersistTaps="handled"
    >
      <TextInput placeholder="Name" />
      <TextInput placeholder="Email" />
      <TextInput placeholder="Phone" />
      <TextInput placeholder="Address" />
      <Button title="Submit" />
    </KeyboardAwareScrollView>
  );
}
```

### 3. Manual Keyboard Listener

For custom animations or non-form layouts (e.g. chat input that slides up).

```tsx
import { Keyboard, KeyboardEvent } from 'react-native';

function ChatInput() {
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const insets = useSafeAreaInsets();

  useEffect(() => {
    const show = Keyboard.addListener('keyboardWillShow', (e: KeyboardEvent) => {
      setKeyboardHeight(e.endCoordinates.height);
    });
    const hide = Keyboard.addListener('keyboardWillHide', () => {
      setKeyboardHeight(0);
    });
    return () => {
      show.remove();
      hide.remove();
    };
  }, []);

  return (
    <View style={{ flex: 1 }}>
      <MessageList />
      <View style={{
        paddingBottom: keyboardHeight > 0 ? keyboardHeight : insets.bottom,
      }}>
        <TextInput placeholder="Type a message..." />
      </View>
    </View>
  );
}
```

> **Note**: `keyboardWillShow` / `keyboardWillHide` are iOS only. On Android use `keyboardDidShow` / `keyboardDidHide`.

### 4. Typing State & Completion — isTyping / Enter / Debounce

No native `isComplete` prop. Three complementary patterns for different "when has the user finished typing?" scenarios:

#### Pattern A: `isTyping` — 输入中状态

标准 JS API：`onChangeText` 时 `setIsTyping(true)` + `setTimeout` 延时复位。

```tsx
function useIsTyping(text: string, delay = 500): boolean {
  const [isTyping, setIsTyping] = useState(false);

  useEffect(() => {
    if (text.length === 0) {
      setIsTyping(false);
      return;
    }
    setIsTyping(true);                              // 每次按键 → true
    const timer = setTimeout(() => {
      setIsTyping(false);                           // 停笔 delay ms → false
    }, delay);
    return () => clearTimeout(timer);
  }, [text, delay]);

  return isTyping;
}
```

对于中文/日文/韩文输入法（IME），用 `onCompositionStart` / `onCompositionEnd` 避免拼字中途误判：

```tsx
function ChatInput() {
  const [text, setText] = useState('');
  const [isComposing, setIsComposing] = useState(false);
  const [isTyping, setIsTyping] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout>>();

  const clearTyping = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setIsTyping(false), 500);
  };

  return (
    <TextInput
      value={text}
      onChangeText={(t) => {
        setText(t);
        if (!isComposing) {
          setIsTyping(true);
          clearTyping();
        }
      }}
      onCompositionStart={() => setIsComposing(true)}
      onCompositionEnd={(e) => {
        setIsComposing(false);
        setIsTyping(true);
        clearTyping();
      }}
    />
  );
}
```

| 场景 | `isTyping` 机制 |
|------|----------------|
| 英文/数字输入 | `onChangeText` → `setIsTyping(true)` + `setTimeout(..., 500)` |
| 中文拼音/日文假名输入 | `onCompositionStart` 时不触发，`onCompositionEnd` 才算一次 |
| 清空输入框 | `text.length === 0` → 立即 `setIsTyping(false)` |
| Chat "对方正在输入..." | 配合 WebSocket 在 `isTyping` 变化时发送 typing indicator |

#### Pattern B: `onSubmitEditing` — Enter / Done Key

当用户点击键盘的 **Enter / Search / Done / Send** 按钮时触发。
⚠️ **CJK 输入法（中文拼音/五笔、日文假名）选字按 Enter 也会触发 `onSubmitEditing`**，用 `nativeEvent.isComposing` 过滤。

```tsx
function SearchField() {
  const [query, setQuery] = useState('');

  const handleSubmit = useCallback(() => {
    if (!query.trim()) return;
    searchAPI(query.trim());
    Keyboard.dismiss();
  }, [query]);

  return (
    <TextInput
      value={query}
      onChangeText={setQuery}
      onSubmitEditing={(e) => {
        // nativeEvent.isComposing 原生支持，RN + 浏览器通用
        if ((e.nativeEvent as any).isComposing) return;
        handleSubmit();
      }}
      returnKeyType="search"
    />
  );
}
```

| `returnKeyType` | 键盘按钮 | 典型场景 |
|-----------------|---------|----------|
| `'search'` | 搜索 | 搜索栏 |
| `'done'` | 完成 | 单字段表单 |
| `'send'` | 发送 | 聊天 |
| `'go'` | 前往 | URL 输入 |
| `'next'` | 下一项 | 多表单跳转 |
| `'default'` | 换行 ↵ | 多行输入 |

多表单连续输入 — 按 "Next" 跳到下一个，同样防输入法误触：

```tsx
function LoginForm() {
  const emailRef = useRef<TextInput>(null);
  const passwordRef = useRef<TextInput>(null);

  return (
    <View>
      <TextInput
        ref={emailRef}
        placeholder="Email"
        returnKeyType="next"
        onSubmitEditing={(e) => {
          if ((e.nativeEvent as any).isComposing) return;
          passwordRef.current?.focus();
        }}
      />
      <TextInput
        ref={passwordRef}
        placeholder="Password"
        returnKeyType="done"
        secureTextEntry
        onSubmitEditing={(e) => {
          if ((e.nativeEvent as any).isComposing) return;
          handleLogin();
        }}
      />
    </View>
  );
}
```

> **底层原理：** `isComposing` 是 DOM 标准属性（`KeyboardEvent.isComposing`），React Native 也透传了它。
> 不需要手动维护 `onCompositionStart/End` + ref，`nativeEvent.isComposing` 在 RN 和浏览器上都可用。

#### Pattern B2: Chat 发送 — Enter 防输入法误触

聊天输入框既要支持多行（Enter 换行），又要支持 Enter 发送，还要防选字时误发：

```tsx
function ChatInput() {
  const [text, setText] = useState('');

  const sendMessage = () => {
    if (!text.trim()) return;
    send(text);
    setText('');
    Keyboard.dismiss();
  };

  return (
    <TextInput
      value={text}
      onChangeText={setText}
      multiline
      blurOnSubmit={false}
      onKeyPress={({ nativeEvent }) => {
        // Enter（非输入法选字）→ 发送
        // Shift+Enter → 换行（multiline 自然处理）
        if (nativeEvent.key === 'Enter' && !(nativeEvent as any).isComposing) {
          sendMessage();
        }
      }}
    />
  );
}
```

> ⚠️ `multiline` 为 true 时 `returnKeyType` / `onSubmitEditing` 均不生效（RN 行为），Enter 由 `onKeyPress` 接管。

#### Pattern C: Debounce — Stopped Typing (Auto-Save / Search)

No built-in `isComplete` prop on TextInput. Use debounce to detect when the user **stops typing** for a defined pause.

```tsx
// Option 1: useDebounce (ahooks) — debounce the VALUE
import { useDebounce } from 'ahooks';
const debouncedQuery = useDebounce(query, { wait: 300 });
useEffect(() => { if (debouncedQuery) searchAPI(debouncedQuery); }, [debouncedQuery]);

// Option 2: useDebounceFn (ahooks) — debounce the ACTION
import { useDebounceFn } from 'ahooks';
const { run: autoSave } = useDebounceFn((t) => saveDraftAPI(t), { wait: 800 });

// Option 3: lodash.debounce — minimal deps
import debounce from 'lodash/debounce';
const search = useCallback(debounce((t) => searchAPI(t), 300), []);
```

| Approach | Best for | Debounce target |
|----------|----------|----------------|
| `useDebounce` (ahooks) | Search, filter, derived state | **Value** — debounce the text value |
| `useDebounceFn` (ahooks) | Auto-save, API calls | **Action** — debounce the function call |
| `lodash.debounce` | Minimal deps, no ahooks | **Action** — debounce the callback |

#### Which pattern to use?

| Scenario | Pattern |
|----------|---------|
| "对方正在输入..." / typing indicator | **A** — `isTyping` |
| User pressed Search/Done/Send key | **B** — `onSubmitEditing` |
| Search-as-you-type / auto-save | **C** — Debounce |
| Chat send button + Enter key | **B + C** — `onSubmitEditing` sends immediately, debounce saves draft |

> **Native side (iOS/Android):** There is no native `isComplete` callback for "user stopped typing." The standard UIKit/Android approach is `textField(_:shouldChangeCharactersIn:)` / `onTextChanged` with a timer — which is exactly what the JS debounce pattern replicates. `onSubmitEditing` maps directly to `textFieldShouldReturn` (iOS) / `onEditorAction(IME_ACTION_DONE)` (Android).

---

## Keyboard Controller — react-native-keyboard-controller

Replace built-in `KeyboardAvoidingView` + `Keyboard` listener boilerplate with [`react-native-keyboard-controller`](https://kirillzyusko.github.io/react-native-keyboard-controller/) — consistent on both platforms, animated, interactive.

### Setup

```tsx
// App.tsx — 替换 SafeAreaProvider 或包在外面
import { KeyboardProvider } from 'react-native-keyboard-controller';

export default function App() {
  return (
    <KeyboardProvider>
      <SafeAreaProvider>
        <NavigationContainer>
          <RootNavigator />
        </NavigationContainer>
      </SafeAreaProvider>
    </KeyboardProvider>
  );
}
```

### useReanimatedKeyboardAnimation — 替代 Manual Keyboard Listener

```tsx
import { useReanimatedKeyboardAnimation } from 'react-native-keyboard-controller';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';

function ChatInput() {
  const { height, progress } = useReanimatedKeyboardAnimation();
  const insets = useSafeAreaInsets();

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: -height.value }],
  }));

  return (
    <View style={{ flex: 1 }}>
      <MessageList />
      <Animated.View style={[{ paddingBottom: insets.bottom }, animatedStyle]}>
        <TextInput placeholder="Type a message..." />
      </Animated.View>
    </View>
  );
}
```

`height` = 键盘实际高度，`progress` = 0→1 动画进度，都是 Reanimated shared value，60fps 不丢帧。

### KeyboardAwareScrollView — 替代 KeyboardAwareScrollView (第三方)

自带键盘感知滚动，不需要另外装 `react-native-keyboard-aware-scroll-view`。

```tsx
import { KeyboardAwareScrollView } from 'react-native-keyboard-controller';

function LongForm() {
  return (
    <KeyboardAwareScrollView keyboardShouldPersistTaps="handled">
      <TextInput placeholder="Name" />
      <TextInput placeholder="Email" />
      <Button title="Submit" />
    </KeyboardAwareScrollView>
  );
}
```

### KeyboardAvoidingView — 替代内置 KeyboardAvoidingView

```tsx
import { KeyboardAvoidingView } from 'react-native-keyboard-controller';

// 不需要 behavior / keyboardVerticalOffset，自动处理
<KeyboardAvoidingView style={{ flex: 1 }}>
  <ScrollView keyboardShouldPersistTaps="handled">
    <TextInput />
  </ScrollView>
</KeyboardAvoidingView>
```

### KeyboardStickyView — 吸附键盘顶部

适合聊天输入框、底部工具条：

```tsx
import { KeyboardStickyView } from 'react-native-keyboard-controller';

<KeyboardStickyView>
  <View style={{ flexDirection: 'row', padding: 8 }}>
    <TextInput placeholder="Type a message..." style={{ flex: 1 }} />
    <Button title="Send" />
  </View>
</KeyboardStickyView>
```

自动吸附在键盘上方，键盘弹出时上移、收起时下移，动画平滑。

### KeyboardToolbar — 表单导航工具栏

为表单自动添加 Prev / Next / Done 工具栏（类似 Safari 表单栏）：

```tsx
import { KeyboardToolbar } from 'react-native-keyboard-controller';

<View>
  <TextInput placeholder="Email" />
  <TextInput placeholder="Password" />
  <KeyboardToolbar />
</View>
```

### KeyboardEvents — 替代 Keyboard.addListener

```tsx
import { KeyboardEvents } from 'react-native-keyboard-controller';

useEffect(() => {
  const sub1 = KeyboardEvents.addListener('keyboardWillShow', (e) => {
    console.log('height:', e.height, 'duration:', e.duration);
  });
  const sub2 = KeyboardEvents.addListener('keyboardWillHide', (e) => {
    console.log('will hide');
  });
  return () => {
    sub1.remove();
    sub2.remove();
  };
}, []);
```

`keyboardWillShow` / `keyboardWillHide` 在 iOS 和 Android 上都生效（内置 `Keyboard` 的 will 事件仅 iOS 有）。

### Imperative API — KeyboardController

```tsx
import { KeyboardController } from 'react-native-keyboard-controller';

// 主动控制键盘
KeyboardController.dismiss();
KeyboardController.setMode('resize');    // 切换软输入模式（Android）
KeyboardController.setMode('pan');
KeyboardController.setMode('nothing');
```

### Summary — 替换对照表

| 旧方案（内置/第三方） | 替代 |
|----------------------|------|
| `KeyboardAvoidingView` (RN) | `KeyboardAvoidingView` (keyboard-controller) |
| `KeyboardAwareScrollView` (第三方) | `KeyboardAwareScrollView` (keyboard-controller) |
| `Keyboard.addListener('keyboardWillShow')` | `KeyboardEvents.addListener('keyboardWillShow')` |
| `useState` + `setTimeout` 手动跟键盘高度 | `useReanimatedKeyboardAnimation()` |
| Chat 输入框手动动画 | `KeyboardStickyView` |
| 表单 Prev/Next/Done 工具栏 | `KeyboardToolbar` |
| `Keyboard.dismiss()` | `KeyboardController.dismiss()` |

### Platform-Specific Tips

---

## Custom Keyboard — 全量替换系统键盘

适合 PIN 输入、数字金额、计算器、点单数量选择等场景。完全不使用原生键盘，用自定义 View 代替。

### 方案 A: DIY — 最灵活跨平台

核心思路：**不用 TextInput 做输入**，用 TouchableOpacity 触发自定义键盘面板，值存在 JS state 里。

```tsx
function PINKeyboard({ value, onChange, maxLength = 6 }) {
  const handlePress = (key: string) => {
    if (key === 'backspace') {
      onChange(value.slice(0, -1));
    } else if (key === 'clear') {
      onChange('');
    } else if (value.length < maxLength) {
      onChange(value + key);
    }
  };

  const keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['clear', '0', 'backspace'],
  ];

  return (
    <View style={{ paddingBottom: insets.bottom }}>
      {keys.map((row, i) => (
        <View key={i} style={{ flexDirection: 'row' }}>
          {row.map((key) => (
            <TouchableOpacity
              key={key}
              style={{ flex: 1, height: 56, justifyContent: 'center', alignItems: 'center' }}
              onPress={() => handlePress(key)}
            >
              <Text style={{ fontSize: 24 }}>
                {key === 'backspace' ? '⌫' : key === 'clear' ? '清除' : key}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      ))}
    </View>
  );
}

function PINInput() {
  const [pin, setPin] = useState('');

  return (
    <View style={{ flex: 1, justifyContent: 'center' }}>
      {/* 显示区域 */}
      <View style={{ flexDirection: 'row', justifyContent: 'center', marginBottom: 40 }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <View key={i} style={{
            width: 16, height: 16, borderRadius: 8,
            backgroundColor: pin[i] ? '#000' : '#ddd',
            marginHorizontal: 8,
          }} />
        ))}
      </View>

      {/* 自定义键盘 */}
      <PINKeyboard value={pin} onChange={setPin} />
    </View>
  );
}
```

### 方案 B: TextInput + showSoftInputOnFocus (Android)

如果既要 TextInput 的焦点管理能力、又不显示系统键盘：

```tsx
function CustomKeyboardInput() {
  const inputRef = useRef<TextInput>(null);
  const [value, setValue] = useState('');

  const handleCustomKeyPress = (key: string) => {
    if (key === 'backspace') {
      setValue(v => v.slice(0, -1));
    } else {
      setValue(v => v + key);
    }
  };

  return (
    <View>
      {/* 隐藏的 TextInput，只用来获取焦点但不弹键盘 */}
      <TextInput
        ref={inputRef}
        showSoftInputOnFocus={false}   // Android: 聚焦时不弹系统键盘
        style={{ height: 0, width: 0 }} // 彻底隐藏
      />

      {/* 显示区域 — 点击触发焦点 */}
      <TouchableOpacity onPress={() => inputRef.current?.focus()}>
        <Text style={{ fontSize: 24, letterSpacing: 8 }}>
          {value || '点击输入'}
        </Text>
      </TouchableOpacity>

      {/* 自定义键盘面板 */}
      <CustomKeyboard onKeyPress={handleCustomKeyPress} />
    </View>
  );
}
```

> ⚠️ `showSoftInputOnFocus` 是 Android 专有 prop。iOS 上没有等效 API，需要用方案 A 完全绕过 TextInput。

### 方案 C: 第三方库

| 库 | 场景 | 备注 |
|---|------|------|
| `react-native-keyboard-kit` | 通用自定义键盘 | Notifee 维护，支持自定义 keyboard view 替换系统键盘 |
| `react-native-nice-keyboard` | 数字键盘 | 纯数字输入场景 |
| `react-native-pure-keyboard` | 安全键盘 | 防截屏、防录屏的安全输入 |

### 默认推荐：方案 A (DIY) — 原因

iOS 原生 `secureTextEntry` 安全键盘的**按键圆角无法自定义**，和你的 UI 设计可能不一致。所以默认推荐用 **方案 A (DIY)**：

```tsx
// ✅ 自定义安全键盘 — 按键内容完全由你控制
// 可以纯数字（PIN）、字母+数字（密码）、自定义符号

type KeyRow = { label: string; value: string }[];

function SecureKeyboard({ value, onChange, maxLength, keys, shuffle }: {
  value: string;
  onChange: (v: string) => void;
  maxLength: number;
  keys?: KeyRow[];                       // 自定义按键布局
  shuffle?: boolean;
  keyStyle?: ViewStyle;                  // 按键自定义样式（圆角等）
}) {
  const handlePress = (k: string) => {
    if (k === 'backspace') return onChange(value.slice(0, -1));
    if (k === 'clear') return onChange('');
    if (value.length >= maxLength) return;
    onChange(value + k);
  };

  // 默认布局 — 纯数字 PIN
  const defaultKeys: KeyRow[] = shuffle
    ? [shuffleArray(['1','2','3']), shuffleArray(['4','5','6']),
       shuffleArray(['7','8','9']), ['clear', shuffleArray(['0'])[0], 'backspace']]
    : [['1','2','3'], ['4','5','6'], ['7','8','9'], ['clear','0','backspace']];

  const rows = keys ?? defaultKeys;

  return (
    <View>
      {rows.map((row, i) => (
        <View key={i} style={{ flexDirection: 'row' }}>
          {row.map((k) => (
            <TouchableOpacity key={k.label ?? k}
              style={[{ flex: 1, height: 56, justifyContent: 'center', alignItems: 'center' }, keyStyle]}
              onPress={() => handlePress(k.value ?? k)}
            >
              <Text style={{ fontSize: 24 }}>
                {k.label ?? (k === 'backspace' ? '⌫' : k === 'clear' ? '清除' : k)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      ))}
    </View>
  );
}

// 纯数字 PIN
function SecurePINInput() {
  const [pin, setPin] = useState('');
  return (
    <View style={{ flex: 1 }}>
      <Dots value={pin} length={6} />
      <SecureKeyboard value={pin} onChange={setPin} maxLength={6}
        keyStyle={{ borderRadius: 0 }} shuffle />
    </View>
  );
}

// 字母+数字 安全密码键盘
function SecurePasswordInput() {
  const [pwd, setPwd] = useState('');
  const alphaKeys: KeyRow[] = [
    ['Q','W','E','R','T','Y','U','I','O','P'],
    ['A','S','D','F','G','H','J','K','L'],
    ['Z','X','C','V','B','N','M','backspace'],
    ['clear',' ','done'],
  ].map(row => row.map(k => ({ label: k, value: k })));

  return (
    <View style={{ flex: 1 }}>
      <Dots value={pwd} length={8} />
      <SecureKeyboard value={pwd} onChange={setPwd} maxLength={8}
        keys={alphaKeys}
        keyStyle={{ borderRadius: 0 }} />
    </View>
  );
}

// 自定义符号键盘（如交易密码 + 金额键盘）
function CustomSymbolInput() {
  const [val, setVal] = useState('');
  const symbolKeys: KeyRow[] = [
    ['1','2','3','+'],
    ['4','5','6','-'],
    ['7','8','9','.'],
    ['clear','0','backspace','done'],
  ].map(row => row.map(k => ({ label: k, value: k })));

  return <SecureKeyboard value={val} onChange={setVal} maxLength={10} keys={symbolKeys} />;
}
```

> **关键点：** 因为是纯 View 实现，**输入内容完全不受限制**。
> - `keys` prop 传入任意 KeyRow[]，就可以渲染数字、字母、符号、中文等各种按键
> - `shuffle` 乱序适用于安全键盘（防偷窥）
> - 每个按键的样式（圆角、颜色、字体）完全由你控制
> - 适合各种金融安全输入场景（PIN、交易密码、支付金额等）

> ⚠️ **iOS 原生 `secureTextEntry` 的限制：**
> - 按键圆角（corner radius）不可修改
> - 无法乱序排列
> - 无法自定义按键颜色/字体
> - 如果这些对你不是问题，可以直接用 `secureTextEntry` + `TextInput`
>
> **Android** 上 `secureTextEntry` 的按键样式可定制（theme 控制），iOS 完全不行。

### 何时用哪种？

| 场景 | 推荐方案 |
|------|---------|
| PIN / 密码输入（默认） | **A (DIY)** — iOS 原生安全键盘圆角不可自定义 |
| 安全键盘 + 乱序排列 | **A (DIY)** — 自定义乱序 + 样式完全可控 |
| 数字金额输入 (Android) | **B** — `showSoftInputOnFocus`，保留焦点管理 |
| 数字金额输入 (iOS) | **A** — iOS 不支持 `showSoftInputOnFocus` |
| 安全输入（银行类） | **A (DIY)** 或 **C** — `pure-keyboard` 自带防截屏 |
| 复杂自定义布局（计算器、点单） | **A** — DIY，完全自由 |

## Combined Pattern — SafeArea + Keyboard

### 推荐方案：react-native-keyboard-controller

```tsx
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { KeyboardAwareScrollView } from 'react-native-keyboard-controller';

function FormScreen() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, paddingBottom: insets.bottom }}>
      <KeyboardAwareScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{
          paddingTop: insets.top,
          paddingHorizontal: 16,
        }}
      >
        <HeaderSection />
        <FormField label="Name" />
        <FormField label="Email" />
        <Button title="Submit" />
      </KeyboardAwareScrollView>
    </View>
  );
}
```

### 备选方案：内置 API（无需额外安装）

```tsx
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { KeyboardAvoidingView, Platform } from 'react-native';
import { KeyboardAwareScrollView } from 'react-native-keyboard-aware-scroll-view';

function FormScreen() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, paddingBottom: insets.bottom }}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.select({ ios: 88, android: 0 })}
      >
        <KeyboardAwareScrollView
          keyboardShouldPersistTaps="handled"
          extraScrollHeight={20}
          enableOnAndroid
          contentContainerStyle={{
            paddingTop: insets.top,
            paddingHorizontal: 16,
          }}
        >
          <HeaderSection />
          <FormField label="Name" />
          <FormField label="Email" />
          <FormField label="Phone" />
          <Button title="Submit" />
        </KeyboardAwareScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}
```

**Layering logic (备选方案):**
1. Outer `View` handles `insets.bottom` (SafeArea bottom padding is always respected)
2. `KeyboardAvoidingView` handles the keyboard push (iOS only)
3. `KeyboardAwareScrollView` handles auto-scroll to the focused input
4. Inner `contentContainerStyle` handles `insets.top` (SafeArea top padding)

---

## Red Flags — Immediate STOPS

- ❌ Using `SafeAreaView` from `react-native` core (deprecated, no edge control)
- ❌ Missing `SafeAreaProvider` wrapper → `useSafeAreaInsets()` returns `{ top: 0, bottom: 0, ... }`
- ❌ Forgetting `keyboardVerticalOffset` on iOS → content pushed too high by nav bar height
- ❌ Using `keyboardWillShow` on Android → event never fires, use `keyboardDidShow`（或用 `keyboard-controller` 的 `KeyboardEvents`，双平台都支持 will 事件）
- ❌ `KeyboardAvoidingView` without `behavior` prop → no effect（或用 `keyboard-controller` 的版本，不需要 behavior）
- ❌ Ignoring gesture navigation bottom inset on Android (`insets.bottom > 0` on gesture nav devices)
- ❌ Waiting for a native `isComplete` callback — RN TextInput has no such prop, use JS debounce
- ❌ `onSubmitEditing` without `returnKeyType` — keyboard button shows default "return" instead of "Search"/"Done"/"Send"
- ❌ Missing `Keyboard.dismiss()` in `onSubmitEditing` — keyboard stays open after submit on some platforms
- ❌ CJK 输入法选字 Enter 误触 `onSubmitEditing` — 用 `nativeEvent.isComposing` 过滤，不需要手动维护 ref + `onCompositionStart/End`
- ❌ `multiline` 下用了 `onSubmitEditing` / `returnKeyType` — 这两个 prop 对 multiline TextInput 不生效，改用 `onKeyPress` 拦截 Enter
- ❌ iOS 上用了 `showSoftInputOnFocus={false}` — iOS 不支持此 prop，用 DIY View 方案替代
- ❌ 混用 `KeyboardAvoidingView` (RN) + `keyboard-controller` 在同一页 — 只用其中一个即可
