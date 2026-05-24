{
  lib,
  stdenvNoCC,
  bash,
  # Each consumer overrides this with the service name mac-mgmt should manage.
  # The default placeholder fails loudly at build time so a forgotten override
  # surfaces immediately instead of silently shimming `systemctl ... unset`.
  serviceName ? "UNSET-OVERRIDE-ME",
}:

stdenvNoCC.mkDerivation {
  pname = "mac-mgmt-systemctl-shim-${serviceName}";
  version = "0.1.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    substitute ${./systemctl.sh} $out/bin/systemctl \
      --replace-fail '@bash@' '${bash}/bin/bash' \
      --replace-fail '@serviceName@' ${lib.escapeShellArg serviceName}
    chmod +x $out/bin/systemctl
    runHook postInstall
  '';

  passthru = { inherit serviceName; };

  meta = {
    description = "systemctl drop-in that routes calls to `mac-mgmt systemctl ... ${serviceName}`";
    longDescription = ''
      A tiny `systemctl` binary that rewrites every invocation as
      `mac-mgmt systemctl <args> ${serviceName}`. Designed to be prepended
      to the PATH of a wrapped consumer (openclaw, hermes-agent, ...) so
      the consumer's existing systemd calls are silently delegated to
      mac-mgmt for centralised service management.

      Override `serviceName` per consumer:

        (mac-mgmt-systemctl-shim.override { serviceName = "openclaw"; })
    '';
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "systemctl";
    maintainers = with lib.maintainers; [ mkg20001 ];
  };
}
