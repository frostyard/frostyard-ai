---
name: uber-go-style
description: >
  WHEN: Writing, reviewing, or refactoring Go code.
  WHEN NOT: Non-Go languages, general questions unrelated to Go programming.
---

# Uber Go Style Guide — Quick Reference

> **Priority:** This is the baseline authority for Go style in frostyard repos. Modern Go features (`use-modern-go` skill) override this when newer syntax is available. See `go-best-practices` for patterns where Uber is silent.

Distilled from the [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md). Focus: patterns that are non-obvious or commonly violated.

## Error Handling

### Wrapping Strategy

| Caller needs to match? | Message | Use |
|------------------------|---------|-----|
| No | Static | `errors.New()` |
| No | Dynamic | `fmt.Errorf()` |
| Yes | Static | `var ErrFoo = errors.New()` |
| Yes | Dynamic | Custom error type |

- Use `%w` when callers should unwrap; `%v` to hide the underlying error.
- Avoid "failed to" prefix — it piles up through the call stack: `"new store: %w"` not `"failed to create new store: %w"`.

### Handle Errors Once

Choose ONE: wrap-and-return OR log-and-degrade. Never log AND return — upstream callers will double-log.

```go
// Good: wrap and return
return fmt.Errorf("get user %q: %w", id, err)

// Good: log and degrade
if err != nil {
    log.Warn("user timezone lookup failed", zap.Error(err))
    tz = time.UTC
}

// Bad: log AND return
log.Error("failed", zap.Error(err))
return err
```

### Error Naming

- Exported sentinel: `ErrFoo` prefix
- Unexported sentinel: `errFoo` prefix (no underscore — exception to global naming)
- Custom type: `FooError` suffix

## Concurrency

### Channel Size: One or None

Channels should be unbuffered (`make(chan T)`) or size 1 (`make(chan T, 1)`). Any other size needs rigorous justification for why it won't block or saturate.

### No Fire-and-Forget Goroutines

Every goroutine must have a predictable stop time or a stop signal. Use `sync.WaitGroup` or `chan struct{}` to wait. Test with `go.uber.org/goleak`.

```go
done := make(chan struct{})
go func() {
    defer close(done)
    // work
}()
<-done
```

### No Goroutines in init()

Expose objects with `Close()`/`Shutdown()` methods instead. Goroutine lifetime must be controllable by the caller.

### Recover Panics in Goroutines

An unrecovered panic in a goroutine crashes the entire process. Always defer a recovery handler in goroutines that could panic.

```go
go func() {
    defer func() {
        if r := recover(); r != nil {
            log.Error("goroutine panicked", zap.Any("panic", r))
        }
    }()
    // work that might panic
}()
```

### Zero-Value Mutexes

Use `var mu sync.Mutex`, not `new(sync.Mutex)`. In structs, use named fields — never embed mutexes (leaks to public API).

```go
type SMap struct {
    mu   sync.Mutex  // named field, not embedded
    data map[string]string
}
```

### Context as First Parameter

Always pass `context.Context` as the first parameter, named `ctx`. Never store it in a struct.

```go
// Good
func (s *Store) Get(ctx context.Context, id string) (*Item, error)

// Bad — context in struct
type Store struct { ctx context.Context }
```

## Defensive Copying

### Copy Slices and Maps at Boundaries

Copy when **receiving** (prevents caller mutation of your state) AND when **returning** (prevents caller mutation of returned state).

```go
// Receiving
func (d *Driver) SetTrips(trips []Trip) {
    d.trips = make([]Trip, len(trips))
    copy(d.trips, trips)
}

// Returning
func (s *Stats) Snapshot() map[string]int {
    s.mu.Lock()
    defer s.mu.Unlock()
    result := make(map[string]int, len(s.counters))
    for k, v := range s.counters {
        result[k] = v
    }
    return result
}
```

## Initialization Patterns

### Verify Interface Compliance at Compile Time

```go
var _ http.Handler = (*Handler)(nil)
```

Place after type declaration. Catches missing methods at compile time, not runtime.

### Avoid Mutable Globals

Inject dependencies instead of using package-level `var` or function pointers.

```go
// Bad
var timeNow = time.Now

// Good
type signer struct { now func() time.Time }
func newSigner() *signer { return &signer{now: time.Now} }
```

### Prefix Unexported Globals with `_`

```go
const (
    _defaultPort = 8080
    _defaultUser = "user"
)
```

