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

Track whether the user is actively typing. `isTyping = true` starts on first keystroke; after a pause (debounce) it flips back to `false`.

```tsx
import { useDebounce } from 'ahooks';

function ChatInput() {
  const [text, setText] = useState('');

  // 用户正在输入 → true, 停笔 500ms → false
  const isTyping = useDebounce(text, { wait: 500 }) !== text
                    || (text.length > 0 && text === useDebounce(text, { wait: 500 }));

  // 更直观的写法：独立 isTyping state
  const [isTyping, setIsTyping] = useState(false);

  useEffect(() => {
    if (text.length > 0) {
      setIsTyping(true);
      const timer = setTimeout(() => setIsTyping(false), 500);
      return () => clearTimeout(timer);
    } else {
      setIsTyping(false);
    }
  }, [text]);

  return (
    <View>
      <TextInput value={text} onChangeText={setText} />
      {isTyping && <Text>对方正在输入...</Text>}
    </View>
  );
}
```

For a reusable hook:

```tsx
function useIsTyping(text: string, delay = 500): boolean {
  const [isTyping, setIsTyping] = useState(false);

  useEffect(() => {
    if (text.length === 0) {
      setIsTyping(false);
      return;
    }
    setIsTyping(true);
    const timer = setTimeout(() => setIsTyping(false), delay);
    return () => clearTimeout(timer);
  }, [text, delay]);

  return isTyping;
}
```

| Use | `isTyping = true` | `isTyping = false` |
|-----|-------------------|---------------------|
| Chat "对方正在输入..." | User starts typing | 500ms after last keystroke |
| Send button state | Text exists (combined with `text.length > 0`) | Text cleared |

#### Pattern B: `onSubmitEditing` — Enter / Done Key Press

When the user taps the **Enter / Return / Done / Search** button on the keyboard.
This is the closest RN has to a native "input complete" signal.

```tsx
function SearchField() {
  const [query, setQuery] = useState('');

  const handleSubmit = useCallback(() => {
    if (!query.trim()) return;
    searchAPI(query.trim());
    Keyboard.dismiss(); // dismiss keyboard after submit
  }, [query]);

  return (
    <TextInput
      value={query}
      onChangeText={setQuery}
      onSubmitEditing={handleSubmit}   // fires on Enter/Done
      returnKeyType="search"           // "search" / "done" / "send" / "go"
      blurOnSubmit                     // iOS: dismiss keyboard (default true)
    />
  );
}
```

| `returnKeyType` | Keyboard button label | Typical use |
|-----------------|----------------------|-------------|
| `'search'` | Search | Search bar |
| `'done'` | Done | Single-field form |
| `'send'` | Send | Chat / message |
| `'go'` | Go | URL / navigation |
| `'next'` | Next | Multi-field form (focus next) |
| `'default'` | return / ↵ | Multi-line input |

Multi-field form — press "Next" to focus the next field:

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
        onSubmitEditing={() => passwordRef.current?.focus()}
      />
      <TextInput
        ref={passwordRef}
        placeholder="Password"
        returnKeyType="done"
        secureTextEntry
        onSubmitEditing={handleLogin}
      />
    </View>
  );
}
```

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

### Platform-Specific Tips

### Platform-Specific Tips

---

## Combined Pattern — SafeArea + Keyboard

The most robust pattern for screens with both SafeArea and keyboard:

```tsx
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { KeyboardAvoidingView, Platform, Keyboard } from 'react-native';
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

**Layering logic:**
1. Outer `View` handles `insets.bottom` (SafeArea bottom padding is always respected)
2. `KeyboardAvoidingView` handles the keyboard push (iOS only)
3. `KeyboardAwareScrollView` handles auto-scroll to the focused input
4. Inner `contentContainerStyle` handles `insets.top` (SafeArea top padding)

---

## Red Flags — Immediate STOPS

- ❌ Using `SafeAreaView` from `react-native` core (deprecated, no edge control)
- ❌ Missing `SafeAreaProvider` wrapper → `useSafeAreaInsets()` returns `{ top: 0, bottom: 0, ... }`
- ❌ Forgetting `keyboardVerticalOffset` on iOS → content pushed too high by nav bar height
- ❌ Using `keyboardWillShow` on Android → event never fires, use `keyboardDidShow`
- ❌ `KeyboardAvoidingView` without `behavior` prop → no effect
- ❌ Ignoring gesture navigation bottom inset on Android (`insets.bottom > 0` on gesture nav devices)
- ❌ Waiting for a native `isComplete` callback — RN TextInput has no such prop, use JS debounce
- ❌ `onSubmitEditing` without `returnKeyType` — keyboard button shows default "return" instead of "Search"/"Done"/"Send"
- ❌ Missing `Keyboard.dismiss()` in `onSubmitEditing` — keyboard stays open after submit on some platforms
