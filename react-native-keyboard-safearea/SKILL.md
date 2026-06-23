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

### Platform-Specific Tips

| Concern | iOS | Android |
|---------|-----|---------|
| Keyboard events | `keyboardWillShow/Hide` (animated) | `keyboardDidShow/Hide` (no animation) |
| KeyboardAvoidingView `behavior` | `'padding'` | `'height'` |
| `keyboardVerticalOffset` | NavBar height needed | Usually 0 |
| Dismiss keyboard on tap | `Keyboard.dismiss()` + `resignFirstResponder` | `Keyboard.dismiss()` + `android:windowSoftInputMode="adjustResize"` |

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
