# Contribution Guidelines

Thank you for considering a contribution to `StayLit`! Please open issues and pull requests on [ideal2545/StayLit](https://github.com/ideal2545/StayLit).

## Localizations
To update or add a localization, the preferred pull request contains **only** the modified `*.xliff` files inside a `*.xcloc` localization catalog. You can export updated translations from _Xcode_ as an `*.xcloc` catalog. Updated translations go in `Localizations/StayLit/<language>.xcloc/Localized Contents/<language>.xliff`. The folder keeps its original name so upstream changes still merge cleanly.

Keep a localization pull request to a single language, with no unrelated code changes. Pull requests that change `*.xcstrings` files directly are accepted, but please avoid them where you can.

### Credits (Optional)
Anyone who adds a language or contributes a major translation update can be credited in `Credits.rtf`, which appears in the "About" tab of the app settings. To be credited, include a line in this format in the pull request or its description:

```
[language] Translation
[existing name or username] <email or URL as clickable link>
[your name or username] <email or URL as clickable link>
```

_(just follow the pattern of the other translation credits)_

## Code Style and Programming Language
There are no strict code style rules. Please follow the style of the existing code, especially for brackets (`{}`, `()`), spaces and line breaks. Use the `Auto` helper macro for type inference of local variables. It's non-standard in Objective-C.

Objective-C, C and C++ are the project's languages. Please don't convert code to other languages.

Code that comes from KeepingYouAwake keeps its original file headers and copyright notices.

## Features, Structural Changes and UI Modifications
For features, structural changes or UI changes, please open an issue with a proposal first. That avoids long review cycles and wasted work.

## Upstream
StayLit changes aren't meant for KeepingYouAwake, so please don't send them there as pull requests.

---

> _Thank you very much!_
