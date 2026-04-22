# CLAUDE.md — Company Code Generation Standards

> This file instructs Claude on how to generate code that complies with company standards.
> Place this file at the root of your project repository. Claude will automatically detect and follow it.

---

## 🎯 Purpose

When generating code in this project, Claude must produce clean, readable, maintainable code
that follows company conventions — regardless of language or format requested.

---

## 📐 General Principles

- Prioritize **readability over cleverness**. Code is read far more than it is written.
- Every piece of generated code must be **understandable without a walkthrough**.
- Consistency across the codebase matters more than personal preference.
- When in doubt, be explicit — avoid implicit or "magic" behavior.

---

## 🔤 Naming Conventions

### Variables
- Use **descriptive, intention-revealing names**. Never use single letters except in loop counters (`i`, `j`).
- Prefer full words over abbreviations: `userAccountBalance` not `usrAccBal`.
- Boolean variables must read as a question: `isActive`, `hasPermission`, `canEdit`.

```js
// ❌ Bad
const x = getUserData();
const flg = true;
const arr = [];

// ✅ Good
const currentUserProfile = getUserData();
const isFeatureEnabled = true;
const pendingOrders = [];
```

### Functions / Methods
- Use **verb + noun** format: `fetchUserById`, `calculateTotalPrice`, `validateEmailAddress`.
- Avoid generic names like `handleData`, `doStuff`, `process`.

```python
# ❌ Bad
def process(d):
    pass

# ✅ Good
def calculate_monthly_revenue(transaction_list):
    pass
```

### Classes / Types / Interfaces
- Use **PascalCase**: `UserAccount`, `OrderService`, `PaymentGatewayConfig`.
- Interface/type names should describe what the object **is**, not what it **does**.

### Constants
- Use **UPPER_SNAKE_CASE** for module-level constants: `MAX_RETRY_ATTEMPTS`, `DEFAULT_TIMEOUT_MS`.

---

## 📏 Indentation & Formatting

