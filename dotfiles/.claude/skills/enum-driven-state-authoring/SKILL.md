---
name: enum-driven-state-authoring
description: When writing new code, model state as sum types from the start. Apply when creating entities with distinct modes, phases, or lifecycle states.
---

## **Enum-Driven State: Authoring Guide**
> When writing new code, model state as sum types from the start. Don't create optional fields that depend on other fields.

---

### Before You Write

**Ask these questions about your data:**

1. **What are the mutually exclusive states?** (e.g., Loading, Success, Error)
2. **For each state, what data is required?** (e.g., Success needs `data`, Error needs `error`)
3. **Is there any data shared across ALL states?** (e.g., `id`, `timestamp` → keep on wrapper)

---

### Decision Flow

```
Does this entity have distinct modes/phases/states?
  │
  ├─ YES → Define a sum type with one variant per state
  │         Each variant holds only its required data
  │
  └─ NO → A simple struct/class is fine
           But watch for optional fields creeping in later
```

---

### Patterns to Apply

**Async/Remote Data**
```typescript
// Start here, not with optional fields
type RemoteData<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```

**Polymorphic Entities**
```rust
// When type determines structure, use enum not optionals
enum Shape {
    Circle { radius: f64 },
    Rectangle { width: f64, height: f64 },
}
```

**Workflow/Lifecycle States**
```python
@dataclass
class Draft:
    content: str

@dataclass
class Published:
    content: str
    published_at: datetime
    url: str

@dataclass
class Archived:
    content: str
    archived_at: datetime
    reason: str

Article = Draft | Published | Archived
```

**Connection/Session State**
```kotlin
sealed interface ConnectionState {
    data object Disconnected : ConnectionState
    data class Connecting(val attempt: Int) : ConnectionState
    data class Connected(val socket: Socket) : ConnectionState
    data class Error(val reason: Throwable) : ConnectionState
}
```

---

### Anti-Patterns to Avoid

❌ **Don't add convenience computed properties that turn enums back into booleans/optionals:**
```swift
enum State {
    case idle
    case loading
    case success(Data)
    case error(Error)

    // ❌ BAD: Defeats the purpose of the sum type
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var data: Data? {
        if case .success(let d) = self { return d }
        return nil
    }
}

// ✅ GOOD: Use pattern matching directly at call sites
switch state {
case .loading: showSpinner()
case .success(let data): display(data)
case .error(let e): showError(e)
case .idle: break
}
```

These "convenience" properties re-introduce the boolean/optional problems you're trying to avoid. They allow callers to bypass exhaustive matching and lead back to `isX && hasY` combinations. Always use direct pattern matching at call sites instead.

---

❌ **Don't start with this:**
```typescript
interface User {
  id: string;
  status: 'guest' | 'registered' | 'premium';
  email?: string;           // only if registered/premium
  subscriptionId?: string;  // only if premium
  expiresAt?: Date;         // only if premium
}
```

✅ **Start with this:**
```typescript
type User =
  | { status: 'guest'; id: string }
  | { status: 'registered'; id: string; email: string }
  | { status: 'premium'; id: string; email: string; subscriptionId: string; expiresAt: Date };
```

---

### Shared Data Pattern

When some fields exist on ALL variants, wrap them:

```rust
struct Event {
    id: Uuid,
    timestamp: DateTime,
    payload: EventPayload,  // The sum type
}

enum EventPayload {
    UserCreated { name: String },
    OrderPlaced { items: Vec<Item> },
    PaymentFailed { reason: String },
}
```

---

### Checklist When Authoring

- [ ] Identified all mutually exclusive states
- [ ] Each state has a dedicated variant/case
- [ ] Data lives INSIDE its variant, not as optional sibling
- [ ] Shared fields are on a wrapper struct
- [ ] No optional field depends on another field's value