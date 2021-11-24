{ lib
, fetchFromGitLab
, flutter
}:

flutter.mkFlutterApp rec {
  pname = "fluffychat";
  # 42.3 is latest
  version = "0.41.2";

  src = fetchFromGitLab {
    owner = "famedly";
    repo = "fluffychat";
    rev = "v${version}";
    hash = "sha256-3eAManOo+kzg16difcTRwWIFDU2hkxZDnLl7jr0b40M=";
  };

  vendorHash = "sha256-sb59Y2lRD9T97u5sL7fWUedfrGfF3jI+4j8PvGh72BU=";
}
