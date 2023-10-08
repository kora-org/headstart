const std = @import("std");
const builtin = @import("builtin");
const Arch = std.Target.Cpu.Arch;
const CrossTarget = std.zig.CrossTarget;

const kora_version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

pub fn build(b: *std.Build) !void {
    const arch = b.option(Arch, "arch", "The CPU architecture to build for") orelse .x86_64;
    const target = try genTarget(arch);
    const optimize = b.standardOptimizeOption(.{});

    const exe_options = b.addOptions();

    // From zls
    const version = v: {
        const version_string = b.fmt("{d}.{d}.{d}", .{ kora_version.major, kora_version.minor, kora_version.patch });

        var code: u8 = undefined;
        const git_describe_untrimmed = b.execAllowFail(&[_][]const u8{
            "git", "-C", b.build_root.path.?, "describe", "--match", "*.*.*", "--tags",
        }, &code, .Ignore) catch break :v version_string;

        const git_describe = std.mem.trim(u8, git_describe_untrimmed, " \n\r");

        switch (std.mem.count(u8, git_describe, "-")) {
            0 => {
                // Tagged release version (e.g. 0.10.0).
                std.debug.assert(std.mem.eql(u8, git_describe, version_string)); // tagged release must match version string
                break :v version_string;
            },
            2 => {
                // Untagged development build (e.g. 0.10.0-dev.216+34ce200).
                var it = std.mem.split(u8, git_describe, "-");
                const tagged_ancestor = it.first();
                const commit_height = it.next().?;
                const commit_id = it.next().?;

                const ancestor_ver = std.SemanticVersion.parse(tagged_ancestor) catch unreachable;
                std.debug.assert(kora_version.order(ancestor_ver) == .gt); // version must be greater than its previous version
                std.debug.assert(std.mem.startsWith(u8, commit_id, "g")); // commit hash is prefixed with a 'g'

                break :v b.fmt("{s}-dev.{s}+{s}", .{ version_string, commit_height, commit_id[1..] });
            },
            else => {
                std.debug.print("Unexpected 'git describe' output: '{s}'\n", .{git_describe});
                std.process.exit(1);
            },
        }
    };

    exe_options.addOption([:0]const u8, "version", b.allocator.dupeZ(u8, version) catch "0.1.0-dev");

    const exe = b.addExecutable(.{
        .name = "headstart",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFiles(&[_][]const u8{
        "external/flanterm/flanterm.c",
        "external/flanterm/backends/fb.c",
    }, &[_][]const u8{
        "-ffreestanding",
        "-nostdlib",
        "-mno-red-zone",
    });
    exe.addIncludePath(.{ .path = "external" });
    exe.addOptions("build_options", exe_options);
    exe.code_model = switch (target.cpu_arch.?) {
        .x86_64 => .kernel,
        .aarch64 => .small,
        .riscv64 => .medium,
        else => return error.UnsupportedArchitecture,
    };

    b.installArtifact(exe);
    try run(b, arch);
}

fn genTarget(arch: Arch) !CrossTarget {
    var target = CrossTarget{
        .cpu_arch = arch,
        .os_tag = .uefi,
        .abi = .msvc,
    };

    switch (arch) {
        .x86_64, .aarch64, .riscv64 => {},
        else => return error.UnsupportedArchitecture,
    }

    return target;
}

fn downloadEdk2(b: *std.Build, arch: Arch) !void {
    const link = switch (arch) {
        .x86_64 => "https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd",
        .aarch64 => "https://retrage.github.io/edk2-nightly/bin/RELEASEAARCH64_QEMU_EFI.fd",
        .riscv64 => "https://retrage.github.io/edk2-nightly/bin/RELEASERISCV64_VIRT.fd",
        else => return error.UnsupportedArchitecture,
    };

    const cmd = &[_][]const u8{ "curl", link, "-Lo", try edk2FileName(b, arch) };
    var child_proc = std.ChildProcess.init(cmd, b.allocator);
    try child_proc.spawn();
    const ret_val = try child_proc.wait();
    try std.testing.expectEqual(ret_val, .{ .Exited = 0 });
}

fn edk2FileName(b: *std.Build, arch: Arch) ![]const u8 {
    return std.mem.concat(b.allocator, u8, &[_][]const u8{ "zig-cache/edk2-", @tagName(arch), ".fd" });
}

fn run(b: *std.Build, arch: Arch) !void {
    _ = std.fs.cwd().statFile(try edk2FileName(b, arch)) catch try downloadEdk2(b, arch);

    const qemu_executable = switch (arch) {
        .x86_64 => "qemu-system-x86_64",
        .aarch64 => "qemu-system-aarch64",
        .riscv64 => "qemu-system-riscv64",
        else => return error.UnsupportedArchitecture,
    };

    const boot_efi_filename = switch (arch) {
        .x86_64 => "BOOTX64.EFI",
        .aarch64 => "BOOTAA64.EFI",
        .riscv64 => "BOOTRISCV64.EFI",
        else => return error.UnsupportedArchitecture,
    };

    const cmd = &[_][]const u8{
        // zig fmt: off
        "sh", "-c",
        try std.mem.concat(b.allocator, u8, &[_][]const u8{
        try std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p zig-out/efi-root/EFI/BOOT && ",
            "cp zig-out/bin/headstart.efi zig-out/efi-root/EFI/BOOT/", boot_efi_filename, " && ",
            "cp headstart.example.json zig-out/efi-root/headstart.json && ",
        }),
        try std.mem.concat(b.allocator, u8, switch (arch) {
            .x86_64 => &[_][]const u8{
                // zig fmt: off
                qemu_executable, " ",
                //"-cpu max ",
                "-smp 2 ",
                "-M q35,accel=kvm:whpx:hvf:tcg ",
                "-m 2G ",
                "-hda fat:rw:zig-out/efi-root ",
                "-bios ", try edk2FileName(b, arch), " ",
                "-no-reboot ",
                "-no-shutdown ",
                "-d guest_errors ",
                // zig fmt: on
            },
            .aarch64, .riscv64 => &[_][]const u8{
                // zig fmt: off
                qemu_executable, " ",
                "-cpu cortex-a57 ",
                "-smp 2 ",
                "-M virt,accel=kvm:whpx:hvf:tcg ",
                "-device virtio-gpu-pci ",
                "-m 2G ",
                "-hda fat:rw:zig-out/efi-root ",
                "-bios ", try edk2FileName(b, arch), " ",
                "-no-reboot ",
                "-no-shutdown ",
                // zig fmt: on
            },
            else => return error.UnsupportedArchitecture,
        }),
        }),
        // zig fmt: on
    };

    const run_cmd = b.addSystemCommand(cmd);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Boot Headstart in QEMU");
    run_step.dependOn(&run_cmd.step);
}
