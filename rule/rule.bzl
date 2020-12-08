_MessageInfo = provider("Simple message provider", fields = ["message"])

def _sample_impl(ctx):
    toolchain = ctx.toolchains["//toolchain:toolchain_type"]
    rule_message = ctx.attr.message

    message = 'sample message: "%s", toolchain message: "%s"' % (rule_message, toolchain.message)

    log = ctx.outputs.log
    ctx.actions.write(
        output = log,
        content = message + "\n",
    )
    message_info = _MessageInfo(message = message)
    return [
        DefaultInfo(files = depset([log])),
        message_info,
    ]

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

def _fat_binary_impl(ctx):
    base_message = ctx.attr.message
    dep_messages = []
    for key, deps in ctx.split_attr.dep.items():
        dep_messages.append("%s: %s" % (str(key), deps[_MessageInfo].message))

    message = "%s: %s" % (
        base_message,
        ";".join(dep_messages),
    )
    log = ctx.outputs.log
    ctx.actions.write(
        output = log,
        content = message + "\n",
    )
    message_info = _MessageInfo(message = message)
    return [
        DefaultInfo(files = depset([log])),
        message_info,
    ]

fat_binary = rule(
    implementation = _fat_binary_impl,
    attrs = {
        "message": attr.string(),
        "dep": attr.label(
            cfg = platform_common.multi_platform_transition,
            providers = [_MessageInfo],
        ),
    },
    outputs = {
        "log": "%{name}.log",
    },
)
