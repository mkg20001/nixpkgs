{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  hermes-agent,
}:
let
  # hermesVenv is a Python venv (built by hermes-agent's uv2nix flake) that
  # already contains every runtime dep both packages need: pyyaml for the
  # WebUI, plus the `agent` and `run_agent` modules the WebUI imports at
  # module load (see api/providers.py line 157).
  hermesVenv = hermes-agent.hermesVenv;
  # hermesVenv is a uv2nix mkVirtualEnv result, not a pkgs.python wrapper, so it
  # has no `.python` attribute. Resolve site-packages by globbing instead.
  agentSitePackages = "${hermesVenv}/lib/python3.12/site-packages";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hermes-webui";
  version = "0.51.124";

  src = fetchFromGitHub {
    owner = "nesquena";
    repo = "hermes-webui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-n/58Gy67v+974AA+sloIB4eZ0o4S5O2I9kxK5vAO2TM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d $out/share/hermes-webui
    cp -r api static scripts $out/share/hermes-webui/
    install -m 0644 bootstrap.py server.py mcp_server.py requirements.txt \
      $out/share/hermes-webui/

    makeWrapper ${hermesVenv}/bin/python3 $out/bin/hermes-webui \
      --add-flags "$out/share/hermes-webui/bootstrap.py --no-browser --skip-agent-install" \
      --set-default HERMES_WEBUI_PYTHON ${hermesVenv}/bin/python3 \
      --set-default HERMES_WEBUI_AGENT_DIR ${agentSitePackages}

    runHook postInstall
  '';

  meta = {
    description = "Lightweight web UI for the Hermes Agent (three-panel sessions/chat/workspace)";
    homepage = "https://github.com/nesquena/hermes-webui";
    changelog = "https://github.com/nesquena/hermes-webui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "hermes-webui";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = [ ];
  };
})
