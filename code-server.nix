{ pkgs ? import <nixpkgs> { overlays = [ (import ./overlay.nix) ]; } }:

let
  # define the nix user UID and GID
  uid = "1000";
  gid = "100";

  envs = pkgs.lib.fileset.toSource {
    root = ./.;
    fileset = ./envs;
  };

  # the /etc/profile script will be executed by the shell starting code-server
  profile = pkgs.runCommand "profile" { } ''
    mkdir -p $out/etc
    cat >> $out/etc/profile << EOF
    # ensure necessary PATH and environment settings for nix
    source /etc/profile.d/nix.sh
    EOF
    chmod +x $out/etc/profile
    '';

  entryPoint = pkgs.writeScript "entrypoint.sh" (builtins.readFile ./entrypoint.sh);

in pkgs.dockerTools.buildImage {
  inherit uid;
  inherit gid;

  name = "code-server";
  tag = "latest";

  # build a base image with bash, core linux tools, nix tools, and certificates
  copyToRoot = pkgs.buildEnv {
    name = "env";
    pathsToLink = [ "/bin" "/etc" "/lib" "/lib64" "/envs" ];
    paths =

      # dockerTools helper packages
      (with pkgs.dockerTools; [
        caCertificates usrBinEnv binSh
      ]) ++

      # minimal set of common shell requirements
      (with pkgs; [
        profile iana-etc bashInteractive busybox nix
      ]) ++

      # development environment
      (with pkgs; [
        git openssl glibc zlib stdenv.cc.cc.lib code-server
      ]) ++

      # example development toolkits
      [ envs ];
  };

  # set the entrypoint, user working folder, certificates env var
  # mount the home directory volume if it is used for persistence
  config = {
    # container will run as nix user
    WorkingDir = "/home/nix";
    Volumes = { "/home/nix" = { }; };
    Volumes = { "/certs" = { }; };
    User = "nix";

    # load the nix scripts at startup so that PATH is set
    Cmd = [ "/bin/bash" ];
    Entrypoint = [ entryPoint ];
    ExposedPorts = {
      "8443/tcp" = {};
      "8080/tcp" = {};
    };

    # other common environment variables
    Env = [
      "PAGER=cat"
      "USER=nix"
      "NIX_PATH=nixpkgs=channel:nixos-unstable"
      "NIX_ENFORCE_PURITY=0"
      "LD_LIBRARY_PATH=/lib"
    ];
  };

  # finalize the image building by adding necessary components to get
  # a functional nix environment: nixbld group, users, and nix.conf
  runAsRoot = ''
    #!${pkgs.runtimeShell}
    ${pkgs.dockerTools.shadowSetup}

    # create the necessary groups
    groupadd -g ${gid} users

    # create the nix user
    useradd -m -u ${uid} -g ${gid} -s /bin/bash -G users nix

    # configure nix
    mkdir -p /etc/nix && cat > /etc/nix/nix.conf << EOF
    experimental-features = nix-command flakes
    EOF

    # ensure tmp exists with correct permissions
    mkdir -p /tmp
    chmod 1777 /tmp

    # allow binaries to run without patching
    ln -sf ${pkgs.glibc}/lib64/ld-linux-x86-64.so.* /lib64
  '';
}
