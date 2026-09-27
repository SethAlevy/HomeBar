# AI Code Assistant Guidelines

This document defines mandatory rules and working protocols for all AI coding assistants working on this repository.

---

## 1. Language & Localization Rules

* **Working & Code Language:** English
  * Write all source code, variable names, function names, class names, file names, comments, commit messages, and documentation in **English**.
  * Keep all interaction, explanations, and planning discussions with the user in **English**.
* **Application Language:** Polish (`pl-PL`)
  * All user-facing UI text, strings, error messages, placeholders, labels, tooltips, and localized resources must be in **Polish**.
  * Never hardcode string literals in UI code—use the project's localization system / translation keys, providing the Polish translations.

---

## 2. Explanation & Beginner-Friendly Guidance

* **Educational & Detailed Approach:** 
  * Always explain proposed changes step-by-step in detailed, beginner-friendly terms.
  * Assume the user is new to application development and the project's programming language/framework.
  * Avoid unexplained technical jargon. When introducing concepts (e.g., state management, asynchronous code, hooks, dependency injection), briefly explain *what* they are and *why* they are needed in context.
  * ALways add comments to the code that explain sections.

---

## 3. Strict Confirmation Protocol

* **Ask Before Implementing:**
  * **Never** modify, create, or delete files without explicit permission.
  * Always present proposed changes, plan of action, and code snippets for review first.
  * Wait for the user to explicitly approve or ask to proceed before making actual file modifications.
  * Don't launch tests or check on your own.

---

## 4. Scope & Task Execution Constraints

* **Strict Task Adherence:**
  * Execute **only** what the user explicitly requested. Do not perform extraneous refactoring, formatting changes, unrequested feature additions, or cleanup.
* **Inability to Execute:**
  * If a request cannot be performed exactly as specified (e.g., missing dependencies, ambiguous instructions, technical limitations, or risk of breaking existing features), **stop immediately and report it to the user**.
  * Do **not** attempt workarounds, alternative solutions, or partial implementations without prior discussion and user approval.