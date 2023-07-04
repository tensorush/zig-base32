## :lizard: :abc: **zig base32**

[![CI][ci-shield]][ci-url]
[![CD][cd-shield]][cd-url]
[![Docs][docs-shield]][docs-url]
[![License][license-shield]][license-url]
[![Resources][resources-shield]][resources-url]

### Zig implementation of the [Base32 encoding scheme](https://www.crockford.com/base32.html).

#### :rocket: Usage

1. Add `base32` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_program>",
        .version = "<version_of_your_program>",
        .dependencies = .{
            .base32 = .{
                .url = "https://github.com/tensorush/zig-base32/archive/refs/tags/<git_tag>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    If unsure what to put for `<package_hash>`, set it to any value and Zig will provide the correct one in an error message.

    </details>

2. Add `base32` as a module in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const base32 = b.dependency("base32", .{});
    exe.addModule("base32", base32.module("base32"));
    ```

    </details>

<!-- MARKDOWN LINKS -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-base32/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zig-base32/blob/main/.github/workflows/ci.yaml
[cd-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-base32/cd.yaml?branch=main&style=for-the-badge&logo=github&label=CD&labelColor=black
[cd-url]: https://github.com/tensorush/zig-base32/blob/main/.github/workflows/cd.yaml
[docs-shield]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=docs&labelColor=black
[docs-url]: https://tensorush.github.io/zig-base32
[license-shield]: https://img.shields.io/github/license/tensorush/zig-base32.svg?style=for-the-badge&labelColor=black
[license-url]: https://github.com/tensorush/zig-base32/blob/main/LICENSE.md
[resources-shield]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=resources&labelColor=black
[resources-url]: https://github.com/tensorush/Awesome-Languages-Learning#lizard-zig
