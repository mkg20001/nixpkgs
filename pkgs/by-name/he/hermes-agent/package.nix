# Hermes Agent — flake-compat shim bound to the host nixpkgs.
#
# Upstream ships its build as a flake (uv2nix + pyproject-nix + npm-lockfile-fix);
# rather than vendoring nix/hermes-agent.nix and its helpers, we evaluate the
# flake in place and override only the `nixpkgs` input so the resulting
# derivation builds against this tree's python312/nodejs_22/etc. instead of
# the flake's pinned nixos-unstable.
#
# Bumping: change `tag`, `rev`, and `hash`. If the flake.lock at the new tag
# changes inputs, flake-compat will fetch them via narHash from the lock —
# no further action needed here.
{
  lib,
  fetchFromGitHub,
  stdenv,
  pkgs,
  symlinkJoin,
  makeWrapper,
  mac-mgmt-systemctl-shim,
}:
let
  tag = "v2026.5.16";
  rev = "a91a57fa5a13d516c38b07a141a9ce8a3daabeb0";

  systemctlShim = mac-mgmt-systemctl-shim.override { serviceName = "hermes"; };

  upstreamSrc = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    inherit tag;
    hash = "sha256-d9qhrTy45Q5UsmjapqMHOVi9e+gR9zE8Nq9Z0wObLmc=";
  };

  # Patches:
  # 1. lazy_deps.py — use a mutable overlay venv at $HERMES_HOME/venv instead
  #    of trying to pip-install into the read-only Nix store venv.
  # 2. hermes-agent.nix — add uv to runtimeDeps so the overlay venv installer
  #    has a working package manager on PATH.
  src = pkgs.applyPatches {
    name = "hermes-agent-patched-${tag}";
    src = upstreamSrc;
    patches = [
      ./nix-venv-lazy-deps.patch
      ./nix-add-uv-runtime.patch
    ];
  };

  flake-compat = import (fetchFromGitHub {
    owner = "edolstra";
    repo = "flake-compat";
    rev = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
    hash = "sha256-vNpUSpF5Nuw8xvDLj2KCwwksIbjua2LZCqhV1LNRDns=";
  });

  system = stdenv.hostPlatform.system;

  # Lock-file-driven resolution of every transitive input, lazily fetched.
  # We don't touch `compat.defaultNix.outputs` — those were computed against
  # the flake's own pinned nixpkgs. We just borrow its `inputs` thunks and
  # re-call `flake.outputs` with `nixpkgs` swapped for the host pkgs.
  compat = flake-compat { inherit src; };

  # A flake-shaped facade over the host nixpkgs. flake-parts.lib.mkFlake
  # reads `inputs.nixpkgs.legacyPackages.${system}` to seed each
  # perSystem's `pkgs`, so that is what must be present.
  hostNixpkgs = {
    outPath = pkgs.path;
    inherit lib;
    legacyPackages.${system} = pkgs;
    _type = "flake";
  };

  flake = import (src + "/flake.nix");

  resolvedInputs = compat.defaultNix.inputs // {
    nixpkgs = hostNixpkgs;
  };

  outputs = flake.outputs (resolvedInputs // { self = self'; });

  self' =
    src
    // outputs
    // {
      inherit rev outputs;
      inputs = resolvedInputs;
      shortRev = builtins.substring 0 7 rev;
      sourceInfo = { inherit rev; };
      _type = "flake";
    };

  hermesAgent = outputs.packages.${system}.default;

  # On Linux, prepend the mac-mgmt systemctl shim to PATH for every
  # hermes-* binary so any systemctl call inside the agent is routed to
  # `mac-mgmt systemctl ... hermes`. Skip on Darwin (no systemctl).
  wrapped = symlinkJoin {
    inherit (hermesAgent) name;
    paths = [ hermesAgent ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      for bin in $out/bin/hermes $out/bin/hermes-acp $out/bin/hermes-agent; do
        [ -e "$bin" ] || continue
        wrapProgram "$bin" --prefix PATH : ${lib.makeBinPath [ systemctlShim ]}
      done
    '';
    passthru = hermesAgent.passthru or { };
    inherit (hermesAgent) meta;
  };
in
if stdenv.hostPlatform.isLinux then wrapped else hermesAgent
