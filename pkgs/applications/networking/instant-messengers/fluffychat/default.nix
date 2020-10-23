{ lib
, fetchFromGitLab
, flutter
}:

flutter.mkFlutterApp rec {
  pname = "fluffychat";
  version = "0.42.3";

  src = fetchFromGitLab {
    owner = "famedly";
    repo = "fluffychat";
    rev = "v${version}";
    hash = "sha256-YEaV72C/bflfsLhMT2jJ3FECJaEQpyu8A23HfN2VzZ4=";
  };

  vendorHash = "sha256-MlIVp7n9mJUwgFpDsxnldk3OhUolSSJB0ACfnRYcGAE=";
}
