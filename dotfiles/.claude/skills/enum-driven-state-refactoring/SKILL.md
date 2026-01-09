---
name: enum-driven-state-refactoring
description: Refactor loose state models (optional fields, parallel booleans) into strict sum types. Apply when a field's validity depends on another field's value.
---

## **Enum-Driven State**
> A behavior-preserving refactor that makes unintended states structurally impossible using Sum Types (Enums, Discriminated Unions, Sealed Classes).

---

### Core Principles

1. **Make Illegal States Unrepresentable**: Structure types so invalid combinations cannot compile—no runtime validation or comments needed.
2. **Sum Types over Product Types**: Replace structs with optional fields (`status`, `data?`, `error?`) with enums where each variant holds exactly what it needs.
3. **Pattern Matching**: Replace boolean checks (`if isX`) with exhaustive `match`/`switch`. Adding a new state forces compiler errors at all call sites.
4. **Parse, Don't Validate**: Push checks to the boundary. Once an object exists, it is guaranteed valid.
5. **Co-location of Data**: Data valid only in a specific state belongs *inside* that state's definition, not as an optional sibling.

---

### Quick Decision

| If you see... | Then consider... |
|---------------|------------------|
| `isX && isY` boolean checks | Sum type with exclusive variants |
| `data?: T` with `error?: E` | Result-style union |
| `status` + nullable siblings | Discriminated union with co-located data |
| Field validity depends on another field | Move data inside the relevant case |
| `get isX() { return type === 'x' }` | You already have a discriminator—formalize it |

---

### Detection Heuristics

**Smell: Conditional Optionality**
```typescript
// 🚩 Field optionality depends on another field's value
interface Request {
  status: string;
  response?: Data;     // "present if status is 'success'"
  error?: Error;       // "present if status is 'error'"
  retryCount?: number; // "only tracked if status is 'error'"
}
// If a field is only valid when another field has a specific value,
// it belongs INSIDE that state, not as an optional sibling.
```

**Smell: Parallel Booleans**
```python
# 🚩 N booleans = 2^N possible states, most invalid
class Task:
    is_pending: bool
    is_running: bool
    is_complete: bool
    is_failed: bool
```

**Smell: Defensive Nil Checks**
```rust
// 🚩 Checking nullability after checking discriminator
if self.status == Status::Success {
    if let Some(data) = &self.data {  // Why is this optional?
        process(data);
    }
}
```

**Smell: Temporal Coupling**
```go
// 🚩 Field validity depends on method call order
conn := &Connection{} // socket is nil
conn.Connect()        // now socket is valid
conn.Send(data)       // crashes if Connect() wasn't called
```

---

### Language Patterns

| Language | Construct | Example |
|----------|-----------|---------|
| **Rust** | `enum` with variants | `enum Result<T,E> { Ok(T), Err(E) }` |
| **Swift** | `enum` with associated values | `case .loaded(Data)` |
| **TypeScript** | Discriminated union | `{ status: 'ok', data: T } \| { status: 'err', error: E }` |
| **Python 3.10+** | `Union` of dataclasses | `CreditCard \| PayPal` with `match` |
| **Kotlin** | `sealed interface` | `sealed interface State` with `data class` impls |
| **Java 17+** | `sealed interface` + `record` | `sealed interface State permits Loading, Success` |
| **Go** | Interface + unexported marker | Or struct with discriminator + exclusive pointers |

---

### Refactor Procedure

```
1. MAP STATES
   └─ List all valid (state, required_data) pairs
   └─ Identify mutually exclusive states

2. GROUP DATA
   └─ For each state: which fields are REQUIRED?
   └─ Move those fields INTO the state definition

3. DEFINE SUM TYPE
   └─ One variant per valid state
   └─ Each variant contains only its required data

4. UPDATE CALL SITES
   └─ Replace `if (obj.field != null)` with pattern match
   └─ Compiler errors guide you to all locations

5. DELETE DEAD CODE
   └─ Remove runtime invariant checks
   └─ Remove defensive null guards
   └─ Remove boolean flag logic
```

---

### Canonical Examples

**Async State (TypeScript)**
```typescript
// ❌ Before: 4 fields × optional = ambiguous
interface State<T> {
  status: 'idle' | 'loading' | 'success' | 'error';
  data?: T;
  error?: Error;
}

// ✅ After: exactly 4 valid shapes
type State<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```

**Connection Config (Rust)**
```rust
// ❌ Before: ssh_key meaningless for HTTP
struct Config {
    protocol: String,
    url: String,
    ssh_key: Option<String>,
}

// ✅ After: each variant has exactly what it needs
enum Connection {
    Http { url: String, port: u16 },
    Ssh { host: String, key: PathBuf },
    Unix { path: PathBuf },
}
```

**Payment Method (Python)**
```python
# ❌ Before: which fields go with which type?
@dataclass
class Payment:
    type: str
    cc_number: str | None = None
    paypal_email: str | None = None

# ✅ After: structural pattern matching
@dataclass
class CreditCard:
    number: str
    cvv: str

@dataclass
class PayPal:
    email: str

Payment = CreditCard | PayPal

def process(p: Payment):
    match p:
        case CreditCard(number=n): charge(n)
        case PayPal(email=e): invoice(e)
```

---

### Boundaries (When to Stop)

| Situation | Guidance |
|-----------|----------|
| **DTOs / DB models** | Keep flat for serialization; convert to sum type at domain boundary |
| **Cross-cutting fields** | Keep `id`, `timestamp`, etc. on wrapper: `struct Event { id, payload: EventKind }` |
| **Large variant data** | Extract to dedicated struct: `case Success(SuccessPayload)` |
| **Serialization** | Configure tagged union support (Serde `#[serde(tag)]`, Zod discriminatedUnion, etc.) |
| **Trivial flags** | A single boolean `is_enabled` doesn't need a sum type |

---

### Why This Works (Cardinality)

**Product types multiply** → most combinations invalid
**Sum types add** → only valid combinations exist

```
Product: status × data? × error? = 3 × 2 × 2 = 12 states (8 invalid)
Sum:     Idle + Loading + Success(T) + Error(E) = 4 states (0 invalid)
```
