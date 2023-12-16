{ lib, buildGoModule, fetchFromGitHub, nixosTests, fetchurl }:

buildGoModule rec {
  pname = "yggdrasil";
  version = "0.5.4";

  src = fetchFromGitHub {
    owner = "yggdrasil-network";
    repo = "yggdrasil-go";
    rev = "v${version}";
    sha256 = "sha256-or+XTt8V/1BuLSJ53w1aKqJfx3Pka6VmC4TpvpP83+0=";
  };

  patches = [
    (fetchurl {
      url = "https://github.com/yggdrasil-network/yggdrasil-go/pull/1052.patch";
      hash = "sha256-aEd0St56ASinSmQsGpD62q56iy5BIWbY2pVpT4C1CG4=";
    })
  ];

  vendorHash = "sha256-K7VJ+1x7+DgdwTjEgZ7sJ7SaCssBg+ukQupJ/1FN4F0=";

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
