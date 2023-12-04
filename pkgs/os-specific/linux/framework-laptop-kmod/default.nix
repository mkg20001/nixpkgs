{ lib
, stdenv
, linuxPackages
, kernel
}:

stdenv.mkDerivation rec {
  pname = "framework-laptop-kmod ";
  version = "unstable-2023-12-03";

  src = builtins.fetchGit {
    url = "https://github.com/DHowett/framework-laptop-kmod.git";
    ref = "main";
    rev = "d5367eb9e5b5542407494d04ac1a0e77f10cc89d";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernel.makeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    install -D framework_laptop.ko -t $out/lib/modules/${kernel.modDirVersion}/extra
    runHook postInstall
  '';

  meta = with lib; {
    description = "A kernel module that exposes the Framework Laptop (13, 16)'s battery charge limit and LEDs to userspace.";
    homepage = "https://github.com/DHowett/framework-laptop-kmod";
    license = licenses.gpl2;
    maintainers = with maintainers; [ gaykitty ];
    platforms = platforms.linux;
  };
}
