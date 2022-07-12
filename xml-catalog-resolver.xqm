(:~ 
 : This module provides an XML Resolver for OASIS XML Catalogs entirely in XQuery.
 : Use this module to resolve the location a DTD specified in a DOCTYPE before parsing XML.
 : 
 : Tested with BaseX version 9.7.3. 
 : May work in other XQuery processors.
 :
 : @author Vincent Lizzi
 : @see https://github.com/vincentml/xml-catalog-resolver
 : @see https://basex.org/
 : @see https://docs.basex.org/wiki/Options#CATFILE
 : @see https://xmlresolver.org/
 : @see https://xerces.apache.org/xml-commons/components/resolver/resolver-article.html
 : @see http://www.sagehill.net/docbookxsl/WriteCatalog.html
 :)
module namespace resolver = "xml-catalog-resolver";

import module namespace file = "http://expath.org/ns/file";

(:~ Namespace for OASIS XML Catalogs :)
declare namespace catalog = "urn:oasis:names:tc:entity:xmlns:xml:catalog";

(:~ regular expression to match space characters in XML DOCTYPE :)
declare variable $resolver:space := '[&#x20;&#x9;&#xD;&#xA;]+';

(:~ regular expression to match the beginning of an XML DOCTYPE up to the root element name :)
declare variable $resolver:doctype_start := '(<!DOCTYPE' || $resolver:space || '[:_A-Za-z&#xC0;-&#xD6;&#xD8;-&#xF6;&#xF8;-&#x2FF;&#x370;-&#x37D;&#x37F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;&#x10000;-&#xEFFFF;][:_\.\-0-9A-Za-z&#xb7;&#x0300;-&#x036F;&#x203F;-&#x2040;&#xC0;-&#xD6;&#xD8;-&#xF6;&#xF8;-&#x2FF;&#x370;-&#x37D;&#x37F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;&#x10000;-&#xEFFFF;]*' || $resolver:space || ')';


(:~ 
 : Parse XML Catalog and return a list of all catalog entries with URIs expanded.
 : URI expansion will be based on file paths relative to the XML Catalog file or 
 : the @xml:base attribute if present in the XML Catalog. 
 :
 : @param $catfile Semicolon-separated list of XML catalog files. Absolute file path works best. 
 :
 : @return Sequence of all entries from all XML Catalogs that were loaded.
 :)
declare function resolver:catalogEntries($catfile as xs:string) as element()* {
  for $cat in tokenize($catfile, ';\s*') return
  let $catalog := (# db:dtd false #) (# db:intparse true #) { doc(file:resolve-path($cat)) }
  let $catparent := file:parent($cat)
  for $e in $catalog//*
  let $base := 
    if ($e/ancestor-or-self::catalog:*/@xml:base) 
    then ($e/ancestor-or-self::catalog:*/@xml:base)[last()]/string() 
    else $catparent
  return typeswitch ($e)
  case 
    element(catalog:system) |
    element(catalog:systemSuffix) |
    element(catalog:public) |
    element(catalog:uri) |
    element(catalog:uriSuffix)
    return resolver:expandUri($e, $base)
  case 
    element(catalog:nextCatalog) | 
    element(catalog:delegatePublic) |
    element(catalog:delegateSystem) |
    element(catalog:delegateURI)
    return resolver:catalogEntries(file:resolve-path($e/@catalog, $base))
  case
    element(catalog:rewriteSystem) |
    element(catalog:rewriteURI)
    return $e
  default return ()
};


declare %private function resolver:expandUri($entry as element(), $base as xs:string) as element() {
  copy $c := $entry
  modify replace value of node $c/@uri with file:path-to-uri(file:resolve-path($entry/@uri, $base))
  return $c
};


declare %private function resolver:regexEscapeString($string as xs:string) as xs:string {
  $string => replace("\\", "\\\\")
};


(:~ 
 : Resolve XML DOCTYPE using XML Catalog. 
 : The system literal URI in the DOCTYPE will be replaced with location provided by the XML Catalog.
 : The replacement strategy uses regular expressions that closely adhere to the grammar that is defined in the W3C Recommendation.
 : No attempt has been made to skip text that looks like a DOCTYPE but isn't, such as a DOCTYPE that is inside a comment.
 :
 : @param $xml XML as a string
 : @param $catfile Semicolon-separated list of XML catalog files. Absolute file path works best. 
 :
 : @return XML string with DOCTYPE resolved using the XML Catalog. If no mapping is found then the string is returned unchanged.
 : 
 : @see https://www.w3.org/TR/xml/#NT-doctypedecl
 :)
declare function resolver:resolveDOCTYPE($xml as xs:string, $catfile as xs:string) as xs:string {
  let $catalog := resolver:catalogEntries($catfile)
    
  return fold-left($catalog, $xml, function($x, $c) {
    typeswitch ($c)
    case element(catalog:public) return 
      let $public := resolver:regexEscapeString($c/@publicId)
      let $match := $resolver:doctype_start || 'PUBLIC'  || $resolver:space || '("' || $public || '"|' || "'" || $public || "')"  || $resolver:space || "('[^']*'|" || '"[^"]*")'
      let $replace := '$1PUBLIC $2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:system) return
      let $system := resolver:regexEscapeString($c/@systemId)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "('" || $system || "'|""" || $system || """)"
      let $replace := '$1$2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:systemSuffix) return
      let $system := resolver:regexEscapeString($c/@systemIdSuffix)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "('[^']*" || $system || "'|""[^""]*" || $system || """)"
      let $replace := '$1$2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:rewriteSystem) return
      let $system := resolver:regexEscapeString($c/@systemIdStartString)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "(?:'" || $system || "([^']*)'|""" || $system || "([^""]*)"")"
      let $replace := '$1$2 "' || $c/@rewritePrefix || '$3$4"'
      return replace($x, $match, $replace)

    default return $x
  })
};


