# Wireframes: {{FEATURE_NAME}}

## Screen Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │
│   Screen 1   │────▶│   Screen 2   │────▶│   Screen 3   │
│              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │              │
                     │   Screen 4   │
                     │              │
                     └──────────────┘
```

_Description of the overall user flow._

---

## Screens

### {{SCREEN_NAME}}

**Purpose:** _What is this screen for?_

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│  [Logo]                              [User Menu ▼]     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                  Header Section                  │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌────────────────────┐  ┌────────────────────────┐   │
│  │                    │  │                        │   │
│  │   Left Panel       │  │   Main Content Area    │   │
│  │                    │  │                        │   │
│  │   - Item 1         │  │   [ Content Block ]    │   │
│  │   - Item 2         │  │                        │   │
│  │   - Item 3         │  │   [ Content Block ]    │   │
│  │                    │  │                        │   │
│  └────────────────────┘  └────────────────────────┘   │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [Cancel]                    [Primary Action]    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Components:**
| Component | Type | Description |
|-----------|------|-------------|
| Logo | Image | Application logo, links to home |
| User Menu | Dropdown | User profile and settings |
| Header Section | Container | Page title and description |
| Left Panel | Navigation | List of navigation items |
| Main Content Area | Container | Primary content display |
| Cancel | Button | Secondary action, cancels operation |
| Primary Action | Button | Main call-to-action |

**Interactions:**
- [ ] Clicking Logo navigates to home
- [ ] User Menu opens dropdown on click
- [ ] Left Panel items highlight on hover
- [ ] Primary Action button triggers main operation

---

### {{SCREEN_NAME}}

**Purpose:** _What is this screen for?_

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│  [← Back]                            [Action Button]   │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                   Form Section                   │  │
│  │                                                  │  │
│  │   Label 1:  [________________________]          │  │
│  │                                                  │  │
│  │   Label 2:  [________________________]          │  │
│  │                                                  │  │
│  │   Label 3:  [________________________]  [?]     │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [Reset]                            [Submit]     │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Components:**
| Component | Type | Description |
|-----------|------|-------------|
| Back | Button | Returns to previous screen |
| Action Button | Button | Secondary page action |
| Form Section | Form | Input fields container |
| Input Fields | Text Input | User data entry |
| Help Icon [?] | Icon Button | Shows tooltip with help |
| Reset | Button | Clears form fields |
| Submit | Button | Submits form data |

**Interactions:**
- [ ] Back button navigates to previous screen
- [ ] Input fields validate on blur
- [ ] Help icon shows tooltip on hover/click
- [ ] Submit button validates form and submits

---

## Component Hierarchy

```
App
├── Header
│   ├── Logo
│   ├── Navigation
│   └── UserMenu
│       ├── Avatar
│       └── DropdownMenu
├── MainContent
│   ├── PageHeader
│   │   ├── Title
│   │   └── Breadcrumbs
│   ├── Sidebar
│   │   └── NavItems
│   └── ContentArea
│       ├── ContentBlock
│       └── ContentBlock
└── Footer
    ├── Links
    └── Copyright
```

## Responsive Breakpoints

| Breakpoint | Width | Layout Changes |
|------------|-------|----------------|
| Mobile | < 768px | Single column, hamburger menu |
| Tablet | 768px - 1024px | Two columns, collapsed sidebar |
| Desktop | > 1024px | Full layout, expanded sidebar |
