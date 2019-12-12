let
  toTOMLInner = { data, path }:
    if builtins.isAttrs data then
      builtins.concatMap iter (builtins.attrNames set)
    else if builtins.isFloat then
      builtins.toString data
    else if builtins.isInt then
      builtins.toString data
    else if builtins.isNull then
      "null"
    else if builtins.isString then
      data # TODO: escape
    else if builtins.isBool then
      if data then "true" else "false"
    else if builtins.isFunction then
      builtins.throw "Can't convert a function to a string"
    else if builtins.isList then
    else if builtins.isPath then
      builtins.toString data # TODO: escape
    else builtins.throw "Not any valid data-type";

  toTOML = data:
    if builtins.isAttrs data then
      toTOMLInner { inherit data; path = []; }
    else
      builtins.throw "Must be of type attrs";
in
{
  testData = {
    sub = {
      sub2 = {
        e = true;
      };
    };

    e = true;
  };
}
