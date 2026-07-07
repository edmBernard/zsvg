const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zsvg", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_mod_tests.step);

    const examples_step = b.step("examples", "Build and run all examples");

    const example_names = [_][]const u8{
        "basic",
        "basic_shapes",
        "bezier_curves",
        "gradient",
        "paths",
        "save",
        "shapes",
        "text",
    };
    inline for (example_names) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/" ++ name ++ ".zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zsvg", .module = mod },
                },
            }),
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const single = b.step(
            "example-" ++ name,
            "Run the '" ++ name ++ "' example",
        );
        single.dependOn(&run_cmd.step);

        examples_step.dependOn(&run_cmd.step);
    }
}
