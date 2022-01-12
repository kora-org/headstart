const std = @import("std");
const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;
const pkgs = @import("deps.zig").pkgs;

fn build_bios(b: *Builder) *std.build.RunStep {
    const out_path = b.pathJoin(&.{ b.install_path, "/bin" });

    const bios = b.addExecutable("stage1.elf", "stage1/stage1.zig");
    bios.setMainPkgPath(".");
    bios.addPackagePath("io", "lib/io.zig");
    bios.addPackagePath("console", "stage1/bios/console.zig");
    bios.addPackagePath("graphics", "stage1/bios/graphics.zig");
    bios.addPackagePath("filesystem", "stage1/bios/filesystem.zig");
    bios.addPackagePath("allocator", "stage1/bios/allocator.zig");
    bios.addAssemblyFile("stage1/bios/entry.s");
    bios.setOutputDir(out_path);

    const features = std.Target.x86.Feature;
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;
    disabled_features.addFeature(@enumToInt(features.mmx));
    disabled_features.addFeature(@enumToInt(features.sse));
    disabled_features.addFeature(@enumToInt(features.sse2));
    disabled_features.addFeature(@enumToInt(features.avx));
    disabled_features.addFeature(@enumToInt(features.avx2));

    enabled_features.addFeature(@enumToInt(features.soft_float));
    bios.code_model = .kernel;

    bios.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.i386,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    });

    bios.setBuildMode(b.standardReleaseOptions());
    bios.setLinkerScriptPath(.{ .path = "stage1/bios/linker.ld" });
    pkgs.addAllTo(bios);
    bios.install();

    const bin = b.addInstallRaw(bios, "stage1.bin", .{});

    // zig fmt: off
    const bootsector = b.addSystemCommand(&[_][]const u8{
        "nasm", "-Ox", "-w+all", "-fbin", "stage0/bootsect.s", "-Istage0",
        "-o", out_path, "/stage0.bin",
    });
    // zig fmt: on
    bootsector.step.dependOn(&bin.step);

    // zig fmt: off
    const append = b.addSystemCommand(&[_][]const u8{
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "cat ",
            out_path, "/stage0.bin ",
            out_path, "/stage1.bin ",
            ">", out_path, "/xeptoboot.bin",
        }) catch unreachable,
    });
    // zig fmt: on
    append.step.dependOn(&bootsector.step);

    const bios_step = b.step("bios", "Build the BIOS version");
    bios_step.dependOn(&append.step);

    return append;
}

fn build_uefi(b: *Builder) *std.build.LibExeObjStep {
    const out_path = b.pathJoin(&.{ b.install_path, "/bin" });

    const uefi = b.addExecutable("xeptoboot", "stage1/uefi/entry.zig");
    uefi.setMainPkgPath(".");
    uefi.addPackagePath("io", "lib/io.zig");
    uefi.addPackagePath("console", "stage1/uefi/console.zig");
    uefi.addPackagePath("graphics", "stage1/uefi/graphics.zig");
    uefi.addPackagePath("filesystem", "stage1/uefi/filesystem.zig");
    uefi.addPackagePath("allocator", "stage1/uefi/allocator.zig");
    uefi.setOutputDir(out_path);

    const features = std.Target.x86.Feature;
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;
    disabled_features.addFeature(@enumToInt(features.mmx));
    disabled_features.addFeature(@enumToInt(features.sse));
    disabled_features.addFeature(@enumToInt(features.sse2));
    disabled_features.addFeature(@enumToInt(features.avx));
    disabled_features.addFeature(@enumToInt(features.avx2));

    enabled_features.addFeature(@enumToInt(features.soft_float));
    uefi.code_model = .kernel;

    uefi.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.uefi,
        .abi = Target.Abi.msvc,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    });

    uefi.setBuildMode(b.standardReleaseOptions());
    pkgs.addAllTo(uefi);
    uefi.install();

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
        "-machine", "accel=kvm:whpx:tcg",
        "-no-reboot", "-no-shutdown",
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
            "cp ", dir, "/bin/xeptoboot.efi ", dir, "/efi-root/EFI/BOOT/BOOTX64.EFI && ",
            "cp ", dir, "/../xeptoboot.zzz.example ", dir, "/efi-root/xeptoboot.zzz && ",
            "qemu-system-x86_64 ",
            // This doesn't work for some reason
            // "-drive if=none,format=raw,media=disk,file=fat:rw:", dir, "/efi-root ",
            "-hda fat:rw:", dir, "/efi-root ",
            "-debugcon stdio ",
            "-vga virtio ",
            "-m 4G ",
            "-machine q35,accel=kvm:whpx:tcg ",
            "-drive if=pflash,format=raw,unit=0,file=external/ovmf-prebuilt/bin/RELEASEX64_OVMF.fd,readonly=on ",
            "-no-reboot -no-shutdown",
        }) catch unreachable,
        // zig fmt: on
    };

    const run_step = b.addSystemCommand(cmd);

    const run_command = b.step("run-uefi", "Run the UEFI version");
    run_command.dependOn(&run_step.step);

    return run_step;
}

pub fn build(b: *Builder) void {
    const bios_path = b.pathJoin(&.{b.install_path, "/bin/xeptoboot.bin"});

    const bios = build_bios(b);
    const uefi = build_uefi(b);

    const bios_step = run_qemu_bios(b, bios_path);
    bios_step.step.dependOn(&bios.step);

    const uefi_step = run_qemu_uefi(b, b.install_path);
    uefi_step.step.dependOn(&uefi.step);

    b.default_step.dependOn(&uefi_step.step);
}
