{
  description = "Windows Server 2025 disk image build environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      installIso = pkgs.fetchurl {
        name = "winserver2025.iso";
        url = "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso";
        hash = "sha256-ewUlc7p4lMmSTj6HunMszTVNGMt1qIPvqbkA6hJb/VE=";
      };

      nopromptIso = pkgs.runCommand "winserver2025-noprompt.iso" {
        nativeBuildInputs = [ pkgs._7zz pkgs.xorriso ];
      } ''
        bash ${./scripts/make-noprompt-iso.sh} ${installIso} "$out"
      '';

      virtioIso = pkgs.fetchurl {
        name = "virtio-win-0.1.302.iso";
        url = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.302-1/virtio-win-0.1.302.iso";
        hash = "sha256-MD965A2tSV1q5HT9xXHfWJWKTbxcN6Ui2A+aIDhnlJ0=";
      };

      firmware = pkgs.OVMF.fd;

      ciImage = pkgs.runCommand "nylon-ci-win2025" {
        nativeBuildInputs = [ pkgs.qemu pkgs.xorriso pkgs.zstd ];
        requiredSystemFeatures = [ "kvm" ];
        preferLocalBuild = true;
        INSTALL_ISO = "${nopromptIso}";
        VIRTIO_ISO = "${virtioIso}";
        OVMF_CODE = "${firmware}/FV/OVMF_CODE.fd";
        OVMF_VARS = "${firmware}/FV/OVMF_VARS.fd";
      } ''
        cp -r ${./unattend} ./unattend
        BUILD_ROOT="$PWD" bash ${./build.sh}
        mkdir -p "$out"
        mv build/nylon-ci-win2025.qcow2.zst "$out/"
      '';
    in
    {
      packages.${system} = {
        winserver2025-iso = installIso;
        winserver2025-noprompt-iso = nopromptIso;
        virtio-win-iso = virtioIso;
        nylon-ci-win2025 = ciImage;
        default = nopromptIso;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.qemu
          pkgs.xorriso
          pkgs.zstd
          (pkgs.ansible.override { windowsSupport = true; })
          firmware
        ];

        INSTALL_ISO = "${nopromptIso}";
        VIRTIO_ISO = "${virtioIso}";
        OVMF_CODE = "${firmware}/FV/OVMF_CODE.fd";
        # Copy this template to a writable file for each VM's UEFI variables.
        OVMF_VARS = "${firmware}/FV/OVMF_VARS.fd";
      };
    };
}
