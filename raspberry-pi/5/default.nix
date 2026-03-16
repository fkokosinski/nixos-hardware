{
  lib,
  pkgs,
  config,
  ...
}:
{
  nixpkgs.overlays = [
    (import ./overlay.nix)
  ];

  boot.loader.grub.enable = lib.mkDefault false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;

  boot = {
    kernelPackages = lib.mkDefault (
      pkgs.linuxPackagesFor (
        pkgs.callPackage ../common/kernel.nix {
          rpiVersion = 5;
        }
      )
    );
    initrd.availableKernelModules = [
      "nvme"
      "usbhid"
      "usb-storage"
    ];
  };

  hardware.deviceTree = {
    overlays = [
      {
        name = "pciex1-on";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
          	compatible = "brcm,bcm2712";

          	fragment@0 {
          		target = <&pciex1>;
          		__overlay__ {
          		  status = "okay";

              	/* Enable L1 sub-state support */
          			brcm,clkreq-mode = "default";
              	/* Disable ASPM L0s */
          			aspm-no-l0s;
              	/* Use RC MSI target instead of MIP MSIx target */
          			msi-parent = <&pciex1>;
                /* enable gen 3 */
          			max-link-speed = <3>;

              	/*
              	 * Shift the start of the 32bit outbound window to 2GB,
              	 * so there are no BARs starting at 0x0. Expand the 64bit
              	 * outbound window to use the spare 2GB.
              	 */
          			#address-cells = <3>;
          			#size-cells = <2>;
          			ranges = <0x02000000 0x00 0x80000000
          				  0x1b 0x80000000
          				  0x00 0x7ffffffc>,
          				 <0x43000000 0x04 0x00000000
          				  0x18 0x00000000
          				  0x03 0x80000000>;
          		};
          	};

          	__overrides__ {
          		l1ss = <0>, "+0";
          		no-l0s = <0>, "+1";
          		no-mip = <0>, "+2";
          		mmio-hi = <0>, "+3";
          	};
          };
        '';
      }
      {
        name = "fan-on";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
          	compatible = "brcm,bcm2712";

          	fragment@0 {
          		target = <&fan>;
          		__overlay__ {
          		  status = "okay";
            	};
          	};

          	fragment@1 {
          		target = <&rp1_pwm1>;
          		__overlay__ {
          		  status = "okay";
            	};
            };
          };
        '';
      }
    ];
  };

  # Needed for Xorg to start (https://github.com/raspberrypi-ui/gldriver-test/blob/master/usr/lib/systemd/scripts/rp1_test.sh)
  # This won't work for displays connected to the RP1 (DPI/composite/MIPI DSI), since I don't have one to test.
  services.xserver.extraConfig = ''
    Section "OutputClass"
      Identifier "vc4"
      MatchDriver "vc4"
      Driver "modesetting"
      Option "PrimaryGPU" "true"
    EndSection
  '';

  assertions = [
    {
      assertion = (lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.1.54");
      message = "The Raspberry Pi 5 requires a newer kernel version (>=6.1.54). Please upgrade nixpkgs for this system.";
    }
  ];
}
