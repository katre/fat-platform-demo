def _sample_impl(ctx):
    toolchain = ctx.toolchains["//toolchain:toolchain_type"]
    message = ctx.attr.message

    str = 'Using toolchain: rule message: "%s", toolchain message: "%s"\n' % (message, toolchain.message)

    log = ctx.outputs.log
    ctx.actions.write(
        output = log,
        content = str,
    )
    return [DefaultInfo(files = depset([log]))]

sample = rule(
    implementation = _sample_impl,
    attrs = {
        "message": attr.string(),
    },
    outputs = {
        "log": "%{name}.log",
    },
    toolchains = ["//toolchain:toolchain_type"],
    incompatible_use_toolchain_transition = True,
)
