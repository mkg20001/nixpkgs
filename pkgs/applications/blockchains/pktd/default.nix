{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule {
  pname = "pktd";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "pkt-cash";
    repo = "pktd";
    rev = "bd3839cc6ccea56ec4e745f0180d9fcf95128567";
    sha256 = "iySRxBIpd7lFjiykPJfNfigw//bam/yWpo4yrlvmNhA=";
    fetchSubmodules = false;
  };

  vendorSha256 = "sha256-jHHvf/VqqUp7YxVGkT36lMtxxpv9ZDdXXJ/nRp3rgdQ=";
  
  subPackages = [ "." "pktwallet" "cmd/btcctl" ];
}