| Context          | Rule                                                  |
|------------------|-------------------------------------------------------|
| Indentation      | 2 spaces (JS/TS/HTML/CSS) or 4 spaces (Python/Java/C#) |
| Line length      | Max **100 characters** per line                       |
| Trailing spaces  | Never allowed                                         |
| End of file      | Always a single newline                               |
| Braces (JS/TS)   | Opening brace on the **same line**                    |
| Braces (Java/C#) | Opening brace on the **same line**                    |

```typescript
// ✅ Correct indentation and brace style (TypeScript)
function applyDiscount(orderTotal: number, discountPercent: number): number {
  if (discountPercent <= 0 || discountPercent > 100) {
    throw new Error("Discount percent must be between 1 and 100");
  }

  const discountAmount = orderTotal * (discountPercent / 100);
  return orderTotal - discountAmount;
}
```

```python
# ✅ Correct indentation (Python — 4 spaces)
def send_welcome_email(user_email: str, user_name: str) -> bool:
    if not user_email or not user_name:
        raise ValueError("Email and name are required fields")

    message_body = f"Welcome to the platform, {user_name}!"
    return email_service.send(recipient=user_email, body=message_body)
```

---

## 💬 Comments & Documentation

### When to Comment
- Comment **why**, not **what**. The code should explain what it does; comments explain intent.
- Avoid redundant comments that restate the code.

```js
// ❌ Bad — restates the code
// increment i by 1
i++;

// ✅ Good — explains the "why"
// Offset by 1 because the API uses 1-based pagination
const pageNumber = currentIndex + 1;
```

### Function / Method Documentation
Every public function must have a docstring or JSDoc comment describing:
- What it does (one line)
- Parameters (name, type, description)
- Return value
- Any exceptions/errors thrown

```typescript
/**
 * Calculates the final price after applying a percentage-based discount.
 *
 * @param orderTotal - The original price before discount (in cents)
 * @param discountPercent - Discount percentage (1–100)
 * @returns The discounted price in cents
 * @throws {RangeError} If discountPercent is outside the valid range
 */
function applyDiscount(orderTotal: number, discountPercent: number): number {
  // ...
}
```

```python
def calculate_tax(subtotal: float, tax_rate: float) -> float:
    """
    Calculate the tax amount for a given subtotal.

    Args:
        subtotal: The pre-tax order amount in USD.
        tax_rate: The tax rate as a decimal (e.g., 0.08 for 8%).

    Returns:
        The computed tax amount, rounded to 2 decimal places.

    Raises:
        ValueError: If subtotal or tax_rate is negative.
    """
```

---

## 🏗️ Code Structure

### Functions
- A function must do **one thing only**.
- Maximum **30 lines** per function body. Longer functions must be refactored.
- Maximum **4 parameters**. Use an options object / config struct beyond that.

```typescript
// ❌ Bad — too many parameters
function createUser(name, email, role, age, country, referralCode, isAdmin) { }

// ✅ Good — grouped into a typed config object
interface CreateUserOptions {
  name: string;
  email: string;
  role: UserRole;
  age: number;
  country: string;
  referralCode?: string;
  isAdmin?: boolean;
}

function createUser(options: CreateUserOptions): User { }
```

### Files
- One primary class or responsibility per file.
- Group related files into **feature-based folders**, not type-based folders.

```
// ❌ Type-based (avoid)
/components/Button.tsx
/components/UserCard.tsx
/hooks/useAuth.ts
/services/authService.ts

// ✅ Feature-based (preferred)
/auth/AuthButton.tsx
/auth/useAuth.ts
/auth/authService.ts
/users/UserCard.tsx
```

---

## ⚠️ Error Handling

- **Never silently swallow errors**. Always log or rethrow.
- Use typed/custom errors where possible.
- Validate inputs at the boundary of every public function.

```typescript
// ❌ Bad
try {
  await saveRecord(data);
} catch (e) {
  // do nothing
}

// ✅ Good
try {
  await saveRecord(data);
} catch (error) {
  logger.error("Failed to save record", { data, error });
  throw new DatabaseWriteError("Record save failed", { cause: error });
}
```

---

## 🔒 Security & Safety

- **Never hardcode** credentials, API keys, tokens, or secrets. Use environment variables.
- Always **sanitize and validate** user input before use.
- Avoid `eval()`, `exec()`, dynamic SQL concatenation, or any code injection patterns.
- Sensitive data (passwords, PII) must never appear in logs.

```python
# ❌ Bad
db.query("SELECT * FROM users WHERE email = '" + user_input + "'")

# ✅ Good — parameterized query
db.query("SELECT * FROM users WHERE email = %s", (user_input,))
```

---

## 🧪 Testability

- Every generated function must be **pure or injectable** — no hidden global state.
- Side effects (DB calls, API calls, file I/O) must be **isolated** so they can be mocked.
- Test file naming: `<module>.test.ts` or `test_<module>.py` colocated with source.

---

## 📦 Imports & Dependencies

- Group imports in this order, separated by blank lines:
  1. Standard library / built-ins
  2. Third-party packages
  3. Internal project modules

```typescript
// ✅ Correct import order
import path from "path";
import fs from "fs";

import express from "express";
import { z } from "zod";

import { UserService } from "@/services/userService";
import { logger } from "@/utils/logger";
```

- **Never import entire namespaces** when only specific exports are needed.

---

## 🌐 Language-Specific Rules

### JavaScript / TypeScript
- Always use `const` by default; use `let` only when reassignment is necessary.
- Use `async/await` — avoid raw `.then()` chains.
- Strict TypeScript mode must be enabled (`"strict": true` in tsconfig).
- No use of `any` type unless explicitly justified with a comment.

### Python
- Follow **PEP 8** for all formatting.
- Use **type hints** for all function signatures.
- Prefer **f-strings** over `.format()` or `%` formatting.
- Use `pathlib.Path` instead of string-based `os.path` operations.

### SQL
- Keywords in **UPPERCASE**: `SELECT`, `FROM`, `WHERE`, `JOIN`.
- Each clause on its own line for readability.
- Always use table aliases for multi-table queries.

```sql
-- ✅ Correct SQL style
SELECT
  u.id,
  u.email,
  o.total_amount
FROM users AS u
  INNER JOIN orders AS o ON o.user_id = u.id
WHERE
  u.is_active = TRUE
  AND o.created_at >= '2024-01-01'
ORDER BY o.created_at DESC;
```

---

## 🚫 What Claude Must Never Generate

- Magic numbers without named constants
- Nested ternaries more than 1 level deep
- Functions longer than 30 lines without a documented reason
- Dead code or commented-out code blocks
- `TODO` comments without a ticket/issue reference (e.g., `// TODO [PROJ-123]: refactor this`)
- Hardcoded environment-specific values (URLs, ports, credentials)

---

## ✅ Code Review Checklist (Claude Self-Check)

Before finalizing any generated code, Claude must verify:

- [ ] All variable/function names are descriptive and follow conventions
- [ ] No function exceeds 30 lines
- [ ] All public functions have documentation comments
- [ ] Error handling is explicit and logged
- [ ] No hardcoded secrets or magic numbers
- [ ] Imports are ordered and minimal
- [ ] Code is properly indented and formatted
- [ ] Types/interfaces are used where applicable
- [ ] The code does exactly one thing per function

---

*Last updated: April 2026 — Place this file at your project root as `CLAUDE.md`*
