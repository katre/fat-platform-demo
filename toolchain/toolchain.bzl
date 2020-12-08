def _sample_toolchain_impl(ctx):
    message = "sample_toolchain: message: %s" % (
        ctx.attr.message,
    )

    toolchain = platform_common.ToolchainInfo(
        message = message,
    )
    return [toolchain]

sample_toolchain = rule(
    implementation = _sample_toolchain_impl,
    attrs = {
        "message": attr.string(),
    },
)
