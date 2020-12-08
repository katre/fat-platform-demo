# Fat Platform Demo

This is a demo of a Bazel change to allow using
[platforms](https://docs.bazel.build/versions/3.7.0/platforms.html) to declare
how to build multi-architecture binaries (ie, a fat APK or a zipfile containing
binaries for multiple machines). This repository needs to be used with Bazel
from from https://github.com/katre/bazel/tree/fat-platforms.

This requires changes to both user code, and to Bazel internals, and these will
be explained separately.

# Testing thise code

To test this code, check out https://github.com/katre/bazel/tree/fat-platforms
and build Bazel as normal. Then use that binary in this repo:

```
$ bazel-dev build --platforms=//:fat_platform //:fat_binary
INFO: Analyzed target //:fat_binary (0 packages loaded, 0 targets configured).
INFO: Found 1 target...
Target //:fat_binary up-to-date:
  bazel-bin/fat_binary.log
INFO: Elapsed time: 0.117s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action

$ cat bazel-bin/fat_binary.log
fat binary says: //:linux: sample message: "Hello", toolchain message: "sample_toolchain: message: linux toolchain";//:windows: sample message: "Hello", toolchain message: "sample_toolchain: message: windows toolchain"
```

# User code changes

In addition to declaring normal platforms with the `platform` rule, users will
be able to create new **fat platforms** that include several other platforms, as
follows (see https://github.com/katre/fat-platform-demo/blob/main/BUILD.bazel):

```
platform(
    name = "linux",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "windows",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
)

fat_platform(
    name = "fat_platform",
    platforms = [
        ":linux",
        ":windows",
    ],
)
```

Here, the target `//:fat_platform` indicates that multi-architecture aware rules
can build dependencies for both platforms, and combine the output appropriately.
Any rules which are **not** prepared for multiple target platforms will only use
the first platform (here, `//:linux`) as their target platform.

To write a rule that can use multiple target platforms, rule author will need to
use the new `platform_common.multi_platform_transition` transition on attributes
(see https://github.com/katre/fat-platform-demo/blob/main/rule/rule.bzl):

```
fat_binary = rule(
    implementation = _fat_binary_impl,
    attrs = {
        ...
        "dep": attr.label(
            cfg = platform_common.multi_platform_transition,
        ),
    },
)

```

And then, in the implementation they use the existing `ctx.split_attr` API:

```
for key, deps in ctx.split_attr.dep.items():
    dep_messages.append("%s: %s" % (str(key), deps[_MessageInfo].message))
```

With `platform_common.multi_platform_transition`, the split keys are the
different target platform labels.

# Bazel changes

There are a number of Bazel changes required to make this work properly.

- Add the new [`fat_platform`
  rule](https://github.com/katre/bazel/blob/fat-platforms/src/main/java/com/google/devtools/build/lib/rules/platform/FatPlatformRule.java)
  and [`FatPlatformInfo`
  provider](https://github.com/katre/bazel/blob/fat-platforms/src/main/java/com/google/devtools/build/lib/analysis/platform/FatPlatformInfo.java)
- During toolchain resolution, copy the `FatInfoProvider` into the
  `ToolchainContext`
   - [`PlatformLookupUtil`](https://github.com/katre/bazel/blob/3f1cd5f1aaae2e32bb61d148bb13c5d70a4aab9a/src/main/java/com/google/devtools/build/lib/skyframe/PlatformLookupUtil.java#L106)
     needs to find and copy `FatPlatformInfo`
   - [`ToolchainResolutionFunction`](https://github.com/katre/bazel/blob/3f1cd5f1aaae2e32bb61d148bb13c5d70a4aab9a/src/main/java/com/google/devtools/build/lib/skyframe/ToolchainResolutionFunction.java#L453)
     can then copy it into the
     [`ToolchainContext`](https://github.com/katre/bazel/blob/fat-platforms/src/main/java/com/google/devtools/build/lib/analysis/ToolchainContext.java)
- During [dependency
  resolution](https://github.com/katre/bazel/blob/3f1cd5f1aaae2e32bb61d148bb13c5d70a4aab9a/src/main/java/com/google/devtools/build/lib/analysis/DependencyResolver.java#L419),
  copy the labels of the platforms from the `FatInfoProvider` into the
  `AttributeTransitionData`
- Add the new [`MultiPlatformTransitionFactory` split
  transition](https://github.com/katre/bazel/blob/fat-platforms/src/main/java/com/google/devtools/build/lib/rules/platform/MultiPlatformTransitionFactory.java)
  and expose it to Starlark
   - When the transition is created, copy the fat platform labels into the
     transition
   - Use the labels to create the split, if present.
   - Update the platform suffix to ensure that actions don't conflict

As well as several cleanups to make the data more consistent.