Exception: error sentinels use `err` prefix without underscore.

### Avoid init()

Move complex init to helper functions called from `main()`. When `init()` is unavoidable: no side effects, no I/O, no goroutines, deterministic.

### Avoid Embedding Types in Public Structs

Embedding leaks implementation details and inhibits API evolution. Write delegation methods.

```go
// Bad: exposes AbstractList methods
type ConcreteList struct { *AbstractList }

// Good: controls surface area
type ConcreteList struct { list *AbstractList }
func (l *ConcreteList) Add(e Entity) { l.list.Add(e) }
```

## Struct and Map Patterns

### Struct Initialization

- Always use field names: `User{FirstName: "John"}` not `User{"John", "Doe"}`
- Omit zero-value fields unless they add clarity
- Use `var user User` for fully zero-valued structs (not `User{}`)
- Use `&T{}` not `new(T)` for struct references

### Map Initialization

- `make(map[K]V)` for programmatically populated maps
- Map literal `map[K]V{k1: v1}` for fixed elements
- Provide capacity hint when size is known: `make(map[K]V, len(items))`

### Enums Start at One

```go
type Operation int
const (
    Add Operation = iota + 1
    Subtract
    Multiply
)
```

Zero value means "unset" — distinguishable from valid values. Exception: when zero IS the desired default.

### Field Tags on Marshaled Structs

Always tag fields in JSON/YAML structs. Protects against refactoring breaking the serialization contract.

```go
type Stock struct {
    Price int    `json:"price"`
    Name  string `json:"name"`
}
```

## Program Lifecycle

### Exit in Main, Exit Once

Only `main()` calls `os.Exit` or `log.Fatal`. All other functions return errors. Wrap business logic in `run() error`.

```go
func main() {
    if err := run(); err != nil {
        log.Fatal(err)
    }
}
```

## Performance

| Instead of | Use | Why |
|-----------|-----|-----|
| `fmt.Sprint(n)` | `strconv.Itoa(n)` | No reflection, fewer allocs |
| Repeated `[]byte(s)` | Convert once, reuse | Avoid allocation per conversion |
| `make([]T, 0)` | `make([]T, 0, cap)` | Pre-allocate when size known |
| `make(map[K]V)` | `make(map[K]V, len)` | Pre-allocate when size known |

## Style

### Reduce Nesting — Early Returns

```go
// Good: handle error first, continue with happy path
for _, v := range data {
    if v.F1 != 1 {
        log.Printf("Invalid v: %v", v)
        continue
    }
    v = process(v)
    if err := v.Call(); err != nil {
        return err
    }
}
```

### Unnecessary Else

If a variable is set in both branches, initialize before the `if`:

```go
a := 10
if b {
    a = 100
}
```

### Naked Parameters

Use C-style comments when parameter meaning is unclear:

```go
printInfo("foo", true /* isLocal */, true /* done */)
```

Or better: use custom types instead of bare booleans.

### Line Length

Soft limit of 99 characters. Wrap before hitting it.

### Import Ordering

Two groups separated by blank line: standard library first, everything else second.

### Function Ordering

Rough call order. Exported functions first, then `NewXYZ()`, then methods by receiver, then utilities.

## Functional Options

Use for constructors with 3+ optional parameters:

```go
type options struct {
    cache  bool
    logger *zap.Logger
}

type Option interface { apply(*options) }

type cacheOption bool
func (c cacheOption) apply(o *options) { o.cache = bool(c) }
func WithCache(c bool) Option { return cacheOption(c) }

func Open(addr string, opts ...Option) (*Connection, error) {
    o := options{cache: defaultCache, logger: zap.NewNop()}
    for _, opt := range opts {
        opt.apply(&o)
    }
    // ...
}
```

## Time Handling

- Use `time.Time` for instants, `time.Duration` for periods — never bare `int`
- When external systems can't use `time.Duration`, include unit in field name: `IntervalMillis`
- Don't assume 24h days or 60s minutes (DST, leap seconds)

## Testing

### Table-Driven Tests

Use `tests` for the slice, `tt` for each case, `give`/`want` prefixes for fields.

### Avoid Complex Table Tests

If a table test needs conditional assertions, mock setup functions, or branching beyond a single `shouldErr` field — split into separate test functions.

### Parallel Test Scoping

With `t.Parallel()`, loop variables are properly scoped per iteration in Go 1.22+. For older versions, re-assign loop vars.
