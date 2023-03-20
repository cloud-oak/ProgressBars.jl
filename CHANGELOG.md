# Changelog

## Next Release
* FEATURE: Ability to use just total and update without passing an iterable
* FIX: Multi-threaded progress bars now finish correctly
* FIX: Multiline postfix now correctly works together with ANSI escape codes (e.g. for colorful output)

## 1.4.1 (2022-03-10)
* FIX: Progress bars on 32bit systems use the correct integer type now (`UInt` -> `UInt64`)

## 1.4.0 (2021-08-12)

* CHANGE: Print to `stderr` instead of `stdout` to be in line with other libraries (Contributed by @InnovativeInventor, see PR #47)
