{ lib, buildPythonPackage, fetchPypi, pythonOlder
, aiohttp, webargs, apispec, jinja2
}:

buildPythonPackage rec {
  pname = "aiohttp-apispec";
  version = "2.2.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0hhlmh3mc3xg68znsxyhypb5k12vg59yf72qkyw6ahg8zy3qfz2m";
  };

  disabled = pythonOlder "3.0";

  propagatedBuildInputs = [ aiohttp webargs apispec jinja2 ];

  doCheck = false;

  meta = with lib; {
    description = "Build and document REST APIs with aiohttp and apispec";
    homepage = "https://github.com/maximdanilchenko/aiohttp-apispec/";
    license = licenses.mit;
  };
}
