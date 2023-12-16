{ lib, buildGoModule, fetchFromGitHub, nixosTests, fetchurl }:

buildGoModule rec {
  pname = "yggdrasil";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "yggdrasil-network";
    repo = "yggdrasil-go";
    rev = "v${version}";
    sha256 = "sha256-LiQKAkFN9JRdl7P3TMIzEeRxKBysidFWMWGGW8jEm/E=";
  };

  vendorHash = "sha256-Bfq8AjOljSg/mWHUwTSKwslukW3aZXOFi4KigUsIogc=";

  patches = [
    (fetchurl {
      url = "https://github.com/yggdrasil-network/yggdrasil-go/pull/1052.patch";
      hash = "sha256-VKsie3IR4fc0XXX+4P25Z297L5XJVjDBEZUDRjT28FQ=";
    })
  ];

  subPackages = [ "cmd/genkeys" "cmd/yggdrasil" "cmd/yggdrasilctl" ];

  ldflags = [
    "-X github.com/yggdrasil-network/yggdrasil-go/src/version.buildVersion=${version}"
    "-X github.com/yggdrasil-network/yggdrasil-go/src/version.buildName=${pname}"
    "-X github.com/yggdrasil-network/yggdrasil-go/src/config.defaultAdminListen=unix:///var/run/yggdrasil/yggdrasil.sock"
    "-s"
    "-w"
  ];

  passthru.tests.basic = nixosTests.yggdrasil;

  meta = with lib; {
    description =
      "An experiment in scalable routing as an encrypted IPv6 overlay network";
    homepage = "https://yggdrasil-network.github.io/";
    license = licenses.lgpl3;
    maintainers = with maintainers; [ ehmry gazally lassulus ];
  };
}
