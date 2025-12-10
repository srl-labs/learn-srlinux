# NDK Releases

NDK release cycle does not follow the SR Linux release cycle. NDK releases are published independently due to the fact that not every SR Linux release contains NDK updates.  
For the same reason the NDK versioning scheme is different from the SR Linux's one and uses [Semantic Versioning](https://semver.org/).

At the same time, new NDK release appear together with a certain SR Linux release where NDK updates were made.

/// admonition | Semantic Versioning and Non Backwards Compatible Changes
    type: subtle-note
Semantic Versioning imposes certain rules on how to version software releases. The most important one is that a new major version release (e.g. 2.0.0) may contain non backwards compatible changes.

Since NDK is versioned with `v0`, we may introduce non backwards compatible changes in the forthcoming releases until we reach `v1`. The non-backwards compatible (NBC) changes will be mentioned in the release notes.
///

The following table shows the mapping between SR Linux and NDK releases:

| NDK Release      | SR Linux Release[^1] | Comments |
| ---------------- | -------------------- | -------- |
| [v0.2.0](0.2.md) | 23.10.1              |          |
| [v0.3.0](0.3.md) | 24.3.1               |          |
| [v0.4.0](0.4.md) | 24.10.1              |          |
| [v0.5.0](0.5.md) | 25.3.1               | Breaking changes! |

[^1]: SR Linux release where NDK changes were introduced.
