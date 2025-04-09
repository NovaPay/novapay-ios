# Novapay iOS SDK

Table of contents
=================
<!-- NOTE: Use case-sensitive anchor links for docc compatibility -->
<!--ts-->
   * [NovaPaySDKFramework](#NovaPaySDKFramework)
<!--te-->

## NovaPaySDKFramework

## Code style
We use [swiftlint](https://github.com/realm/SwiftLint) to enforce code style.

To install it, run `brew install swiftlint`

To lint your code before pushing you can run `ci_scripts/lint_modified_files.sh`

You can also add this script as a pre-push hook by running `ln -s "$(pwd)/ci_scripts/lint_modified_files.sh" .git/hooks/pre-push && chmod +x .git/hooks/pre-push`

To format modified files automatically, you can use `ci_scripts/format_modified_files.sh` and you can add it as a pre-commit hook using `ln -s "$(pwd)/ci_scripts/format_modified_files.sh" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

## Licenses

- [Novapay iOS SDK License](LICENSE)
