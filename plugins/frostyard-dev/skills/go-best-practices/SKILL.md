---
name: go-best-practices
description: >
  WHEN: General Go pattern questions, code review, asking "what's the best way to..." in Go.
  WHEN NOT: Non-Go languages. Topics already covered by uber-go-style.
---

# Go Best Practices

> **Priority:** Supplements `uber-go-style` (the baseline) with patterns Uber doesn't cover. For modern Go syntax, see `use-modern-go`. For frostyard org conventions, see `frostyard-conventions`.

Apply idiomatic Go patterns for interfaces, concurrency, testing, packages, and naming.

## Interface Design

- **Accept interfaces, return structs**: Functions should accept interfaces but return concrete types
- **Keep interfaces small**: Prefer single-method interfaces
- **Define interfaces at point of use**: Not where the implementation lives
- **Don't export interfaces unnecessarily**: Only if users need to mock

```go
// Good - interface defined by consumer
type Reader interface {
    Read(p []byte) (n int, err error)
}

func ProcessData(r Reader) error { ... }

// Avoid - exporting implementation details
type Service interface {
    Method1() error
    Method2() error
    Method3() error  // Too many methods
}
```

## Concurrency

- **Don't communicate by sharing memory; share memory by communicating**
- **Use channels for coordination, mutexes for state**
- **Always pass context.Context as first parameter**
- **Use errgroup for coordinating goroutines**
- **Avoid goroutine leaks**: Ensure goroutines can exit

```go
// Good - using errgroup
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    item := item  // capture loop variable
    g.Go(func() error {
        return process(ctx, item)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

To collect ALL errors (not just the first), use a custom collector or `errors.Join`:

```go
var mu sync.Mutex
var errs []error
for _, item := range items {
    g.Go(func() error {
        if err := process(ctx, item); err != nil {
            mu.Lock()
            errs = append(errs, err)
            mu.Unlock()
        }
        return nil
    })
}
g.Wait()
return errors.Join(errs...)
```

## Graceful Shutdown

- Trap `os.Interrupt` and `syscall.SIGTERM` with `signal.NotifyContext`
- Use `context.Context` cancellation to propagate shutdown
- Call `server.Shutdown(ctx)` for HTTP servers — not `Close()`

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()

srv := &http.Server{Addr: ":8080", Handler: mux}
go func() { srv.ListenAndServe() }()

<-ctx.Done()
shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
srv.Shutdown(shutdownCtx)
```

## Logging

- Use `log/slog` (Go 1.21+) for structured logging
- Pass `*slog.Logger` via dependency injection, not package globals
- Use `slog.With` to add context fields
- Log at appropriate levels: `Debug` for development, `Info` for operations, `Warn` for recoverable issues, `Error` for failures

```go
func NewServer(logger *slog.Logger) *Server {
    return &Server{log: logger.With("component", "server")}
}

func (s *Server) Handle(r *http.Request) {
    s.log.Info("request received", "method", r.Method, "path", r.URL.Path)
}
```

## Configuration

- Use struct-based configuration with explicit defaults
- Load from environment variables, config files, or flags — in that precedence order
- Validate configuration at startup, fail fast on invalid values
- Keep config types in a dedicated package or close to `main`

```go
type Config struct {
    Port    int           `env:"PORT"`
    Timeout time.Duration `env:"TIMEOUT"`
}

func DefaultConfig() Config {
    return Config{Port: 8080, Timeout: 30 * time.Second}
}
```

## Testing

- **Use table-driven tests** for multiple scenarios
- **Call t.Parallel()** for independent tests
- **Use t.Helper()** in test helpers
- **Test behavior, not implementation**
- **Use testify for assertions** when it improves readability

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive numbers", 2, 3, 5},
        {"with zero", 5, 0, 5},
        {"negative numbers", -2, -3, -5},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

## Package Organization

- **Package names should be short and lowercase**: `user` not `userService`
- **Avoid package-level state**: Use dependency injection
- **One package per directory**: No multi-package directories
- **internal/ for non-public packages**: Prevents external imports

## Naming Conventions

- **Use MixedCaps or mixedCaps**: Not underscores
- **Acronyms should be consistent**: `URL`, `HTTP`, `ID` (all caps for exported, all lower otherwise)
- **Short names for short scopes**: `i` for loop index, `err` for errors
- **Descriptive names for exports**: `ReadConfig` not `RC`

## Code Organization

- **Declare variables close to use**
- **Use defer for cleanup immediately after resource acquisition**
- **Group related declarations**
- **Order: constants, variables, types, functions**

## Anti-Patterns to Avoid

- **Empty interface (`interface{}` or `any`)**: Use specific types when possible
- **Naked returns**: Always name what you're returning
- **Stuttering**: `user.UserService` should be `user.Service`
- **Complex constructors**: Use functional options pattern

## When in Doubt

- Refer to [Effective Go](https://go.dev/doc/effective_go)
- Check the Go standard library for examples
- Use `go vet` and `staticcheck` for automated guidance
