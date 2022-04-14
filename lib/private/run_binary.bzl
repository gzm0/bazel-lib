# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""run_binary implementation"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//lib/private:expand_make_vars.bzl", "expand_locations", "expand_variables")

def _impl(ctx):
    if ctx.attr.output_dir and ctx.outputs.outs:
        fail("Only one of output_dir and outs may be specified")
    if not ctx.attr.output_dir and not ctx.outputs.outs:
        fail("One of output_dir and outs must be specified")

    tool_as_list = [ctx.attr.tool]
    tool_inputs, tool_input_mfs = ctx.resolve_tools(tools = tool_as_list)
    args = ctx.actions.args()

    # `expand_locations(...).split(" ")` is a work-around https://github.com/bazelbuild/bazel/issues/10309
    # _expand_locations returns an array of args to support $(execpaths) expansions.
    # TODO: If the string has intentional spaces or if one or more of the expanded file
    # locations has a space in the name, we will incorrectly split it into multiple arguments
    for a in ctx.attr.args:
        args.add_all([expand_variables(ctx, e, outs = ctx.outputs.outs, output_dir = ctx.attr.output_dir) for e in expand_locations(ctx, a, ctx.attr.srcs).split(" ")])
    envs = {}
    for k, v in ctx.attr.env.items():
        envs[k] = " ".join([expand_variables(ctx, e, outs = ctx.outputs.outs, output_dir = ctx.attr.output_dir, attribute_name = "env") for e in expand_locations(ctx, v, ctx.attr.srcs).split(" ")])
    if ctx.attr.output_dir:
        outputs = [ctx.actions.declare_directory(ctx.attr.name)]
    else:
        outputs = ctx.outputs.outs
    ctx.actions.run(
        outputs = outputs,
        inputs = ctx.files.srcs,
        tools = tool_inputs,
        executable = ctx.executable.tool,
        arguments = [args],
        mnemonic = "RunBinary",
        use_default_shell_env = False,
        env = dicts.add(ctx.configuration.default_shell_env, envs),
        input_manifests = tool_input_mfs,
    )
    return DefaultInfo(
        files = depset(outputs),
        runfiles = ctx.runfiles(files = outputs),
    )

run_binary = rule(
    implementation = _impl,
    doc = "Runs a binary as a build action.<br/><br/>This rule does not require Bash (unlike" +
          " <code>native.genrule</code>).",
    attrs = {
        "tool": attr.label(
            doc = "The tool to run in the action.<br/><br/>Must be the label of a *_binary rule," +
                  " of a rule that generates an executable file, or of a file that can be" +
                  " executed as a subprocess (e.g. an .exe or .bat file on Windows or a binary" +
                  " with executable permission on Linux). This label is available for" +
                  " <code>$(location)</code> expansion in <code>args</code> and <code>env</code>.",
            executable = True,
            allow_files = True,
            mandatory = True,
            cfg = "exec",
        ),
        "env": attr.string_dict(
            doc = "Environment variables of the action.<br/><br/>Subject to " +
                  " <code><a href=\"https://docs.bazel.build/versions/main/be/make-variables.html#location\">$(location)</a></code>" +
                  " expansion.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Additional inputs of the action.<br/><br/>These labels are available for" +
                  " <code>$(location)</code> expansion in <code>args</code> and <code>env</code>.",
        ),
        "output_dir": attr.bool(
            doc = "Set to True if you want the output to be a directory." +
                  " Exactly one of `outs`, `output_dir` may be used." +
                  " If you output a directory, there can only be one output, which will be a" +
                  " directory named the same as the target.",
        ),
        "outs": attr.output_list(
            doc = "Output files generated by the action.<br/><br/>These labels are available for" +
                  " <code>$(location)</code> expansion in <code>args</code> and <code>env</code>.",
        ),
        "args": attr.string_list(
            doc = "Command line arguments of the binary.<br/><br/>Subject to" +
                  "<code><a href=\"https://docs.bazel.build/versions/main/be/make-variables.html#location\">$(location)</a></code>" +
                  " expansion.",
        ),
    },
)
