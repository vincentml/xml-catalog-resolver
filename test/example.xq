import module namespace resolver = "xml-catalog-resolver" at "../xml-catalog-resolver.xqm";

declare variable $file external := "example.xml";

let $catfile := 
  if (db:option("catfile") ne "") 
  then db:option("catfile")
  else file:resolve-path("catalog1.xml", file:base-dir())
let $xml := unparsed-text(file:resolve-path($file, file:base-dir()))
let $resolved := resolver:resolveDOCTYPE($xml, $catfile)
let $parsed := resolver:parse-xml($xml, $catfile)
return ($catfile, $xml, $resolved, $parsed)
