---
name: storybook-conventions
description: Use when setting up or writing Storybook stories — covers component stories, args, play tests, interaction testing, and integration with design systems
---

# Storybook Conventions

## 1. Setup

```bash
npx storybook@latest init
```

## 2. Story Structure

```
src/components/
├── Button/
│   ├── Button.tsx
│   ├── Button.stories.tsx    # colocate — same folder
│   └── Button.css
├── PostCard/
│   ├── PostCard.tsx
│   └── PostCard.stories.tsx
```

## 3. Story Format — CSF 3

```tsx
// Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  args: { label: 'Click me', disabled: false },
  argTypes: {
    onClick: { action: 'clicked' },
    variant: { control: 'select', options: ['primary', 'secondary', 'ghost'] },
  },
};
export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = { args: { variant: 'primary' } };
export const Secondary: Story = { args: { variant: 'secondary' } };
export const Disabled: Story = { args: { disabled: true } };
```

| CSF 3 | Old CSF 2 |
|-------|-----------|
| `StoryObj<typeof C>` | `Template.bind({})` |
| `args` in meta + story override | `args` only in template |
| Auto-generated types | Manual typing |

## 4. Interaction Tests — `play` Function

```tsx
import { userEvent, within } from '@storybook/test';

export const SubmitForm: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.type(canvas.getByLabelText('Email'), 'test@example.com');
    await userEvent.click(canvas.getByRole('button', { name: 'Submit' }));
    // Assert result
  },
};
```

Run: `npx test-storybook` — runs all `play` functions as tests.

## 5. What Gets a Story

| Write story for | Skip |
|-----------------|------|
| Shared UI components (Button, Card, Modal) | Page-level one-off components |
| Design system tokens (colors, typography) | Route handlers |
| Complex state components (loading, error, empty) | API client functions |
| Edge cases (long text, missing data) | Server-only code |

**Rule:** If it's in `packages/ui/` → must have a story. If it's in `apps/web/app/` → optional.

## 6. Addons

```bash
pnpm add -D @storybook/addon-a11y @storybook/addon-links @storybook/addon-viewport
```

| Addon | Use |
|-------|-----|
| `@storybook/addon-a11y` | axe-core accessibility checks per story |
| `@storybook/addon-viewport` | Test mobile/tablet/desktop |
| `@storybook/addon-links` | Link between stories |
| `@storybook/test` | `play()` interaction tests |

## Red Flags

- Story in a different folder than component → colocate
- No `play` test for interactive component → missing regression safety
- Stories without edge cases → only happy path covered
- No a11y addon → accessibility not tested