(:~ 
 : Resolve a URI using XML Catalog.
 : 
 : @param $uri The URI to resolve
 : @param $catfile Semicolon-separated list of XML catalog files. Absolute file path works best.
 : 
 : @return The resolved URI. If no mapping is found in the XML Catalog the URI will be returned unchanged.
 :)
declare function resolver:resolveURI($uri as xs:string, $catfile as xs:string) as xs:string {
  let $catalog := resolver:catalogEntries($catfile)
  return fold-left($catalog, $uri, function($x, $c) {
    typeswitch ($c)
    case element(catalog:uri) return 
      if ($c/@name eq $uri) then string($c/@uri) else $x
    case element(catalog:uriSuffix) return
      if (ends-with($x, $c/@uriSuffix)) 
      then string($c/@uri) 
      else $x
    case element(catalog:rewriteURI) return
      if (starts-with($x, $c/@uriStartString)) 
      then concat($c/@rewritePrefix, substring-after($x, $c/@uriStartString)) 
      else $x
    default return $x
  })
};


(:~ 
 : Parse XML using XML Catalog
 :
 : @param $xml an XML string or file path to the XML file
 : @param $catfile Semicolon-separated list of XML catalog files. Absolute file path works best.
 :
 : @return parsed XML document
 :)
declare function resolver:parse-xml($xml as xs:string, $catfile as xs:string) as document-node() {
  let $temp := file:create-temp-file('catalog-resolver', '.xml')
  let $raw := if ($xml castable as xs:anyURI) then unparsed-text($xml) else $xml
  let $resolved := resolver:resolveDOCTYPE($raw, $catfile)
  return (
    file:write-text($temp, $resolved),
    (# db:dtd true #) (# db:intparse false #) (# db:chop false #) { doc($temp) },
    file:delete($temp)
  )
};


(:~
 : Modifies a DOCTYPE to remove a PUBLIC or SYSTEM reference to an external DTD.
 : If the DOCTYPE contains an internal DTD then the internal part will remain intact.
 : The intention for this function is to prevent loading an external DTD when it is
 : known that the DTD is not needed, and mainly for parsing XML Catalogs.
 : With BaseX parsing options set to INTPARSE=true and DTD=false this function is not needed.
 :
 : @param $xml XML as a string
 :
 : @return XML string with the DOCTYPE modified. If no PUBLIC or SYSTEM reference is present then the string is returned unchanged.
 : 
 : @see https://www.w3.org/TR/xml/#NT-doctypedecl
 : @see https://docs.basex.org/wiki/Options#INTPARSE
 : @see https://docs.basex.org/wiki/Options#DTD
 :)
declare function resolver:removeExternalDTD($xml as xs:string) as xs:string {
  let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "(?:'[^']*'|""[^""]*"")"
  return replace($xml, $match, "$1")
};


declare %unit:test function resolver:test_catalogEntries() {
  let $base := file:base-dir()
  let $catfile := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  let $entries := resolver:catalogEntries($catfile)
  return (
    prof:dump($catfile, 'catfile: '),
    prof:dump($entries, 'entries: '),
    unit:assert-equals($entries[1], <catalog:system systemId="https://example.org/example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[2], <catalog:systemSuffix systemIdSuffix="example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[3], <catalog:public publicId="-//EXAMPLE//DTD v1//EN" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[4], <catalog:uri name="https://example.org/example-v1.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[5], <catalog:uriSuffix uriSuffix="example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[6], <catalog:system systemId="http://example.org/example2.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[7], <catalog:system systemId="http://example.org/example3.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[8], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[9], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[10], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[11], <catalog:rewriteSystem systemIdStartString="C:\" rewritePrefix="file:///C:/path/"/>),
    unit:assert-equals($entries[12], <catalog:rewriteURI uriStartString="C:\" rewritePrefix="file:///C:/path/"/>),
    unit:assert-equals($entries[13], <catalog:public publicId="-//EXAMPLE//DTD v2//EN" uri="file:///C:/base1/example.dtd"/>),
    unit:assert-equals($entries[14], <catalog:public publicId="-//EXAMPLE//DTD v3//EN" uri="file:///C:/base2/example.dtd" xml:base="file:///C:/base2/"/>)
  )
};

declare %unit:test function resolver:test_resolveDOCTYPE() {
  let $base := file:base-dir()
  let $catfile := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  return (
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "not-mapped"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'public'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//DTD v1//EN'' ''not-mapped''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//DTD v1//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'public'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "https://example.org/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' ''https://example.org/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "https://example.org/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM ''https://example.org/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "path/to/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' ''path/to/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "path/to/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM ''path/to/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'systemSuffix'),

    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "C:\another.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "file:///C:/path/another.dtd"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'rewriteSystem'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "C:\another.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "file:///C:/path/another.dtd"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catfile)
    return unit:assert-equals($result, $exp, 'rewriteSystem')
    
  )
};


declare %unit:test function resolver:test_resolveURI() {
  let $base := file:base-dir()
  let $catfile := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  return (
    let $uri := "https://example.org/example-v1.dtd"
    let $result := resolver:resolveURI($uri, $catfile)
    return unit:assert-equals($result, $exampledtd, "uri"),
    
    let $uri := "path/to/example.dtd"
    let $result := resolver:resolveURI($uri, $catfile)
    return unit:assert-equals($result, $exampledtd, "uriSuffix"),
    
    let $uri := "C:\file.txt"
    let $result := resolver:resolveURI($uri, $catfile)
    return unit:assert-equals($result, "file:///C:/path/file.txt", "rewriteURI"),
    
    let $uri := "http://not-mapped.org/"
    let $result := resolver:resolveURI($uri, $catfile)
    return unit:assert-equals($result, $uri, "not mapped")
  )
};


declare %unit:test function resolver:test_parse-xml() {
  let $base := file:base-dir()
  let $catfile := file:resolve-path("catalog1.xml", $base)
  let $examplexml := file:resolve-path("example.xml", $base)
  let $result := resolver:parse-xml($examplexml, $catfile)
  return unit:assert-equals($result, document{<example att="default">expansion from external DTD</example>})
};


declare %unit:test function resolver:test_removeExternalDTD() {
  let $example := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog PUBLIC "-//OASIS//DTD Entity Resolution XML Catalog V1.0//EN" "http://www.oasis-open.org/committees/entity/release/1.0/catalog.dtd" []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog  []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected),
  
  let $example := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog SYSTEM "http://www.oasis-open.org/committees/entity/release/1.0/catalog.dtd" []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog  []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected),
  
  let $example := '<?xml version="1.0" encoding="UTF-8"?><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected)
};
