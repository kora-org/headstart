const std = @import("std");
const Builder = @import("std").build.Builder;
const Target = @import("std").Target;

fn build_bios(b: *Builder) void {
    const bios_target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = Target.Cpu.Arch.i386,
            .os_tag = Target.Os.Tag.freestanding,
            .abi = Target.Abi.none
        }
    });

    const bios = b.addExecutable("stage1.elf", "stage1/stage1.zig");
    bios.setMainPkgPath(".");
    bios.addPackagePath("io", "common/io.zig");
    bios.addPackagePath("console", "stage1/bios/console.zig");
    bios.addAssemblyFile("stage1/bios/entry.s");
    bios.setTarget(bios_target);
    bios.setBuildMode(b.standardReleaseOptions());
    bios.setLinkerScriptPath(.{ .path = "stage1/bios/linker.ld" });

    const bin = b.addInstallRaw(bios, "stage1.bin");
    const out_path = std.mem.concat(b.allocator, u8, &[_][]const u8{ b.install_path, "/bin" }) catch unreachable;

    const bootsector = b.addSystemCommand(&[_][]const u8{
        "nasm", "-fbin", "stage0/bootsect.s", "-Istage0",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "-o", out_path, "/stage0.bin"
        }) catch unreachable
    });
    bootsector.step.dependOn(&bin.step);

    const append = b.addSystemCommand(&[_][]const u8{
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "cat ",
            out_path, "/stage0.bin ",
            out_path, "/stage1.bin ",
            ">", out_path, "/xeptoboot.bin"
        }) catch unreachable
    });
    append.step.dependOn(&bootsector.step);

    const bios_step = b.step("bios", "Build the BIOS version");
    bios_step.dependOn(&append.step);
}

fn build_uefi(b: *Builder) void {
    const out_path = std.mem.concat(b.allocator, u8, &[_][]const u8{ b.install_path, "/bin" }) catch unreachable;

    const uefi_target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.uefi,
            .abi = Target.Abi.msvc
        }
    });

    const uefi = b.addExecutable("xeptoboot", "stage1/uefi/entry.zig");
    uefi.setMainPkgPath(".");
    uefi.addPackagePath("io", "common/io.zig");
    uefi.addPackagePath("console", "stage1/uefi/console.zig");
    uefi.setOutputDir(out_path);
    uefi.setTarget(uefi_target);
    uefi.setBuildMode(b.standardReleaseOptions());

    const uefi_step = b.step("uefi", "Build the UEFI version");
    uefi_step.dependOn(&uefi.step);
}

pub fn build(b: *Builder) void {
    build_bios(b);
    build_uefi(b);
}
