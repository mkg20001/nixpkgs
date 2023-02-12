import ./make-test-python.nix ({ pkgs, lib, qemu ? true, nftables ? false, apparmor ? false, ... } :

with lib;

let
  lxd-image = import ../release.nix {
    configuration = {
      # Building documentation makes the test unnecessarily take a longer time:
      documentation.enable = lib.mkForce false;

      # Our tests require `grep` & friends:
      environment.systemPackages = with pkgs; [ busybox ];
    };
  };

  lxd-image-metadata = lxd-image.lxdMeta.${pkgs.stdenv.hostPlatform.system};
  lxd-image-rootfs = lxd-image.lxdImage.${pkgs.stdenv.hostPlatform.system};

in {
  name = "lxd${optionalString nftables "-nftables"}${optionalString apparmor "-apparmor"}${optionalString (!qemu) "-no-qemu"}";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ patryk27 ifd3f mkg20001 ];
  };

  nodes.machine = { lib, ... }: {
    virtualisation = {
      diskSize = 4096;

      # Since we're testing `limits.cpu`, we've gotta have a known number of
      # cores to lean on
      cores = 2;

      # Ditto, for `limits.memory`
      memorySize = 512;

      lxc.lxcfs.enable = true;
      lxd.enable = true;
      lxd.enableQemu = qemu;
    };

    security.apparmor.enable = apparmor;
    networking = optionalAttrs nftables {
      nftables.enable = true;
      firewall.trustedInterfaces = [ "lxdbr0" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("sockets.target")
    machine.wait_for_unit("lxd.service")
    machine.wait_for_file("/var/lib/lxd/unix.socket")

    # It takes additional second for lxd to settle
    machine.sleep(1)

    # lxd expects the pool's directory to already exist
    machine.succeed("mkdir /var/lxd-pool")

    machine.succeed(
        "cat ${./common/lxd/config.yaml} | lxd init --preseed"
    )

    ${optionalString nftables ''
    machine.wait_for_unit("network.target")

    with subtest("When nftables is enabled, lxd doesn't depend on iptables anymore"):
        machine.succeed("lsmod | grep nf_tables")
        machine.fail("lsmod | grep ip_tables")
    ''}

    machine.succeed(
        "lxc image import ${lxd-image-metadata}/*/*.tar.xz ${lxd-image-rootfs}/*/*.tar.xz --alias nixos"
    )

    ${optionalString qemu ''
    machine.succeed(
        "lxc image import ${./lxd-qemu.qcow2} ${./meta-lxd-qemu.tar.xz} --alias nixos"
    )

    with subtest("Qemu container works"):
        machine.succeed("lxd launch nixos vm --vm")
        machine.sleep(5)
        machine.succeed("echo true | lxc exec vm /bin/bash -")
        machine.succeed("lxc delete -f vm")
    ''}

    with subtest("Container can be managed"):
        machine.succeed("lxc launch nixos container")
        machine.sleep(5)
        machine.succeed("echo true | lxc exec container /run/current-system/sw/bin/bash -")
        machine.succeed("lxc exec container true")
        machine.succeed("lxc delete -f container")

    with subtest("Container is mounted with lxcfs inside"):
        machine.succeed("lxc launch nixos container")
        machine.sleep(5)

        ## ---------- ##
        ## limits.cpu ##

        machine.succeed("lxc config set container limits.cpu 1")
        machine.succeed("lxc restart container")
        machine.sleep(5)

        assert (
            "1"
            == machine.succeed("lxc exec container grep -- -c ^processor /proc/cpuinfo").strip()
        )

        machine.succeed("lxc config set container limits.cpu 2")
        machine.succeed("lxc restart container")
        machine.sleep(5)

        assert (
            "2"
            == machine.succeed("lxc exec container grep -- -c ^processor /proc/cpuinfo").strip()
        )

        ## ------------- ##
        ## limits.memory ##

        machine.succeed("lxc config set container limits.memory 64MB")
        machine.succeed("lxc restart container")
        machine.sleep(5)

        assert (
            "MemTotal:          62500 kB"
            == machine.succeed("lxc exec container grep -- MemTotal /proc/meminfo").strip()
        )

        machine.succeed("lxc config set container limits.memory 128MB")
        machine.succeed("lxc restart container")
        machine.sleep(5)

        assert (
            "MemTotal:         125000 kB"
            == machine.succeed("lxc exec container grep -- MemTotal /proc/meminfo").strip()
        )

        machine.succeed("lxc delete -f container")
  '';
})
