const std = @import("std");
const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;

fn build_bios(b: *Builder) *std.build.RunStep {
    const out_path = std.mem.concat(b.allocator, u8, &[_][]const u8{ b.install_path, "/bin" }) catch unreachable;

    const bios = b.addExecutable("stage1.elf", "stage1/stage1.zig");
    bios.setMainPkgPath(".");
    bios.addPackagePath("io", "common/io.zig");
    bios.addPackagePath("console", "stage1/bios/console.zig");
    bios.addPackagePath("graphics", "stage1/bios/graphics.zig");
    bios.addAssemblyFile("stage1/bios/entry.s");
    bios.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.i386,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none
    });
    bios.setBuildMode(b.standardReleaseOptions());
    bios.setLinkerScriptPath(.{ .path = "stage1/bios/linker.ld" });
    bios.install();

    const bin = b.addInstallRaw(bios, "stage1.bin");

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

    return append;
}

fn build_uefi(b: *Builder) *std.build.LibExeObjStep {
    const out_path = std.mem.concat(b.allocator, u8, &[_][]const u8{ b.install_path, "/bin" }) catch unreachable;

    const uefi = b.addExecutable("xeptoboot", "stage1/uefi/entry.zig");
    uefi.setMainPkgPath(".");
    uefi.addPackagePath("io", "common/io.zig");
    uefi.addPackagePath("console", "stage1/uefi/console.zig");
    uefi.addPackagePath("graphics", "stage1/uefi/graphics.zig");
    uefi.setOutputDir(out_path);
    uefi.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.uefi,
        .abi = Target.Abi.msvc
    });
    uefi.setBuildMode(b.standardReleaseOptions());

    const uefi_step = b.step("uefi", "Build the UEFI version");
    uefi_step.dependOn(&uefi.step);

    return uefi;
}

fn run_qemu_bios(b: *Builder, path: []const u8) *std.build.RunStep {
    const cmd = &[_][]const u8{
        // zig fmt: off
        "qemu-system-x86_64",
        "-hda", path,
        "-debugcon", "stdio",
        "-vga", "virtio",
        "-m", "4G",
        // This prevents the BIOS to boot the bootsector
        // "-machine", "q35,accel=kvm:whpx:tcg",
        "-no-reboot", "-no-shutdown"
        // zig fmt: on
    };

    const run_step = b.addSystemCommand(cmd);

    const run_command = b.step("run-bios", "Run the BIOS version");
    run_command.dependOn(&run_step.step);

    return run_step;
}

fn run_qemu_uefi(b: *Builder, dir: []const u8) *std.build.RunStep {
    const cmd = &[_][]const u8{
        // zig fmt: off
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ", dir, "/efi-root/EFI/BOOT && ",
            "cp ", dir, "/bin/xeptoboot.efi ", dir, "/efi-root/EFI/BOOT/BOOTX64.EFI &&",
            "qemu-system-x86_64 ",
            // This doesn't work for some reason
            // "-drive if=none,format=raw,media=disk,file=fat:rw:", dir, "/efi-root ",
            "-hda fat:rw:", dir, "/efi-root ",
            "-debugcon stdio ",
            "-vga virtio ",
            "-m 4G ",
            "-machine q35,accel=kvm:whpx:tcg ",
            "-drive if=pflash,format=raw,unit=0,file=external/ovmf-prebuilt/bin/RELEASEX64_OVMF.fd,readonly=on ",
            "-no-reboot -no-shutdown"
        }) catch unreachable
        // zig fmt: on
    };

    const run_step = b.addSystemCommand(cmd);

    const run_command = b.step("run-uefi", "Run the UEFI version");
    run_command.dependOn(&run_step.step);

    return run_step;
}

pub fn build(b: *Builder) void {
    const bios_path = std.mem.concat(b.allocator, u8, &[_][]const u8{ b.install_path, "/bin/xeptoboot.bin" }) catch unreachable;

    const bios = build_bios(b);
    const uefi = build_uefi(b);

    const bios_step = run_qemu_bios(b, bios_path);
    bios_step.step.dependOn(&bios.step);

    const uefi_step = run_qemu_uefi(b, b.install_path);
    uefi_step.step.dependOn(&uefi.step);

    b.default_step.dependOn(&uefi_step.step);
}
