# Versioning

Pet Halo uses semantic product versions and monotonically increasing integer build numbers.

- `CFBundleShortVersionString` is numeric Apple form, such as `0.1.0`.
- `CFBundleVersion` is a positive integer, such as `1`.
- Beta identity belongs in the Git tag and release title, such as `v0.1.0-beta.1` and `Pet Halo 0.1.0 Beta 1`.
- Release artifact names use `Pet-Halo-<semantic-version>-beta.<n>-universal.zip`.
- Every tag must resolve to a reviewed commit whose injected bundle versions match the tag.

Compatibility or security fixes increment the patch version or Beta sequence as appropriate. User-facing compatible features increment minor. Breaking compatibility increments major after an explicit migration plan. No tag or build number is reused.
